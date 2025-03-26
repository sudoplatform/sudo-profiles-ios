//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Represents a Sudo.
public struct Sudo: Equatable, Codable, Comparable {

    // MARK: - Properties

    /// Globally unique identifier of this Sudo. This is generated and set by Sudo service.
    public let id: String

    /// Claims.
    public let claims: Set<Claim>

    /// Arbitrary metadata set by the backend.
    public let metadata: [String: String]

    /// Date and time at which this Sudo was created.
    public let createdAt: Date

    /// Date and time at which this Sudo was updated.
    public let updatedAt: Date

    /// Current version of this Sudo.
    public let version: Int

    // MARK: - Methods

    /// Returns the claim with the specified name.
    /// - Parameter name: Claim name.
    /// - Returns: Claim of the specified name.
    public func getClaim(name: String) -> Claim? {
        claims.first(where: { $0.name == name })
    }

    // MARK: - Conformance: Comparable

    public static func < (lhs: Sudo, rhs: Sudo) -> Bool {
        if lhs.createdAt < rhs.createdAt {
            return true
        }
        return lhs.id < rhs.id
    }
}

// MARK: - Default Sudo schema.

public extension Sudo {

    // MARK: - Supplementary

    /// Namespace for String constants for Sudo claim names.
    enum ClaimName {
        static let title = "title"
        static let firstName = "firstName"
        static let lastName = "lastName"
        static let label = "label"
        static let notes = "notes"
        static let avatar = "avatar"
        static let externalId = "ExternalId"
    }

    // MARK: - Properties

    /// Title.
    var title: String? { getStringClaim(ClaimName.title) }

    /// First name.
    var firstName: String? { getStringClaim(ClaimName.firstName) }

    /// Last name.
    var lastName: String? { getStringClaim(ClaimName.lastName) }

    /// Label.
    var label: String? { getStringClaim(ClaimName.label) }

    /// Notes.
    var notes: String? { getStringClaim(ClaimName.notes) }

    /// External ID associated with this Sudo.
    var externalId: String? { metadata[ClaimName.externalId] }

    /// Whether the Sudo has an avatar image.
    var hasAvatar: Bool { getClaim(name: ClaimName.avatar) != nil }

    /// The optional avatar blob claim.  To download the associated avatar data, pass this value to the
    /// `SudoProfilesClient.getBlob(forClaim:cachePolicy` method.
    var avatarClaim: Claim? { getClaim(name: ClaimName.avatar) }

    // MARK: - Helpers

    internal func getStringClaim(_ name: String) -> String? {
        guard case .string(let stringValue) = getClaim(name: name)?.value else {
            return nil
        }
        return stringValue
    }
}
