import Shared
import SwiftUI

struct ContentView: View {
    private let sharedModuleStatus = KmpCheck.shared.isWorking()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.tint)

                Text("VibeSync All in ONE PDF Suite")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("iOS application scaffold")
                    .font(.headline)

                Text(sharedModuleStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("shared_module_status")
            }
            .padding(24)
            .navigationTitle("VibeSync")
        }
    }
}
