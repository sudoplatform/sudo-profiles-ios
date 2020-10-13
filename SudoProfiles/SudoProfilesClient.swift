//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoLogging
import SudoUser
import AWSAppSync
import AWSS3
import SudoConfigManager
import SudoApiClient

/// List of possible errors thrown by `SudoProfilesClient` implementation.
///
/// - invalidConfig: Indicates that the configuration dictionary passed to initialize the client was not valid.
/// - invalidInput: Indicates that the input to the API was invalid.
/// - notSignedIn: Indicates the API being called requires the client to sign in.
/// - badData: Indicates the bad data was found in cache or in backend response.
/// - graphQLError: Indicates that a GraphQL error was returned by the backend.
/// - fatalError: Indicates that a fatal error occurred. This could be due to coding error, out-of-memory
///     condition or other conditions that is beyond control of `SudoProfilesClient` implementation.
public enum SudoProfilesClientError: Error {
    case invalidConfig
    case invalidInput
    case notSignedIn
    case badData
    case graphQLError(description: String)
    case fatalError(description: String)
}

/// Options for controlling the behaviour of `listSudos` API.
///
/// - cacheOnly: returns Sudos from the local cache only. The cache is only updated after listSudos is called with remoteOnly.
/// - remoteOnly:fetches Sudos from the backend, updates the local cache and returns the fetched Sudos.
public enum ListOption {
    case cacheOnly
    case remoteOnly
}

/// Generic API result. The API can fail with an error or complete successfully.
///
/// - success: API completed successfully.
/// - failure: API failed with an error.
public enum ApiResult {
    case success
    case failure(cause: Error)
}

/// Result returned by API for creating a new Sudo. The API can fail with an
/// error or return the newly created Sudo.
///
/// - success: Sudo was created successfully.
/// - failure: Sudo creation failed with an error.
public enum CreateSudoResult {
    case success(sudo: Sudo)
    case failure(cause: Error)
}

/// Result returned by API for updating a new Sudo. The API can fail with an
/// error or return the updated Sudo.
///
/// - success: Sudo was updated successfully.
/// - failure: Sudo creation failed with an error.
public enum UpdateSudoResult {
    case success(sudo: Sudo)
    case failure(cause: Error)
}

/// Result returned by API for listing Sudos owned by the signed in user. The
/// API can fail with an error or return the list of Sudos owned by the user. 
///
/// - success: List of Sudos was retrieved successfully.
/// - failure: Sudos retrieval failed with an error.
public enum ListSudosResult {
    case success(sudos: [Sudo])
    case failure(cause: Error)
}

/// Result returned by API for redeem a token to grant additional entitlements.
/// API can fail with an error or return the resulting entitlements.
///
/// - success: Token was redeemeed successfully.
/// - failure: Token redemption failed with an error.
public enum RedeemResult {
    case success(entitlements: [Entitlement])
    case failure(cause: Error)
}

/// Protocol encapsulating a library functions for managing Sudos in the Sudo service.
public protocol SudoProfilesClient: class {

    /// Creates a new Sudo.
    ///
    /// - Parameters:
    ///   - sudo: Sudo to create.
    ///   - completion: The completion handler to invoke to pass the creation result.
    /// - Throws: `SudoProfilesClientError`
    func createSudo(sudo: Sudo, completion: @escaping (CreateSudoResult) -> Void) throws

    /// Update a Sudo.
    ///
    /// - Parameters:
    ///   - sudo: Sudo to update.
    ///   - completion: The completion handler to invoke to pass the update result.
    /// - Throws: `SudoProfilesClientError`
    func updateSudo(sudo: Sudo, completion: @escaping (UpdateSudoResult) -> Void) throws

    /// Deletes a Sudo.
    ///
    /// - Parameters:
    ///   - sudo: Sudo to delete.
    ///   - completion: The completion handler to invoke to pass the deletion result.
    /// - Throws: `SudoProfilesClientError`
    func deleteSudo(sudo: Sudo, completion: @escaping (ApiResult) -> Void) throws

    /// Retrieves all Sudos owned by signed in user.
    ///
    /// - Parameter option: option for controlling the behaviour of this API. Refer to `ListOption` enum.
    /// - Parameter completion: The completion handler to invoke to pass the list result.
    /// - Throws: `SudoProfilesClientError`
    func listSudos(option: ListOption, completion: @escaping (ListSudosResult) -> Void) throws

    /// Redeem a token to be granted additional entitlements.
    ///
    /// - Parameters:
    ///   - token: Token.
    ///   - type: Token type. Currently only valid value is "entitlements" but this maybe extended in future.
    ///   - completion: The completion handler to invoke to pass the resulting entitlements or error.
    func redeem(token: String, type: String, completion: @escaping (RedeemResult) -> Void) throws

