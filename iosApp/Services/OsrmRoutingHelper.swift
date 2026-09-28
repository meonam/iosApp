import Foundation
import CoreLocation

public struct RouteResult: Codable, Hashable {
    public let distanceKm: Double
    public let durationMinutes: Int
    public let coordinates: [[Double]] // [[lat, lng], [lat, lng], ...]

    public init(distanceKm: Double, durationMinutes: Int, coordinates: [[Double]]) {
        self.distanceKm = distanceKm
        self.durationMinutes = durationMinutes
        self.coordinates = coordinates
    }
}

public class OsrmRoutingHelper {
    public static let shared = OsrmRoutingHelper()

    public var defaultApiKey: String = "AIzaSyCd5zerDho7eveBBrcbq6FFBOMMCo_Y1eE"

    private init() {}

    // MARK: - DECODE GOOGLE ENCODED POLYLINE
    public static func decodePolyline(_ encoded: String) -> [[Double]] {
        var poly: [[Double]] = []
        let bytes = Array(encoded.utf8)
        var index = 0
        let len = bytes.count
        var lat = 0
        var lng = 0

        while index < len {
            var b: Int
            var shift = 0
            var result = 0
            repeat {
                if index >= len { break }
                b = Int(bytes[index]) - 63
                index += 1
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20
            let dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += dlat

            shift = 0
            result = 0
            repeat {
                if index >= len { break }
                b = Int(bytes[index]) - 63
                index += 1
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20
            let dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += dlng

            poly.append([Double(lat) / 1e5, Double(lng) / 1e5])
        }
        return poly
    }

    // MARK: - FETCH ROUTE (GOOGLE DIRECTIONS -> OSRM FALLBACK)
    public func fetchRoute(
        startLat: Double,
        startLng: Double,
        destLat: Double,
        destLng: Double
    ) async -> RouteResult? {
        guard startLat != 0, startLng != 0, destLat != 0, destLng != 0 else { return nil }

        // 1. Thử qua Google Directions API nếu có API key
        if !defaultApiKey.isEmpty {
            if let res = await fetchGoogleRoute(startLat: startLat, startLng: startLng, destLat: destLat, destLng: destLng, apiKey: defaultApiKey) {
                return res
            }
        }

        // 2. Dự phòng 100% chuẩn xác và miễn phí: OSRM Routing Engine (vẽ đường đi theo từng con đường thực tế tại VN)
        return await fetchOsrmRoute(startLat: startLat, startLng: startLng, destLat: destLat, destLng: destLng)
    }

    private func fetchGoogleRoute(startLat: Double, startLng: Double, destLat: Double, destLng: Double, apiKey: String) async -> RouteResult? {
        let urlStr = "https://maps.googleapis.com/maps/api/directions/json?origin=\(startLat),\(startLng)&destination=\(destLat),\(destLng)&mode=driving&language=vi&key=\(apiKey)"
        guard let url = URL(string: urlStr) else { return nil }

        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("QLTB_iOS/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String, status == "OK",
                  let routes = json["routes"] as? [[String: Any]], let firstRoute = routes.first,
                  let legs = firstRoute["legs"] as? [[String: Any]], let firstLeg = legs.first else {
                return nil
            }

            let distObj = firstLeg["distance"] as? [String: Any]
            let durObj = firstLeg["duration"] as? [String: Any]
            let distMeters = (distObj?["value"] as? Double) ?? (Double(distObj?["value"] as? Int ?? 0))
            let durSec = (durObj?["value"] as? Double) ?? (Double(durObj?["value"] as? Int ?? 0))

            let overviewPolylineObj = firstRoute["overview_polyline"] as? [String: Any]
            let points = overviewPolylineObj?["points"] as? String ?? ""
            let coords = points.isEmpty ? [] : Self.decodePolyline(points)

            let distKm = Double(round((distMeters / 1000.0) * 10) / 10)
            let durMin = max(1, Int(durSec / 60.0))

            return RouteResult(distanceKm: distKm, durationMinutes: durMin, coordinates: coords)
        } catch {
            return nil
        }
    }

    private func fetchOsrmRoute(startLat: Double, startLng: Double, destLat: Double, destLng: Double) async -> RouteResult? {
        let urlStr = "https://router.project-osrm.org/route/v1/driving/\(startLng),\(startLat);\(destLng),\(destLat)?overview=full&geometries=geojson"
        guard let url = URL(string: urlStr) else { return nil }

        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) QLTB/2.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let code = json["code"] as? String, code == "Ok",
                  let routes = json["routes"] as? [[String: Any]], let firstRoute = routes.first else {
                return nil
            }

            let distMeters = (firstRoute["distance"] as? Double) ?? (Double(firstRoute["distance"] as? Int ?? 0))
            let durSec = (firstRoute["duration"] as? Double) ?? (Double(firstRoute["duration"] as? Int ?? 0))

            var coords: [[Double]] = []
            if let geometry = firstRoute["geometry"] as? [String: Any],
               let coordinatesArray = geometry["coordinates"] as? [[Double]] {
                for pt in coordinatesArray {
                    if pt.count >= 2 {
                        // GeoJSON format is [lng, lat] -> convert to [lat, lng]
                        coords.append([pt[1], pt[0]])
                    }
                }
            }

            let distKm = Double(round((distMeters / 1000.0) * 10) / 10)
            let durMin = max(1, Int(durSec / 60.0))

            return RouteResult(distanceKm: distKm, durationMinutes: durMin, coordinates: coords)
        } catch {
            return nil
        }
    }

