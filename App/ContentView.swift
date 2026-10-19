import SwiftUI
import UIKit

@MainActor final class LocationModel: ObservableObject {
    @Published var input = ""
    @Published var result: MapResult?
    @Published var error: String?
    @Published var busy = false
    @Published var needsNetwork = false

    func process(network: Bool = false) {
        busy = true; error = nil; needsNetwork = false; result = nil
        let value = input
        Task {
            do {
                result = try await LinkResolver.resolve(value, allowNetwork: network)
                if result?.selected?.coordinateText == nil { needsNetwork = !network }
            } catch {
                if !network, MapParser.extractURL(value) != nil { needsNetwork = true }
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}

struct ContentView: View {
    @StateObject private var model = LocationModel()
    @AppStorage("customMapName") private var customName = "Custom map"
    @AppStorage("customMapURL") private var customURL = ""
    @State private var showSettings = false
    @State private var message: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    inputCard
                    if model.busy { ProgressView("Finding location…").frame(maxWidth: .infinity).padding() }
                    if let error = model.error { Text(error).foregroundStyle(.secondary).padding(.horizontal, 4) }
                    if model.needsNetwork { networkCard }
                    if let result = model.result { resultCard(result) }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("GeoShare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Settings", systemImage: "gearshape") { showSettings = true } } }
            .sheet(isPresented: $showSettings) { settings }
            .alert("GeoShare", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
            .onAppear(perform: readInbox)
            .onChange(of: scenePhase) { _, phase in if phase == .active { readInbox() } }
        }
        .tint(Color(red: 0.14, green: 0.44, blue: 0.39))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 42)).foregroundStyle(.teal)
            Text("One place. Any map.").font(.largeTitle.bold())
            Text("Paste a map link or share one to GeoShare to find its coordinates and open it where you like.")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MAP LINK OR COORDINATES").font(.caption.bold()).foregroundStyle(.secondary)
            TextField("https://maps.app.goo.gl/…", text: $model.input, axis: .vertical)
                .lineLimit(2...5).textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.URL)
            HStack {
                Button("Paste", systemImage: "doc.on.clipboard") {
                    if let text = UIPasteboard.general.string { model.input = text }
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Find location", systemImage: "arrow.right") { model.process() }
                    .buttonStyle(.borderedProminent).disabled(model.input.isEmpty || model.busy)
            }
        }
        .padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("This link needs a connection", systemImage: "network") .font(.headline)
            Text("GeoShare can visit the map service to follow its short link or read the place coordinates. The service will receive this link and your IP address.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Resolve online") { model.process(network: true) }.buttonStyle(.borderedProminent)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
    }

    private func resultCard(_ result: MapResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.service.uppercased()).font(.caption.bold()).foregroundStyle(.teal)
                    Text(result.selected?.name ?? "Location found").font(.title3.bold())
                }
                Spacer()
                Image(systemName: "mappin.circle.fill").font(.title).foregroundStyle(.teal)
            }
            if result.points.count > 1 {
                Text("\(result.points.count) points in this route").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(result.points) { point in
                VStack(alignment: .leading, spacing: 8) {
                    Text(point.name ?? point.coordinateText ?? "Unknown point").font(.headline)
                    if let coordinates = point.coordinateText {
                        Text(coordinates).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                        HStack {
                            Button("Copy coordinates", systemImage: "doc.on.doc") { UIPasteboard.general.string = coordinates }
                            if let geo = point.geoURL { Button("Copy geo: link") { UIPasteboard.general.string = geo.absoluteString } }
                        }.font(.subheadline)
                    } else { Text("Coordinates unavailable; the name may be ambiguous.").font(.subheadline).foregroundStyle(.secondary) }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            if let point = result.selected, point.coordinateText != nil {
                Divider()
                Text("OPEN IN").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(MapTarget.allCases) { target in
                    Button { open(target, point) } label: {
                        HStack { Label(target.rawValue, systemImage: target.symbol); Spacer(); Image(systemName: "arrow.up.right") }
                            .padding(.vertical, 5)
                    }
                }
                if !customURL.isEmpty {
                    Button { openCustom(point) } label: { Label(customName, systemImage: "link") }
                }
                if let url = MapTarget.apple.url(for: point) { ShareLink("Share location", item: url) }
                Button("Share GPX file", systemImage: "square.and.arrow.up") { shareGPX(result.points) }
            }
            if let note = result.note { Text(note).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Custom map") {
                    TextField("Name", text: $customName)
                    TextField("URL template", text: $customURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Use {lat}, {lon}, {coords}, and {name}. Example: https://example.org/?q={coords}")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Privacy") { Text("Links with coordinates are processed on device. GeoShare only connects to a map service after you choose Resolve online.") }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSettings = false } } }
        }
    }

    private func readInbox() {
        guard let value = SharedInbox.take() else { return }
        model.input = value
        model.process()
    }

    private func open(_ target: MapTarget, _ point: MapPoint) {
        guard let url = target.url(for: point) else { return }
        UIApplication.shared.open(url) { success in
            if !success { Task { @MainActor in message = "Install \(target.rawValue) to open this location." } }
        }
    }

    private func openCustom(_ point: MapPoint) {
        guard let lat = point.latitude, let lon = point.longitude else { return }
        let value = customURL.replacingOccurrences(of: "{lat}", with: String(lat))
            .replacingOccurrences(of: "{lon}", with: String(lon))
            .replacingOccurrences(of: "{coords}", with: "\(lat),\(lon)")
            .replacingOccurrences(of: "{name}", with: (point.name ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        guard let url = URL(string: value), ["https", "http"].contains(url.scheme ?? "") else { message = "Enter a valid HTTP or HTTPS custom map URL."; return }
        UIApplication.shared.open(url)
    }

    private func shareGPX(_ points: [MapPoint]) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GeoShare-location.gpx")
        do {
            try LocationExport.gpx(points).write(to: url, atomically: true, encoding: .utf8)
            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow?.rootViewController?.present(activity, animated: true)
        } catch { message = error.localizedDescription }
    }
}
