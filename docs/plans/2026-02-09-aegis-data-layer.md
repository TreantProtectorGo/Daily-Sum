# Aegis Data Layer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the complete data layer foundation for Aegis - a privacy-first financial management iOS app

**Architecture:** SwiftData with @Observable pattern, local-first storage, optional iCloud sync, multi-language support

**Tech Stack:** SwiftUI, SwiftData, iOS 26, Swift 6 (strict concurrency), Liquid Glass design

---

## Task Dependency Graph

```
Wave 0 (Foundation)
├── [T0.1] Create folder structure
└── [T0.2] Delete Item.swift (deprecated)

Wave 1 (Enums & Types - ALL PARALLEL)
├── [T1.1] TransactionType enum
├── [T1.2] AccountType enum
├── [T1.3] RecurrenceRule enum
├── [T1.4] BudgetPeriod enum
└── [T1.5] SupportedCurrency enum

Wave 2 (Core Models - Partial dependencies)
├── [T2.1] Currency model
├── [T2.2] Category model (needs T1.1)
├── [T2.3] Account model (needs T1.2, T2.1)
├── [T2.4] Transaction model (needs T1.1, T1.3, T2.1-T2.3)
└── [T2.5] Budget model (needs T1.4, T2.1, T2.2)

Wave 3 (Localization - ALL PARALLEL)
├── [T3.1] String Catalog setup (Localizable.xcstrings)
├── [T3.2] Category localization data
└── [T3.3] RegionalSettings (color logic)

Wave 4 (Infrastructure - ALL PARALLEL)
├── [T4.1] ModelContainer configuration
├── [T4.2] CurrencyFormatter utility
├── [T4.3] DateFormatter utility
└── [T4.4] DefaultDataSeeder

Wave 5 (CRUD Services - ALL PARALLEL)
├── [T5.1] TransactionService
├── [T5.2] CategoryService
├── [T5.3] AccountService
├── [T5.4] BudgetService
└── [T5.5] RecurringTransactionGenerator

Wave 6 (Tests - ALL PARALLEL)
├── [T6.1] Model unit tests
├── [T6.2] Service unit tests
├── [T6.3] Localization tests
└── [T6.4] Currency conversion tests

Wave 7 (Integration)
└── [T7.1] Update FluxApp.swift & ContentView.swift
```

---

## Wave 0: Foundation Setup

### T0.1 - Create Folder Structure
| Category | quick | Skills | None | Parallel | Yes |

**Action:** Create directory structure:
- `Flux/Models/`
- `Flux/Models/Enums/`
- `Flux/Models/SwiftData/`
- `Flux/Services/`
- `Flux/Utilities/`
- `Flux/Utilities/Formatters/`
- `Flux/Utilities/Localization/`
- `Flux/Resources/`

### T0.2 - Delete Item.swift
| Category | quick | Skills | None | Parallel | Yes |

**Action:** Delete `Flux/Item.swift` (deprecated template file)

---

## Wave 1: Enums & Types

### T1.1 - TransactionType Enum
| Category | quick | Skills | swiftui-expert-skill | File | `Flux/Models/Enums/TransactionType.swift` |

```swift
import Foundation

/// Represents the type of financial transaction
enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
    
    var localizedName: String {
        switch self {
        case .income:
            String(localized: "transaction.type.income", defaultValue: "Income")
        case .expense:
            String(localized: "transaction.type.expense", defaultValue: "Expense")
        }
    }
}
```

### T1.2 - AccountType Enum
| Category | quick | Skills | swiftui-expert-skill | File | `Flux/Models/Enums/AccountType.swift` |

```swift
import Foundation

/// Types of financial accounts supported by the app
enum AccountType: String, Codable, CaseIterable {
    case cash
    case bank
    case creditCard
    case investment
    
    var localizedName: String {
        switch self {
        case .cash:
            String(localized: "account.type.cash", defaultValue: "Cash")
        case .bank:
            String(localized: "account.type.bank", defaultValue: "Bank Account")
        case .creditCard:
            String(localized: "account.type.creditCard", defaultValue: "Credit Card")
        case .investment:
            String(localized: "account.type.investment", defaultValue: "Investment")
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .creditCard: "creditcard"
        case .investment: "chart.line.uptrend.xyaxis"
        }
    }
}
```

### T1.3 - RecurrenceRule Enum
| Category | quick | Skills | swiftui-expert-skill | File | `Flux/Models/Enums/RecurrenceRule.swift` |

