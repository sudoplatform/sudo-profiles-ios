//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoLogging
import SudoUser
import SudoConfigManager
import SudoApiClient

/// Protocol encapsulating a library functions for managing Sudos in the Sudo service.
public protocol SudoProfilesClient: AnyObject {

    // MARK: - Properties

    /// Configuration parameters used to instantiate the client.
    var config: SudoProfilesClientConfig { get }

    // MARK: - CRUD

    /// Creates a new Sudo.
    /// - Parameter input: The input used to create the Sudo.
    /// - Returns: The created Sudo.
    /// - Throws: `SudoProfilesClientError`
    func createSudo(input: SudoCreateInput) async throws -> Sudo

    /// Update a Sudo.
    /// - Parameter input: The input to apply when updating the Sudo.
    /// - Returns: The updated Sudo.
    /// - Throws: `SudoProfilesClientError`
    func updateSudo(input: SudoUpdateInput) async throws -> Sudo

    /// Deletes a Sudo.
    /// - Parameter input: The input containing identifying information about the Sudo to delete.
    /// - Throws: `SudoProfilesClientError`
    func deleteSudo(input: SudoDeleteInput) async throws

    /// Retrieves all Sudos owned by signed in user.
    /// - Returns: An array of all the Sudos owned by signed in user.
    /// - Throws: `SudoProfilesClientError`
    func listSudos(cachePolicy: CachePolicy) async throws -> [Sudo]

    /// Retrieves the blob data associated with a given Sudo claim.
    /// - Parameters:
    ///   - claim: The `Claim` object for which to fetch the blob.
    ///   - cachePolicy: The `CachePolicy` determining whether to fetch from cache or network.
    /// - Returns: The blob data as `Data`.
    /// - Throws: A  `SudoProfilesClientError` if the blob retrieval fails.
    func getBlob(forClaim claim: Claim, cachePolicy: CachePolicy) async throws -> Data
    
    /// Will remove all cached Sudos and blob claims.
    func clearCache() throws

    /// Resets any cached data.
    /// - Throws: `SudoProfilesClientError`
    func reset() async throws

    // MARK: - Subscriptions

    /// Subscribes to be notified of new, updated or deleted Sudos. Blob data is not downloaded automatically
    /// so the caller is expected to use `getBlob` API if they need to access any associated blobs.
    /// - Parameters:
    ///   - id: Unique ID to be associated with the subscriber.
    ///   - changeType: Change type to subscribe to.  Defaults to all change types.
    ///   - subscriber: Subscriber to notify.
    func subscribe(id: String, changeTypes: [SudoChangeType], subscriber: SudoSubscriber) async throws

    /// Unsubscribes the specified subscriber so that it no longer receives notifications about
    /// new, updated or deleted Sudos.
    /// - Parameters:
    ///   - id: Unique ID associated with the subscriber to unsubscribe.
    ///   - changeTypes: Change type to unsubscribe from.  Defaults to all change types.
    func unsubscribe(id: String, changeTypes: [SudoChangeType])

    /// Unsubscribe all subscribers from receiving notifications about new, updated or deleted Sudos.
    func unsubscribeAll()

    // MARK: - Crypto

    /// Retrieves a signed ownership proof for the specified Sudo.
    /// - Parameters:
    ///   - sudo: Sudo to generate an ownership proof for.
    ///   - audience: Target audience for this proof.
    /// - Returns: JSON Web Token representing Sudo ownership proof.
    func getOwnershipProof(sudo: Sudo, audience: String) async throws -> String

    /// Generate an encryption key to use for encrypting Sudo claims. Any existing keys are not removed
    /// to be able to decrypt existing claims but new claims will be encrypted using the newly generated
    /// key.
    /// - Returns: Unique ID of the generated key.
    @discardableResult
    func generateEncryptionKey() throws -> String

    /// Get the current (most recently generated) symmetric key ID..
    /// - Returns: Symmetric Key ID.
    func getSymmetricKeyId() throws -> String?

    /// Import encryption keys to use for encrypting and decrypting Sudo claims. All existing keys will be removed
    /// before the new keys are imported.
    /// - Parameters:
    ///    - keys: Keys to import.
    ///    - currentKeyId: ID of the key to use for encrypting new claims..
    func importEncryptionKeys(keys: [EncryptionKey], currentKeyId: String) throws

    /// Export encryption keys used for encrypting and decrypting Sudo claims.
    /// - Returns: Encryption keys.
    func exportEncryptionKeys() throws -> [EncryptionKey]
}

// MARK: - Default Values

public extension SudoProfilesClient {

    func subscribe(id: String, changeTypes: [SudoChangeType] = SudoChangeType.allCases, subscriber: SudoSubscriber) async throws {
        try await subscribe(id: id, changeTypes: changeTypes, subscriber: subscriber)
    }

    func unsubscribe(id: String, changeTypes: [SudoChangeType] = SudoChangeType.allCases) {
        unsubscribe(id: id, changeTypes: changeTypes)
    }
}
