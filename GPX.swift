import Foundation
import CoreLocation

enum GPX {
    static func export(track: [CLLocation], waypoints: [Waypoint], name: String) -> String {
        let iso = ISO8601DateFormatter()
        var s = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="TrailQuest" xmlns="http://www.topografix.com/GPX/1/1">

        """
        for w in waypoints {
            s += "  <wpt lat=\"\(w.coordinate.latitude)\" lon=\"\(w.coordinate.longitude)\"><name>\(escape(w.name))</name></wpt>\n"
        }
        if !track.isEmpty {
            s += "  <trk><name>\(escape(name))</name><trkseg>\n"
            for p in track {
                s += "    <trkpt lat=\"\(p.coordinate.latitude)\" lon=\"\(p.coordinate.longitude)\">"
                s += "<ele>\(p.altitude)</ele><time>\(iso.string(from: p.timestamp))</time></trkpt>\n"
            }
            s += "  </trkseg></trk>\n"
        }
        s += "</gpx>\n"
        return s
    }

    static func parse(data: Data) -> (track: [CLLocation], waypoints: [Waypoint]) {
        let handler = Parser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return (handler.track, handler.waypoints)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private final class Parser: NSObject, XMLParserDelegate {
        var track: [CLLocation] = []
        var waypoints: [Waypoint] = []

        private var text = ""
        private var lat = 0.0, lon = 0.0, ele = 0.0
        private var time: Date?
        private var name = ""
        private var inWpt = false
        private let iso = ISO8601DateFormatter()
        private let isoFrac: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            text = ""
            if elementName == "wpt" || elementName == "trkpt" {
                lat = Double(attributeDict["lat"] ?? "") ?? 0
                lon = Double(attributeDict["lon"] ?? "") ?? 0
                ele = 0
                time = nil
                name = ""
                inWpt = (elementName == "wpt")
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch elementName {
            case "ele": ele = Double(t) ?? 0
            case "time": time = iso.date(from: t) ?? isoFrac.date(from: t)
            case "name": if inWpt { name = t }
            case "wpt":
                waypoints.append(Waypoint(name: name.isEmpty ? "Точка" : name,
                                          coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                inWpt = false
            case "trkpt":
                track.append(CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                        altitude: ele, horizontalAccuracy: 5, verticalAccuracy: 5,
                                        timestamp: time ?? Date()))
            default: break
            }
        }
    }
}
