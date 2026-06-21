# Transaction CSV Export Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a one-tap Settings action that exports every non-template transaction as a safe, Excel-compatible CSV containing original and display-currency amounts.

**Architecture:** A pure `CSVEncoder` handles BOM, CRLF, escaping, and spreadsheet-injection protection. `TransactionCSVExportService` fetches SwiftData transactions, obtains per-row conversion quotes, constructs deterministic rows, and writes a temporary file. `SettingsViewModel` owns export state while `SettingsView` presents a share sheet for the generated URL.

**Tech Stack:** Swift 5, SwiftUI, Observation, SwiftData, XCTest, UIKit share sheet.

---

### Task 1: CSV serialization contract

**Files:**
- Create: `Flux/Services/CSVEncoder.swift`
- Create: `FluxTests/CSVEncoderTests.swift`

**Step 1: Write failing serializer tests**

Cover:
- UTF-8 BOM and CRLF output.
- Header-only exports.
- Quotes, commas, carriage returns, line feeds, and Chinese text.
- Doubling embedded quotes.
- Prefixing text beginning with `=`, `+`, `-`, or `@` with a single quote.
- Leaving raw numeric fields such as `-12.5` unchanged.

Use a typed field API so formula protection applies only to text:

```swift
enum CSVField: Equatable {
    case raw(String)
    case text(String)
}

struct CSVEncoder {
    func encode(headers: [String], rows: [[CSVField]]) throws -> Data
}
```

**Step 2: Run tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test \
  -project Flux.xcodeproj -scheme Flux \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:FluxTests/CSVEncoderTests
```

Expected: compile failure because `CSVEncoder` and `CSVField` do not exist.

**Step 3: Implement the serializer**

Validate that every row has the same field count as the header. Emit `EF BB BF`, comma-separated values, and `\r\n` after every record. Protect spreadsheet text before RFC 4180 quoting.

**Step 4: Run tests and verify GREEN**

Run the Task 1 command. Expected: all `CSVEncoderTests` pass.

**Step 5: Commit**

```bash
git add Flux/Services/CSVEncoder.swift FluxTests/CSVEncoderTests.swift
git commit -m "feat: add safe CSV serializer"
```

### Task 2: Transaction export service

**Files:**
- Create: `Flux/Services/TransactionCSVExportService.swift`
- Create: `FluxTests/TransactionCSVExportServiceTests.swift`

**Step 1: Write failing service tests**

Create an in-memory SwiftData container and a controllable `CurrencyQuoteProviding` test double. Cover:
- Excluding recurring templates while including generated occurrences.
- Sorting by transaction date descending, then creation date descending, then UUID string.
- Stable 19-column English schema from the approved design.
- Original amount/currency and historical display-currency quote/rate.
- Same-currency conversion returning the original amount with rate `1` without calling the quote provider.
- A failed quote leaving `converted_amount`, `converted_currency`, and `conversion_rate` empty without dropping the row.
- ISO 8601 dates, empty optional values, account/category display names, travel fields, and `has_receipt`.
- Header-only export when there are no transactions.
- Filename `Flux_Transactions_YYYY-MM-DD.csv` using an injected clock.

Desired protocol:

```swift
@MainActor
protocol TransactionCSVExportServicing {
    func exportTransactions(displayCurrencyCode: String) async throws -> URL
}
```

**Step 2: Run tests and verify RED**

Run the Task 1 command with `-only-testing:FluxTests/TransactionCSVExportServiceTests`.
Expected: compile failure because the service does not exist.

**Step 3: Implement the service**

Fetch `Transaction` with `!isRecurringTemplate`. Map each transaction to the approved schema, use `.historical` conversion, isolate quote failures per row, encode with `CSVEncoder`, remove any previous file at the target URL, and atomically write the new data.

**Step 4: Run tests and verify GREEN**

Run the Task 2 test command. Expected: all service tests pass.

**Step 5: Commit**

```bash
git add Flux/Services/TransactionCSVExportService.swift FluxTests/TransactionCSVExportServiceTests.swift
git commit -m "feat: export transactions as CSV"
```

### Task 3: Settings state, UI, share flow, and localization

**Files:**
- Modify: `Flux/ViewModels/SettingsViewModel.swift`
- Modify: `Flux/Views/SettingsView.swift`
- Modify: `Flux/Resources/Localizable.xcstrings`
- Create: `FluxTests/SettingsViewModelCSVExportTests.swift`
- Modify: `FluxTests/SettingsViewLayoutTests.swift`
- Modify: `FluxTests/LocalizationTests.swift`

**Step 1: Write failing state and source-contract tests**

Cover:
- View-model success returns/publishes a URL, clears errors, and exits loading state.
- View-model failure publishes a localized error and exits loading state.
- Duplicate taps while an export is running do not start another export.
- Settings Data Management contains an `Export Transactions CSV` action, progress state, accessibility identifiers, and item-based share presentation.
- English, Simplified Chinese, and Traditional Chinese strings exist for action, footer, and failure fallback.

Inject `TransactionCSVExportServicing` through `SettingsViewModel.init`, defaulting to `TransactionCSVExportService(context:)`.

**Step 2: Run tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test \
  -project Flux.xcodeproj -scheme Flux \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:FluxTests/SettingsViewModelCSVExportTests \
  -only-testing:FluxTests/SettingsViewLayoutTests \
  -only-testing:FluxTests/LocalizationTests
```

Expected: failures because state, UI, and localization keys are absent.

**Step 3: Implement view-model state**

Add `isExportingTransactionsCSV`, `transactionCSVExportErrorMessage`, and an async export method guarded against concurrent requests. Resolve the target currency from the current setting before calling the service.

**Step 4: Implement Settings UI and sharing**

Add a normal button above Clear All Data. Disable it and show a `ProgressView` while exporting. On success, present `.sheet(item:)` with a small `UIViewControllerRepresentable` wrapping `UIActivityViewController`; keep the activity controller outside business logic.

**Step 5: Add localization**

Add `settings.csvExport.action`, `settings.csvExport.footer`, and `settings.csvExport.error` in English, Simplified Chinese, and Traditional Chinese.

**Step 6: Run tests and verify GREEN**

Run the Task 3 command. Expected: all selected tests pass.

**Step 7: Commit**

```bash
git add Flux/ViewModels/SettingsViewModel.swift Flux/Views/SettingsView.swift \
  Flux/Resources/Localizable.xcstrings FluxTests/SettingsViewModelCSVExportTests.swift \
  FluxTests/SettingsViewLayoutTests.swift FluxTests/LocalizationTests.swift
git commit -m "feat: add transaction CSV export to settings"
```

### Task 4: Final verification and review

**Files:**
- Review all files changed since `630989a`.

**Step 1: Run focused CSV tests**

Run all new and modified test classes. Expected: zero failures.

**Step 2: Build the app**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild build \
  -project Flux.xcodeproj -scheme Flux \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0'
```

Expected: `BUILD SUCCEEDED`.

**Step 3: Run the full unit suite**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test \
  -project Flux.xcodeproj -scheme Flux \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:FluxTests
```

Expected: CSV-related tests pass. Record the known unrelated stale-version failure in `ActionButtonShortcutTests.testControlWidgetExtensionVersionMatchesContainingApp` unless it is fixed separately.

**Step 4: Review requirements and diff**

Check `git diff 630989a...HEAD`, CSV safety, conversion failure isolation, actor isolation, localization, accessibility, and temporary-file lifecycle. Fix findings through failing tests first.
