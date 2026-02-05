import SwiftUI

@main
struct ClawPhoneApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            if appState.hasCheckedConnection {
                if appState.isConnected {
                    ContentView()
                        .preferredColorScheme(.dark)
                        .environmentObject(appState)
                } else {
                    // First time - show setup screen
                    SetupView()
                        .preferredColorScheme(.dark)
                        .environmentObject(appState)
                }
            } else {
                // Loading state
                ZStack {
                    Color(hex: "0A0A0F").ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)
                        Text("ClawPhone")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding(.top)
                    }
                }
                .preferredColorScheme(.dark)
                .onAppear {
                    appState.checkConnection()
                }
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var isConnected = false
    @Published var hasCheckedConnection = false
    @Published var connectedBotName: String?
    
    private var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: "deviceId") {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "deviceId")
        return newId
    }
    
    func checkConnection() {
        guard let url = URL(string: "http://142.132.160.28:8080/api/connection/status?deviceId=\(deviceId)") else {
            hasCheckedConnection = true
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let connected = json["connected"] as? Bool {
                    self?.isConnected = connected
                    self?.connectedBotName = json["botName"] as? String
                }
                self?.hasCheckedConnection = true
            }
        }.resume()
    }
    
    func markConnected(botName: String) {
        isConnected = true
        connectedBotName = botName
    }
}

// Setup screen for first-time users
struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0F").ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.purple)
                
                Text("Welcome to ClawPhone")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Talk to your AI bot using your voice")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 16) {
                    SetupStep(number: 1, text: "Message your bot: \"connect clawphone\"")
                    SetupStep(number: 2, text: "Your bot will give you an 8-digit code")
                    SetupStep(number: 3, text: "Enter the code below to connect")
                }
                .padding()
                .background(Color(hex: "1A1A24"))
                .cornerRadius(16)
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: { showingSettings = true }) {
                    Text("Connect Your Bot")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            appState.checkConnection()
        }) {
            SettingsView()
        }
    }
}

struct SetupStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.purple)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

// Color extension defined in ContentView.swift
