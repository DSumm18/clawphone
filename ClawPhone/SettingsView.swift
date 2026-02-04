import SwiftUI

struct SettingsView: View {
    @ObservedObject private var voiceManager = VoiceManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingVoiceTest = false
    
    var body: some View {
        NavigationView {
            Form {
                // Voice Selection
                Section(header: Text("Character Voice")) {
                    ForEach(CharacterVoice.allCases) { voice in
                        Button(action: {
                            voiceManager.selectedVoice = voice
                            voiceManager.saveSettings()
                            updateServerCharacter(voice)
                        }) {
                            HStack {
                                Text(voice.emoji)
                                    .font(.title2)
                                Text(voice.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if voiceManager.selectedVoice == voice {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Voice Mode
                Section(header: Text("Voice Mode"), footer: Text("Fish Audio provides character voices like SpongeBob. Apple TTS is a fallback.")) {
                    Toggle("Use Fish Audio", isOn: $voiceManager.useFishAudio)
                        .onChange(of: voiceManager.useFishAudio) { _ in
                            voiceManager.saveSettings()
                        }
                }
                
                // Test Voice
                Section {
                    Button(action: testVoice) {
                        HStack {
                            Image(systemName: "speaker.wave.3")
                            Text("Test Voice")
                        }
                    }
                    .disabled(voiceManager.isSpeaking)
                }
                
                // About
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Server")
                        Spacer()
                        Text("142.132.160.28")
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func testVoice() {
        let testPhrases: [CharacterVoice: String] = [
            .spongebob: "I'm ready, I'm ready, I'm ready!",
            .patrick: "Is mayonnaise an instrument?",
            .mrkrabs: "Money money money!",
            .squidward: "Oh please, how utterly predictable.",
            .ed: "Hey there! Ready to get things done?"
        ]
        
        let phrase = testPhrases[voiceManager.selectedVoice] ?? "Hello! This is a test."
        voiceManager.speak(phrase)
    }
    
    func updateServerCharacter(_ voice: CharacterVoice) {
        let deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? ""
        guard !deviceId.isEmpty else { return }
        
        Task {
            try? await APIClient.shared.setCharacter(voice.rawValue, userId: deviceId)
        }
    }
}

#Preview {
    SettingsView()
}
