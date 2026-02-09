import Foundation
import SwiftUI

@Observable
final class RegionalSettings {
    static let shared = RegionalSettings()
    
    var region: Region
    var colorSchemeOverride: GainLossColorScheme?
    
    private init() {
        self.region = Region.fromLocale()
        self.colorSchemeOverride = nil
    }
    
    var gainLossColors: GainLossColorScheme {
        colorSchemeOverride ?? region.defaultColorScheme
    }
    
    var gainColor: Color {
        gainLossColors.gainColor
    }
    
    var lossColor: Color {
        gainLossColors.lossColor
    }
    
    func color(for value: Decimal) -> Color {
        if value > 0 {
            gainColor
        } else if value < 0 {
            lossColor
        } else {
            .primary
        }
    }
    
    enum Region: String, CaseIterable {
        case unitedStates
        case taiwan
        case china
        case other
        
        static func fromLocale(_ locale: Locale = .current) -> Region {
            guard let regionCode = locale.region?.identifier else {
                return .other
            }
            
            switch regionCode {
            case "US": return .unitedStates
            case "TW": return .taiwan
            case "CN", "HK", "MO": return .china
            default: return .other
            }
        }
        
        var defaultColorScheme: GainLossColorScheme {
            switch self {
            case .unitedStates, .other:
                .western
            case .taiwan, .china:
                .eastern
            }
        }
        
        var defaultCurrency: SupportedCurrency {
            switch self {
            case .unitedStates, .other: .USD
            case .taiwan: .TWD
            case .china: .CNY
            }
        }
    }
    
    enum GainLossColorScheme: String, CaseIterable, Identifiable {
        case western
        case eastern
        
        var id: String { rawValue }
        
        var gainColor: Color {
            switch self {
            case .western: .green
            case .eastern: .red
            }
        }
        
        var lossColor: Color {
            switch self {
            case .western: .red
            case .eastern: .green
            }
        }
        
        var localizedName: String {
            switch self {
            case .western:
                String(localized: "settings.colorScheme.western", 
                       defaultValue: "Western (Green +, Red -)")
            case .eastern:
                String(localized: "settings.colorScheme.eastern", 
                       defaultValue: "Eastern (Red +, Green -)")
            }
        }
    }
}

private struct RegionalSettingsKey: EnvironmentKey {
    static let defaultValue = RegionalSettings.shared
}

extension EnvironmentValues {
    var regionalSettings: RegionalSettings {
        get { self[RegionalSettingsKey.self] }
        set { self[RegionalSettingsKey.self] = newValue }
    }
}
