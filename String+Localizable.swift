import Foundation

extension String {
    var localized: String {
        NSLocalizedString(self, tableName: "Localizable", bundle: .main, comment: "")
    }
}
