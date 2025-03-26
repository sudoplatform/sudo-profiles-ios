//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// The entity provided to the `SudoProfilesClient.updateSudo(input:)` method.
public struct SudoUpdateInput: Equatable {

    // MARK: - Properties
    
    /// The unique identifier of the Sudo to update.
    public let sudoId: String

    /// The version of the Sudo to update.
    public let version: Int

    /// The claims to update.  Existing claims not included in this set will not be updated.
    public let updatedClaims: Set<ClaimUpdateInput>

    // MARK: - Lifecycle
    
    /// Initialize a Sudo update input.
    /// - Parameters:
    ///   - sudoId: The unique identifier of the Sudo to update.
    ///   - version: The version of the Sudo to update.
    ///   - updatedClaims: The claims to update.  Existing claims not included in this set will not be updated.
    public init(sudoId: String, version: Int, updatedClaims: Set<ClaimUpdateInput>) {
        self.sudoId = sudoId
        self.version = version
        self.updatedClaims = updatedClaims
    }
}

// MARK: - Default Sudo schema

public extension SudoUpdateInput {

    // MARK: - Lifecycle
    
    /// Convenience initializer with default Sudo claim properties.
    /// - Parameters:
    ///   - sudoId: The unique identifier of the Sudo to update.
    ///   - version: The version of the Sudo to update.
    ///   - title: The updatable title.  Defaults to `oldValue`.
    ///   - firstName: The updatable first name.  Defaults to `oldValue`.
    ///   - lastName: The updatable last name.  Defaults to `oldValue`.
    ///   - label: The updatable label.  Defaults to `oldValue`.
    ///   - notes: The updatable notes.  Defaults to `oldValue`.
    ///   - avatar: The updatable avatar data reference.  Defaults to `oldValue`.
    ///   - otherUpdatedClaims: Other claims to update.  Defaults to an empty list.
    init(
        sudoId: String,
        version: Int,
        title: Updatable<String?> = .oldValue,
        firstName: Updatable<String?> = .oldValue,
        lastName: Updatable<String?> = .oldValue,
        label: Updatable<String?> = .oldValue,
        notes: Updatable<String?> = .oldValue,
        avatar: Updatable<DataReference?> = .oldValue,
        otherUpdatedClaims: Set<ClaimUpdateInput> = []
    ) {
        var updatedClaims: Set<ClaimUpdateInput> = []
        if case .newValue(let titleNewValue) = title {
            updatedClaims.insert(ClaimUpdateInput(name: Sudo.ClaimName.title, stringValue: titleNewValue))
        }
        if case .newValue(let firstNameNewValue) = firstName {
            updatedClaims.insert(ClaimUpdateInput(name: Sudo.ClaimName.firstName, stringValue: firstNameNewValue))
        }
        if case .newValue(let lastNameNewValue) = lastName {
            updatedClaims.insert(ClaimUpdateInput(name: Sudo.ClaimName.lastName, stringValue: lastNameNewValue))
        }
        if case .newValue(let labelNewValue) = label {
            updatedClaims.insert(ClaimUpdateInput(name: Sudo.ClaimName.label, stringValue: labelNewValue))
        }
        if case .newValue(let notesNewValue) = notes {
            updatedClaims.insert(ClaimUpdateInput(name: Sudo.ClaimName.notes, stringValue: notesNewValue))
        }
        if case .newValue(let newAvatar) = avatar {
            updatedClaims.insert(ClaimUpdateInput(name: Sudo.ClaimName.avatar, dataReference: newAvatar))
        }
        self.init(sudoId: sudoId, version: version, updatedClaims: updatedClaims.union(otherUpdatedClaims))
    }
}
