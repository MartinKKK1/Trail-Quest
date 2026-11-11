import SwiftUI
import UniformTypeIdentifiers

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var loc: LocationManager
    @State private var follow = true
    @State private var shareItem: ShareItem?
    @State private var showImporter = false
    @State private var showNamePrompt = false
    @State private var waypointName = ""
    @State private var errorText: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            MapView(follow: $follow)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                stats
                controls
            }
            .padding()
        }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url) }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml]) { result in
            importGPX(result)
        }
        .alert("Новая точка", isPresented: $showNamePrompt) {
            TextField("Название", text: $waypointName)
            Button("Добавить") {
                loc.addWaypoint(name: waypointName)
                waypointName = ""
            }
            Button("Отмена", role: .cancel) { waypointName = "" }
        }
        .alert("Ошибка", isPresented: Binding(get: { errorText != nil },
                                              set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private var stats: some View {
        HStack(spacing: 20) {
            stat("Дистанция", String(format: "%.2f км", loc.distance / 1000))
            stat("Скорость", String(format: "%.1f км/ч", max(0, loc.current?.speed ?? 0) * 3.6))
            stat("Высота", String(format: "%.0f м", loc.current?.altitude ?? 0))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            roundButton("location.fill", active: follow) { follow = true }
            roundButton("mappin.and.ellipse") { showNamePrompt = true }
            Button {
                loc.isRecording ? loc.stopRecording() : loc.startRecording()
            } label: {
                Image(systemName: loc.isRecording ? "stop.fill" : "record.circle")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(loc.isRecording ? Color.red : Color.orange, in: Circle())
            }
            roundButton("square.and.arrow.up") { exportGPX() }
            roundButton("square.and.arrow.down") { showImporter = true }
        }
    }

    private func roundButton(_ icon: String, active: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(active ? Color.white : Color.primary)
                .frame(width: 48, height: 48)
                .background(active ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.regularMaterial), in: Circle())
        }
    }

    private func exportGPX() {
        guard !loc.track.isEmpty || !loc.waypoints.isEmpty else {
            errorText = "Нет данных для экспорта: запишите трек или добавьте точку."
            return
        }
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        let name = "TrailQuest-\(df.string(from: Date()))"
        let xml = GPX.export(track: loc.track, waypoints: loc.waypoints, name: name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).gpx")
        do {
            try xml.write(to: url, atomically: true, encoding: .utf8)
            shareItem = ShareItem(url: url)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func importGPX(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorText = error.localizedDescription
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let parsed = GPX.parse(data: data)
                if parsed.track.isEmpty && parsed.waypoints.isEmpty {
                    errorText = "В файле не найдено ни треков, ни точек."
                } else {
                    loc.load(track: parsed.track, waypoints: parsed.waypoints)
                    follow = false
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
