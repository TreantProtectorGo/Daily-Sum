# Transaction CSV Export Design

## Goal

Add a dependable, one-tap export of all actual transactions for spreadsheet analysis and record keeping. The first version deliberately excludes filters and column customisation.

## User Experience

- Add **Export Transactions CSV** under **Settings → Data Management**.
- Tapping the row exports immediately and presents the iOS share sheet.
- While generating the file, disable the action and show progress.
- If generation fails, keep the user in Settings and show a localised error.
- Use the filename `Flux_Transactions_YYYY-MM-DD.csv`.

## Export Scope

- Export every actual transaction.
- Exclude recurring transaction templates.
- Include generated recurring occurrences because they are actual transactions.
- Sort rows by transaction date descending, with creation date and ID as deterministic tie-breakers.

## Columns

Use stable English machine-readable headers so changing the app language does not change the schema:

1. `id`
2. `date`
3. `created_at`
4. `type`
5. `original_amount`
6. `original_currency`
7. `converted_amount`
8. `converted_currency`
9. `conversion_rate`
10. `account`
11. `category`
12. `notes`
13. `is_travel_transaction`
14. `travel_amount`
15. `travel_currency`
16. `travel_exchange_rate`
17. `travel_exchange_rate_effective_date`
18. `travel_exchange_rate_provider`
19. `has_receipt`

Amounts must be plain decimal values without currency symbols or grouping separators. Dates must use ISO 8601. Boolean values must use `true` and `false`. Missing optional values must produce empty fields.

## Currency Conversion

- Preserve every transaction's original amount and currency.
- Convert the amount to the user's current display currency using the same conversion policy as reports.
- Record the converted currency and effective conversion rate in separate columns.
- If conversion is unavailable, still export the row with the original fields intact and leave all conversion-derived fields empty.
- A failure to convert one row must not abort the whole export.

## CSV Encoding

- Encode as UTF-8 with a byte-order mark for reliable Excel handling of Chinese text.
- Use RFC 4180-style comma separation and CRLF line endings.
- Quote fields containing commas, quotes, carriage returns, or line feeds.
- Escape an embedded quote by doubling it.
- Protect spreadsheet users from formula injection by prefixing text fields beginning with `=`, `+`, `-`, or `@` with a single quote.

## Architecture

Create a dedicated CSV export service responsible for fetching, converting, ordering, serialising, and writing transactions to a temporary file. Keep CSV escaping and row construction independent from SwiftUI so they can be unit tested directly.

The Settings view model starts the export, exposes loading and error state, and holds the generated file URL long enough for the share sheet. Temporary files should be replaced on the next export and may be removed when the share flow finishes.

## Error Handling

- Fetch, serialization, or file-write failures stop the export and show a localised error.
- Individual currency conversion failures are non-fatal and produce empty conversion fields.
- An empty database still produces a valid CSV containing only the header row.

## Testing

- Verify scope excludes recurring templates and includes generated occurrences.
- Verify deterministic date ordering.
- Verify original and converted currency fields.
- Verify non-fatal conversion failures.
- Verify commas, quotes, line breaks, Chinese text, and formula-like text are escaped safely.
- Verify UTF-8 BOM, CRLF line endings, headers, empty export, and filename format.
- Verify Settings loading, success/share, and failure states.

## Deferred

- Date-range and transaction filters
- User-selectable columns
- Localised headers
- Importing the CSV back into Flux
- PDF export
