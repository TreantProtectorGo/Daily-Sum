import Foundation
import SwiftUI

@Observable
final class RegionalSettings {
    static let shared = RegionalSettings()
    
    var region: Region
    
    private init() {
        self.region = Region.fromLocale()
    }
    
    var gainColor: Color {
        .green
    }
    
    var lossColor: Color {
        .red
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
        
        var defaultCurrency: SupportedCurrency {
            switch self {
            case .unitedStates, .other: .USD
            case .taiwan: .TWD
            case .china: .CNY
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