```swift
import Foundation

/// Defines how a recurring transaction repeats
enum RecurrenceRule: Codable, Equatable {
    case daily
    case weekly
    case monthly
    case yearly
    case custom(interval: Int, unit: RecurrenceUnit)
    
    enum RecurrenceUnit: String, Codable {
        case days
        case weeks
        case months
    }
    
    var localizedDescription: String {
        switch self {
        case .daily:
            String(localized: "recurrence.daily", defaultValue: "Daily")
        case .weekly:
            String(localized: "recurrence.weekly", defaultValue: "Weekly")
        case .monthly:
            String(localized: "recurrence.monthly", defaultValue: "Monthly")
        case .yearly:
            String(localized: "recurrence.yearly", defaultValue: "Yearly")
        case .custom(let interval, let unit):
            String(localized: "recurrence.custom.\(unit.rawValue)",
                   defaultValue: "Every \(interval) \(unit.rawValue)")
        }
    }
    
    /// Returns the next occurrence date from a given date
    func nextDate(from date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .daily:
            calendar.date(byAdding: .day, value: 1, to: date)!
        case .weekly:
            calendar.date(byAdding: .weekOfYear, value: 1, to: date)!
        case .monthly:
            calendar.date(byAdding: .month, value: 1, to: date)!
        case .yearly:
            calendar.date(byAdding: .year, value: 1, to: date)!
        case .custom(let interval, let unit):
            let component: Calendar.Component = switch unit {
            case .days: .day
            case .weeks: .weekOfYear
            case .months: .month
            }
            return calendar.date(byAdding: component, value: interval, to: date)!
        }
    }
}
```

### T1.4 - BudgetPeriod Enum
| Category | quick | Skills | swiftui-expert-skill | File | `Flux/Models/Enums/BudgetPeriod.swift` |

```swift
import Foundation

/// The time period a budget covers
enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly
    case monthly
    
    var localizedName: String {
        switch self {
        case .weekly:
            String(localized: "budget.period.weekly", defaultValue: "Weekly")
        case .monthly:
            String(localized: "budget.period.monthly", defaultValue: "Monthly")
        }
    }
    
    /// Returns the date range for this period containing the given date
    func dateRange(containing date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        switch self {
        case .weekly:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            return (start, end)
        case .monthly:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        }
    }
}
```

### T1.5 - SupportedCurrency Enum
| Category | quick | Skills | swiftui-expert-skill | File | `Flux/Models/Enums/SupportedCurrency.swift` |

```swift
import Foundation

/// ISO 4217 currency codes supported by the app
enum SupportedCurrency: String, Codable, CaseIterable, Identifiable {
    case USD
    case TWD
    case CNY
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .USD: "$"
        case .TWD: "NT$"
        case .CNY: "¥"
        }
    }
    
    var localizedName: String {
        switch self {
        case .USD:
            String(localized: "currency.USD", defaultValue: "US Dollar")
        case .TWD:
            String(localized: "currency.TWD", defaultValue: "New Taiwan Dollar")
        case .CNY:
            String(localized: "currency.CNY", defaultValue: "Chinese Yuan")
        }
    }
    
    /// Number of decimal places for this currency (standard)
    var decimalPlaces: Int {
        switch self {
        case .USD: 2
        case .TWD: 0  // TWD typically doesn't use decimals
        case .CNY: 2
        }
    }
    
    /// Returns the default currency based on device locale
    static var defaultFromLocale: SupportedCurrency {
        let regionCode = Locale.current.region?.identifier ?? "US"
        switch regionCode {
        case "TW": return .TWD
        case "CN", "HK", "MO": return .CNY
        default: return .USD
        }
    }
}
```

---

## Wave 2: SwiftData Models

(See full plan file for complete model implementations)

---

## Test Commands

```bash
# Build the project
xcodebuild -project Flux.xcodeproj -scheme Flux -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run unit tests
xcodebuild -project Flux.xcodeproj -scheme Flux -destination 'platform=iOS Simulator,name=iPhone 16' test
```

---

## File Structure After Implementation

```
Flux/
├── FluxApp.swift (updated)
├── ContentView.swift (updated)
├── Models/
│   ├── Enums/
│   │   ├── TransactionType.swift
│   │   ├── AccountType.swift
│   │   ├── RecurrenceRule.swift
│   │   ├── BudgetPeriod.swift
│   │   └── SupportedCurrency.swift
│   └── SwiftData/
│       ├── Currency.swift
│       ├── Category.swift
│       ├── Account.swift
│       ├── Transaction.swift
│       └── Budget.swift
├── Services/
│   ├── TransactionService.swift
│   ├── CategoryService.swift
│   ├── AccountService.swift
│   ├── BudgetService.swift
│   └── RecurringTransactionGenerator.swift
├── Utilities/
│   ├── ModelContainerConfiguration.swift
│   ├── DefaultDataSeeder.swift
│   ├── Formatters/
│   │   ├── CurrencyFormatter.swift
│   │   └── DateFormatterUtility.swift
│   └── Localization/
│       └── RegionalSettings.swift
├── Resources/
│   ├── Localizable.xcstrings
│   └── CategoryLocalizations.xcstrings
└── Assets.xcassets/
```

---

**Total Tasks: 29**
**Estimated Time: 2-3 hours with parallel execution**
