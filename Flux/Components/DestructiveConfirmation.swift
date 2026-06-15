import SwiftUI

struct DestructiveConfirmation: Equatable {
    let title: String
    let message: String
    let destructiveTitle: String
    let cancelTitle: String

    init(
        title: String,
        message: String,
        destructiveTitle: String,
        cancelTitle: String = AppLocalization.string("action.cancel", defaultValue: "Cancel")
    ) {
        self.title = title
        self.message = message
        self.destructiveTitle = destructiveTitle
        self.cancelTitle = cancelTitle
    }

    static var accountDelete: DestructiveConfirmation {
        DestructiveConfirmation(
            title: AppLocalization.string("account.delete.confirm.title", defaultValue: "Delete this account?"),
            message: AppLocalization.string(
                "account.delete.confirm.message",
                defaultValue: "Deleting an account removes all its transactions. This cannot be undone."
            ),
            destructiveTitle: AppLocalization.string(
                "account.delete.confirm.action",
                defaultValue: "Delete Account"
            )
        )
    }

    static var budgetDelete: DestructiveConfirmation {
        DestructiveConfirmation(
            title: AppLocalization.string("budget.deleteConfirmation.title", defaultValue: "Delete Budget?"),
            message: AppLocalization.string(
                "budget.deleteConfirmation.message",
                defaultValue: "This action cannot be undone."
            ),
            destructiveTitle: AppLocalization.string(
                "budget.deleteConfirmation.action",
                defaultValue: "Delete Budget"
            )
        )
    }

    static var clearAllData: DestructiveConfirmation {
        DestructiveConfirmation(
            title: AppLocalization.string("settings.clearData.title", defaultValue: "Clear all data?"),
            message: AppLocalization.string(
                "settings.clearData.message",
                defaultValue: "You cannot undo this action."
            ),
            destructiveTitle: AppLocalization.string("settings.clearData", defaultValue: "Clear All Data")
        )
    }

    static var restoreBackup: DestructiveConfirmation {
        DestructiveConfirmation(
            title: AppLocalization.string(
                "settings.backup.restore.confirm.title",
                defaultValue: "Restore Backup?"
            ),
            message: AppLocalization.string(
                "settings.backup.restore.confirm.message",
                defaultValue: "Restore replaces current financial data and restores the preferences included in this backup."
            ),
            destructiveTitle: AppLocalization.string(
                "settings.backup.restore.confirm.action",
                defaultValue: "Restore Backup"
            )
        )
    }
}

extension View {
    func destructiveConfirmation(
        _ confirmation: DestructiveConfirmation,
        isPresented: Binding<Bool>,
        destructiveAccessibilityIdentifier: String? = nil,
        onConfirm: @escaping () -> Void
    ) -> some View {
        alert(confirmation.title, isPresented: isPresented) {
            Button(confirmation.cancelTitle, role: .cancel) { }
            if let destructiveAccessibilityIdentifier {
                Button(confirmation.destructiveTitle, role: .destructive, action: onConfirm)
                    .accessibilityIdentifier(destructiveAccessibilityIdentifier)
            } else {
                Button(confirmation.destructiveTitle, role: .destructive, action: onConfirm)
            }
        } message: {
            Text(confirmation.message)
        }
    }
}
