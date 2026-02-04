import SwiftUI
import WatchKit
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = WatchViewModel()
    
    var body: some View {
        VStack(spacing: 8) {
            // Status
            if viewModel.isConnected {
                Text("🦞 Connected")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Text("Setup in iPhone app")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            // Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.messages.suffix(5), id: \.id) { msg in
                        MessageRow(message: msg)
                    }
                }
            }
            .frame(maxHeight: 80)
            
            // Voice button
            Button(action: { viewModel.toggleRecording() }) {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.purple)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
        }
        .onAppear { viewModel.checkConnection() }
    }
}

struct MessageRow: View {
    let message: WatchMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                Text(message.text)
                    .font(.caption2)
                    .padding(6)
                    .background(Color.purple.opacity(0.3))
                    .cornerRadius(8)
            } else {
                Text(message.text)
                    .font(.caption2)
                    .padding(6)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
                Spacer()
            }
        }
    }
}

struct WatchMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
}

class WatchViewModel: ObservableObject {
    @Published var messages: [WatchMessage] = []
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var isConnected = false
    
    private let baseURL = "http://142.132.160.28:8080/api"
    
    func checkConnection() {
        // Check if device is linked via shared UserDefaults
        if let deviceId = UserDefaults.standard.string(forKey: "deviceId"),
           !deviceId.isEmpty {
            isConnected = true
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        isRecording = true
        // TODO: Speech recognition
    }
    
    func stopRecording() {
        isRecording = false
        // Send message
        sendMessage("Hello from Watch!")
    }
    
    func sendMessage(_ text: String) {
        guard let deviceId = UserDefaults.standard.string(forKey: "deviceId") else { return }
        
        messages.append(WatchMessage(text: text, isFromUser: true))
        isProcessing = true
        
        guard let url = URL(string: "\(baseURL)/send") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["message": text, "userId": deviceId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                self?.isProcessing = false
                self?.pollForResponse()
            }
        }.resume()
    }
    
    func pollForResponse() {
        // Poll for response after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.messages.append(WatchMessage(text: "Response received!", isFromUser: false))
        }
    }
}