    /// Returns the count of outstanding create or update requests.
    ///
    /// - Returns: Outstanding requests count.
    func getOutstandingRequestsCount() -> Int

    /// Resets any cached data.
    ///
    /// - Throws: `SudoProfilesClientError`
    func reset() throws

    /// Subscribes to be notified of new, updated or deleted Sudos. Blob data is not downloaded automatically
    /// so the caller is expected to use `listSudos` API if they need to access any associated blobs.
    ///
    /// - Parameter id: Unique ID to be associated with the subscriber.
    /// - Parameter changeType: Change type to subscribe to.
    /// - Parameter subscriber: Subscriber to notify.
    func subscribe(id: String, changeType: SudoChangeType, subscriber: SudoSubscriber) throws

    /// Subscribes to be notified of new, updated and deleted Sudos. Blob data is not downloaded automatically
    /// so the caller is expected to use `listSudos` API if they need to access any associated blobs.
    ///
    /// - Parameter id: Unique ID to be associated with the subscriber.
    /// - Parameter subscriber: Subscriber to notify.
    func subscribe(id: String, subscriber: SudoSubscriber) throws

    /// Unsubscribes the specified subscriber so that it no longer receivies notifications about
    ///  new, updated or deleted Sudos.
    ///
    /// - Parameter id: Unique ID associated with the subscriber to unsubscribe.
    /// - Parameter changeType: Change type to unsubscribe from.
    func unsubscribe(id: String, changeType: SudoChangeType)

    /// Unsubscribe all subscribers from receiving notifications about new, updated or deleted Sudos.
    func unsubscribeAll()

    /// Retrieves a signed owernship proof for the specified Sudo.
    ///
    /// - Parameters:
    ///   - sudo: Sudo to generate an ownership proof for.
    ///   - audience: Target audience for this proof.
    func getOwnershipProof(sudo: Sudo, audience: String, completion: @escaping (GetOwnershipProofResult) -> Void) throws

}

/// Default implementation of `SudoProfilesClient`.
public class DefaultSudoProfilesClient: SudoProfilesClient {

    public enum CacheType {
        case memory
        case disk
    }

    public struct Config {

        // Configuration namespace.
        struct Namespace {
            static let sudoService = "sudoService"
            static let apiService = "apiService"
            static let identityService = "identityService"
        }

        /// Configuration parameters.
        struct SudoService {
            static let region = "region"
            static let bucket = "bucket"
        }

    }

    private struct Constants {

        static let s3ClientKey = "com.sudoplatform.s3"

    }

    private enum GetSudoResult {
        case success(sudo: Sudo?)
        case failure(cause: Error)
    }

    /// Default logger for the client.
    private let logger: Logger

    /// AWS region hosting directory service.
    private let region: String

    /// S3 bucket used by Sudo service for storing large objects.
    private let s3Bucket: String

    ///`SudoProfilesClient` instance required to issue authentication tokens and perform cryptographic operations.
    private let sudoUserClient: SudoUserClient

    /// GraphQL client for communicating with the Sudo  service.
    private let graphQLClient: AWSAppSyncClient

    /// Wrapper client for S3 access.
    private let s3Client: S3Client

    /// Default query for fetch Sudos.
    private let defaultQuery: ListSudosQuery

    /// Cache for storing large binary objects.
    private let blobCache: BlobCache

    /// Operation queue used for serializing and rate controlling expensive remote API calls.
    private let sudoOperationQueue = SudoOperationQueue()

    /// Subscription manager for Sudo creation events.
    private var onCreateSubscriptionManager = SubscriptionManager<OnCreateSudoSubscription>()

    /// Subscription manager for Sudo update events.
    private var onUpdateSubscriptionManager = SubscriptionManager<OnUpdateSudoSubscription>()

    /// Subscription manager for Sudo deletion events.
    private var onDeleteSubscriptionManager = SubscriptionManager<OnDeleteSudoSubscription>()

    /// Queue for processing API result.
    private let apiResultQueue = DispatchQueue(label: "com.sudoplatform.sudoprofiles.api.result")

    /// Sudo ownership proof issuer.
    private let ownershipProofIssuer: OwnershipProofIssuer

