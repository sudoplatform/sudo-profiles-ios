//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoApiClient

/// Utility for transforming between different Sudo representation types.
enum SudoTransformer {

    /// Converts a `GraphQLSudo` object into a `Sudo` model, decrypting claims as needed.
    /// - Parameters:
    ///   - sudo: The GraphQL representation of a Sudo.
    ///   - cryptoProvider: The cryptographic provider for decrypting data.
    /// - Throws: `SudoProfilesClientError.badData` if decryption or data conversion fails.
    /// - Returns: A transformed `Sudo` object.
    static func transformGraphQLSudo(_ sudo: any SudoModel, cryptoProvider: CryptoProvider) throws -> Sudo {
        let claims = try sudo.claims.map {
            guard let algorithm = SymmetricKeyEncryptionAlgorithm(rawValue: $0.algorithm) else {
                throw SudoProfilesClientError.badData
            }
            let value = try decryptData($0.base64Data, algorithm: algorithm, keyId: $0.keyId, cryptoProvider: cryptoProvider)
            return Claim(
                name: $0.name,
                value: .string(value: value),
                sudoId: sudo.id,
                version: $0.version,
                algorithm: algorithm,
                keyId: $0.keyId
            )
        }
        let objects = try sudo.objects.map {
            guard let algorithm = SymmetricKeyEncryptionAlgorithm(rawValue: $0.algorithm) else {
                throw SudoProfilesClientError.badData
            }
            return Claim(
                name: $0.name,
                value: .blob(key: $0.key),
                sudoId: sudo.id,
                version: $0.version,
                algorithm: algorithm,
                keyId: $0.keyId
            )
        }
        let metadata = Dictionary(sudo.metadata.map { ($0.name, $0.value) }, uniquingKeysWith: { lhs, _ in lhs })
        return Sudo(
            id: sudo.id,
            claims: Set(claims + objects),
            metadata: metadata,
            createdAt: Date(timeIntervalSince1970: sudo.createdAtEpochMs / 1000),
            updatedAt: Date(timeIntervalSince1970: sudo.updatedAtEpochMs / 1000),
            version: sudo.version
        )
    }

    /// Converts a `SudoCreateInput` into a `SudoUpdateInput`, preserving claims.
    /// - Parameters:
    ///   - createInput: The input for creating a Sudo.
    ///   - sudoId: The identifier of the Sudo being created.
    ///   - version: The version of the created Sudo.
    /// - Returns: A `SudoUpdateInput` with the corresponding claims.
    static func transformCreateInput(_ createInput: SudoCreateInput, sudoId: String, version: Int) -> SudoUpdateInput {
        let updatedClaims = createInput.claims.map { claim in
            let value: ClaimUpdateInput.Value
            switch claim.value {
            case .blob(let dataReference):
                value = .blob(dataReference)
            case .string(let stringValue):
                value = .string(stringValue)
            }
            return ClaimUpdateInput(name: claim.name, value: value)
        }
        return SudoUpdateInput(sudoId: sudoId, version: version, updatedClaims: Set(updatedClaims))
    }

    /// Converts a `SudoUpdateInput` into an `UpdateSudoInput`, preserving unmodified claims.
    /// - Parameters:
    ///   - input: The update input containing modified claims.
    ///   - sudo: The existing GraphQL representation of the Sudo.
    ///   - claims: The claims to be updated.
    ///   - objects: The objects to be updated.
    /// - Returns: An `UpdateSudoInput` that includes both updated and unmodified claims/objects.
    static func transformUpdateInput(
        _ input: SudoUpdateInput,
        sudo: any SudoModel,
        claims: [SecureClaimInput],
        objects: [SecureS3ObjectInput]
    ) -> UpdateSudoInput {
        let updatedClaimNames = Set(input.updatedClaims.map(\.name))
        let unmodifiedClaims = sudo.claims
            .filter { !updatedClaimNames.contains($0.name) }
            .map {
                SecureClaimInput(
                    name: $0.name,
                    version: $0.version,
                    algorithm: $0.algorithm,
                    keyId: $0.keyId,
                    base64Data: $0.base64Data
                )
            }
        let unmodifiedObjects = sudo.objects
            .filter { !updatedClaimNames.contains($0.name) }
            .map {
                SecureS3ObjectInput(
                    name: $0.name,
                    version: $0.version,
                    algorithm: $0.algorithm,
                    keyId: $0.keyId,
                    bucket: $0.bucket,
                    region: $0.region,
                    key: $0.key
                )
            }
        return UpdateSudoInput(
            id: sudo.id,
            claims: claims + unmodifiedClaims,
            objects: objects + unmodifiedObjects,
            expectedVersion: sudo.version
        )
    }

    /// Decrypts base64-encoded data using the specified encryption algorithm.
    /// - Parameters:
    ///   - base64Data: The encrypted data in Base64 format.
    ///   - algorithm: The encryption algorithm used.
    ///   - keyId: The identifier of the encryption key.
    ///   - cryptoProvider: The cryptographic provider used for decryption.
    /// - Throws: `SudoProfilesClientError.badData` if decryption fails.
    /// - Returns: A decrypted string representation of the data.
    static func decryptData(
        _ base64Data: String,
        algorithm: SymmetricKeyEncryptionAlgorithm,
        keyId: String,
        cryptoProvider: CryptoProvider
    ) throws -> String {
        guard let encryptedData = Data(base64Encoded: base64Data) else {
            throw SudoProfilesClientError.badData
        }
        let decryptedData = try cryptoProvider.decrypt(keyId: keyId, algorithm: algorithm, data: encryptedData)
        guard let value = String(data: decryptedData, encoding: .utf8) else {
            throw SudoProfilesClientError.badData
        }
        return value
    }

    /// Converts a `GraphQLClientConnectionState` into a `SubscriptionConnectionState`, if applicable.
    /// - Parameter connectionState: The current connection state of the GraphQL client.
    /// - Returns: The corresponding `SubscriptionConnectionState`, or `nil` if still connecting.
    static func transformConnectionState(_ connectionState: GraphQLClientConnectionState) -> SubscriptionConnectionState? {
        switch connectionState {
        case .connecting:
            return nil
        case .connected:
            return .connected
        case .disconnected:
            return .disconnected
        }
    }
}
