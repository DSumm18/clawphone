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
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var isLoading = false
    
    enum SubscriptionStatus {
        case notSubscribed
        case subscribed
        case expired
        case unknown
    }
    
    private var updateListenerTask: Task<Void, Never>?
    
    init() {
        startListening()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Start Listening for Transactions
    private func startListening() {
        updateListenerTask = Task(priority: .background) { [weak self] in
            for await verificationResult in StoreKit.Transaction.updates {
                await self?.handle(verificationResult)
            }
        }
    }
    
    private func handle(_ verificationResult: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = verificationResult else {
            return
        }
        await updateSubscriptionStatus()
        await transaction.finish()
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
        case .success(let verificationResult):
            guard case .verified(let transaction) = verificationResult else {
                return false
            }
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
        
        for await result in StoreKit.Transaction.currentEntitlements {
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
}

// MARK: - Subscribe View
struct SubscribeView: View {
    @ObservedObject var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let catalog = VoiceCatalog.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                ClawTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("🎭")
                                .font(.system(size: 60))
                            
                            Text("Unlock \(catalog.totalVoiceCount) Voices")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(ClawTheme.text)
                            
                            Text("\(catalog.categoryCount) categories of premium characters")
                                .foregroundColor(ClawTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Voice categories
                        ForEach(catalog.allCategories) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(category.emoji)
                                    Text(category.displayName)
                                        .font(.headline)
                                        .foregroundColor(ClawTheme.text)
                                    Spacer()
                                    Text("\(category.voices.count) voices")
                                        .font(.caption)
                                        .foregroundColor(ClawTheme.textSecondary)
                                }
                                
                                ForEach(category.voices) { voice in
                                    HStack {
                                        Text(voice.emoji)
                                            .font(.title3)
                                        Text(voice.name)
                                            .foregroundColor(ClawTheme.text)
                                        Spacer()
                                        if voice.isFree {
                                            Text("FREE")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.2))
                                                .foregroundColor(.green)
                                                .cornerRadius(4)
                                        }
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                            .padding()
                            .background(ClawTheme.surface)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                    
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
                .padding(.bottom, 20)
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

// VoicePreviewRow removed - using VoiceCatalog instead

#Preview {
    SubscribeView()
}
