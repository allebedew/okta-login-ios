//
//  PKCE.swift
//  OktaLogin
//
//  Created by Alex on 12/5/18.
//  Copyright © 2018 Alex. All rights reserved.
//

import Foundation
import CommonCrypto

class PKCE {
    let codeVerifier: String
    let codeChallange: String
    
    init() {
        codeVerifier = String.randomAlphanumeric(length: 64)
        codeChallange = codeVerifier.data(using: .utf8)!.sha256().base64urlEncodedString()
        print("PKCE generated\nCode Verifier: \(codeVerifier)\nCode Challange: \(codeChallange)")
    }
}

extension String {
    static func randomAlphanumeric(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0...length-1).map{ _ in letters.randomElement()! })
    }
}

extension Data {
    func sha256() -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes({
            _ = CC_SHA256($0, CC_LONG(count), &digest)
        })
        return Data(bytes: digest)
    }

    func hexString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }

    func base64urlEncodedString() -> String {
        var string = self.base64EncodedString()
        string = string.replacingOccurrences(of: "+", with: "-")
        string = string.replacingOccurrences(of: "/", with: "_")
        string = string.replacingOccurrences(of: "=", with: "")
        return string
    }
}
