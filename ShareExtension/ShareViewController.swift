import SwiftUI
import UniformTypeIdentifiers
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareContentView(close: { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        loadInput { value in
            host.rootView = ShareContentView(input: value, close: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            })
        }
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
    var input = ""
    var close: () -> Void
    @State private var result: MapResult?
    @State private var error: String?
    @State private var busy = false
    @State private var needsNetwork = false
    @State private var shareURL: URL?
    @AppStorage(ConnectionPreferences.automaticKey, store: ConnectionPreferences.store) private var automaticallyResolveOnline = false

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
                        Button("Resolve online") { process(network: true) }.buttonStyle(.borderedProminent)
                    }
                    if let result {
                        ForEach(result.points) { point in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(point.name ?? "Location").font(.headline)
                                if let coordinates = point.coordinateText {
                                    Text(coordinates).font(.system(.body, design: .monospaced))
                                    Button("Copy coordinates", systemImage: "doc.on.doc") { UIPasteboard.general.string = coordinates }
                                    if let geo = point.geoURL { Button("Copy geo: link") { UIPasteboard.general.string = geo.absoluteString } }
                                } else { Text("Coordinates unavailable").foregroundStyle(.secondary) }
                            }
                            .padding().frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        if let point = result.selected, point.coordinateText != nil {
                            Button("Save for GeoShare app", systemImage: "square.and.arrow.down") {
                                SharedInbox.save(input); close()
                            }.buttonStyle(.borderedProminent)
                            Text("Open the GeoShare app to choose Apple Maps, Organic Maps, CoMaps, or another map.")
                                .font(.caption).foregroundStyle(.secondary)
                            if let url = MapTarget.apple.url(for: point) { ShareLink("Share Apple Maps link", item: url) }
                        }
                    }
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("GeoShare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done", action: close) } }
            .onAppear { if !input.isEmpty { process() } }
        }
        .tint(Color(red: 0.14, green: 0.44, blue: 0.39))
    }

    private func process(network: Bool = false) {
        busy = true; error = nil; needsNetwork = false
        Task { @MainActor in
            do { result = try await LinkResolver.resolve(input, allowNetwork: network || automaticallyResolveOnline) }
            catch {
                self.error = error.localizedDescription
                if !network && !automaticallyResolveOnline && MapParser.extractURL(input) != nil { needsNetwork = true }
            }
            busy = false
        }
    }
}
