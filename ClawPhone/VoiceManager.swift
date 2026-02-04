import Foundation
import AVFoundation

// MARK: - Character Voices (Fish Audio)
enum CharacterVoice: String, CaseIterable, Identifiable {
    case spongebob = "spongebob"
    case patrick = "patrick"
    case mrkrabs = "mrkrabs"
    case squidward = "squidward"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .spongebob: return "SpongeBob"
        case .patrick: return "Patrick"
        case .mrkrabs: return "Mr. Krabs"
        case .squidward: return "Squidward"
        }
    }
    
    var emoji: String {
        switch self {
        case .spongebob: return "🧽"
        case .patrick: return "⭐"
        case .mrkrabs: return "🦀"
        case .squidward: return "🦑"
        }
    }
}

// MARK: - Voice Manager
class VoiceManager: NSObject, ObservableObject {
    static let shared = VoiceManager()
    
    @Published var isSpeaking = false
    @Published var selectedVoice: CharacterVoice = .spongebob
    @Published var useFishAudio = true  // Always use Fish Audio (toggle removed)
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private let api = APIClient.shared
    
    override init() {
        super.init()
        synthesizer.delegate = self
        loadSettings()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[Voice] Audio session setup failed: \(error)")
        }
    }
    
    func loadSettings() {
        if let saved = UserDefaults.standard.string(forKey: "selectedVoice"),
           let voice = CharacterVoice(rawValue: saved) {
            selectedVoice = voice
        }
        useFishAudio = UserDefaults.standard.bool(forKey: "useFishAudio")
        // Default to Fish Audio on first launch
        if UserDefaults.standard.object(forKey: "useFishAudio") == nil {
            useFishAudio = true
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(selectedVoice.rawValue, forKey: "selectedVoice")
        UserDefaults.standard.set(useFishAudio, forKey: "useFishAudio")
    }
    
    func speak(_ text: String) {
        // Clean text (remove emojis for TTS)
        let cleanText = text
            .replacingOccurrences(of: "🦞", with: "")
            .replacingOccurrences(of: "🧽", with: "")
            .replacingOccurrences(of: "⭐", with: "")
            .replacingOccurrences(of: "🦀", with: "")
            .replacingOccurrences(of: "🦑", with: "")
            .replacingOccurrences(of: "🔥", with: "")
            .replacingOccurrences(of: "✨", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        guard !cleanText.isEmpty else { return }
        
        if useFishAudio {
            speakWithFishAudio(cleanText)
        } else {
            speakWithApple(cleanText)
        }
    }
    
    // MARK: - Fish Audio TTS (SpongeBob etc)
    private func speakWithFishAudio(_ text: String) {
        isSpeaking = true
        
        Task {
            do {
                print("[Voice] Fetching Fish Audio for: \(selectedVoice.rawValue)")
                
                if let audioData = try await api.fetchTTSAudio(text: text, voice: selectedVoice.rawValue) {
                    await MainActor.run {
                        playAudioData(audioData)
                    }
                } else {
                    // No audio URL returned - fall back to Apple TTS
                    print("[Voice] Fish Audio unavailable, using Apple TTS")
                    await MainActor.run {
                        self.speakWithApple(text)
                    }
                }
            } catch {
                print("[Voice] Fish Audio error: \(error)")
                await MainActor.run {
                    self.speakWithApple(text)
                }
            }
        }
    }
    
    private func playAudioData(_ data: Data) {
        do {
            // Ensure audio session is active
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Stop any current playback
            audioPlayer?.stop()
            synthesizer.stopSpeaking(at: .immediate)
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            print("[Voice] Playing Fish Audio (\(data.count) bytes)")
        } catch {
            print("[Voice] Audio playback error: \(error)")
            isSpeaking = false
        }
    }
    
    // MARK: - Apple TTS (Fallback)
    private func speakWithApple(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Find best British English voice
        let preferredVoices = [
            "com.apple.voice.compact.en-GB.Daniel",
            "com.apple.ttsbundle.Daniel-compact",
            "Daniel"
        ]
        
        var selectedAppleVoice: AVSpeechSynthesisVoice?
        for voiceId in preferredVoices {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
                selectedAppleVoice = voice
                break
            }
        }
        
        // Fallback to any British voice
        if selectedAppleVoice == nil {
            selectedAppleVoice = AVSpeechSynthesisVoice(language: "en-GB")
        }
        
        utterance.voice = selectedAppleVoice
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        isSpeaking = false
    }
}

// MARK: - Delegates
extension VoiceManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

extension VoiceManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
