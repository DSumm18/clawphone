import SwiftUI
import AVFoundation
import Speech

// MARK: - Theme
struct ClawTheme {
    static let background = Color(hex: "0A0A0F")
    static let surface = Color(hex: "1A1A24")
    static let primary = Color(hex: "8B5CF6")
    static let secondary = Color(hex: "06B6D4")
    static let accent = Color(hex: "F472B6")
    static let text = Color.white
    static let textSecondary = Color(hex: "9CA3AF")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingSetup = false
    
    var body: some View {
        ZStack {
            ClawTheme.background.ignoresSafeArea()
            
            if viewModel.isConnected {
                ChatView(viewModel: viewModel)
            } else {
                SetupView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Setup View
struct SetupView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var code = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Logo
            Text("🦞")
                .font(.system(size: 80))
            
            Text("ClawPhone")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(ClawTheme.primary)
            
            Text("Voice chat with Ed")
                .font(.title3)
                .foregroundColor(ClawTheme.textSecondary)
            
            Spacer()
            
            // Setup instructions
            VStack(spacing: 16) {
                Text("Get your 6-digit code:")
                    .font(.headline)
                    .foregroundColor(ClawTheme.text)
                
                Text("Message @ClawWatchSetup_bot on Telegram\nand send /connect")
                    .font(.subheadline)
                    .foregroundColor(ClawTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Code input
            TextField("Enter 6-digit code", text: $code)
                .keyboardType(.numberPad)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
                .background(ClawTheme.surface)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .onChange(of: code) { newValue in
                    code = String(newValue.prefix(6).filter { $0.isNumber })
                }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Connect button
            Button(action: connect) {
                HStack {
                    if isConnecting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isConnecting ? "Connecting..." : "Connect")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(code.count == 6 ? ClawTheme.primary : ClawTheme.surface)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(code.count != 6 || isConnecting)
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    func connect() {
        isConnecting = true
        errorMessage = nil
        
        guard let url = URL(string: "https://clawwatch-setup.vercel.app/api/verify") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["code": code])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isConnecting = false
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool, success,
                      let config = json["config"] as? [String: Any],
                      let chatId = config["chatId"] as? Int else {
                    errorMessage = "Invalid or expired code"
                    return
                }
                
                viewModel.connect(chatId: String(chatId))
            }
        }.resume()
    }
}

// MARK: - Chat View
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🦞")
                    .font(.title2)
                Text("Ed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ClawTheme.text)
                
                Spacer()
                
                // Settings button
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(ClawTheme.textSecondary)
                }
                .padding(.trailing, 8)
                
                // Disconnect button
                Button(action: { viewModel.disconnect() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(ClawTheme.textSecondary)
                }
            }
            .padding()
            .background(ClawTheme.surface)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Voice input area
            VoiceInputBar(viewModel: viewModel, messageText: $messageText)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser { Spacer(minLength: 60) }
            
            HStack(alignment: .top, spacing: 8) {
                if !message.isFromUser {
                    Text("🦞")
                        .font(.title3)
                }
                
                Text(message.text)
                    .padding(12)
                    .background(message.isFromUser ? ClawTheme.primary : ClawTheme.surface)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            
            if !message.isFromUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Voice Input Bar
struct VoiceInputBar: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var messageText: String
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isRecording = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Text field
            TextField("Type or tap mic...", text: $messageText)
                .padding(12)
                .background(ClawTheme.surface)
                .cornerRadius(20)
                .onSubmit { sendMessage() }
            
            // Mic / Send button
            Button(action: {
                if !messageText.isEmpty {
                    sendMessage()
                } else {
                    toggleRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : (messageText.isEmpty ? ClawTheme.secondary : ClawTheme.primary))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: isRecording ? "stop.fill" : (messageText.isEmpty ? "mic.fill" : "arrow.up"))
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(ClawTheme.background)
        .onChange(of: speechRecognizer.transcript) { newValue in
            messageText = newValue
        }
    }
    
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        viewModel.sendMessage(messageText)
        messageText = ""
    }
    
    func toggleRecording() {
        if isRecording {
            speechRecognizer.stopTranscribing()
            isRecording = false
            if !messageText.isEmpty {
                sendMessage()
            }
        } else {
            messageText = ""
            speechRecognizer.startTranscribing()
            isRecording = true
        }
    }
}

// MARK: - Data Models
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    let timestamp: Date
}

// MARK: - Chat View Model
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isConnected = false
    
    private var chatId: String = ""
    private var pollTimer: Timer?
    private let voiceManager = VoiceManager.shared
    
    init() {
        // Check if already connected
        if let savedChatId = UserDefaults.standard.string(forKey: "chatId"), !savedChatId.isEmpty {
            chatId = savedChatId
            isConnected = true
            startPolling()
        }
    }
    
    func connect(chatId: String) {
        self.chatId = chatId
        UserDefaults.standard.set(chatId, forKey: "chatId")
        isConnected = true
        startPolling()
        
        // Welcome message
        let welcome = ChatMessage(text: "Hey! I'm Ed 🦞 What's on your mind?", isFromUser: false, timestamp: Date())
        messages.append(welcome)
        speak(welcome.text)
    }
    
    func disconnect() {
        chatId = ""
        UserDefaults.standard.removeObject(forKey: "chatId")
        isConnected = false
        messages.removeAll()
        pollTimer?.invalidate()
    }
    
    func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchMessages()
        }
    }
    
    func fetchMessages() {
        guard !chatId.isEmpty else { return }
        
        guard let url = URL(string: "https://clawwatch-setup.vercel.app/api/messages?chatId=\(chatId)") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messages = json["messages"] as? [[String: Any]] else { return }
            
            DispatchQueue.main.async {
                for msg in messages {
                    if let text = msg["text"] as? String {
                        let response = ChatMessage(text: text, isFromUser: false, timestamp: Date())
                        self?.messages.append(response)
                        self?.speak(text)
                    }
                }
            }
        }.resume()
    }
    
    func sendMessage(_ text: String) {
        guard !chatId.isEmpty else { return }
        
        let userMessage = ChatMessage(text: text, isFromUser: true, timestamp: Date())
        messages.append(userMessage)
        
        guard let url = URL(string: "https://clawwatch-setup.vercel.app/api/send") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "chatId": chatId,
            "message": text
        ])
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func speak(_ text: String) {
        voiceManager.speak(text)
    }
}

// MARK: - Speech Recognizer
class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    
    func startTranscribing() {
        transcript = ""
        
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            
            DispatchQueue.main.async {
                self?.startRecording()
            }
        }
    }
    
    private func startRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    func stopTranscribing() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}

#Preview {
    ContentView()
}
