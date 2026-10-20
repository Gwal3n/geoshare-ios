import SwiftUI
import UniformTypeIdentifiers
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: makeContent(input: ""))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        loadInput { value in
            host.rootView = self.makeContent(input: value)
        }
    }

    private func makeContent(input: String) -> ShareContentView {
        ShareContentView(input: input, close: { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }, open: { [weak self] url, completion in
            guard let context = self?.extensionContext else { completion(false); return }
            context.open(url) { success in
                DispatchQueue.main.async { completion(success) }
            }
        }, offer: { [weak self] url in
            guard let self else { return }
            let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = self.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
            self.present(sheet, animated: true)
        })
    }

    private func loadInput(_ completion: @escaping (String) -> Void) {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                DispatchQueue.main.async { completion((item as? URL)?.absoluteString ?? (item as? String) ?? "") }
            }
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                DispatchQueue.main.async { completion((item as? String) ?? "") }
            }
        } else {
            completion(items.compactMap { $0.attributedContentText?.string }.first ?? "")
        }
    }
}

private struct ShareContentView: View {
    @Environment(\.openURL) private var openURL
    var input = ""
    var close: () -> Void
    var open: (URL, @escaping (Bool) -> Void) -> Void
    var offer: (URL) -> Void
    @State private var result: MapResult?
    @State private var error: String?
    @State private var busy = false
    @State private var needsNetwork = false
    @State private var copiedValue: String?
    @AppStorage(ConnectionPreferences.automaticKey, store: ConnectionPreferences.store) private var automaticallyResolveOnline = false
    @AppStorage("customMapName", store: ConnectionPreferences.store) private var customName = "Custom map"
    @AppStorage("customMapURL", store: ConnectionPreferences.store) private var customURL = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Jump between maps", systemImage: "location.north.circle.fill")
                        .font(.title2.bold()).foregroundStyle(.teal)
                    Text(input.isEmpty ? "Waiting for a map link…" : input)
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                    if busy { ProgressView("Finding location…") }
                    if let error { Text(error).font(.subheadline).foregroundStyle(.secondary) }
                    if needsNetwork {
                        Text("This link needs an online lookup. The map service will receive the link and your IP address.")
                            .font(.subheadline)
                        Button("Resolve online", systemImage: "network") { process(network: true) }
                            .frame(maxWidth: .infinity, minHeight: 52).geoPrimaryAction()
                        Button("Always resolve online") { automaticallyResolveOnline = true; process(network: true) }
                    }
                    if let result {
                        ForEach(Array(result.points.enumerated()), id: \.element.id) { index, point in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 10) {
                                    Text(point.name ?? "Place \(index + 1)").font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                    if let address = point.name, !address.isEmpty {
                                        Button {
                                            UIPasteboard.general.string = address
                                            copiedValue = address
                                        } label: {
                                            Label(copiedValue == address ? "Copied" : "Copy address", systemImage: copiedValue == address ? "checkmark" : "doc.on.doc")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                        .frame(minHeight: 44).geoSecondaryAction()
                                        .accessibilityHint("Copies the place name or address shown here")
                                    }
                                }
                                if let coordinates = point.coordinateText {
                                    Text(coordinates).font(.system(.body, design: .monospaced))
                                    Button("Copy coordinates", systemImage: "doc.on.doc") { UIPasteboard.general.string = coordinates }
                                    if let geo = point.geoURL {
                                        Button("Copy geo: link", systemImage: "link") { UIPasteboard.general.string = geo.absoluteString }
                                    }
                                    if result.points.count > 1 {
                                        Menu("Open in…", systemImage: "arrow.up.right") {
                                            ForEach(MapTarget.allCases) { target in
                                                Button(target.rawValue) { openTarget(target, point) }
                                            }
                                        }
                                    }
                                } else { Text("Coordinates unavailable").foregroundStyle(.secondary) }
                            }
                            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                        }
                        if let point = result.selected, point.coordinateText != nil {
                            if let url = MapTarget.apple.url(for: point) {
                                HStack(spacing: 10) {
                                    Button { offer(url) } label: {
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
                            Text("OPEN IN").font(.caption.bold()).foregroundStyle(.secondary)
                            ForEach(MapTarget.allCases) { target in
                                Button { openTarget(target, point) } label: {
                                    HStack { Label(target.rawValue, systemImage: target.symbol); Spacer(); Image(systemName: "arrow.up.right") }
                                        .font(.body.weight(.semibold))
                                        .frame(minHeight: 52)
                                        .padding(.horizontal, 16)
                                }
                                .geoSecondaryAction()
                            }
                            if !customURL.isEmpty, let url = customTargetURL(point) {
                                Button { openDestination(url, fallback: url) } label: {
                                    Label(customName, systemImage: "link")
                                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                        .padding(.horizontal, 16)
                                }
                                .geoSecondaryAction()
                            }
                            Text("If iOS blocks opening from the share extension, choose an app from the system sheet.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Continue in GeoShare app", systemImage: "arrow.up.forward.app") {
                                SharedInbox.save(input); close()
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .geoSecondaryAction()
                        }
                    }
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("GeoShare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done", action: close) } }
            .onChange(of: input, initial: true) { _, sharedLink in
                if !sharedLink.isEmpty { process() }
            }
            .onChange(of: automaticallyResolveOnline) { _, enabled in
                if enabled && needsNetwork { process() }
            }
        }
        .tint(Color(red: 0.14, green: 0.44, blue: 0.39))
    }

    private func process(network: Bool = false) {
        busy = true; result = nil; error = nil; needsNetwork = false
        let sharedLink = input
        let allowNetwork = network || ConnectionPreferences.automaticallyResolveOnline
        Task { @MainActor in
            do { result = try await LinkResolver.resolve(sharedLink, allowNetwork: allowNetwork) }
            catch {
                self.error = error.localizedDescription
                if !allowNetwork && MapParser.extractURL(sharedLink) != nil { needsNetwork = true }
            }
            busy = false
        }
    }

    private func openTarget(_ target: MapTarget, _ point: MapPoint) {
        guard let url = target.url(for: point) else { return }
        openDestination(url, fallback: target.webURL(for: point) ?? url)
    }

    private func openDestination(_ url: URL, fallback: URL) {
        openURL(url) { accepted in
            if accepted {
                close()
            } else {
                open(url) { success in
                    if success { close() }
                    else { offer(fallback) }
                }
            }
        }
    }

    private func customTargetURL(_ point: MapPoint) -> URL? {
        guard let latitude = point.latitude, let longitude = point.longitude else { return nil }
        let value = customURL.replacingOccurrences(of: "{lat}", with: String(latitude))
            .replacingOccurrences(of: "{lon}", with: String(longitude))
            .replacingOccurrences(of: "{coords}", with: "\(latitude),\(longitude)")
            .replacingOccurrences(of: "{name}", with: (point.name ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        guard let url = URL(string: value), ["https", "http"].contains(url.scheme ?? "") else { return nil }
        return url
    }
}
