import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var voiceManager = VoiceManager.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingVoiceTest = false
    @State private var showingSubscribe = false
    @State private var showingSupport = false
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
                // Connection Section - Step by Step Guide
                Section(header: Text("🔗 Connect to Your Bot")) {
                    
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
                    
                    // Step-by-step guide when not connected
                    if case .notConnected = connectionStatus {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Step 1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text("connect clawphone")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.orange)
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = "connect clawphone"
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                            Text("Message your Clawbot on Telegram")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            Text("Step 2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Your bot will reply with an 8-digit code")
                                .font(.subheadline)
                            
                            Divider()
                            
                            Text("Step 3")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Enter the code below:")
                                .font(.subheadline)
                            
                            HStack {
                                TextField("8-digit code", text: $connectCode)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(.title3, design: .monospaced))
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
                        .padding(.vertical, 8)
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
                
                // Subscription Status
                Section(header: Text("🎭 Premium Voices")) {
                    if storeManager.isSubscribed {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Subscribed")
                                .foregroundColor(.green)
                            Spacer()
                            Text("All voices unlocked")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    } else {
                        Button(action: { showingSubscribe = true }) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Unlock All Voices")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("£0.99/mo")
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Voice Selection - Grouped by Category
                ForEach(CharacterVoice.grouped, id: \.category) { category, voices in
                    Section(header: Text(category)) {
                        ForEach(voices) { voice in
                            let isLocked = !storeManager.isSubscribed && !voice.isFree
                            
                            Button(action: {
                                if isLocked {
                                    showingSubscribe = true
                                } else {
                                    voiceManager.selectedVoice = voice
                                    voiceManager.saveSettings()
                                    updateServerCharacter(voice)
                                }
                            }) {
                                HStack {
                                    Text(voice.emoji)
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(voice.displayName)
                                            .foregroundColor(isLocked ? .secondary : .primary)
                                        if voice.isFree && !storeManager.isSubscribed {
                                            Text("FREE")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    Spacer()
                                    if isLocked {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.orange)
                                    } else if voiceManager.selectedVoice == voice {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Voice Mode - hidden from users, always use Fish Audio
                // (Internal toggle removed for cleaner UX)
                
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
                        Text("4.2.0")
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
                
                // Support
                Section {
                    Button(action: { showingSupport = true }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                            Text("Help & Support")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
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
            .sheet(isPresented: $showingSubscribe) {
                SubscribeView()
            }
            .sheet(isPresented: $showingSupport) {
                SupportView()
            }
        }
    }
    
    func testVoice() {
        let testPhrases: [CharacterVoice: String] = [
            .spongebob: "I'm ready, I'm ready, I'm ready!",
            .patrick: "Is mayonnaise an instrument?",
            .mrkrabs: "Money money money!",
            .squidward: "Oh please, how utterly predictable."
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
                        isConnecting = false
                        // Update AppState directly so we go to chat
                        appState.markConnected(botName: result.botName ?? "Bot")
                        // Dismiss settings and go to chat
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.dismiss()
                        }
                    } else {
                        connectionStatus = .error(result.message ?? "Invalid code")
                        isConnecting = false
                    }
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
        .environmentObject(AppState())
}
