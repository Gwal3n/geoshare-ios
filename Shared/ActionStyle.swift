import SwiftUI

extension View {
    @ViewBuilder func geoPrimaryAction() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.controlSize(.large).buttonStyle(.glassProminent)
        } else {
            self.controlSize(.large).buttonStyle(.borderedProminent)
        }
        #else
        self.controlSize(.large).buttonStyle(.borderedProminent)
        #endif
    }

    @ViewBuilder func geoSecondaryAction() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.controlSize(.large).buttonStyle(.glass)
        } else {
            self.controlSize(.large).buttonStyle(.bordered)
        }
        #else
        self.controlSize(.large).buttonStyle(.bordered)
        #endif
    }
}
