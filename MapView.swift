import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @EnvironmentObject var loc: LocationManager
    @Binding var follow: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = true
        map.showsScale = true

        // Тайлы OpenStreetMap. Для публичного релиза используйте своего провайдера
        // тайлов: https://operations.osmfoundation.org/policies/tiles/
        let tiles = MKTileOverlay(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
        tiles.canReplaceMapContent = true
        tiles.maximumZ = 19
        map.addOverlay(tiles, level: .aboveLabels)
        map.setUserTrackingMode(.follow, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.parent = self

        if loc.track.count != c.trackCount {
            c.trackCount = loc.track.count
            if let old = c.polyline { map.removeOverlay(old) }
            c.polyline = nil
            if loc.track.count > 1 {
                let coords = loc.track.map { $0.coordinate }
                let line = MKPolyline(coordinates: coords, count: coords.count)
                map.addOverlay(line, level: .aboveLabels)
                c.polyline = line
            }
        }

        if loc.waypoints.count != c.waypointCount {
            c.waypointCount = loc.waypoints.count
            map.removeAnnotations(map.annotations.filter { $0 is MKPointAnnotation })
            for w in loc.waypoints {
                let a = MKPointAnnotation()
                a.title = w.name
                a.coordinate = w.coordinate
                map.addAnnotation(a)
            }
        }

        if loc.focusRequest != c.focusRequest {
            c.focusRequest = loc.focusRequest
            if let line = c.polyline {
                map.setUserTrackingMode(.none, animated: false)
                map.setVisibleMapRect(line.boundingMapRect,
                                      edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 220, right: 40),
                                      animated: true)
            }
        }

        if follow && map.userTrackingMode == .none {
            map.setUserTrackingMode(.follow, animated: true)
        } else if !follow && map.userTrackingMode != .none {
            map.setUserTrackingMode(.none, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var polyline: MKPolyline?
        var trackCount = -1
        var waypointCount = -1
        var focusRequest = 0

        init(_ parent: MapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            if let line = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = .systemOrange
                r.lineWidth = 4
                r.lineJoin = .round
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            DispatchQueue.main.async {
                self.parent.follow = (mode != .none)
            }
        }
    }
}
