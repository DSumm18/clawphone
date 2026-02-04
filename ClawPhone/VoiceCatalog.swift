import Foundation

// MARK: - Voice Category
enum VoiceCategory: String, CaseIterable, Identifiable {
    case spongebob = "SpongeBob"
    case southpark = "South Park"
    case rickmorty = "Rick & Morty"
    case aiAssistants = "AI Assistants"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var emoji: String {
        switch self {
        case .spongebob: return "🧽"
        case .southpark: return "🏔️"
        case .rickmorty: return "🧪"
        case .aiAssistants: return "🤖"
        }
    }
    
    var description: String {
        switch self {
        case .spongebob: return "Bikini Bottom favorites"
        case .southpark: return "Adult animated comedy"
        case .rickmorty: return "Interdimensional adventures"
        case .aiAssistants: return "Sci-fi AI companions"
        }
    }
    
    var voices: [VoiceOption] {
        switch self {
        case .spongebob:
            return [
                VoiceOption(id: "spongebob", name: "SpongeBob", emoji: "🧽", fishAudioId: "c4b9d66aa7a24f5781684e6ae4b2fcfd", category: self, isFree: true),
                VoiceOption(id: "patrick", name: "Patrick", emoji: "⭐", fishAudioId: "d1520b60870b4e9aa01eab5bfefb1c45", category: self),
                VoiceOption(id: "mrkrabs", name: "Mr. Krabs", emoji: "🦀", fishAudioId: "394d3112f0da41049c42177f3ca31c5a", category: self),
                VoiceOption(id: "squidward", name: "Squidward", emoji: "🦑", fishAudioId: "08d0db87333c4362881d395fdd18de59", category: self),
            ]
        case .southpark:
            return [
                VoiceOption(id: "cartman", name: "Cartman", emoji: "🍩", fishAudioId: "b4f55643a15944e499defe42964d2ebf", category: self),
                VoiceOption(id: "kyle", name: "Kyle", emoji: "🧢", fishAudioId: "f19377d1769a419c87053f75ec98453d", category: self),
            ]
        case .rickmorty:
            return [
                VoiceOption(id: "rick", name: "Rick Sanchez", emoji: "🧪", fishAudioId: "d2e75a3e3fd6419893057c02a375a113", category: self),
                VoiceOption(id: "morty", name: "Morty", emoji: "😰", fishAudioId: "3d445d095ba04681bcba7177faedf55a", category: self),
            ]
        case .aiAssistants:
            return [
                VoiceOption(id: "jarvis", name: "JARVIS", emoji: "🎯", fishAudioId: "612b878b113047d9a770c069c8b4fdfe", category: self),
            ]
        }
    }
}

// MARK: - Voice Option
struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let fishAudioId: String
    let category: VoiceCategory
    var isFree: Bool = false
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: VoiceOption, rhs: VoiceOption) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Voice Catalog
class VoiceCatalog {
    static let shared = VoiceCatalog()
    
    var allCategories: [VoiceCategory] {
        VoiceCategory.allCases
    }
    
    var allVoices: [VoiceOption] {
        VoiceCategory.allCases.flatMap { $0.voices }
    }
    
    var freeVoices: [VoiceOption] {
        allVoices.filter { $0.isFree }
    }
    
    var premiumVoices: [VoiceOption] {
        allVoices.filter { !$0.isFree }
    }
    
    func voice(for id: String) -> VoiceOption? {
        allVoices.first { $0.id == id }
    }
    
    func fishAudioId(for voiceId: String) -> String? {
        voice(for: voiceId)?.fishAudioId
    }
    
    var totalVoiceCount: Int {
        allVoices.count
    }
    
    var categoryCount: Int {
        allCategories.count
    }
}
