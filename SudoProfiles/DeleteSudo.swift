//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSAppSync
import SudoLogging
import SudoApiClient

/// Operation to delete an existing Sudo.
class DeleteSudo: SudoOperation {

    private unowned let graphQLClient: SudoApiClient

    private let query: ListSudosQuery

    var sudo: Sudo

    /// Initializes an operation to delete an existing Sudo.
    ///
    /// - Parameters:
    ///   - graphQLClient: GraphQL client to use to interact with Sudo service.
    ///   - logger: Logger to use for logging.
    ///   - query: Query in the AppSync cache to update.
    ///   - sudo: Sudo to delete.
    init(graphQLClient: SudoApiClient,
         logger: Logger = Logger.sudoProfilesClientLogger,
         query: ListSudosQuery,
         sudo: Sudo) {
        self.graphQLClient = graphQLClient
        self.query = query
        self.sudo = sudo

        super.init(logger: logger)
    }

    override func execute() {
        guard let id = sudo.id else {
            self.logger.error("Sudo ID is missing but is required to update an Sudo.")
            self.error = SudoOperationError.preconditionFailure
            return self.done()
        }

        do {
            try self.graphQLClient.perform(
                mutation: DeleteSudoMutation(input: DeleteSudoInput(id: id, expectedVersion: sudo.version)),
                queue: self.queue,
                resultHandler: { (result, error) in
                    if let error = error {
                        self.logger.error("Failed to delete a Sudo: \(error)")
                        self.error = SudoProfilesClientError.fromApiOperationError(error: error)
                        return self.done()
                    }

                    guard let result = result else {
                        self.error = SudoProfilesClientError.fatalError(description: "Mutation completed successfully but result is missing.")
                        return self.done()
                    }

                    if let error = result.errors?.first {
                        self.logger.error("Failed to delete a Sudo: \(error)")
                        self.error = SudoProfilesClientError.fromApiOperationError(error: error)
                        return self.done()
                    }

                    guard let item = result.data?.deleteSudo else {
                        self.error = SudoProfilesClientError.fatalError(description: "Mutation completed successfully but result is empty.")
                        return self.done()
                    }

                    _ = self.graphQLClient.getAppSyncClient().store?.withinReadWriteTransaction { transaction in
                        try transaction.update(query: self.query) { (data: inout ListSudosQuery.Data) in
                            // Remove the deleted Sudo from the cache.
                            let newState = data.listSudos?.items?.filter { $0.id != item.id }
                            data.listSudos?.items = newState
                        }
                    }

                    self.logger.info("Sudo deleted successfully.")
                    self.done()
                }
            )
        } catch {
            self.error = SudoProfilesClientError.fromApiOperationError(error: error)
            self.done()
        }
    }

}
