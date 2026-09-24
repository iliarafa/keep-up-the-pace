import PaceKit
import SwiftUI

struct SettingsView: View {
    @Bindable var saved: SavedData

    var body: some View {
        Form {
            Section {
                Picker("Units", selection: $saved.settings.units) {
                    Text("Auto").tag(UnitsSetting.auto)
                    Text("Imperial").tag(UnitsSetting.imperial)
                    Text("Metric").tag(UnitsSetting.metric)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Units")
            } footer: {
                Text("Auto uses miles in the US and kilometres elsewhere.")
            }
            .listRowBackground(Theme.surface)

            Section("About") {
                LabeledContent("Version", value: Self.version)
                Text("Keep the Pace tells you how many seconds ahead of or behind schedule you are on the way to a place.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Settings")
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
