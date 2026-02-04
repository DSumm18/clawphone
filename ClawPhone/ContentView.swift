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
    
    var body: some View {
        ZStack {
            ClawTheme.background.ignoresSafeArea()
            ChatView(viewModel: viewModel)
        }
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
                Text(viewModel.voiceManager.selectedVoice.emoji)
                    .font(.title2)
                Text(viewModel.voiceManager.selectedVoice.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ClawTheme.text)
                
                Spacer()
                
                // Status indicator
                if viewModel.isWaitingForResponse {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }
                
                // Settings button
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
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
                            MessageBubble(message: message, emoji: viewModel.voiceManager.selectedVoice.emoji)
                                .id(message.id)
                        }
                        
                        // Show typing indicator when waiting
                        if viewModel.isWaitingForResponse {
                            TypingIndicator(emoji: viewModel.voiceManager.selectedVoice.emoji)
                                .id("typing")
                                .transition(.opacity.combined(with: .scale))
                        }
                        
                        // Bottom anchor for reliable scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isWaitingForResponse)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    // Delay to ensure view has rendered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // Scroll to bottom on load
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        proxy.scrollTo("bottom", anchor: .bottom)
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
    let emoji: String
    @State private var appeared = false
    
    var body: some View {
        HStack {
            if message.isFromUser { Spacer(minLength: 60) }
            
            HStack(alignment: .top, spacing: 8) {
                if !message.isFromUser {
                    Text(emoji)
                        .font(.title3)
                }
                
                Text(message.text)
                    .padding(12)
                    .background(message.isFromUser ? ClawTheme.primary : ClawTheme.surface)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .scaleEffect(appeared ? 1.0 : 0.8)
            .opacity(appeared ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    appeared = true
                }
            }
            
            if !message.isFromUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    let emoji: String
    @State private var dotScale: [CGFloat] = [1, 1, 1]
    
    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 8) {
                Text(emoji)
                    .font(.title3)
                
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(ClawTheme.textSecondary)
                            .frame(width: 8, height: 8)
                            .scaleEffect(dotScale[index])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(ClawTheme.surface)
                .cornerRadius(16)
            }
            Spacer(minLength: 60)
        }
        .onAppear { animateDots() }
    }
    
    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                Animation.easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
            ) {
                dotScale[i] = 1.4
            }
        }
    }
}

// MARK: - Voice Input Bar
struct VoiceInputBar: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var messageText: String
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isRecording = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    @State private var rotation: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Text field
            TextField("Type or tap the lobster...", text: $messageText)
                .padding(12)
                .background(ClawTheme.surface)
                .foregroundColor(ClawTheme.text)
                .cornerRadius(20)
                .onSubmit { sendMessage() }
                .disabled(viewModel.isWaitingForResponse)
            
            // Lobster button with animations
            Button(action: {
                if !messageText.isEmpty {
                    sendMessage()
                } else {
                    toggleRecording()
                }
            }) {
                ZStack {
                    // Outer pulsing ring (when idle and ready)
                    if !isRecording && !viewModel.isWaitingForResponse && messageText.isEmpty {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [ClawTheme.primary, ClawTheme.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 70, height: 70)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity)
                    }
                    
                    // Main button circle
                    Circle()
                        .fill(
                            isRecording ? 
                                LinearGradient(colors: [Color.red, Color.red.opacity(0.8)], startPoint: .top, endPoint: .bottom) :
                                LinearGradient(
                                    colors: [ClawTheme.primary.opacity(0.2), ClawTheme.secondary.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [ClawTheme.primary, ClawTheme.secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    
                    // Lobster or send icon
                    if !messageText.isEmpty {
                        Image(systemName: "arrow.up")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ClawTheme.primary)
                    } else {
                        Text("🦞")
                            .font(.system(size: 30))
                            .rotationEffect(.degrees(isRecording ? rotation : 0))
                    }
                }
            }
            .disabled(viewModel.isWaitingForResponse && !isRecording)
        }
        .padding()
        .background(ClawTheme.background)
        .onChange(of: speechRecognizer.transcript) { newValue in
            messageText = newValue
        }
        .onAppear {
            startPulseAnimation()
        }
        .onChange(of: isRecording) { recording in
            if recording {
                startRecordingAnimation()
            } else {
                rotation = 0
            }
        }
    }
    
    func startPulseAnimation() {
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
            pulseOpacity = 0.3
        }
    }
    
    func startRecordingAnimation() {
        withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
            rotation = 360
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
    let id: String
    let text: String
    let isFromUser: Bool
    let timestamp: Date
}

// MARK: - Chat View Model
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isWaitingForResponse = false
    
    let voiceManager = VoiceManager.shared
    private let api = APIClient.shared
    private var pollTimer: Timer?
    private var lastMessageId = "0"
    
    // Device ID for this phone
    private let deviceId: String = {
        if let saved = UserDefaults.standard.string(forKey: "deviceId") {
            return saved
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "deviceId")
        return newId
    }()
    
    init() {
        startPolling()
        
        // Welcome message
        let welcome = ChatMessage(
            id: "welcome",
            text: "Hey! I'm \(voiceManager.selectedVoice.displayName)! What's on your mind?",
            isFromUser: false,
            timestamp: Date()
        )
        messages.append(welcome)
    }
    
    func startPolling() {
        // Poll every 1 second for faster responses
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetchMessages()
        }
    }
    
    func fetchMessages() {
        Task {
            do {
                let newMessages = try await api.fetchMessages(userId: deviceId, since: lastMessageId)
                
                await MainActor.run {
                    for msg in newMessages {
                        // Only add messages from Ed that we haven't seen
                        if !msg.isFromUser && !messages.contains(where: { $0.id == msg.id }) {
                            let chatMessage = ChatMessage(
                                id: msg.id,
                                text: msg.text,
                                isFromUser: false,
                                timestamp: Date()
                            )
                            messages.append(chatMessage)
                            
                            // Speak the response
                            voiceManager.speak(msg.text)
                            
                            // No longer waiting
                            isWaitingForResponse = false
                        }
                        
                        // Update last seen ID
                        if msg.id > lastMessageId {
                            lastMessageId = msg.id
                        }
                    }
                }
            } catch {
                print("[Chat] Poll error: \(error)")
            }
        }
    }
    
    func sendMessage(_ text: String) {
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            text: text,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        isWaitingForResponse = true
        
        Task {
            do {
                let response = try await api.sendMessage(text, userId: deviceId)
                print("[Chat] Message sent: \(response.source)")
                
                // If AI responded directly (not linked to Ed), we'll get it in poll
                // If waiting for Ed, poll will pick it up
                
            } catch {
                print("[Chat] Send error: \(error)")
                await MainActor.run {
                    isWaitingForResponse = false
                }
            }
        }
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
