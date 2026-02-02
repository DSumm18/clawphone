import Foundation
import AVFoundation

// MARK: - Voice Manager
class VoiceManager: NSObject, ObservableObject {
    static let shared = VoiceManager()
    
    @Published var isSpeaking = false
    @Published var voiceType: VoiceType = .free
    @Published var voiceCredits: Int = 100
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    
    enum VoiceType: String, CaseIterable {
        case free = "free"
        case premium = "premium"
        
        var displayName: String {
            switch self {
            case .free: return "Ed (Free)"
            case .premium: return "Ed Premium ✨"
            }
        }
        
        var description: String {
            switch self {
            case .free: return "Apple's built-in voice"
            case .premium: return "Natural AI voice (uses credits)"
            }
        }
    }
    
    override init() {
        super.init()
        synthesizer.delegate = self
        loadSettings()
    }
    
    func loadSettings() {
        if let saved = UserDefaults.standard.string(forKey: "voiceType"),
           let type = VoiceType(rawValue: saved) {
            voiceType = type
        }
        voiceCredits = UserDefaults.standard.integer(forKey: "voiceCredits")
        if voiceCredits == 0 { voiceCredits = 100 } // Default credits
    }
    
    func saveSettings() {
        UserDefaults.standard.set(voiceType.rawValue, forKey: "voiceType")
        UserDefaults.standard.set(voiceCredits, forKey: "voiceCredits")
    }
    
    func speak(_ text: String) {
        // Clean text (remove emojis for TTS)
        let cleanText = text
            .replacingOccurrences(of: "🦞", with: "")
            .replacingOccurrences(of: "🔥", with: "")
            .replacingOccurrences(of: "✨", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        guard !cleanText.isEmpty else { return }
        
        switch voiceType {
        case .free:
            speakWithApple(cleanText)
        case .premium:
            if voiceCredits > 0 {
                speakWithPremium(cleanText)
            } else {
                // Fall back to free if no credits
                speakWithApple(cleanText)
            }
        }
    }
    
    // MARK: - Free Voice (Apple TTS)
    private func speakWithApple(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Find best British English voice
        let preferredVoices = [
            "com.apple.voice.compact.en-GB.Daniel",
            "com.apple.ttsbundle.Daniel-compact",
            "Daniel"
        ]
        
        var selectedVoice: AVSpeechSynthesisVoice?
        for voiceId in preferredVoices {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
                selectedVoice = voice
                break
            }
        }
        
        // Fallback to any British voice
        if selectedVoice == nil {
            selectedVoice = AVSpeechSynthesisVoice(language: "en-GB")
        }
        
        utterance.voice = selectedVoice
        utterance.rate = 0.52  // Slightly slower for clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    // MARK: - Premium Voice (OpenAI TTS)
    private func speakWithPremium(_ text: String) {
        guard let apiKey = UserDefaults.standard.string(forKey: "openaiApiKey"), !apiKey.isEmpty else {
            // No API key, fall back to free
            speakWithApple(text)
            return
        }
        
        isSpeaking = true
        
        Task {
            do {
                let audioData = try await fetchOpenAITTS(text: text, apiKey: apiKey)
                await playAudio(data: audioData)
                
                // Deduct credit
                DispatchQueue.main.async {
                    self.voiceCredits -= 1
                    self.saveSettings()
                }
            } catch {
                print("Premium TTS error: \(error)")
                // Fall back to free
                DispatchQueue.main.async {
                    self.speakWithApple(text)
                }
            }
        }
    }
    
    private func fetchOpenAITTS(text: String, apiKey: String) async throws -> Data {
        let url = URL(string: "https://api.openai.com/v1/audio/speech")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": "onyx",  // Deep, warm male voice
            "response_format": "mp3"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "TTS API error"])
        }
        
        return data
    }
    
    @MainActor
    private func playAudio(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("Audio playback error: \(error)")
            isSpeaking = false
        }
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
