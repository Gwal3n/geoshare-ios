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
    @AppStorage(ConnectionPreferences.automaticKey, store: ConnectionPreferences.store) private var automaticallyResolveOnline = false
    @State private var showSettings = false
    @State private var message: String?
    @State private var copiedValue: String?
    @FocusState private var inputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("A place, in every map")
                            .font(.largeTitle.bold())
                        Text("Paste a map link and take the location anywhere.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    inputCard
                    if model.busy { ProgressView("Finding location…").frame(maxWidth: .infinity).padding() }
                    if let error = model.error { Text(error).foregroundStyle(.secondary).padding(.horizontal, 4) }
                    if model.needsNetwork { networkCard }
                    if let result = model.result { resultCard(result) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
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
            .alert("GeoShare", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
            .onAppear(perform: readInbox)
            .onChange(of: scenePhase) { _, phase in if phase == .active { readInbox() } }
        }
        .tint(Color(red: 0.14, green: 0.44, blue: 0.39))
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Map link or coordinates", systemImage: "link")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            TextField("https://maps.app.goo.gl/…", text: $model.input, axis: .vertical)
                .lineLimit(2...5).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($inputFocused)
                .keyboardType(.URL)
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            HStack(spacing: 10) {
                Button("Paste", systemImage: "doc.on.clipboard") {
                    if let text = UIPasteboard.general.string { model.input = text }
                }
                .frame(minHeight: 52)
                .geoSecondaryAction()
                Button("Find location", systemImage: "arrow.right") { inputFocused = false; model.process() }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .geoPrimaryAction().disabled(model.input.isEmpty || model.busy)
            }
        }
        .padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("This link needs a connection", systemImage: "network") .font(.headline)
            Text("GeoShare can visit the map service to follow its short link or read the place coordinates. The service will receive this link and your IP address.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Resolve online", systemImage: "network") { inputFocused = false; model.process(network: true) }
                .frame(maxWidth: .infinity, minHeight: 52).geoPrimaryAction()
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 26))
    }

    private func resultCard(_ result: MapResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.service.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.teal)
                    Text(result.selected?.name ?? "Location found").font(.title2.bold())
                        .textSelection(.enabled)
                }
                Spacer()
                if let address = result.selected?.name, !address.isEmpty {
                    Button {
                        UIPasteboard.general.string = address
                        copiedValue = address
                    } label: {
                        Label(copiedValue == address ? "Copied" : "Copy address", systemImage: copiedValue == address ? "checkmark" : "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(minHeight: 44)
                    .geoSecondaryAction()
                    .accessibilityHint("Copies the place name or address shown here")
                }
            }
            if result.points.count > 1 {
                Text("\(result.points.count) points in this route").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(result.points) { point in
                VStack(alignment: .leading, spacing: 8) {
                    Text(point.name ?? point.coordinateText ?? "Unknown point").font(.headline)
                    if let coordinates = point.coordinateText {
                        Text(coordinates).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                        Button("Copy coordinates", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = coordinates
                            copiedValue = coordinates
                        }
                        .font(.subheadline.weight(.medium))
                        if let geo = point.geoURL {
                            Button("Copy geo: link", systemImage: "link") {
                                UIPasteboard.general.string = geo.absoluteString
                                copiedValue = geo.absoluteString
                            }
                            .font(.subheadline.weight(.medium))
                        }
                        if result.points.count > 1 {
                            Menu("Open in…", systemImage: "arrow.up.right") {
                                ForEach(MapTarget.allCases) { target in
                                    Button(target.rawValue) { open(target, point) }
                                }
                                if !customURL.isEmpty { Button(customName) { openCustom(point) } }
                            }
                        }
                    } else { Text("Coordinates unavailable; the name may be ambiguous.").font(.subheadline).foregroundStyle(.secondary) }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            }
            if let point = result.selected, point.coordinateText != nil {
                if let url = MapTarget.apple.url(for: point) {
                    HStack(spacing: 10) {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .geoPrimaryAction()
                        Button {
                            UIPasteboard.general.url = url
                            copiedValue = url.absoluteString
                        } label: {
                            Label(copiedValue == url.absoluteString ? "Copied" : "Copy link", systemImage: copiedValue == url.absoluteString ? "checkmark" : "link")
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .geoSecondaryAction()
                    }
                }
                Text(result.points.count > 1 ? "OPEN LAST POINT IN" : "OPEN IN")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(MapTarget.allCases) { target in
                    Button { open(target, point) } label: {
                        HStack { Label(target.rawValue, systemImage: target.symbol); Spacer(); Image(systemName: "arrow.up.right") }
                            .font(.body.weight(.semibold))
                            .frame(minHeight: 52)
                            .padding(.horizontal, 16)
                    }
                    .geoSecondaryAction()
                }
                if !customURL.isEmpty {
                    Button { openCustom(point) } label: {
                        Label(customName, systemImage: "link")
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .padding(.horizontal, 16)
                    }
                    .geoSecondaryAction()
                }
                Button("Share GPX file", systemImage: "square.and.arrow.up") { shareGPX(result.points) }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .geoSecondaryAction()
            }
            if let note = result.note { Text(note).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
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
