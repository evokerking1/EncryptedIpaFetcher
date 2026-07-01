import Foundation

struct LoginRequest: Hashable {
    let appleID: String
    let password: String
    let twoFactorCode: String?
}
