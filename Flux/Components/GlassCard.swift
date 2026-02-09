import SwiftUI

// MARK: - Glass Card

/// A reusable glass card container component with iOS 26+ Liquid Glass support
struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    let isInteractive: Bool
    
    init(
        cornerRadius: CGFloat = 16,
        padding: CGFloat = 16,
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isInteractive = isInteractive
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .glassBackground(cornerRadius: cornerRadius, isInteractive: isInteractive)
    }
}

// MARK: - Glass Section Header

/// A glass-styled section header for grouped content
struct GlassSectionHeader: View {
    let title: String
    let systemImage: String?
    
    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
}

// MARK: - Glass List Row

/// A glass-styled list row container
struct GlassListRow<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground(cornerRadius: 12, isInteractive: true)
    }
}

// MARK: - Glass Button

/// A glass-styled action button
struct GlassActionButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    
    init(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(.fluxGlass)
    }
}

// MARK: - Glass Prominent Button

/// A prominent glass-styled action button for primary actions
struct GlassProminentButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    
    init(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(.fluxGlassProminent)
    }
}

// MARK: - Glass Divider

/// A subtle glass-styled divider
struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.glassBorder)
            .frame(height: 0.5)
    }
}

// MARK: - Previews

#Preview("Glass Card") {
    ZStack {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("$12,345.67")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GlassCard(cornerRadius: 12, padding: 12) {
                HStack {
                    Image(systemName: "cart.fill")
                        .foregroundStyle(.orange)
                    Text("Shopping")
                    Spacer()
                    Text("-$45.00")
                        .foregroundStyle(.red)
                }
            }
            
            HStack(spacing: 12) {
                GlassActionButton("Cancel", systemImage: "xmark") { }
                GlassProminentButton("Save", systemImage: "checkmark") { }
            }
        }
        .padding()
    }
}

#Preview("Glass Section") {
    ZStack {
        Color.blue.opacity(0.3).ignoresSafeArea()
        
        VStack(spacing: 8) {
            GlassSectionHeader("Recent Transactions", systemImage: "clock")
            
            GlassListRow {
                HStack {
                    Text("Coffee")
                    Spacer()
                    Text("-$4.50")
                }
            }
            
            GlassListRow {
                HStack {
                    Text("Salary")
                    Spacer()
                    Text("+$3,000")
                }
            }
        }
        .padding()
    }
}