    /// Intializes a new `DefaultSudoProfilesClient` instance.  It uses configuration parameters defined in
    /// `sudoplatformconfig.json` file located in the app bundle.
    ///
    /// - Parameters:
    ///   - sudoUserClient: `SudoUserClient` instance required to issue authentication tokens and perform cryptographic operations.
    ///   - blobContainerURL: Container URL to which large binary objects will be stored.
    ///   - maxSudos: Maximum number of Sudos to cap the queries to. Defaults to 10.
    ///   - logger: A logger to use for logging messages. If none provided then a default internal logger will be used.
    /// - Throws: `SudoProfilesClientError`
    convenience public init(sudoUserClient: SudoUserClient, blobContainerURL: URL, maxSudos: Int = 10) throws {
        guard let configManager = DefaultSudoConfigManager(),
            let identityServiceConfig = configManager.getConfigSet(namespace: Config.Namespace.identityService),
            let apiServiceConfig = configManager.getConfigSet(namespace: Config.Namespace.apiService) else {
            throw SudoProfilesClientError.invalidConfig
        }

        // Use the singleton AppSync client instance if we are using the config file.
        guard let graphQLClient = try ApiClientManager.instance?.getClient(sudoUserClient: sudoUserClient) else {
            throw SudoProfilesClientError.invalidConfig
        }

        try self.init(config: [Config.Namespace.identityService: identityServiceConfig, Config.Namespace.apiService: apiServiceConfig],
                      sudoUserClient: sudoUserClient, blobContainerURL: blobContainerURL, maxSudos: maxSudos, graphQLClient: graphQLClient)
    }

    /// Intializes a new `DefaultSudoProfilesClient` instance with the specified backend configuration.
    ///
    /// - Parameters:
    ///   - config: Configuration parameters for the client.
    ///   - sudoUserClient: `SudoUserClient` instance required to issue authentication tokens and perform cryptographic operations.
    ///   - cacheType: Cache type to use. Please refer to CacheType enum.
    ///   - blobContainerURL: Container URL to which large binary objects will be stored.
    ///   - maxSudos: Maximum number of Sudos to cap the quries to. Defaults to 10.
    ///   - logger: A logger to use for logging messages. If none provided then a default internal logger will be used.
    ///   - graphQLClient: Optional GraphQL client to use. Mainly used for unit testing.
    ///   - s3Client: Optional S3 client to use. Mainly use for unit testing.
    ///   - ownershipProofIssuer: Optional ownership proof issuer to use. Mainly use for testing of various service clients.
    /// - Throws: `SudoProfilesClientError`
    public init(config: [String: Any], sudoUserClient: SudoUserClient, cacheType: CacheType = .disk, blobContainerURL: URL, maxSudos: Int = 10, logger: Logger? = nil, graphQLClient: AWSAppSyncClient? = nil, s3Client: S3Client? = nil, ownershipProofIssuer: OwnershipProofIssuer? = nil) throws {

        #if DEBUG
            AWSDDLog.sharedInstance.logLevel = .verbose
            AWSDDLog.add(AWSDDTTYLogger.sharedInstance)
        #endif

        let logger = logger ?? Logger.sudoProfilesClientLogger
        self.logger = logger
        self.blobCache = try BlobCache(containerURL: blobContainerURL)
        self.sudoUserClient = sudoUserClient
        self.s3Client = s3Client ?? DefaultS3Client(s3ClientKey: Constants.s3ClientKey)
        self.defaultQuery = ListSudosQuery(limit: maxSudos, nextToken: nil)

        guard let sudoServiceConfig = config[Config.Namespace.apiService] as? [String: Any] ?? config[Config.Namespace.sudoService] as? [String: Any],
            let identityServiceConfig = config[Config.Namespace.identityService] as? [String: Any],
            let configProvider = SudoProfilesClientConfigProvider(config: sudoServiceConfig),
            let region = sudoServiceConfig[Config.SudoService.region] as? String,
            let bucket = identityServiceConfig[Config.SudoService.bucket] as? String else {
            throw SudoProfilesClientError.invalidConfig
        }

        self.region = region
        self.s3Bucket = bucket

        if let graphQLClient = graphQLClient {
            self.graphQLClient = graphQLClient
            try self.ownershipProofIssuer = ownershipProofIssuer ?? DefaultOwnershipProofIssuer(graphQLClient: graphQLClient)
        } else {
            let cacheConfiguration: AWSAppSyncCacheConfiguration
            switch cacheType {
            case .memory:
                cacheConfiguration = AWSAppSyncCacheConfiguration.inMemory
            case .disk:
                cacheConfiguration = try AWSAppSyncCacheConfiguration()
            }

            let appSyncConfig = try AWSAppSyncClientConfiguration(appSyncServiceConfig: configProvider,
                                                                  userPoolsAuthProvider: GraphQLAuthProvider(client: self.sudoUserClient),
                                                                  urlSessionConfiguration: URLSessionConfiguration.default,
                                                                  cacheConfiguration: cacheConfiguration,
                                                                  connectionStateChangeHandler: nil,
                                                                  s3ObjectManager: nil,
                                                                  presignedURLClient: nil,
                                                                  retryStrategy: .exponential)
            let graphQLClient = try AWSAppSyncClient(appSyncConfig: appSyncConfig)
            graphQLClient.apolloClient?.cacheKeyForObject = { $0["id"] }
            self.graphQLClient = graphQLClient
            try self.ownershipProofIssuer = ownershipProofIssuer ?? DefaultOwnershipProofIssuer(graphQLClient: graphQLClient)
        }
    }

