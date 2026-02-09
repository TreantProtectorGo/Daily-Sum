import SwiftUI

struct FloatingActionButton: View {
    let systemImage: String
    let action: () -> Void
    
    init(systemImage: String = "plus", action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(width: 56, height: 56)
        }
        .fabStyle()
    }
}

struct ExpandableFAB: View {
    @State private var isExpanded = false
    @Namespace private var fabNamespace
    
    let items: [FABItem]
    
    struct FABItem: Identifiable {
        let id = UUID()
        let label: String
        let systemImage: String
        let action: () -> Void
    }
    
    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    if isExpanded {
                        ForEach(items) { item in
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    isExpanded = false
                                }
                                item.action()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(item.label)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Image(systemName: item.systemImage)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .frame(width: 44, height: 44)
                                }
                                .padding(.leading, 16)
                                .foregroundStyle(.primary)
                            }
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .glassEffectID(item.id.uuidString, in: fabNamespace)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }
                    }
                    
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "xmark" : "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(width: 56, height: 56)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("main-fab", in: fabNamespace)
                }
            }
        } else {
            VStack(spacing: 12) {
                if isExpanded {
                    ForEach(items) { item in
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                isExpanded = false
                            }
                            item.action()
                        } label: {
                            HStack(spacing: 12) {
                                Text(item.label)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Image(systemName: item.systemImage)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .frame(width: 44, height: 44)
                            }
                            .padding(.leading, 16)
                            .foregroundStyle(.primary)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                }
                
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial, in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

struct FABModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

extension View {
    func fabStyle() -> some View {
        modifier(FABModifier())
    }
    
    func withFAB<FAB: View>(
        alignment: Alignment = .bottomTrailing,
        @ViewBuilder fab: () -> FAB
    ) -> some View {
        overlay(alignment: alignment) {
            fab()
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
    }
}

#Preview("Single FAB") {
    ZStack {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        Color.clear
            .withFAB {
                FloatingActionButton { }
            }
    }
}

#Preview("Expandable FAB") {
    ZStack {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        Color.clear
            .withFAB {
                ExpandableFAB(items: [
                    .init(label: "Transaction", systemImage: "plus.circle") { },
                    .init(label: "Account", systemImage: "building.columns") { }
                ])
            }
    }
}
