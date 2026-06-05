import SwiftUI

// MARK: - Glass Card

enum GlassCardStyle {
    case hero
    case section
    case row
}

/// A reusable glass card container component with iOS 26+ Liquid Glass support
struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    let isInteractive: Bool
    let style: GlassCardStyle
    
    init(
        cornerRadius: CGFloat = 16,
        padding: CGFloat = 16,
        isInteractive: Bool = false,
        style: GlassCardStyle = .section,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isInteractive = isInteractive
        self.style = style
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .glassBackground(
                cornerRadius: cornerRadius,
                isInteractive: isInteractive,
                style: style
            )
            .glassSurfaceHierarchy(style: style, cornerRadius: cornerRadius)
    }
}

private struct GlassSurfaceHierarchyModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let style: GlassCardStyle
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
    }

    private var borderColor: Color {
        switch style {
        case .hero:
            Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10)
        case .section:
            Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.075)
        case .row:
            Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.055)
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .hero:
            1.2
        case .section:
            0.8
        case .row:
            0.6
        }
    }

    private var shadowColor: Color {
        switch style {
        case .hero:
            Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14)
        case .section:
            Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08)
        case .row:
            Color.black.opacity(colorScheme == .dark ? 0.10 : 0.035)
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .hero:
            24
        case .section:
            10
        case .row:
            3
        }
    }

    private var shadowYOffset: CGFloat {
        switch style {
        case .hero:
            14
        case .section:
            5
        case .row:
            1
        }
    }
}

extension View {
    func glassSurfaceHierarchy(
        style: GlassCardStyle,
        cornerRadius: CGFloat
    ) -> some View {
        modifier(GlassSurfaceHierarchyModifier(style: style, cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Section Header

/// A glass-styled section header for grouped content
struct GlassSectionHeader<Trailing: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemImage: String?
    let trailing: Trailing
    
    init(
        _ title: String,
        systemImage: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing()
    }
    
    var body: some View {
        HStack(spacing: 10) {
            sectionMarker

            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryAccent)
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            trailing
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(sectionRuleColor)
                .frame(height: 0.5)
                .padding(.leading, 22)
        }
    }

    private var sectionMarker: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(AppColors.secondaryAccent)
            .frame(width: 3, height: 18)
    }

    private var sectionRuleColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
    }
}

extension GlassSectionHeader where Trailing == EmptyView {
    init(_ title: String, systemImage: String? = nil) {
        self.init(title, systemImage: systemImage) {
            EmptyView()
        }
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
            .glassBackground(cornerRadius: 12, isInteractive: true, style: .row)
            .glassSurfaceHierarchy(style: .row, cornerRadius: 12)
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
            GlassCard(style: .hero) {
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
            
            GlassCard(cornerRadius: 12, padding: 12, style: .row) {
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