    // MARK: - GEOCODE ADDRESS (COOPMART DIRECTORY -> GOOGLE -> NOMINATIM -> REGIONS)
    public func geocodeAddress(_ address: String, customApiKey: String? = nil) async -> (lat: Double, lng: Double)? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 0. Tra cứu danh bạ Saigon Co.op siêu tốc (offline 0ms)
        if let store = CoopmartDirectory.resolveLocation(trimmed) {
            return (store.lat, store.lng)
        }

        let key = customApiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? customApiKey! : defaultApiKey

        // Danh sách từ khóa tìm kiếm
        var candidates: [String] = [trimmed]
        let stripped = trimmed.replacingOccurrences(of: "^\\s*\\[?[0-9]+\\]?\\s*[-_:–.]\\s*", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        if !stripped.isEmpty && stripped != trimmed {
            candidates.append(stripped)
        }

        // Bỏ số nhà
        let withoutHouseNumber = (stripped.isEmpty ? trimmed : stripped)
            .replacingOccurrences(of: "^\\s*\\d+[/A-Za-z0-9-]*\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)^(Tầng|Lô|Số|Khu|Khối)\\s+[^\\,]+\\,\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !withoutHouseNumber.isEmpty && withoutHouseNumber != trimmed {
            candidates.append(withoutHouseNumber)
        }

        if trimmed.localizedCaseInsensitiveContains("Xa lộ Hà Nội") {
            candidates.append("Xa lộ Hà Nội, Hồ Chí Minh")
            candidates.append("Xa lộ Hà Nội, TP Thủ Đức")
        }

        // 1. Google Geocoding
        if !key.isEmpty {
            for cand in candidates {
                if let geo = await geocodeWithGoogle(cand, apiKey: key) {
                    return geo
                }
            }
        }

        // 2. Nominatim OpenStreetMap
        for cand in candidates {
            if let geo = await geocodeWithNominatim(cand) {
                return geo
            }
        }

        // 3. Fallback vùng miền
        return fallbackRegion(for: trimmed)
    }

    private func geocodeWithGoogle(_ address: String, apiKey: String) async -> (lat: Double, lng: Double)? {
        guard let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlStr = "https://maps.googleapis.com/maps/api/geocode/json?address=\(encoded)&language=vi&region=vn&key=\(apiKey)"
        guard let url = URL(string: urlStr) else { return nil }

        var req = URLRequest(url: url)
        req.timeoutInterval = 7
        req.setValue("QLTB_iOS/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String, status == "OK",
                  let results = json["results"] as? [[String: Any]], let first = results.first,
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

    private func geocodeWithNominatim(_ address: String) async -> (lat: Double, lng: Double)? {
        guard let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlStr = "https://nominatim.openstreetmap.org/search?format=json&q=\(encoded)&countrycodes=vn&limit=1"
        guard let url = URL(string: urlStr) else { return nil }

        var req = URLRequest(url: url)
        req.timeoutInterval = 6
        req.setValue("QLTB_App/1.0 (Equipment Management)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = list.first,
                  let latStr = first["lat"] as? String, let lat = Double(latStr),
                  let lngStr = first["lon"] as? String, let lng = Double(lngStr) else {
                return nil
            }
            return (lat, lng)
        } catch {
            return nil
        }
    }

    private func fallbackRegion(for address: String) -> (lat: Double, lng: Double)? {
        let knownRegions: [(String, (Double, Double))] = [
            ("Xa lộ Hà Nội", (10.8523, 106.7716)),
            ("Thủ Đức", (10.8499, 106.7725)),
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
            ("Vũng Tàu", (10.3460, 107.0843)),
            ("Long An", (10.5336, 106.4116)),
            ("Tiền Giang", (10.3601, 106.3644)),
            ("Mỹ Tho", (10.3601, 106.3644)),
            ("Bến Tre", (10.2433, 106.3758)),
            ("Trà Vinh", (9.9348, 106.3455)),
            ("Vĩnh Long", (10.2537, 105.9722)),
            ("Tân Long Hội", (10.2030, 105.9980)),
            ("Đồng Tháp", (10.4578, 105.6334)),
            ("Cao Lãnh", (10.4578, 105.6334)),
            ("An Giang", (10.3759, 105.4185)),
            ("Kiên Giang", (10.0124, 105.0809)),
            ("Cà Mau", (9.1768, 105.1524))
        ]

        for (name, coords) in knownRegions {
            if address.localizedCaseInsensitiveContains(name) {
                return (coords.0, coords.1)
            }
        }
        return nil
    }
}
