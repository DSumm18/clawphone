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

// Setup screen for first-time users - Maltbot branded
struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false
    @State private var lobsterScale: CGFloat = 0.8
    @State private var lobsterOpacity: Double = 0
    
    // Brand colors - matching Maltbot website
    let brandRed = Color(hex: "E85A4F")
    let brandOrange = Color(hex: "F97316")
    let brandDark = Color(hex: "0A0A0F")
    let brandSurface = Color(hex: "1A1A1F")
    
    var body: some View {
        ZStack {
            // Dark background with subtle gradient
            LinearGradient(
                colors: [brandDark, Color(hex: "0F0F15")],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                // Lobster icon with animation
                Image("LobsterButton")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(lobsterScale)
                    .opacity(lobsterOpacity)
                    .onAppear {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                            lobsterScale = 1.0
                            lobsterOpacity = 1.0
                        }
                    }
                
                // Main headline
                VStack(spacing: 8) {
                    Text("Talk to Your Clawbot")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("on iPhone & Apple Watch")
                        .font(.title3)
                        .foregroundColor(brandOrange)
                }
                .padding(.top, 8)
                
                // Tagline - explains the value
                Text("Connect your personal AI assistant and chat using voice — in 20+ fun character voices")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                // Setup steps card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Connect Your Clawbot")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(brandOrange)
                        .textCase(.uppercase)
                        .tracking(1)
                    
                    SetupStep(number: 1, text: "Open Telegram and message your Clawbot", accentColor: brandRed)
                    SetupStep(number: 2, text: "Say: connect clawphone", accentColor: brandRed)
                    SetupStep(number: 3, text: "Enter the 8-digit code below", accentColor: brandRed)
                    
                    // Explainer for new users
                    HStack {
                        Text("Don't have a Clawbot?")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Link("Get one at clawbot.ai", destination: URL(string: "https://clawbot.ai")!)
                            .font(.caption2)
                            .foregroundColor(brandOrange)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .background(brandSurface)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(brandRed.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                Spacer()
                
                // CTA Button - red/orange gradient
                Button(action: { showingSettings = true }) {
                    HStack {
                        Image(systemName: "link.circle.fill")
                        Text("Connect Your Bot")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [brandRed, brandOrange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: brandRed.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            if !appState.isConnected {
                appState.checkConnection()
            }
        }) {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

struct SetupStep: View {
    let number: Int
    let text: String
    var accentColor: Color = Color(hex: "E85A4F")
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(accentColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// Color extension defined in ContentView.swift
