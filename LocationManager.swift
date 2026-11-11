import CoreLocation
import Combine

struct Waypoint: Identifiable {
    let id = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var current: CLLocation?
    @Published var isRecording = false
    @Published var track: [CLLocation] = []
    @Published var waypoints: [Waypoint] = []
    @Published var distance: CLLocationDistance = 0
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    /// Увеличивается, когда карте нужно показать весь трек (после импорта).
    @Published var focusRequest = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func startRecording() {
        track = []
        distance = 0
        isRecording = true
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func stopRecording() {
        isRecording = false
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
    }

    func addWaypoint(name: String) {
        guard let c = current?.coordinate else { return }
        let title = name.trimmingCharacters(in: .whitespaces)
        waypoints.append(Waypoint(name: title.isEmpty ? "Точка \(waypoints.count + 1)" : title,
                                  coordinate: c))
    }

    func load(track newTrack: [CLLocation], waypoints newWaypoints: [Waypoint]) {
        track = newTrack
        waypoints = newWaypoints
        distance = zip(newTrack, newTrack.dropFirst()).reduce(0) { $0 + $1.1.distance(from: $1.0) }
        focusRequest += 1
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        current = last
        guard isRecording else { return }
        for loc in locations where loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy < 50 {
            if let prev = track.last { distance += loc.distance(from: prev) }
            track.append(loc)
        }
    }
}
