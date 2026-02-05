import SwiftUI

struct SupportMessage: Identifiable, Codable {
    let id: String
    let text: String
    let from: String  // "user" or "support"
    let timestamp: Date
}

class SupportViewModel: ObservableObject {
    @Published var messages: [SupportMessage] = []
    @Published var isLoading = false
    
    private let deviceId: String
    private let apiBase = "http://142.132.160.28:8080"
    
    init() {
        self.deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString
        loadMessages()
    }
    
    func loadMessages() {
        // Load from UserDefaults for now
        if let data = UserDefaults.standard.data(forKey: "supportMessages"),
           let decoded = try? JSONDecoder().decode([SupportMessage].self, from: data) {
            messages = decoded
        }
    }
    
    func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(encoded, forKey: "supportMessages")
        }
    }
    
    func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        
        let message = SupportMessage(
            id: UUID().uuidString,
            text: text,
            from: "user",
            timestamp: Date()
        )
        messages.append(message)
        saveMessages()
        
        isLoading = true
        
        // Send to API
        guard let url = URL(string: "\(apiBase)/api/support/message") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "deviceId": deviceId,
            "message": text,
            "appVersion": "4.2.0",
            "platform": "iOS"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let responseText = json["response"] as? String {
                    let supportResponse = SupportMessage(
                        id: UUID().uuidString,
                        text: responseText,
                        from: "support",
                        timestamp: Date()
                    )
                    self?.messages.append(supportResponse)
                    self?.saveMessages()
                }
            }
        }.resume()
    }
}

struct SupportView: View {
    @StateObject private var viewModel = SupportViewModel()
    @State private var messageText = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message
                            if viewModel.messages.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.blue)
                                    
                                    Text("Need Help?")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("Send us a message and we'll get back to you as soon as possible.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .padding(.top, 50)
                            }
                            
                            ForEach(viewModel.messages) { message in
                                HStack {
                                    if message.from == "user" {
                                        Spacer()
                                    }
                                    
                                    VStack(alignment: message.from == "user" ? .trailing : .leading, spacing: 4) {
                                        Text(message.text)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(message.from == "user" ? Color.blue : Color.gray.opacity(0.3))
                                            .foregroundColor(message.from == "user" ? .white : .primary)
                                            .cornerRadius(18)
                                        
                                        Text(message.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .id(message.id)
                                    
                                    if message.from == "support" {
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input bar
                HStack(spacing: 12) {
                    TextField("Type your message...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(viewModel.isLoading)
                    
                    Button(action: {
                        viewModel.sendMessage(messageText)
                        messageText = ""
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(messageText.isEmpty ? Color.gray : Color.blue)
                                .clipShape(Circle())
                        }
                    }
                    .disabled(messageText.isEmpty || viewModel.isLoading)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SupportView()
}