    public func createSudo(sudo: Sudo, completion: @escaping (CreateSudoResult) -> Void) throws {
        self.logger.info("Creating a Sudo.")

        // Retrieve the federated identity's ID from the identity client. This ID is required
        // to authorize the access to S3 bucket and required to be a part of the S3 key.
        guard let identityId = self.sudoUserClient.getIdentityId() else {
            self.logger.error("Identity ID is missing. The client may not be signed in yet.")
            throw SudoProfilesClientError.notSignedIn
        }

        // First create the Sudo without any claims since we need the Sudo ID to create
        // the blob claims in S3.
        let createSudoOp = CreateSudo(sudoUserClient: self.sudoUserClient, graphQLClient: self.graphQLClient, region: self.region, bucket: self.s3Bucket, identityId: identityId, sudo: Sudo())
        createSudoOp.completionBlock = {
            if let error = createSudoOp.error {
                self.logger.error("Failed create Sudo: \(error)")
                completion(CreateSudoResult.failure(cause: error))
            } else {
                do {
                    // Update the newly created Sudo to add the claims.
                    createSudoOp.sudo.claims = sudo.claims
                    try self.updateSudo(sudo: createSudoOp.sudo) { (result) in
                        switch result {
                        case let .success(sudo):
                            self.logger.info("Sudo created successfully.")
                            completion(CreateSudoResult.success(sudo: sudo))
                        case let .failure(cause):
                            completion(CreateSudoResult.failure(cause: cause))
                        }
                    }
                } catch {
                    completion(CreateSudoResult.failure(cause: error))
                }
            }
        }

        self.sudoOperationQueue.addOperation(createSudoOp)
    }

    public func updateSudo(sudo: Sudo, completion: @escaping (UpdateSudoResult) -> Void) throws {
        self.logger.info("Updating a Sudo.")

        guard let sudoId = sudo.id else {
            self.logger.error("Sudo ID is missing.")
            throw SudoProfilesClientError.invalidInput
        }

        // Retrieve the federated identity's ID from the identity client. This ID is required
        // to authorize the access to S3 bucket and required to be a part of the S3 key.
        guard let identityId = self.sudoUserClient.getIdentityId() else {
            self.logger.error("Identity ID is missing. The client may not be signed in yet.")
            throw SudoProfilesClientError.notSignedIn
        }

        var sudo = sudo
        var operations: [SudoOperation] = []

        // Create upload operations for any blob claims.
        for var claim in sudo.claims {
            switch (claim.visibility, claim.value) {
            case (.private, .blob(let value)):
                do {
                    // Copy the blob into the cache and change the claim value to point
                    // to the cache entry since that's going to be master copy.
                    let cacheEntry = try self.blobCache.replace(fileURL: value, id: "sudo/\(sudoId)/\(claim.name)")
                    claim.value = .blob(cacheEntry.toURL())
                    sudo.updateClaim(claim: claim)
                    operations.append(
                        UploadSecureS3Object(
                            sudoUserClient: self.sudoUserClient,
                            s3Client: self.s3Client,
                            blobCache: self.blobCache,
                            region: self.region,
                            bucket: self.s3Bucket,
                            identityId: identityId,
                            objectId: cacheEntry.id
                        )
                    )
                } catch {
                    self.logger.error("Failed to create blob upload operation: \(error)")
                    return completion(UpdateSudoResult.failure(cause: error))
                }
            default:
                break
            }
        }

        let updateSudoOp = UpdateSudo(sudoUserClient: self.sudoUserClient, graphQLClient: self.graphQLClient, region: self.region, bucket: self.s3Bucket, identityId: identityId, sudo: sudo)
        updateSudoOp.completionBlock = {
            let errors = operations.compactMap { $0.error }
            if let error = errors.first {
                self.logger.error("Failed update Sudo: \(error)")
                completion(UpdateSudoResult.failure(cause: error))
            } else {
                self.logger.info("Sudo updated successfully.")
                completion(UpdateSudoResult.success(sudo: updateSudoOp.sudo))
            }
        }
        operations.append(updateSudoOp)
        self.sudoOperationQueue.addOperations(operations, waitUntilFinished: false)
    }

