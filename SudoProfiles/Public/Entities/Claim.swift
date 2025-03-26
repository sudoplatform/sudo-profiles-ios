//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Represents a claim or identity attribute associated with a Sudo.
public struct Claim: Hashable, Codable {

    // MARK: - Supplementary

    /// The value of a claim, representing an identity attribute.
    public enum Value: Codable, Equatable {

        /// A claim value stored as a plain text string.
        /// - Parameter value: The unencrypted string representation of the claim.
        case string(value: String)

        /// A claim value stored as a binary blob.
        /// - Parameter key: A unique key referencing the blob's storage location in the backend.
        case blob(key: String)
    }

    // MARK: - Properties

    /// Claim name.
    public let name: String

    /// Claim value.
    public let value: Value
    
    /// The unique identifier of the Sudo associated with the claim.
    public let sudoId: String
    
    /// The version of the claim set by the backend.
    public let version: Int
    
    /// The algorithm used to encrypted the claim.
    public let algorithm: SymmetricKeyEncryptionAlgorithm
    
    /// The ID of the key used to encrypt the claim.
    public let keyId: String

    // MARK: - Conformance: Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension Claim {
    
    /// Whether the value of the claim is of `blob` type.
    var isBlob: Bool {
        if case .blob = value {
            return true
        }
        return false
    }
}
