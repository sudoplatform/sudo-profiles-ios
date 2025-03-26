//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Combine
import Foundation
import SudoApiClient

/// A repository for managing `Sudo` objects via GraphQL operations.
protocol SudoRepository: AnyObject {
    
    /// Optional delegate to be notified of subscription related events.
    var delegate: SudoRepositoryDelegate? { get set }

    /// Creates a new `Sudo` and returns the resulting object.
    /// - Returns: The created `SudoModel` instance.
    /// - Throws: A `SudoProfilesClientError` if the creation fails.
    func createSudo() async throws -> any SudoModel

    /// Retrieves a `Sudo` by its unique identifier.
    /// - Parameter id: The ID of the `Sudo` to fetch.
    /// - Returns: The requested `SudoModel` instance.
    /// - Throws: A `SudoProfilesClientError` if retrieval fails or the `Sudo` does not exist.
    func getSudo(withId id: String) async throws -> any SudoModel

    /// Lists all available `Sudo` objects.
    /// - Returns: An array of `SudoModel` instances.
    /// - Throws: A `SudoProfilesClientError` if the operation fails.
    func listSudos() async throws -> [any SudoModel]

    /// Updates an existing `Sudo` with the provided input.
    /// - Parameter input: The `UpdateSudoInput` containing the updated data.
    /// - Returns: The updated `SudoModel` instance.
    /// - Throws: A `SudoProfilesClientError`if the update fails.
    func updateSudo(input: UpdateSudoInput) async throws -> any SudoModel

    /// Deletes a `Sudo` by its unique identifier.
    /// - Parameters:
    ///   - sudoId: The ID of the `Sudo` to delete.
    ///   - version: The version of the `Sudo` to delete.
    /// - Returns: The deleted `SudoModel` instance.
    /// - Throws: A `SudoProfilesClientError` if the deletion fails.
    func deleteSudo(withId sudoId: String, version: Int) async throws -> any SudoModel

    /// Subscribes to changes for a given change type.
    /// - Parameters:
    ///   - changeType: The type of change to listen for.
    ///   - owner: The owner of the `Sudo` objects being observed.
    /// - Returns: `true` if the subscription is already connected.
    func subscribe(changeType: SudoChangeType, owner: String) -> Bool

    /// Unsubscribes from changes for a specific change  type.
    /// - Parameter changeType: The type of change to stop listening for.
    func unsubscribe(changeType: SudoChangeType)

    /// Unsubscribes from all active `Sudo` change subscriptions.
    func unsubscribeAll()
}

/// A delegate protocol for handling `SudoRepository` subscription events.
protocol SudoRepositoryDelegate: AnyObject {

    /// Called when a `Sudo` change event occurs.
    /// - Parameters:
    ///   - repository: The `SudoRepository` that triggered the event.
    ///   - changeType: The type of change that occurred.
    ///   - sudo: The `Sudo` instance that was affected.
    func sudoRepository(_ repository: any SudoRepository, didReceiveEvent changeType: SudoChangeType, forSudo sudo: any SudoModel)

    /// Called when the connection state changes for a subscription.
    /// - Parameters:
    ///   - repository: The `SudoRepository` managing the subscription.
    ///   - connectionState: The new connection state.
    ///   - changeType: The type of `Sudo` change subscription affected.
    func sudoRepository(
        _ repository: SudoRepository,
        connectionStateChanged connectionState: GraphQLClientConnectionState,
        forChangeType changeType: SudoChangeType
    )
}
