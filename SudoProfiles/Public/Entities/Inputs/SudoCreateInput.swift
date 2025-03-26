//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// The entity provided to the `SudoProfilesClient.createSudo(input:)` method.
public struct SudoCreateInput: Equatable {

    // MARK: - Properties

    /// The inputs used to create the claims associated with the created Sudo.
    public let claims: Set<ClaimCreateInput>

    // MARK: - Lifecycle
    
    /// Initialize a Sudo create input.
    /// - Parameter claims: The inputs used to create the claims associated with the created Sudo.
    public init(claims: Set<ClaimCreateInput>) {
        self.claims = claims
    }
}

// MARK: - Default Sudo schema

public extension SudoCreateInput {

    // MARK: - Lifecycle

    /// Convenience initializer with default Sudo claim properties.
    /// - Parameters:
    ///   - title: The title of the Sudo. Defaults to `nil`.
    ///   - firstName: First name. Defaults to `nil`.
    ///   - lastName: Last name. Defaults to `nil`.
    ///   - label: Label. Defaults to `nil`.
    ///   - notes: Notes. Defaults to `nil`.
    ///   - avatar: Avatar image data or file URL. Defaults to `nil`.
    ///   - otherClaims: Other claims to include. Defaults to an empty list.
    init(
         title: String? = nil,
         firstName: String? = nil,
         lastName: String? = nil,
         label: String? = nil,
         notes: String? = nil,
         avatar: DataReference? = nil,
         otherClaims: Set<ClaimCreateInput> = []
    ) {
        var defaultClaims: Set<ClaimCreateInput> = []
        if let title {
            defaultClaims.insert(ClaimCreateInput(name: Sudo.ClaimName.title, stringValue: title))
        }
        if let firstName {
            defaultClaims.insert(ClaimCreateInput(name: Sudo.ClaimName.firstName, stringValue: firstName))
        }
        if let lastName {
            defaultClaims.insert(ClaimCreateInput(name: Sudo.ClaimName.lastName, stringValue: lastName))
        }
        if let label {
            defaultClaims.insert(ClaimCreateInput(name: Sudo.ClaimName.label, stringValue: label))
        }
        if let notes {
            defaultClaims.insert(ClaimCreateInput(name: Sudo.ClaimName.notes, stringValue: notes))
        }
        if let avatar {
            defaultClaims.insert(ClaimCreateInput(name: Sudo.ClaimName.avatar, dataReference: avatar))
        }
        self.init(claims: defaultClaims.union(otherClaims))
    }
}
