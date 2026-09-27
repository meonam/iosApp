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
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
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
            if !idToken.isEmpty {
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fields = json["fields"] as? [String: Any] else {
                self.isLoading = false
                self.currentWeekSchedule = ShiftSchedule(id: currentWeekId, companyId: companyId, entries: [])
                return
            }

            var parsedEntries: [ShiftEntry] = []

            // 1. Parse Android 1:1 'entries' array field
            if let entriesObj = fields["entries"] as? [String: Any],
               let arrayVal = entriesObj["arrayValue"] as? [String: Any],
               let values = arrayVal["values"] as? [[String: Any]] {
                for item in values {
                    if let mapVal = item["mapValue"] as? [String: Any],
                       let subFields = mapVal["fields"] as? [String: Any] {
                        let empId = FirestoreHelper.getString(subFields["employeeId"] as? [String: Any])
                        let empName = FirestoreHelper.getString(subFields["employeeName"] as? [String: Any])
                        let maKhuVuc = FirestoreHelper.getString(subFields["maKhuVuc"] as? [String: Any])
                        let donVi = FirestoreHelper.getString(subFields["donVi"] as? [String: Any])
                        
                        var daysMap: [String: String] = [:]
                        if let daysObj = subFields["days"] as? [String: Any],
                           let daysMapVal = daysObj["mapValue"] as? [String: Any],
                           let dayFields = daysMapVal["fields"] as? [String: Any] {
                            for (dayKey, dayCodeVal) in dayFields {
                                let code = FirestoreHelper.getString(dayCodeVal as? [String: Any])
                                if !code.isEmpty {
                                    daysMap[dayKey.lowercased()] = code
                                }
                            }
                        }
                        
                        if !empId.isEmpty || !empName.isEmpty {
                            parsedEntries.append(ShiftEntry(
                                employeeId: empId,
                                employeeName: empName,
                                days: daysMap,
                                maKhuVuc: maKhuVuc,
                                donVi: donVi
                            ))
                        }
                    }
                }
            }

            // 2. Fallback: Parse root emp_... or ktv_... keys if entries array was empty
            if parsedEntries.isEmpty {
                for (key, valObj) in fields {
                    if key.starts(with: "emp_") || key.starts(with: "ktv_") || key.allSatisfy({ $0.isNumber }) {
                        if let map = (valObj as? [String: Any])?["mapValue"] as? [String: Any],
                           let subFields = map["fields"] as? [String: Any] {
                            var daysMap: [String: String] = [:]
                            for dayKey in ["mon", "tue", "wed", "thu", "fri", "sat", "sun"] {
                                let code = FirestoreHelper.getString(subFields[dayKey] as? [String: Any])
                                if !code.isEmpty {
                                    daysMap[dayKey] = code
                                }
                            }
                            let empName = FirestoreHelper.getString(subFields["name"] as? [String: Any])
                            let cleanId = key.replacingOccurrences(of: "emp_", with: "").replacingOccurrences(of: "ktv_", with: "")
                            parsedEntries.append(ShiftEntry(employeeId: cleanId, employeeName: empName.isEmpty ? cleanId : empName, days: daysMap))
                        }
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
        let cleanDayKey = dayKey.lowercased()
        var currentEntries = self.currentWeekSchedule?.entries ?? []
        
        if let idx = currentEntries.firstIndex(where: { $0.employeeId == employeeId }) {
            currentEntries[idx].days[cleanDayKey] = newCode
        } else {
            currentEntries.append(ShiftEntry(
                employeeId: employeeId,
                employeeName: employeeId,
                days: [cleanDayKey: newCode]
            ))
        }
        
        self.currentWeekSchedule?.entries = currentEntries
        saveScheduleEntries(currentEntries, updatedEmpId: employeeId, dayKey: cleanDayKey, newCode: newCode)
    }

    public func addEmployee(employeeId: String, employeeName: String) {
        var currentEntries = self.currentWeekSchedule?.entries ?? []
        guard !currentEntries.contains(where: { $0.employeeId == employeeId }) else { return }
        
        currentEntries.append(ShiftEntry(
            employeeId: employeeId,
            employeeName: employeeName,
            days: [:]
        ))
        
        self.currentWeekSchedule?.entries = currentEntries
        saveScheduleEntries(currentEntries, updatedEmpId: employeeId, dayKey: nil, newCode: nil)
    }

    private func saveScheduleEntries(_ entries: [ShiftEntry], updatedEmpId: String, dayKey: String?, newCode: String?) {
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/shift_schedules/\(currentWeekId)?updateMask.fieldPaths=entries&updateMask.fieldPaths=updatedAt&updateMask.fieldPaths=updatedBy"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            if !idToken.isEmpty {
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var arrayValues: [[String: Any]] = []
            for entry in entries {
                var dayFields: [String: Any] = [:]
                for (k, v) in entry.days {
                    dayFields[k] = ["stringValue": v]
                }
                let entryMap: [String: Any] = [
                    "mapValue": [
                        "fields": [
                            "employeeId": ["stringValue": entry.employeeId],
                            "employeeName": ["stringValue": entry.employeeName],
                            "maKhuVuc": ["stringValue": entry.maKhuVuc],
                            "donVi": ["stringValue": entry.donVi],
                            "days": [
                                "mapValue": [
                                    "fields": dayFields
                                ]
                            ]
                        ]
                    ]
                ]
                arrayValues.append(entryMap)
            }

            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let body: [String: Any] = [
                "fields": [
                    "entries": [
                        "arrayValue": [
                            "values": arrayValues
                        ]
                    ],
                    "updatedAt": ["integerValue": String(now)],
                    "updatedBy": ["stringValue": user.email]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