    public func deleteSudo(sudo: Sudo, completion: @escaping (ApiResult) -> Void) throws {
        self.logger.info("Deleting a Sudo.")

        // Retrieve the federated identity's ID from the identity client. This ID is required
        // to authorize the access to S3 bucket and required to be a part of the S3 key.
        guard let identityId = self.sudoUserClient.getIdentityId() else {
            self.logger.error("Identity ID is missing. The client may not be signed in yet.")
            throw SudoProfilesClientError.notSignedIn
        }

        var operations: [SudoOperation] = []

        // Create delete blob operations for any blob claims.
        for claim in sudo.claims {
            switch claim.value {
            case .blob(let value):
                if let cacheEntry = self.blobCache.get(url: value) {
                    operations.append(
                        DeleteS3Object(
                            s3Client: self.s3Client,
                            blobCache: self.blobCache,
                            region: self.region,
                            bucket: self.s3Bucket,
                            identityId: identityId,
                            objectId: cacheEntry.id
                        )
                    )
                }
            default:
                break
            }
        }

        let deleteSudoOp = DeleteSudo(graphQLClient: self.graphQLClient, sudo: sudo)
        deleteSudoOp.completionBlock = {
            let errors = operations.compactMap { $0.error }
            if let error = errors.first {
                self.logger.error("Failed delete Sudo: \(error)")
                completion(ApiResult.failure(cause: error))
            } else {
                self.logger.info("Sudo deleted succcessfully.")
                completion(ApiResult.success)
            }
        }
        operations.append(deleteSudoOp)

        self.sudoOperationQueue.addOperations(operations, waitUntilFinished: false)
    }

    public func listSudos(option: ListOption, completion: @escaping (ListSudosResult) -> Void) throws {
        self.logger.info("Listing Sudos.")

        let cachePolicy: CachePolicy
        switch option {
        case .cacheOnly:
            cachePolicy = .returnCacheDataDontFetch
        case .remoteOnly:
            cachePolicy = .fetchIgnoringCacheData
        }

        self.graphQLClient.fetch(query: self.defaultQuery, cachePolicy: cachePolicy) { (result, error) in
            if let error = error {
                return completion(ListSudosResult.failure(cause: error))
            }

            guard let result = result else {
                return completion(ListSudosResult.success(sudos: []))
            }

            if let errors = result.errors {
                let message = "listSudos query failed with errors: \(errors)"
                self.logger.error(message)
                return completion(ListSudosResult.failure(cause: SudoProfilesClientError.graphQLError(description: message)))
            }

            guard let items = result.data?.listSudos?.items else {
                return completion(ListSudosResult.failure(cause: SudoProfilesClientError.fatalError(description: "Query result contained no list data.")))
            }

            self.logger.info("Sudos fetched successfully. Processing the result....")

            self.processListSudosResult(items: items, option: option, processS3Objects: true, completion: completion)
        }
    }

    public func redeem(token: String, type: String, completion: @escaping (RedeemResult) -> Void) throws {
        self.logger.info("Redeeming a token for entitlements.")

        let redeemOp = RedeemToken(graphQLClient: self.graphQLClient, token: token, type: type)
        redeemOp.completionBlock = {
           if let error = redeemOp.error {
                self.logger.error("Failed redeem a token for entitlements: \(error)")
                completion(RedeemResult.failure(cause: error))
            } else {
                self.logger.info("Token redeemed succcessfully.")
                completion(RedeemResult.success(entitlements: redeemOp.entitlements))
            }
        }
        self.sudoOperationQueue.addOperations([redeemOp], waitUntilFinished: false)
    }

    public func getOutstandingRequestsCount() -> Int {
        return self.graphQLClient.queuedMutationCount ?? 0
    }

    public func reset() throws {
        self.logger.info("Resetting client state.")

        try self.graphQLClient.clearCaches(options: .init(clearQueries: true, clearMutations: true, clearSubscriptions: true))
        try self.blobCache.reset()
        self.unsubscribeAll()
    }

    public func subscribe(id: String, subscriber: SudoSubscriber) throws {
        try self.subscribe(id: id, changeType: .create, subscriber: subscriber)
        try self.subscribe(id: id, changeType: .delete, subscriber: subscriber)
        try self.subscribe(id: id, changeType: .update, subscriber: subscriber)
    }

