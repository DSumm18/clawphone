import SwiftUI

struct SettingsView: View {
    @ObservedObject var voiceManager = VoiceManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var apiKey: String = ""
    @State private var showingApiKeyInfo = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                ClawTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Voice Selection
                        voiceSection
                        
                        // Premium Section
                        if voiceManager.voiceType == .premium {
                            premiumSection
                        }
                        
                        // Credits
                        creditsSection
                        
                        // Test Voice
                        testSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(ClawTheme.primary)
                }
            }
        }
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
        }
    }
    
    var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice")
                .font(.headline)
                .foregroundColor(ClawTheme.text)
            
            ForEach(VoiceManager.VoiceType.allCases, id: \.self) { type in
                Button(action: {
                    voiceManager.voiceType = type
                    voiceManager.saveSettings()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.displayName)
                                .font(.body)
                                .foregroundColor(ClawTheme.text)
                            Text(type.description)
                                .font(.caption)
                                .foregroundColor(ClawTheme.textSecondary)
                        }
                        Spacer()
                        if voiceManager.voiceType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ClawTheme.primary)
                        }
                    }
                    .padding()
                    .background(ClawTheme.surface)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    var premiumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Premium Voice Setup")
                    .font(.headline)
                    .foregroundColor(ClawTheme.text)
                
                Button(action: { showingApiKeyInfo = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(ClawTheme.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI API Key")
                    .font(.caption)
                    .foregroundColor(ClawTheme.textSecondary)
                
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(ClawTheme.surface)
                    .cornerRadius(12)
                    .onChange(of: apiKey) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "openaiApiKey")
                    }
            }
            
            Text("Premium voice uses OpenAI's TTS. ~£0.01 per message.")
                .font(.caption)
                .foregroundColor(ClawTheme.textSecondary)
        }
        .alert("Premium Voice", isPresented: $showingApiKeyInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Premium uses OpenAI's text-to-speech. Get an API key from platform.openai.com. Each message costs about £0.01.")
        }
    }
    
    var creditsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Credits")
                .font(.headline)
                .foregroundColor(ClawTheme.text)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(voiceManager.voiceCredits)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(ClawTheme.primary)
                    Text("credits remaining")
                        .font(.caption)
                        .foregroundColor(ClawTheme.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: In-app purchase
                }) {
                    Text("Get More")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ClawTheme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
            }
            .padding()
            .background(ClawTheme.surface)
            .cornerRadius(12)
        }
    }
    
    var testSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Voice")
                .font(.headline)
                .foregroundColor(ClawTheme.text)
            
            Button(action: {
                voiceManager.speak("Hey! I'm Ed, your AI assistant. How can I help you today?")
            }) {
                HStack {
                    Image(systemName: voiceManager.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    Text(voiceManager.isSpeaking ? "Speaking..." : "Test Ed's Voice")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ClawTheme.surface)
                .foregroundColor(ClawTheme.secondary)
                .cornerRadius(12)
            }
            .disabled(voiceManager.isSpeaking)
        }
    }
}

#Preview {
    SettingsView()
}
