import Foundation

public protocol SecretStoring: Sendable {
    func secret(for account: String) -> String?
    func store(_ secret: String?, for account: String) throws
}
