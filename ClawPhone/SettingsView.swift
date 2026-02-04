import SwiftUI

struct SettingsView: View {
    @ObservedObject private var voiceManager = VoiceManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingVoiceTest = false
    @State private var connectCode = ""
    @State private var isConnecting = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var connectedBotName: String? = nil
    
    enum ConnectionStatus {
        case unknown, connected, notConnected, error(String)
    }
    
    private let deviceId: String = {
        UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString
    }()
    
    var body: some View {
        NavigationView {
            Form {
                // Connection Section - Most Important!
                Section(header: Text("🔗 Connect to Your Bot"), footer: Text("Get your 8-digit code from your Clawdbot by typing /connect clawphone")) {
                    
                    // Status indicator
                    HStack {
                        Text("Status")
                        Spacer()
                        switch connectionStatus {
                        case .connected:
                            HStack {
                                Circle().fill(Color.green).frame(width: 8, height: 8)
                                Text(connectedBotName ?? "Connected")
                                    .foregroundColor(.green)
                            }
                        case .notConnected:
                            HStack {
                                Circle().fill(Color.orange).frame(width: 8, height: 8)
                                Text("Not Connected")
                                    .foregroundColor(.orange)
                            }
                        case .error(let msg):
                            Text(msg).foregroundColor(.red)
                        case .unknown:
                            Text("Checking...").foregroundColor(.secondary)
                        }
                    }
                    
                    // Connect code input
                    if case .notConnected = connectionStatus {
                        HStack {
                            TextField("Enter 8-digit code", text: $connectCode)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(isConnecting)
                            
                            Button(action: submitConnectCode) {
                                if isConnecting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Connect")
                                        .fontWeight(.semibold)
                                }
                            }
                            .disabled(connectCode.count != 8 || isConnecting)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    // Disconnect option
                    if case .connected = connectionStatus {
                        Button(action: disconnect) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Disconnect")
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                
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
            .onAppear {
                checkConnectionStatus()
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
    
    func checkConnectionStatus() {
        Task {
            do {
                let status = try await APIClient.shared.checkConnectionStatus(deviceId: deviceId)
                await MainActor.run {
                    if status.connected {
                        connectionStatus = .connected
                        connectedBotName = status.botName
                    } else {
                        connectionStatus = .notConnected
                    }
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .notConnected
                }
            }
        }
    }
    
    func submitConnectCode() {
        guard connectCode.count == 8 else { return }
        isConnecting = true
        
        Task {
            do {
                let result = try await APIClient.shared.validateConnectCode(code: connectCode, deviceId: deviceId)
                await MainActor.run {
                    if result.success {
                        connectionStatus = .connected
                        connectedBotName = result.botName
                        connectCode = ""
                    } else {
                        connectionStatus = .error(result.message ?? "Invalid code")
                    }
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .error("Connection failed")
                    isConnecting = false
                }
            }
        }
    }
    
    func disconnect() {
        // Clear local connection (server-side would need an endpoint)
        UserDefaults.standard.removeObject(forKey: "connectedBot")
        connectionStatus = .notConnected
        connectedBotName = nil
    }
}

#Preview {
    SettingsView()
}
