import SwiftUI

enum ContentLoadPhase: Equatable {
    case initialLoading
    case content
    case refreshing
    case initialFailure(String)
    case staleContent(String)

    static func resolve(
        isLoading: Bool,
        errorMessage: String?,
        hasLoadedSuccessfully: Bool
    ) -> ContentLoadPhase {
        if isLoading {
            return hasLoadedSuccessfully ? .refreshing : .initialLoading
        }
        if let errorMessage {
            return hasLoadedSuccessfully
                ? .staleContent(errorMessage)
                : .initialFailure(errorMessage)
        }
        return hasLoadedSuccessfully ? .content : .initialLoading
    }
}

struct ReportsLayoutPolicy {
    static func summaryColumnCount(dynamicTypeSize: DynamicTypeSize) -> Int {
        usesLargeTextLayout(dynamicTypeSize) ? 1 : 2
    }

    static func usesMenuPeriodPicker(dynamicTypeSize: DynamicTypeSize) -> Bool {
        usesLargeTextLayout(dynamicTypeSize)
    }

    private static func usesLargeTextLayout(_ dynamicTypeSize: DynamicTypeSize) -> Bool {
        switch dynamicTypeSize {
        case .xxLarge, .xxxLarge,
             .accessibility1, .accessibility2, .accessibility3,
             .accessibility4, .accessibility5:
            true
        default:
            false
        }
    }
}

struct ContentLoadStateView<Content: View>: View {
    let isLoading: Bool
    let errorMessage: String?
    let hasLoadedSuccessfully: Bool
    let retry: () -> Void
    @ViewBuilder let content: () -> Content

    private var phase: ContentLoadPhase {
        .resolve(
            isLoading: isLoading,
            errorMessage: errorMessage,
            hasLoadedSuccessfully: hasLoadedSuccessfully
        )
    }

    var body: some View {
        switch phase {
        case .initialLoading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(
                    AppLocalization.string("status.loading", defaultValue: "Loading")
                )
        case .initialFailure(let message):
            ContentUnavailableView {
                Label(
                    AppLocalization.string("status.loadFailed", defaultValue: "Unable to Load"),
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(message)
            } actions: {
                retryButton
            }
        case .content:
            content()
        case .refreshing:
            content()
                .overlay(alignment: .top) {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                        .accessibilityLabel(
                            AppLocalization.string("status.refreshing", defaultValue: "Refreshing")
                        )
                }
        case .staleContent(let message):
            VStack(spacing: 0) {
                errorBanner(message: message)
                content()
            }
        }
    }

    private var retryButton: some View {
        Button(
            AppLocalization.string("action.retry", defaultValue: "Retry"),
            action: retry
        )
        .buttonStyle(.fluxGlass)
    }

    private func errorBanner(message: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                errorMessageLabel(message)
                retryButton
            }
            VStack(alignment: .leading, spacing: 10) {
                errorMessageLabel(message)
                retryButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.orange.opacity(0.1))
    }

    private func errorMessageLabel(_ message: String) -> some View {
        Label {
            Text(message)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}
