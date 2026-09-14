import Foundation
import CoreLocation

public struct RouteResult: Sendable {
    public let distanceKm: Double
    public let durationMinutes: Int
    public let coordinates: [[Double]] // [[lat, lng], ...]

    public var polylineCoordinates: [CLLocationCoordinate2D] {
        coordinates.compactMap { pt in
            guard pt.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pt[0], longitude: pt[1])
        }
    }
}

public actor OSRMRoutingService {
    public static let shared = OSRMRoutingService()

    public var defaultGoogleMapsApiKey: String = "AIzaSyDXssW9ZtELkOc5d1GGQ5bjYVPRo6Yq_hc"

    // MARK: - Tính Lộ Trình Đường Bộ OSRM (OpenStreetMap)
    public func fetchRoute(
        startLat: Double,
        startLng: Double,
        destLat: Double,
        destLng: Double
    ) async -> RouteResult? {
        guard startLat != 0.0, startLng != 0.0, destLat != 0.0, destLng != 0.0 else {
            return nil
        }

        let urlString = "https://router.project-osrm.org/route/v1/driving/\(startLng),\(startLat);\(destLng),\(destLat)?overview=full&geometries=geojson"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("QLTB_iOS/1.0 (Equipment and Incident Management)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let routes = json["routes"] as? [[String: Any]],
                  let firstRoute = routes.first else {
                return nil
            }

            let distanceMeters = firstRoute["distance"] as? Double ?? 0.0
            let durationSec = firstRoute["duration"] as? Double ?? 0.0

            var latLngList: [[Double]] = []
            if let geometry = firstRoute["geometry"] as? [String: Any],
               let coords = geometry["coordinates"] as? [[Double]] {
                for pt in coords {
                    if pt.count >= 2 {
                        // GeoJSON format is [lng, lat] -> convert to [lat, lng]
                        latLngList.append([pt[1], pt[0]])
                    }
                }
            }

            let distKm = (distanceMeters / 1000.0 * 10.0).rounded() / 10.0
            let durMin = max(1, Int(durationSec / 60.0))

            return RouteResult(
                distanceKm: distKm,
                durationMinutes: durMin,
                coordinates: latLngList
            )
        } catch {
            return nil
        }
    }

    // MARK: - Geocoding 2 Tầng: Co.opmart Directory -> Google Geocoding -> Nominatim -> Known Regions
    public func geocodeAddress(_ address: String, customApiKey: String? = nil) async -> (lat: Double, lng: Double)? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        // Tầng 0: Tra cứu danh bạ hệ thống Co.opmart (Offline siêu tốc, chính xác 100%)
        if let store = CoopmartDirectory.resolveLocation(trimmed) {
            return (store.lat, store.lng)
        }

        let apiKey = (customApiKey?.trimmingCharacters(in: .whitespaces).isEmpty == false)
            ? customApiKey! : defaultGoogleMapsApiKey

        var candidates: [String] = [trimmed]

        let stripped = trimmed.replacingOccurrences(of: "^\\s*\\[?[0-9]+\\]?\\s*[-_:–.]\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if !stripped.isEmpty && stripped != trimmed {
            candidates.append(stripped)
        }

        let withoutHouseNumber = (stripped.isEmpty ? trimmed : stripped)
            .replacingOccurrences(of: "^\\s*\\d+[/A-Za-z0-9-]*\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^(Tầng|Lô|Số|Khu|Khối)\\s+[^\\,]+\\,\\s*", with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
        if !withoutHouseNumber.isEmpty && withoutHouseNumber != trimmed {
            candidates.append(withoutHouseNumber)
        }

        if trimmed.localizedCaseInsensitiveContains("Xa lộ Hà Nội") || trimmed.localizedCaseInsensitiveContains("Xa lo Ha Noi") {
            candidates.append("Xa lộ Hà Nội, Hồ Chí Minh")
            candidates.append("Xa lộ Hà Nội, TP Thủ Đức")
        }

        if trimmed.localizedCaseInsensitiveContains("Co.op") {
            let unDotted = trimmed.replacingOccurrences(of: "Co.op", with: "Coop", options: .caseInsensitive)
            candidates.append(unDotted)
            if !stripped.isEmpty {
                candidates.append(stripped.replacingOccurrences(of: "Co.op", with: "Coop", options: .caseInsensitive))
            }
        }

        var uniqueCandidates: [String] = []
        for c in candidates {
            if !uniqueCandidates.contains(c) {
                uniqueCandidates.append(c)
            }
        }

        // Tầng 1: Thử Google Maps Geocoding & Nominatim
        for cand in uniqueCandidates {
            if !apiKey.isEmpty {
                if let gRes = await geocodeWithGoogle(cand, apiKey: apiKey) {
                    return gRes
                }
            }
            if let nRes = await geocodeWithNominatim(cand) {
                return nRes
            }
        }

        // Tầng 2: Fallback danh sách vùng miền / Tỉnh thành trọng điểm
        let knownRegions: [(String, (Double, Double))] = [
            ("Xa lộ Hà Nội", (10.8523, 106.7716)),
            ("Xa lo Ha Noi", (10.8523, 106.7716)),
            ("Thủ Đức", (10.8499, 106.7725)),
            ("Thu Duc", (10.8499, 106.7725)),
            ("Quận 9", (10.8523, 106.7716)),
            ("Quận 2", (10.7872, 106.7498)),
            ("Quận 1", (10.7769, 106.7009)),
            ("Quận 7", (10.7340, 106.7218)),
            ("Cần Thơ", (10.0340, 105.7861)),
            ("Hồ Chí Minh", (10.7769, 106.7009)),
            ("TPHCM", (10.7769, 106.7009)),
            ("Sài Gòn", (10.7769, 106.7009)),
            ("Hà Nội", (21.0285, 105.8542)),
            ("Đà Nẵng", (16.0544, 108.2022)),
            ("Hải Phòng", (20.8449, 106.6881)),
            ("Bình Dương", (11.1643, 106.6436)),
            ("Đồng Nai", (10.9574, 106.8427)),
            ("Biên Hòa", (10.9574, 106.8427)),
            ("Bà Rịa", (10.4966, 107.1685)),
            ("Vũng Tàu", (10.3460, 107.0843)),
            ("Long An", (10.5336, 106.4116)),
            ("Tiền Giang", (10.3601, 106.3644)),
            ("Mỹ Tho", (10.3601, 106.3644)),
            ("Bến Tre", (10.2433, 106.3758)),
            ("Trà Vinh", (9.9348, 106.3455)),
            ("Vĩnh Long", (10.2537, 105.9722)),
            ("Đồng Tháp", (10.4578, 105.6334)),
            ("Cao Lãnh", (10.4578, 105.6334)),
            ("An Giang", (10.3759, 105.4185)),
            ("Long Xuyên", (10.3759, 105.4185)),
            ("Kiên Giang", (10.0124, 105.0809)),
            ("Rạch Giá", (10.0124, 105.0809)),
            ("Phú Quốc", (10.2899, 103.9840)),
            ("Hậu Giang", (9.7844, 105.4701)),
            ("Sóc Trăng", (9.6035, 105.9800)),
            ("Bạc Liêu", (9.2941, 105.7278)),
            ("Cà Mau", (9.1764, 105.1508)),
            ("Tây Ninh", (11.3100, 106.0983)),
            ("Bình Phước", (11.7512, 106.9067)),
            ("Lâm Đồng", (11.9404, 108.4583)),
            ("Đà Lạt", (11.9404, 108.4583)),
            ("Bình Thuận", (10.9333, 108.1000)),
            ("Phan Thiết", (10.9333, 108.1000)),
            ("Ninh Thuận", (11.5667, 108.9833)),
            ("Phan Rang", (11.5667, 108.9833)),
            ("Khánh Hòa", (12.2388, 109.1967)),
            ("Nha Trang", (12.2388, 109.1967)),
            ("Phú Yên", (13.0882, 109.3075)),
            ("Bình Định", (13.7820, 109.2197)),
            ("Quy Nhơn", (13.7820, 109.2197)),
            ("Quảng Ngãi", (15.1205, 108.7923)),
            ("Quảng Nam", (15.5684, 108.4754)),
            ("Thừa Thiên Huế", (16.4637, 107.5909)),
            ("Huế", (16.4637, 107.5909))
        ]

        for (regionName, coord) in knownRegions {
            if trimmed.localizedCaseInsensitiveContains(regionName) {
                return coord
            }
        }

        return nil
    }

    private func geocodeWithGoogle(_ query: String, apiKey: String) async -> (Double, Double)? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://maps.googleapis.com/maps/api/geocode/json?address=\(encoded)&key=\(apiKey)&components=country:VN") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String, status == "OK",
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let geometry = first["geometry"] as? [String: Any],
                  let location = geometry["location"] as? [String: Any],
                  let lat = location["lat"] as? Double,
                  let lng = location["lng"] as? Double else {
                return nil
            }
            return (lat, lng)
        } catch {
            return nil
        }
    }

    private func geocodeWithNominatim(_ query: String) async -> (Double, Double)? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://nominatim.openstreetmap.org/search?q=\(encoded)&format=json&countrycodes=vn&limit=1") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("QLTB_iOS/1.0 (Equipment and Incident Management)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            guard let jsonArr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = jsonArr.first,
                  let latStr = first["lat"] as? String,
                  let lngStr = first["lon"] as? String,
                  let lat = Double(latStr),
                  let lng = Double(lngStr) else {
                return nil
            }
            return (lat, lng)
        } catch {
            return nil
        }
    }
}
