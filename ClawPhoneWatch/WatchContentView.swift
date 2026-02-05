import SwiftUI
import AVFoundation
import WatchConnectivity

// Simple watch app that records voice and sends to phone
struct WatchContentView: View {
    @StateObject private var recorder = WatchRecorder()
    @State private var messages: [WatchMessage] = []
    @State private var isConnectedToPhone = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Connection status
            HStack {
                Circle()
                    .fill(isConnectedToPhone ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(isConnectedToPhone ? "Connected" : "Phone Required")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Messages
            if messages.isEmpty {
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
                Text("ClawPhone")
                    .font(.headline)
                Text("Tap to talk")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    ForEach(messages.suffix(5)) { msg in
                        HStack {
                            if msg.isUser { Spacer() }
                            Text(msg.text)
                                .font(.caption)
                                .padding(8)
                                .background(msg.isUser ? Color.purple : Color.gray.opacity(0.3))
                                .cornerRadius(12)
                            if !msg.isUser { Spacer() }
                        }
                    }
                }
            }
            
            // Record button
            Button(action: {
                if recorder.isRecording {
                    recorder.stopRecording()
                } else {
                    recorder.startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Color.red : Color.purple)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(!isConnectedToPhone)
        }
        .padding()
        .onAppear {
            checkPhoneConnection()
        }
    }
    
    func checkPhoneConnection() {
        isConnectedToPhone = WCSession.default.isReachable
    }
}

struct WatchMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

// Simple audio recorder for watchOS
class WatchRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    private var audioRecorder: AVAudioRecorder?
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            
            let url = getDocumentsDirectory().appendingPathComponent("recording.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Recording failed: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        // Send to phone via WatchConnectivity
        sendToPhone()
    }
    
    func sendToPhone() {
        guard WCSession.default.isReachable else { return }
        
        let url = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        if let data = try? Data(contentsOf: url) {
            WCSession.default.sendMessageData(data, replyHandler: nil, errorHandler: nil)
        }
    }
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

#Preview {
    WatchContentView()
}
