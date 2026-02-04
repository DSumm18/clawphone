import StoreKit
import SwiftUI

// MARK: - Product IDs
enum ProductID {
    static let voiceSubscription = "com.dsumm.clawphone.voices.monthly"
}

// MARK: - Store Manager
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var isLoading = false
    
    enum SubscriptionStatus {
        case notSubscribed
        case subscribed
        case expired
        case unknown
    }
    
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        do {
            let productIds = [ProductID.voiceSubscription]
            products = try await Product.products(for: productIds)
            print("[Store] Loaded \(products.count) products")
        } catch {
            print("[Store] Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerifiedInstance(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            print("[Store] Purchase successful!")
            return true
            
        case .pending:
            print("[Store] Purchase pending")
            return false
            
        case .userCancelled:
            print("[Store] User cancelled")
            return false
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("[Store] Purchases restored")
        } catch {
            print("[Store] Restore failed: \(error)")
        }
    }
    
    // MARK: - Check Subscription Status
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == ProductID.voiceSubscription {
                    hasActiveSubscription = true
                    break
                }
            }
        }
        
        subscriptionStatus = hasActiveSubscription ? .subscribed : .notSubscribed
        print("[Store] Subscription status: \(subscriptionStatus)")
    }
    
    var isSubscribed: Bool {
        subscriptionStatus == .subscribed
    }
    
    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await MainActor.run {
                        Task {
                            await self.updateSubscriptionStatus()
                        }
                    }
                    await transaction.finish()
                } catch {
                    print("[Store] Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func checkVerifiedInstance<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Errors
enum StoreError: Error {
    case failedVerification
    case productNotFound
}

// MARK: - Subscribe View
struct SubscribeView: View {
    @ObservedObject var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                ClawTheme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("🎭")
                            .font(.system(size: 60))
                        
                        Text("Unlock All Voices")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(ClawTheme.text)
                        
                        Text("Get premium character voices")
                            .foregroundColor(ClawTheme.textSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Voice preview
                    VStack(spacing: 16) {
                        VoicePreviewRow(emoji: "🧽", name: "SpongeBob", included: true)
                        VoicePreviewRow(emoji: "⭐", name: "Patrick", included: true)
                        VoicePreviewRow(emoji: "🦀", name: "Mr. Krabs", included: true)
                        VoicePreviewRow(emoji: "🦑", name: "Squidward", included: true)
                    }
                    .padding()
                    .background(ClawTheme.surface)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Subscribe button
                    if let product = storeManager.products.first {
                        VStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    do {
                                        let success = try await storeManager.purchase(product)
                                        if success {
                                            dismiss()
                                        }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        showingError = true
                                    }
                                }
                            }) {
                                HStack {
                                    if storeManager.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Subscribe for \(product.displayPrice)/month")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [ClawTheme.primary, ClawTheme.secondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(storeManager.isLoading)
                            
                            Button("Restore Purchases") {
                                Task {
                                    await storeManager.restorePurchases()
                                }
                            }
                            .font(.footnote)
                            .foregroundColor(ClawTheme.textSecondary)
                            
                            Text("Cancel anytime in Settings")
                                .font(.caption)
                                .foregroundColor(ClawTheme.textSecondary)
                        }
                        .padding(.horizontal)
                    } else {
                        ProgressView("Loading...")
                            .foregroundColor(ClawTheme.textSecondary)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(ClawTheme.text)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

struct VoicePreviewRow: View {
    let emoji: String
    let name: String
    let included: Bool
    
    var body: some View {
        HStack {
            Text(emoji)
                .font(.title2)
            Text(name)
                .foregroundColor(ClawTheme.text)
            Spacer()
            Image(systemName: included ? "checkmark.circle.fill" : "lock.fill")
                .foregroundColor(included ? .green : .gray)
        }
    }
}

// MARK: - Preview
#Preview {
    SubscribeView()
}
