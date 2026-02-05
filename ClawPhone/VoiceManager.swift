import Foundation
import AVFoundation

// MARK: - Character Voices (Fish Audio)
enum CharacterVoice: String, CaseIterable, Identifiable {
    // SpongeBob (2 free)
    case spongebob = "spongebob"
    case patrick = "patrick"
    case mrkrabs = "mrkrabs"
    case squidward = "squidward"
    
    // South Park
    case cartman = "cartman"
    case kyle = "kyle"
    
    // Rick & Morty (1 free)
    case rick = "rick"
    case morty = "morty"
    
    // AI Assistants
    case jarvis = "jarvis"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .spongebob: return "SpongeBob"
        case .patrick: return "Patrick"
        case .mrkrabs: return "Mr. Krabs"
        case .squidward: return "Squidward"
        case .cartman: return "Cartman"
        case .kyle: return "Kyle"
        case .rick: return "Rick Sanchez"
        case .morty: return "Morty"
        case .jarvis: return "JARVIS"
        }
    }
    
    var emoji: String {
        switch self {
        case .spongebob: return "🧽"
        case .patrick: return "⭐"
        case .mrkrabs: return "🦀"
        case .squidward: return "🦑"
        case .cartman: return "🍩"
        case .kyle: return "🧢"
        case .rick: return "🧪"
        case .morty: return "😰"
        case .jarvis: return "🎯"
        }
    }
    
    var category: String {
        switch self {
        case .spongebob, .patrick, .mrkrabs, .squidward: return "SpongeBob"
        case .cartman, .kyle: return "South Park"
        case .rick, .morty: return "Rick & Morty"
        case .jarvis: return "AI Assistants"
        }
    }
    
    var isFree: Bool {
        switch self {
        case .spongebob, .patrick, .rick:  // 3 free voices
            return true
        default:
            return false
        }
    }
    
    var fishAudioId: String {
        switch self {
        case .spongebob: return "c4b9d66aa7a24f5781684e6ae4b2fcfd"
        case .patrick: return "d1520b60870b4e9aa01eab5bfefb1c45"
        case .mrkrabs: return "394d3112f0da41049c42177f3ca31c5a"
        case .squidward: return "08d0db87333c4362881d395fdd18de59"
        case .cartman: return "b4f55643a15944e499defe42964d2ebf"
        case .kyle: return "f19377d1769a419c87053f75ec98453d"
        case .rick: return "d2e75a3e3fd6419893057c02a375a113"
        case .morty: return "3d445d095ba04681bcba7177faedf55a"
        case .jarvis: return "612b878b113047d9a770c069c8b4fdfe"
        }
    }
    
    // Group voices by category for display
    static var grouped: [(category: String, voices: [CharacterVoice])] {
        let categories = ["SpongeBob", "South Park", "Rick & Morty", "AI Assistants"]
        return categories.compactMap { cat in
            let voices = allCases.filter { $0.category == cat }
            return voices.isEmpty ? nil : (cat, voices)
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