    public func subscribe(id: String, changeType: SudoChangeType, subscriber: SudoSubscriber) throws {
        self.logger.info("Subscribing for Sudo change notification.")

        guard let owner = try self.sudoUserClient.getSubject() else {
            throw SudoProfilesClientError.notSignedIn
        }

        switch changeType {
        case .create:
            self.onCreateSubscriptionManager.replaceSubscriber(id: id, subscriber: subscriber)

            guard self.onCreateSubscriptionManager.watcher == nil else {
                // If there's existing AppSync subscription then immediately notify the subscriber
                // that the subscription is already connected.
                subscriber.connectionStatusChanged(state: .connected)
                return
            }

            let createSubscription = OnCreateSudoSubscription(owner: owner)
            self.onCreateSubscriptionManager.watcher = try self.graphQLClient.subscribe(subscription: createSubscription, queue: self.apiResultQueue, statusChangeHandler: { (status) in
                self.onCreateSubscriptionManager.connectionStatusChanged(status: status)
            }, resultHandler: { [weak self] (result, transaction, error) in
                guard let self = self else {
                    return
                }

                if let error = error {
                    self.logger.error("Subscription callback invoked with an error: \(error)")
                    return
                }

                guard let result = result else {
                    self.logger.error("Subscription callback called but result was missing.")
                    return
                }

                guard let response = result.data?.onCreateSudo else {
                    self.logger.error("GraphQL response data was missing.")
                    return
                }

                let item = ListSudosQuery.Data.ListSudo.Item(id: response.id,
                                                             claims: response.claims.map {
                                                                ListSudosQuery.Data.ListSudo.Item.Claim(
                                                                    name: $0.name,
                                                                    version: $0.version,
                                                                    algorithm: $0.algorithm,
                                                                    keyId: $0.keyId,
                                                                    base64Data: $0.base64Data
                                                                )
                    },
                                                             objects: response.objects.map {
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
                                                             metadata: response.metadata.map {
                                                                ListSudosQuery.Data.ListSudo.Item.Metadatum(
                                                                    name: $0.name,
                                                                    value: $0.value
                                                                )
                    },
                                                             createdAtEpochMs: response.createdAtEpochMs,
                                                             updatedAtEpochMs: response.updatedAtEpochMs,
                                                             version: response.version,
                                                             owner: response.owner)

                do {
                    // Update the query cache.
                    let query = ListSudosQuery()
                    try transaction?.update(query: query) { (data: inout ListSudosQuery.Data) in
                        // There shouldn't be duplicate entries but just in case remove existing
                        // entry if found.
                        let newState = data.listSudos?.items?.filter { $0.id != item.id }
                        data.listSudos?.items = newState
                        data.listSudos?.items?.append(item)
                    }
                } catch let error {
                    self.logger.error("Query cache updated failed: \(error)")
                }

                self.processListSudosResult(items: [item], option: .cacheOnly, processS3Objects: false) { (result) in
                    // Notify subscribers.
                    switch result {
                    case let .success(sudos):
                        guard let sudo = sudos.first else {
                            return
                        }

                        self.onCreateSubscriptionManager.sudoChanged(changeType: .create, sudo: sudo)
                    case .failure:
                        break
                    }
                }
            })
        case .update:
            self.onUpdateSubscriptionManager.replaceSubscriber(id: id, subscriber: subscriber)

            guard self.onUpdateSubscriptionManager.watcher == nil else {
                // If there's existing AppSync subscription then immediately notify the subscriber
                // that the subscription is already connected.
                subscriber.connectionStatusChanged(state: .connected)
                return
            }

            let updateSubscription = OnUpdateSudoSubscription(owner: owner)
            self.onUpdateSubscriptionManager.watcher = try self.graphQLClient.subscribe(subscription: updateSubscription, queue: self.apiResultQueue, statusChangeHandler: { (status) in
                self.onUpdateSubscriptionManager.connectionStatusChanged(status: status)
            }, resultHandler: { [weak self] (result, transaction, error) in
                guard let self = self else {
                    return
                }

                if let error = error {
                    self.logger.error("Subscription callback invoked with an error: \(error)")
                    return
                }

                guard let result = result else {
                    self.logger.error("Subscription callback called but result was missing.")
                    return
                }

                guard let response = result.data?.onUpdateSudo else {
                    self.logger.error("GraphQL response data was missing.")
                    return
                }

                let item = ListSudosQuery.Data.ListSudo.Item(id: response.id,
                                                             claims: response.claims.map {
                                                                ListSudosQuery.Data.ListSudo.Item.Claim(
                                                                    name: $0.name,
                                                                    version: $0.version,
                                                                    algorithm: $0.algorithm,
                                                                    keyId: $0.keyId,
                                                                    base64Data: $0.base64Data
                                                                )
                    },
                                                             objects: response.objects.map {
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
                                                             metadata: response.metadata.map {
                                                                ListSudosQuery.Data.ListSudo.Item.Metadatum(
                                                                    name: $0.name,
                                                                    value: $0.value
                                                                )
                    },
                                                             createdAtEpochMs: response.createdAtEpochMs,
                                                             updatedAtEpochMs: response.updatedAtEpochMs,
                                                             version: response.version,
                                                             owner: response.owner)

                do {
                    // Update the query cache.
                    let query = ListSudosQuery()
                    try transaction?.update(query: query) { (data: inout ListSudosQuery.Data) in
                        guard let items = data.listSudos?.items else {
                            return
                        }

                        // Replace the older entry.
                        let newState = items.filter { !($0.id == item.id && $0.updatedAtEpochMs < item.updatedAtEpochMs) }
                        if newState.count < items.count {
                            data.listSudos?.items = newState
                            data.listSudos?.items?.append(item)
                        }
                    }
                } catch let error {
                    self.logger.error("Query cache updated failed: \(error)")
                }

                self.processListSudosResult(items: [item], option: .cacheOnly, processS3Objects: false) { (result) in
                    // Notify subscribers.
                    switch result {
                    case let .success(sudos):
                        guard let sudo = sudos.first else {
                            return
                        }

                        self.onUpdateSubscriptionManager.sudoChanged(changeType: .update, sudo: sudo)
                    case .failure:
                        break
                    }
                }
            })
        case .delete:
            self.onDeleteSubscriptionManager.replaceSubscriber(id: id, subscriber: subscriber)

            guard self.onDeleteSubscriptionManager.watcher == nil else {
                // If there's existing AppSync subscription then immediately notify the subscriber
                // that the subscription is already connected.
                subscriber.connectionStatusChanged(state: .connected)
                return
            }

            let deleteSubscription = OnDeleteSudoSubscription(owner: owner)
            self.onDeleteSubscriptionManager.watcher = try self.graphQLClient.subscribe(subscription: deleteSubscription, queue: self.apiResultQueue, statusChangeHandler: { (status) in
                self.onDeleteSubscriptionManager.connectionStatusChanged(status: status)
            }, resultHandler: { [weak self] (result, transaction, error) in
                guard let self = self else {
                    return
                }

                if let error = error {
                    self.logger.error("Subscription callback invoked with an error: \(error)")
                    return
                }

                guard let result = result else {
                    self.logger.error("Subscription callback called but result was missing.")
                    return
                }

                guard let response = result.data?.onDeleteSudo else {
                    self.logger.error("GraphQL response data was missing.")
                    return
                }

                let item = ListSudosQuery.Data.ListSudo.Item(id: response.id,
                                                             claims: response.claims.map {
                                                                ListSudosQuery.Data.ListSudo.Item.Claim(
                                                                    name: $0.name,
                                                                    version: $0.version,
                                                                    algorithm: $0.algorithm,
                                                                    keyId: $0.keyId,
                                                                    base64Data: $0.base64Data
                                                                )
                    },
                                                             objects: response.objects.map {
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
                                                             metadata: response.metadata.map {
                                                                ListSudosQuery.Data.ListSudo.Item.Metadatum(
                                                                    name: $0.name,
                                                                    value: $0.value
                                                                )
                    },
                                                             createdAtEpochMs: response.createdAtEpochMs,
                                                             updatedAtEpochMs: response.updatedAtEpochMs,
                                                             version: response.version,
                                                             owner: response.owner)

                do {
                    let query = ListSudosQuery()
                    try transaction?.update(query: query) { (data: inout ListSudosQuery.Data) in
                        // Remove the deleted Sudo from the cache.
                        let newState = data.listSudos?.items?.filter { $0.id != item.id }
                        data.listSudos?.items = newState
                    }
                } catch let error {
                    self.logger.error("Query cache updated failed: \(error)")
                }

                self.processListSudosResult(items: [item], option: .cacheOnly, processS3Objects: false) { (result) in
                    // Notify subscribers.
                    switch result {
                    case let .success(sudos):
                        guard let sudo = sudos.first else {
                            return
                        }

                        self.onDeleteSubscriptionManager.sudoChanged(changeType: .delete, sudo: sudo)
                    case .failure:
                        break
                    }
                }
            })
        }
    }

    public func unsubscribe(id: String, changeType: SudoChangeType) {
        self.logger.info("Unsubscribing from Sudo change notification.")

        switch changeType {
        case .create:
            self.onCreateSubscriptionManager.removeSubscriber(id: id)
        case .update:
            self.onUpdateSubscriptionManager.removeSubscriber(id: id)
        case .delete:
            self.onDeleteSubscriptionManager.removeSubscriber(id: id)
        }
    }

    public func unsubscribeAll() {
        self.logger.info("Unsubscribing all subscribers from Sudo change notification.")

        self.onCreateSubscriptionManager.removeAllSubscribers()
        self.onUpdateSubscriptionManager.removeAllSubscribers()
        self.onDeleteSubscriptionManager.removeAllSubscribers()
    }

    public func getOwnershipProof(sudo: Sudo, audience: String, completion: @escaping (GetOwnershipProofResult) -> Void) throws {
        self.logger.info("Retrieving ownership proof.")

        guard let subject = try self.sudoUserClient.getSubject() else {
            throw SudoProfilesClientError.notSignedIn
        }

        guard let sudoId = sudo.id else {
            throw SudoProfilesClientError.invalidInput
        }

        try self.ownershipProofIssuer.getOwnershipProof(ownerId: sudoId, subject: subject, audience: audience, completion: completion)
    }

    private func processSecureClaim(secureClaim: ListSudosQuery.Data.ListSudo.Item.Claim) throws -> Claim {
        guard let algorithm = SymmetricKeyEncryptionAlgorithm(rawValue: secureClaim.algorithm) else {
            self.logger.error("Secure claim encryption algorithm is invalid.")
            throw SudoProfilesClientError.badData
        }

        guard let encryptedData = Data(base64Encoded: secureClaim.base64Data) else {
            self.logger.error("Failed to base64 decode secure claim.")
            throw SudoProfilesClientError.badData
        }

        let decryptedData = try self.sudoUserClient.decrypt(keyId: secureClaim.keyId, algorithm: algorithm, data: encryptedData)

        guard let value = String(data: decryptedData, encoding: .utf8) else {
            self.logger.error("Secure claim value cannot be encoded to String.")
            throw SudoProfilesClientError.badData
        }

        return Claim(name: secureClaim.name, visibility: .private, value: .string(value))
    }

    private func getS3ObjectIdFromKey(key: String) -> String? {
        let components = key.components(separatedBy: "/")
        return components.last
    }

    private func processListSudosResult(items: [ListSudosQuery.Data.ListSudo.Item], option: ListOption, processS3Objects: Bool, completion: @escaping (ListSudosResult) -> Void) {
        var sudos: [Sudo] = []
        var downloadOps: [DownloadSecureS3Object] = []
        for item in items {
            do {
                var sudo = Sudo(id: item.id,
                                version: item.version,
                                createdAt: Date(timeIntervalSince1970: item.createdAtEpochMs / 1000),
                                updatedAt: Date(timeIntervalSince1970: item.updatedAtEpochMs / 1000)
                                )

                for metadata in item.metadata {
                    sudo.metadata[metadata.name] = metadata.value
                }

                // Process secure claims which need to be decrypted using the specified key.
                for secureClaim in item.claims {
                    sudo.updateClaim(claim: try self.processSecureClaim(secureClaim: secureClaim))
                }

                if processS3Objects {
                    // Process secure s3 objects which need to be downloaded from AWS S3 and decrypted
                    // using the specified key.
                    for secureS3Object in item.objects {
                        guard let objectId = self.getS3ObjectIdFromKey(key: secureS3Object.key) else {
                            return completion(ListSudosResult.failure(cause: SudoProfilesClientError.fatalError(description: "Invalid key in SecureS3Object.")))
                        }

                        // Check if we already have the S3 object in the cache. Return the cache entry
                        // if asked to fetch from cache but otherwise download the S3 object.
                        if let cacheEntry = self.blobCache.get(id: objectId),
                            option == ListOption.cacheOnly {
                            sudo.updateClaim(claim: Claim(name: secureS3Object.name, visibility: .private, value: .blob(cacheEntry.toURL())))
                        } else {
                            sudo.updateClaim(claim: Claim(name: secureS3Object.name, visibility: .private, value: .blob(self.blobCache.cacheUrlFromId(id: objectId))))
                            downloadOps.append(
                                DownloadSecureS3Object(
                                    sudoUserClient: self.sudoUserClient,
                                    s3Client: self.s3Client,
                                    blobCache: self.blobCache,
                                    bucket: secureS3Object.bucket,
                                    key: secureS3Object.key,
                                    algorithm: secureS3Object.algorithm,
                                    keyId: secureS3Object.keyId,
                                    objectId: objectId
                                )
                            )
                        }
                    }
                }

                sudos.append(sudo)
            } catch {
                self.logger.error("Failed to process secure claims: \(error)")
                return completion(ListSudosResult.failure(cause: error))
            }
        }

        if downloadOps.isEmpty {
            self.logger.info("ListSudos result processed successfully.")
            completion(ListSudosResult.success(sudos: sudos))
        } else {
            downloadOps.last?.completionBlock = {
                let errors = downloadOps.compactMap { $0.error }
                if let error = errors.first {
                    self.logger.error("Failed to process ListSudos result: \(error)")
                    completion(ListSudosResult.failure(cause: error))
                } else {
                    self.logger.info("ListSudos result processed successfully.")
                    completion(ListSudosResult.success(sudos: sudos))
                }
            }

            self.sudoOperationQueue.addOperations(downloadOps, waitUntilFinished: false)
        }
    }

}
