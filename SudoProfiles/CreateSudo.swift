//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSAppSync
import SudoUser
import SudoLogging
import SudoApiClient

/// Operation to create a new Sudo.
class CreateSudo: SudoOperation {

    private unowned let cryptoProvider: CryptoProvider
    private unowned let graphQLClient: SudoApiClient

    private let region: String
    private let bucket: String
    private let identityId: String
    private let query: ListSudosQuery

    var sudo: Sudo

    /// Initializes an operation to create a new Sudo.
    ///
    /// - Parameters:
    ///   - cryptoProvider:`CryptoProvider` to use for encryption.
    ///   - graphQLClient: GraphQL client to use to interact with Sudo service.
    ///   - logger: Logger to use for logging.
    ///   - region: AWS region hosting Sudo service.
    ///   - bucket: Name of S3 bucket to store any blob associated with Sudo.
    ///   - identityId: ID of identity to own the blob in AWS S3.
    ///   - query: Query in the AppSync cache to update.
    ///   - sudo: Sudo to create.
    init(cryptoProvider: CryptoProvider,
         graphQLClient: SudoApiClient,
         logger: Logger = Logger.sudoProfilesClientLogger,
         region: String,
         bucket: String,
         identityId: String,
         query: ListSudosQuery,
         sudo: Sudo) {
        self.cryptoProvider = cryptoProvider
        self.graphQLClient = graphQLClient
        self.region = region
        self.bucket = bucket
        self.identityId = identityId
        self.query = query
        self.sudo = sudo

        super.init(logger: logger)
    }

    override func execute() {
        // Process secure claims or secure S3 objects associated with Sudo.
        var secureClaims: [SecureClaimInput] = []
        var secureS3Objects: [SecureS3ObjectInput] = []
        do {
            for claim in sudo.claims {
                switch (claim.visibility, claim.value) {
                case (.private, .string(let value)):
                    secureClaims.append(try self.createSecureClaim(name: claim.name, value: value))
                case (.private, .blob(let value)):
                    secureS3Objects.append(try self.createSecureS3Object(name: claim.name, key: "\(self.identityId)/\(value.lastPathComponent)"))
                default:
                    // No other claim type currently supported.
                    break
                }
            }
        } catch {
            self.logger.error("Failed to process secure claims and objects: \(error)")
            self.error = error
            return self.done()
        }

        self.logger.info("Creating a Sudo.")
        let input = CreateSudoInput(claims: secureClaims, objects: secureS3Objects)
        do {
            try self.graphQLClient.perform(
                mutation: CreateSudoMutation(input: input),
                queue: self.queue,
                resultHandler: { (result, error) in
                    if let error = error {
                        self.logger.error("Failed to create a Sudo: \(error)")
                        self.error = SudoProfilesClientError.fromApiOperationError(error: error)
                        return self.done()
                    }

                    guard let result = result else {
                        self.error = SudoProfilesClientError.fatalError(description: "Mutation completed successfully but result is missing.")
                        return self.done()
                    }

                    if let error = result.errors?.first {
                        self.logger.error("Failed to create a Sudo: \(error)")
                        self.error = SudoProfilesClientError.fromApiOperationError(error: error)
                        return self.done()
                    }

                    guard let sudo = result.data?.createSudo else {
                        self.error = SudoProfilesClientError.fatalError(description: "Mutation result did not contain required object.")
                        return self.done()
                    }

                    self.sudo.id = sudo.id
                    self.sudo.version = sudo.version
                    self.sudo.createdAt = Date(millisecondsSinceEpoch: sudo.createdAtEpochMs)
                    self.sudo.updatedAt = Date(millisecondsSinceEpoch: sudo.updatedAtEpochMs)

                    let item = ListSudosQuery.Data.ListSudo.Item(id: sudo.id,
                                                                 claims: sudo.claims.map {
                                                                    ListSudosQuery.Data.ListSudo.Item.Claim(
                                                                        name: $0.name,
                                                                        version: $0.version,
                                                                        algorithm: $0.algorithm,
                                                                        keyId: $0.keyId,
                                                                        base64Data: $0.base64Data
                                                                    )
                                                                 },
                                                                 objects: sudo.objects.map {
                                                                    ListSudosQuery.Data.ListSudo.Item.Object(
                                                                        name: $0.name,
                                                                        version: $0.version,
                                                                        algorithm: $0.algorithm,
                                                                        keyId: $0.keyId,
                                                                        bucket: $0.bucket,
                                                                        region: $0.region,
                                                                        key: $0.key
                                                                    )
                                                                 },
                                                                 metadata: sudo.metadata.map {
                                                                    ListSudosQuery.Data.ListSudo.Item.Metadatum(
                                                                        name: $0.name,
                                                                        value: $0.value
                                                                    )
                                                                 },
                                                                 createdAtEpochMs: sudo.createdAtEpochMs,
                                                                 updatedAtEpochMs: sudo.updatedAtEpochMs,
                                                                 version: sudo.version,
                                                                 owner: sudo.owner)

                    _ = self.graphQLClient.getAppSyncClient().store?.withinReadWriteTransaction { transaction in
                        try transaction.update(query: self.query) { (data: inout ListSudosQuery.Data) in
                            var listSudos = data.listSudos ?? ListSudosQuery.Data.ListSudo(items: [])
                            var items = listSudos.items ?? []
                            // There shouldn't be duplicate entries but just in case remove existing
                            // entry if found.
                            items = items.filter { $0.id != item.id }
                            items.append(item)
                            listSudos.items = items
                            data.listSudos = listSudos
                        }
                    }

                    self.logger.info("Sudo created successfully.")
                    self.done()
                }
            )
        } catch {
            self.error = SudoProfilesClientError.fromApiOperationError(error: error)
            self.done()
        }
    }

    /// Create a secure claim from a name and a String value.
    ///
    /// - Parameters:
    ///   - name: Claim name.
    ///   - value: String value of the claim.
    /// - Returns: Secure claim.
    private func createSecureClaim(name: String, value: String) throws -> SecureClaimInput {
        guard let keyId = try self.cryptoProvider.getSymmetricKeyId() else {
            throw SudoProfilesClientError.fatalError(description: "Symmetric key missing.")
        }
        let encrypted = try self.cryptoProvider.encrypt(keyId: keyId, algorithm: SymmetricKeyEncryptionAlgorithm.aesCBCPKCS7Padding, data: value.data(using: .utf8)!)
        return SecureClaimInput(name: name,
                                version: 1,
                                algorithm: SymmetricKeyEncryptionAlgorithm.aesCBCPKCS7Padding.rawValue,
                                keyId: keyId,
                                base64Data: encrypted.base64EncodedString())
    }

    /// Creates a secure S3 object from a name and a key.
    ///
    /// - Parameters:
    ///   - name: Object name.
    ///   - key: Object key.
    /// - Returns: Secure S3 object.
    private func createSecureS3Object(name: String, key: String) throws -> SecureS3ObjectInput {
        guard let keyId = try self.cryptoProvider.getSymmetricKeyId() else {
            throw SudoProfilesClientError.fatalError(description: "Symmetric key missing.")
        }
        return SecureS3ObjectInput(name: name,
                                   version: 1,
                                   algorithm: SymmetricKeyEncryptionAlgorithm.aesCBCPKCS7Padding.rawValue,
                                   keyId: keyId,
                                   bucket: self.bucket,
                                   region: self.region,
                                   key: key)
    }

}
