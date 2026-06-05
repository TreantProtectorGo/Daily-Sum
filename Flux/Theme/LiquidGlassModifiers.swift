import SwiftUI

// MARK: - Liquid Glass View Modifiers

/// Applies a glass effect with iOS 26+ availability check and fallback
struct GlassEffectModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isInteractive: Bool
    let style: GlassCardStyle
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if isInteractive {
                content
                    .glassMaterialFoundation(style: style, cornerRadius: cornerRadius)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content
                    .glassMaterialFoundation(style: style, cornerRadius: cornerRadius)
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            fallbackBackground(for: content)
                .glassMaterialFoundation(style: style, cornerRadius: cornerRadius)
        }
    }

    @ViewBuilder
    private func fallbackBackground(for content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        switch style {
        case .hero:
            content
                .background(.regularMaterial, in: shape)
        case .section:
            content
                .background(.thinMaterial, in: shape)
        case .row:
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }
}

private struct GlassMaterialFoundationModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let style: GlassCardStyle
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                foundationLayer
            }
    }

    @ViewBuilder
    private var foundationLayer: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        switch style {
        case .hero:
            shape
                .fill(heroFill)
        case .section:
            shape
                .fill(sectionFill)
        case .row:
            shape
                .fill(rowFill)
        }
    }

    private var heroFill: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.secondaryAccent.opacity(colorScheme == .dark ? 0.30 : 0.20),
                AppColors.brandCoral.opacity(colorScheme == .dark ? 0.20 : 0.12),
                Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.025)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sectionFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.primary.opacity(colorScheme == .dark ? 0.065 : 0.028),
                AppColors.secondaryAccent.opacity(colorScheme == .dark ? 0.075 : 0.020)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var rowFill: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.025 : 0.010)
    }
}

/// Applies a prominent glass effect for primary actions
struct GlassProminentModifier: ViewModifier {
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// Container that groups multiple glass elements for visual coherence
struct GlassContainerModifier: ViewModifier {
    let spacing: CGFloat
    
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a glass effect with configurable corner radius and interactivity
    /// - Parameters:
    ///   - cornerRadius: The corner radius of the glass shape (default: 16)
    ///   - isInteractive: Whether the element should respond to touch/hover (default: false)
    func glassBackground(
        cornerRadius: CGFloat = 16,
        isInteractive: Bool = false,
        style: GlassCardStyle = .row
    ) -> some View {
        modifier(
            GlassEffectModifier(
                cornerRadius: cornerRadius,
                isInteractive: isInteractive,
                style: style
            )
        )
    }

    func glassMaterialFoundation(
        style: GlassCardStyle,
        cornerRadius: CGFloat
    ) -> some View {
        modifier(GlassMaterialFoundationModifier(style: style, cornerRadius: cornerRadius))
    }
    
    /// Applies a prominent glass effect for primary actions
    /// - Parameter cornerRadius: The corner radius of the glass shape (default: 12)
    func glassProminentBackground(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassProminentModifier(cornerRadius: cornerRadius))
    }
    
    /// Wraps content in a glass container for grouped glass elements
    /// - Parameter spacing: Spacing between glass elements (default: 24)
    func glassContainer(spacing: CGFloat = 24) -> some View {
        modifier(GlassContainerModifier(spacing: spacing))
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == FluxGlassButtonStyle {
    /// A glass-styled button for secondary actions
    static var fluxGlass: FluxGlassButtonStyle { FluxGlassButtonStyle() }
}

extension ButtonStyle where Self == FluxGlassProminentButtonStyle {
    /// A prominent glass-styled button for primary actions
    static var fluxGlassProminent: FluxGlassProminentButtonStyle { FluxGlassProminentButtonStyle() }
}

// MARK: - Custom Button Styles

struct FluxGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .capsule)
                .opacity(configuration.isPressed ? 0.8 : 1.0)
        } else {
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .opacity(configuration.isPressed ? 0.8 : 1.0)
        }
    }
}

struct FluxGlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            configuration.label
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .fontWeight(.semibold)
                .glassEffect(.regular.interactive(), in: .capsule)
                .opacity(configuration.isPressed ? 0.8 : 1.0)
        } else {
            configuration.label
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .fontWeight(.semibold)
                .background(.regularMaterial, in: Capsule())
                .opacity(configuration.isPressed ? 0.8 : 1.0)
        }
    }
}

// MARK: - Preview

#Preview("Glass Modifiers") {
    ZStack {
        LinearGradient(
            colors: [.blue, .purple, .pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            Text("Glass Background")
                .padding()
                .glassBackground(cornerRadius: 12)
            
            Text("Interactive Glass")
                .padding()
                .glassBackground(cornerRadius: 12, isInteractive: true)
            
            Button("Glass Button") { }
                .buttonStyle(.fluxGlass)
            
            Button("Prominent Button") { }
                .buttonStyle(.fluxGlassProminent)
        }
        .foregroundStyle(.white)
    }
}
