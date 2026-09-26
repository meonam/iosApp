import SwiftUI

// MARK: - SHIFT VIEW MODEL (ĐỒNG BỘ 1:1 VỚI SHIFTSCHEDULESCREEN.KT TRÊN ANDROID)
@MainActor
public class ShiftViewModel: ObservableObject {
    public var user: User
    public var companyId: String
    public var idToken: String

    @Published public var currentWeekSchedule: ShiftSchedule? = nil
    @Published public var currentWeekOffset: Int = 0 // 0: Tuần này, -1: Tuần trước, 1: Tuần sau
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId
        self.idToken = idToken
    }

    public var currentWeekId: String {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date()) ?? Date()
        let year = calendar.component(.yearForWeekOfYear, from: targetDate)
        let week = calendar.component(.weekOfYear, from: targetDate)
        return String(format: "%04d-W%02d", year, week)
    }

    public func fetchShiftSchedule() {
        isLoading = true
        errorMessage = nil
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/shift_schedules/\(currentWeekId)"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fields = json["fields"] as? [String: Any] else {
                self.isLoading = false
                self.currentWeekSchedule = ShiftSchedule(id: currentWeekId, companyId: companyId, entries: [])
                return
            }

            // Parse entries map
            var parsedEntries: [ShiftEntry] = []
            for (key, valObj) in fields {
                if key.starts(with: "emp_") || key.starts(with: "ktv_") || key.allSatisfy({ $0.isNumber }) {
                    if let map = (valObj as? [String: Any])?["mapValue"] as? [String: Any],
                       let subFields = map["fields"] as? [String: Any] {
                        var daysMap: [String: String] = [:]
                        for dayKey in ["mon", "tue", "wed", "thu", "fri", "sat", "sun"] {
                            daysMap[dayKey] = FirestoreHelper.getString(subFields[dayKey] as? [String: Any])
                        }
                        let empName = FirestoreHelper.getString(subFields["name"] as? [String: Any])
                        parsedEntries.append(ShiftEntry(employeeId: key, employeeName: empName, days: daysMap))
                    }
                }
            }

            self.currentWeekSchedule = ShiftSchedule(
                id: currentWeekId,
                companyId: companyId,
                entries: parsedEntries
            )
            self.isLoading = false
        }
    }

    public func updateShiftCode(employeeId: String, dayKey: String, newCode: String) {
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/shift_schedules/\(currentWeekId)?updateMask.fieldPaths=\(employeeId).\(dayKey)"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    employeeId: [
                        "mapValue": [
                            "fields": [
                                dayKey: ["stringValue": newCode]
                            ]
                        ]
                    ]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
            self.fetchShiftSchedule()
        }
    }
}
