//
//  SettingsView.swift
//  Unblur
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    Button("Save") {
                        KeychainHelper.set(apiKey, for: SecretKey.claudeAPIKey)
                        saved = true
                    }
                    if saved {
                        Text("Saved").font(.caption).foregroundStyle(.green)
                    }
                    Button("Clear", role: .destructive) {
                        KeychainHelper.delete(SecretKey.claudeAPIKey)
                        apiKey = ""
                        saved = false
                    }
                } header: {
                    Text("Claude API Key")
                } footer: {
                    Text("Used for sentence translation and Q&A. Stored in the iOS Keychain.")
                }
                Section("About") {
                    LabeledContent("Version", value: "0.4-prototype")
                    LabeledContent("Feed", value: "feeds.megaphone.fm/STHZE…")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                apiKey = KeychainHelper.get(SecretKey.claudeAPIKey) ?? ""
            }
        }
    }
}
