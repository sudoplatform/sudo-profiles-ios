//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoKeyManager
import SudoUser
import SudoLogging
import SudoApiClient

/// `OwnershipProofIssuer` implementation that uses a locally stored RSA private key
/// to generated the ownership proof. Mainly used for testing.
public class ClientOwnershipProofIssuer: OwnershipProofIssuer {

    // MARK: - Properties

    private let keyManager: SudoKeyManager

    private let keyId: String

    private let issuer: String

    // MARK: - Lifecycle

    /// Initializes a `ClientOwnershipProofIssuer`.
    ///
    /// - Parameters:
    ///   - privateKey: PEM encoded RSA private key to use for signing the ownership proof.
    ///   - keyManager: `KeyManager` instance to use for cryptographic operations.
    ///   - keyId: Key ID to use for storing the RSA private key in the keychain.
    ///   - issuer: Issuer name to use for the ownership proof.
    public init(privateKey: String, keyManager: SudoKeyManager, keyId: String, issuer: String) throws {
        var privateKey = privateKey
        privateKey = privateKey.replacingOccurrences(of: "\n", with: "")
        privateKey = privateKey.replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
        privateKey = privateKey.replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")

        guard let keyData = Data(base64Encoded: privateKey) else {
            throw SudoProfilesClientError.invalidConfig
        }

        self.keyManager = keyManager
        self.keyId = keyId
        self.issuer = issuer

        try self.keyManager.deleteKeyPair(keyId)
        try self.keyManager.addPrivateKey(keyData, name: keyId)
    }

    // MARK: - Conformance: OwnershipProofIssuer

    public func getOwnershipProof(ownerId: String, subject: String, audience: String) async throws -> String {
        let jwt = JWT(issuer: self.issuer, audience: audience, subject: subject, id: UUID().uuidString)
        jwt.payload["owner"] = ownerId
        let encoded = try jwt.signAndEncode(keyManager: self.keyManager, keyId: self.keyId)
        return encoded
    }
}
