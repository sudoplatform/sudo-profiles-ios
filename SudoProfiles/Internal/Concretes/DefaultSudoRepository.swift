//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Combine
import Foundation
import SudoApiClient
import SudoLogging
import SudoUser

/// A `SudoRepository` conforming instance which uses a `SudoApiClient` for GraphQL operations.
class DefaultSudoRepository: SudoRepository {

    // MARK: - Supplementary
    
    /// Wraps a client subscription with an additional Bool property
    /// to keep track of whether the subscription has connected.
    struct Subscription {

        /// The underlying subscription.
        let value: GraphQLClientSubscription

        /// `true` if the subscription has connected, or `false` otherwise.
        var isConnected: Bool
    }

    // MARK: - Properties

    /// The maximum number of Sudos to fetch at a time.
    let listSudosQueryLimit: Int

    /// GraphQL client for communicating with the Sudo  service.
    let graphQLClient: SudoApiClient
    
    /// A map of active subscriptions keyed by change type.
    var subscriptions: [SudoChangeType: Subscription] = [:]

    /// A lock used to provide thread-safe access to the `subscriptions` property.
    var subscriptionsLock = NSLock()

    /// The queue that results are delivered on to subscribers.
    let apiResultQueue = DispatchQueue(label: "com.sudoplatform.sudoprofiles.api.result")

    /// Default logger for the client.
    let logger: Logger

    // MARK: - Lifecycle

    init(listSudosQueryLimit: Int, graphQLClient: SudoApiClient, logger: Logger) {
        self.listSudosQueryLimit = listSudosQueryLimit
        self.graphQLClient = graphQLClient
        self.logger = logger
    }

    // MARK: - Conformance: SudoRepository

    weak var delegate: SudoRepositoryDelegate?

    func createSudo() async throws -> any SudoModel {
        logger.info("Creating a Sudo.")
        let createInput = CreateSudoInput(claims: [], objects: [])
        let createSudoData: CreateSudoMutation.Data
        do {
            createSudoData = try await graphQLClient.perform(mutation: CreateSudoMutation(input: createInput))
        } catch {
            logger.error("Failed to create a Sudo: \(error)")
            throw SudoProfilesClientError.fromApiOperationError(error: error)
        }
        guard let createdSudo = createSudoData.createSudo else {
            logger.error("Mutation result did not contain required object.")
            throw SudoProfilesClientError.fatalError(description: "Mutation result did not contain required object.")
        }
        logger.info("Sudo created successfully. \(createdSudo.id)")
        return createdSudo
    }

    func getSudo(withId id: String) async throws -> any SudoModel {
        logger.info("Getting a Sudo.")
        let sudo: GetSudoQuery.Data.GetSudo?
        do {
            sudo = try await graphQLClient.fetch(query: GetSudoQuery(id: id)).getSudo
        } catch {
            logger.error("Failed to get Sudo: \(error.localizedDescription)")
            throw SudoProfilesClientError.fromApiOperationError(error: error)
        }
        guard let sudo else {
            throw SudoProfilesClientError.notFound
        }
        return sudo
    }

    func listSudos() async throws -> [any SudoModel] {
        logger.info("Listing Sudos.")
        let listSudosData: ListSudosQuery.Data
        do {
            let listSudosQuery = ListSudosQuery(limit: listSudosQueryLimit, nextToken: nil)
            listSudosData = try await graphQLClient.fetch(query: listSudosQuery)
        } catch {
            logger.error("Failed to list sudos \(error.localizedDescription)")
            throw SudoProfilesClientError.fromApiOperationError(error: error)
        }
        guard let sudos = listSudosData.listSudos?.items else {
            logger.error("Query result contained no list data.")
            throw SudoProfilesClientError.fatalError(description: "Query result contained no list data.")
        }
        logger.info("Sudos fetched successfully. Processing the result....")
        return sudos
    }

