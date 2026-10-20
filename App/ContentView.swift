import SwiftUI
import UIKit

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

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
                let allowNetwork = network || ConnectionPreferences.automaticallyResolveOnline
                result = try await LinkResolver.resolve(value, allowNetwork: allowNetwork)
                if result?.selected?.coordinateText == nil { needsNetwork = !allowNetwork }
            } catch {
                if !network && !ConnectionPreferences.automaticallyResolveOnline && MapParser.extractURL(value) != nil { needsNetwork = true }
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}

struct ContentView: View {
    @StateObject private var model = LocationModel()
    @AppStorage("customMapName", store: ConnectionPreferences.store) private var customName = "Custom map"
    @AppStorage("customMapURL", store: ConnectionPreferences.store) private var customURL = ""
    @AppStorage(ConnectionPreferences.defaultMapKey, store: ConnectionPreferences.store) private var defaultMap = MapTarget.apple.rawValue
    @AppStorage(ConnectionPreferences.automaticKey, store: ConnectionPreferences.store) private var automaticallyResolveOnline = false
    @State private var showSettings = false
    @State private var message: String?
    @State private var sharePayload: SharePayload?
    @FocusState private var inputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    inputCard
                    if model.busy { ProgressView("Finding location…").frame(maxWidth: .infinity).padding() }
                    if let error = model.error { Text(error).foregroundStyle(.secondary).padding(.horizontal, 4) }
                    if model.needsNetwork { networkCard }
                    if let result = model.result { resultCard(result) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("GeoShare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Settings", systemImage: "gearshape") { showSettings = true } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { inputFocused = false }
                }
            }
            .sheet(isPresented: $showSettings) { settings }
            .sheet(item: $sharePayload) { payload in ActivitySheet(items: payload.items) }
            .alert("GeoShare", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
            .onAppear(perform: readInbox)
            .onChange(of: scenePhase) { _, phase in if phase == .active { readInbox() } }
        }
        .tint(Color(red: 0.14, green: 0.44, blue: 0.39))
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste a map link")
                .font(.title3.weight(.semibold))
            TextField("https://maps.app.goo.gl/…", text: $model.input, axis: .vertical)
                .lineLimit(2...5).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($inputFocused)
                .keyboardType(.URL)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button("Paste", systemImage: "doc.on.clipboard") {
                    if let text = UIPasteboard.general.string { model.input = text }
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Find location", systemImage: "arrow.right") { inputFocused = false; model.process() }
                    .buttonStyle(.borderedProminent).disabled(model.input.isEmpty || model.busy)
            }
        }
        .padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("This link needs a connection", systemImage: "network") .font(.headline)
            Text("GeoShare can visit the map service to follow its short link or read the place coordinates. The service will receive this link and your IP address.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Resolve online", systemImage: "network") { inputFocused = false; model.process(network: true) }
                .buttonStyle(.borderedProminent)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }

    private func resultCard(_ result: MapResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.service).font(.caption).foregroundStyle(.secondary)
                    Text(result.selected?.name ?? "Location found").font(.title3.weight(.semibold))
                        .textSelection(.enabled)
                    if result.points.count == 1, let coordinates = result.selected?.coordinateText {
                        Text(coordinates).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if let point = result.selected { actionsMenu(point, result: result) }
            }
            if result.points.count > 1 {
                Text("\(result.points.count) places").font(.subheadline).foregroundStyle(.secondary)
                ForEach(result.points) { point in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(point.name ?? "Location").font(.body.weight(.medium))
                            Text(point.coordinateText ?? "Coordinates unavailable")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        actionsMenu(point, result: result)
                    }
                    .padding(.vertical, 6)
                }
            }
            if let point = result.selected, point.coordinateText != nil {
                Divider()
                Text(result.points.count > 1 ? "Open last place in" : "Open in")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(MapTarget.allCases) { target in
                        mapRow(target.rawValue, symbol: target.symbol, shareURL: target.webURL(for: point)) { open(target, point) }
                        if target != MapTarget.allCases.last { Divider().padding(.leading, 40) }
                    }
                    if !customURL.isEmpty, let url = customTargetURL(point) {
                        Divider().padding(.leading, 40)
                        mapRow(customName, symbol: "link", shareURL: url) { UIApplication.shared.open(url) }
                    }
                }
            }
            if let note = result.note { Text(note).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func actionsMenu(_ point: MapPoint, result: MapResult) -> some View {
        Menu {
            if let address = point.name, !address.isEmpty {
                Button("Copy address", systemImage: "doc.on.doc") { UIPasteboard.general.string = address }
            }
            if let coordinates = point.coordinateText {
                Button("Copy coordinates", systemImage: "number") { UIPasteboard.general.string = coordinates }
            }
            if let url = preferredShareURL(for: point) {
                Button("Copy link", systemImage: "link") { UIPasteboard.general.url = url }
                Button("Share link", systemImage: "square.and.arrow.up") { presentShare([url]) }
            }
            Menu("Default link map", systemImage: "map") {
                ForEach(MapTarget.allCases) { target in
                    Button {
                        defaultMap = target.rawValue
                    } label: {
                        if defaultMap == target.rawValue { Label(target.rawValue, systemImage: "checkmark") }
                        else { Text(target.rawValue) }
                    }
                }
                if !customURL.isEmpty {
                    Button {
                        defaultMap = "custom"
                    } label: {
                        if defaultMap == "custom" { Label(customName, systemImage: "checkmark") }
                        else { Text(customName) }
                    }
                }
            }
            if let geo = point.geoURL {
                Button("Copy geo: link", systemImage: "location") { UIPasteboard.general.string = geo.absoluteString }
            }
            if result.selected?.id == point.id {
                Button("Share GPX file", systemImage: "square.and.arrow.up.on.square") { shareGPX(result.points) }
            }
            if result.points.count > 1, point.coordinateText != nil {
                Menu("Open in…", systemImage: "arrow.up.right") {
                    ForEach(MapTarget.allCases) { target in
                        Button(target.rawValue) { open(target, point) }
                    }
                    if !customURL.isEmpty { Button(customName) { openCustom(point) } }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .accessibilityLabel("Location actions")
    }

    private func mapRow(_ title: String, symbol: String, shareURL: URL?, action: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: symbol).frame(width: 24)
                    Text(title)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                }
                .frame(minHeight: 43)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let shareURL {
                Menu {
                    Button("Share link", systemImage: "square.and.arrow.up") { presentShare([shareURL]) }
                    Button("Copy link", systemImage: "link") { UIPasteboard.general.url = shareURL }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("\(title) link actions")
            }
        }
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Default link map") {
                    Picker("Share and copy with", selection: $defaultMap) {
                        ForEach(MapTarget.allCases) { target in Text(target.rawValue).tag(target.rawValue) }
                        if !customURL.isEmpty { Text(customName).tag("custom") }
                    }
                }
                Section("Custom map") {
                    TextField("Name", text: $customName)
                    TextField("URL template", text: $customURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Use {lat}, {lon}, {coords}, and {name}. Example: https://example.org/?q={coords}")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Online resolution") {
                    Toggle("Connect automatically", isOn: $automaticallyResolveOnline)
                    Text("When a link has no coordinates, connect to its map service without asking each time. The service receives the link and your IP address. Links with coordinates are still processed on device.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("About") {
                    Text("Version \(appVersion)")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSettings = false } } }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func readInbox() {
        guard let value = SharedInbox.take() else { return }
        model.input = value
        inputFocused = false
        model.process()
    }

    private func open(_ target: MapTarget, _ point: MapPoint) {
        guard let url = target.url(for: point) else { return }
        UIApplication.shared.open(url) { success in
            if !success { Task { @MainActor in message = "Install \(target.rawValue) to open this location." } }
        }
    }

    private func openCustom(_ point: MapPoint) {
        guard let url = customTargetURL(point) else { message = "Enter a valid HTTP or HTTPS custom map URL."; return }
        UIApplication.shared.open(url)
    }

    private func customTargetURL(_ point: MapPoint) -> URL? {
        guard let lat = point.latitude, let lon = point.longitude else { return nil }
        let value = customURL.replacingOccurrences(of: "{lat}", with: String(lat))
            .replacingOccurrences(of: "{lon}", with: String(lon))
            .replacingOccurrences(of: "{coords}", with: "\(lat),\(lon)")
            .replacingOccurrences(of: "{name}", with: (point.name ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        guard let url = URL(string: value), ["https", "http"].contains(url.scheme ?? "") else { return nil }
        return url
    }

    private func preferredShareURL(for point: MapPoint) -> URL? {
        if defaultMap == "custom", let url = customTargetURL(point) { return url }
        return (MapTarget(rawValue: defaultMap) ?? .apple).webURL(for: point)
    }

    private func shareGPX(_ points: [MapPoint]) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GeoShare-location.gpx")
        do {
            try LocationExport.gpx(points).write(to: url, atomically: true, encoding: .utf8)
            presentShare([url])
        } catch { message = error.localizedDescription }
    }

    private func presentShare(_ items: [Any]) {
        sharePayload = SharePayload(items: items)
    }
}