    func updateSudo(input: UpdateSudoInput) async throws -> any SudoModel {
        logger.info("Updating a Sudo.")
        let updateSudoData: UpdateSudoMutation.Data
        do {
            updateSudoData = try await graphQLClient.perform(mutation: UpdateSudoMutation(input: input))
        } catch {
            throw SudoProfilesClientError.fromApiOperationError(error: error)
        }
        guard let updatedSudo = updateSudoData.updateSudo else {
            logger.error("Mutation result did not contain required object.")
            throw SudoProfilesClientError.fatalError(description: "Mutation result did not contain required object.")
        }
        logger.info("Sudo updated successfully.")
        return updatedSudo
    }

    func deleteSudo(withId sudoId: String, version: Int) async throws -> any SudoModel {
        logger.info("Deleting a Sudo.")
        let deleteSudoData: DeleteSudoMutation.Data
        do {
            let deleteSudoMutation = DeleteSudoMutation(input: DeleteSudoInput(id: sudoId, expectedVersion: version))
            deleteSudoData = try await graphQLClient.perform(mutation: deleteSudoMutation)
        } catch {
            logger.error("Failed to delete Sudo due to thrown error \(error.localizedDescription)")
            throw SudoProfilesClientError.fromApiOperationError(error: error)
        }
        guard let deletedSudo = deleteSudoData.deleteSudo else {
            logger.error("Mutation completed successfully but result is empty.")
            throw SudoProfilesClientError.fatalError(description: "Mutation completed successfully but result is empty.")
        }
        logger.info("Sudo deleted successfully.")
        return deletedSudo
    }

    func subscribe(changeType: SudoChangeType, owner: String) -> Bool {
        if let existingSubscription = getSubscription(forChangeType: changeType) {
            return existingSubscription.isConnected
        }
        switch changeType {
        case .create:
            subscribe(subscription: OnCreateSudoSubscription(owner: owner), changeType: .create)
        case .update:
            subscribe(subscription: OnUpdateSudoSubscription(owner: owner), changeType: .update)
        case .delete:
            subscribe(subscription: OnDeleteSudoSubscription(owner: owner), changeType: .delete)
        }
        return false
    }

    func unsubscribe(changeType: SudoChangeType) {
        let subscription = subscriptionsLock.withCriticalScope {
            subscriptions.removeValue(forKey: changeType)
        }
        subscription?.value.cancel()
    }

    func unsubscribeAll() {
        let existingSubscriptions = subscriptionsLock.withCriticalScope {
            let values = subscriptions.values
            subscriptions.removeAll()
            return values
        }
        existingSubscriptions.forEach { $0.value.cancel() }
    }

    // MARK: - Helpers

    func getSubscription(forChangeType changeType: SudoChangeType) -> Subscription? {
        subscriptionsLock.withCriticalScope {
            subscriptions[changeType]
        }
    }

    func subscribe<S: GraphQLSubscription>(subscription: S, changeType: SudoChangeType) where S.Data: GraphQLSubscriptionResult {
        let activeSubscription = graphQLClient.subscribe(
            subscription: subscription,
            queue: apiResultQueue,
            statusChangeHandler: { [weak self] connectionState in
                guard let self, connectionState == .connected else { return }
                self.updateSubscriptionIsConnected(true, forChangeType: changeType)
                self.delegate?.sudoRepository(self, connectionStateChanged: .connected, forChangeType: changeType)
            },
            completionHandler: { [weak self] _ in
                guard let self else { return }
                self.unsubscribe(changeType: changeType)
                self.delegate?.sudoRepository(self, connectionStateChanged: .disconnected, forChangeType: changeType)
            },
            resultHandler: { [weak self] result in
                if let self, let sudo = try? result.get().sudo {
                    self.delegate?.sudoRepository(self, didReceiveEvent: changeType, forSudo: sudo)
                }
            }
        )
        subscriptionsLock.withCriticalScope {
            subscriptions[changeType] = Subscription(value: activeSubscription, isConnected: false)
        }
    }

    func updateSubscriptionIsConnected(_ isConnected: Bool, forChangeType changeType: SudoChangeType) {
        subscriptionsLock.withCriticalScope {
            subscriptions[changeType]?.isConnected = isConnected
        }
    }
}
