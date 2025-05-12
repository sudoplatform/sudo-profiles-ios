//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Combine
import Foundation
import SudoLogging
import SudoUser
import SudoConfigManager
import SudoApiClient

/// Default implementation of `SudoProfilesClient`.
public class DefaultSudoProfilesClient: SudoProfilesClient, SudoRepositoryDelegate {

    // MARK: - Types

    typealias UnencryptedClaim = (name: String, value: String)
    typealias UnencryptedBlob = (name: String, dataReference: DataReference)
    typealias UploadedBlob = (object: SecureS3ObjectInput, unencryptedData: Data)

    // MARK: - Supplementary

    struct Constants {
        static let defaultKeyNamespace = "ss"
        static let contentType = "binary/octet-stream"
        static let sudosCacheKey = "sudosCacheKey"
    }

    // MARK: - Properties

    /// `SudoProfilesClient` instance required to issue authentication tokens and perform cryptographic operations.
    let sudoUserClient: SudoUserClient

    /// `CryptoProvider` instance used for cryptographic operations.
    let cryptoProvider: CryptoProvider

    /// Utility for performing GraphQL mutations, queries and subscriptions.
    let sudoRepository: SudoRepository

    /// Provides thread-safe access to a list of the current subscribers.
    let subscriberStore: SubscriberStore

    /// Sudo ownership proof issuer.
    let ownershipProofIssuer: OwnershipProofIssuer

    /// Wrapper client for S3 access.
    let s3Client: S3Client

    /// Caches an array of Sudo objects which are returned when calling `listSudos(cachePolicy: .cacheOnly)`.
    let sudosCache: (any CodableCache<[Sudo]>)?

    /// Cache for storing large binary objects.
    let blobCache: (any CodableCache<Data>)?

    /// Default logger for the client.
    let logger: Logger

    // MARK: - Lifecycle

    /// Initializes a new `DefaultSudoProfilesClient` instance.
    /// - Parameters:
    ///   - config: Configuration parameters used to instantiate the client.  Leave `nil` for a default to be provided.
    ///   - sudoUserClient: `SudoUserClient` instance required to issue authentication tokens and perform cryptographic operations.
    ///   - logger: The logging instance to use in the client.  Leave `nil` for a default to be provided.
    /// - Throws: `SudoProfilesClientError`
    convenience public init(config: SudoProfilesClientConfig? = nil, sudoUserClient: SudoUserClient, logger: Logger? = nil) throws {
        let clientConfig = try config ?? SudoProfilesClientConfig()
        let loggerInstance = logger ?? Logger.sudoProfilesClientLogger
        guard let graphQLClient = try SudoApiClientManager.instance?.getClient(sudoUserClient: sudoUserClient) else {
            throw SudoProfilesClientError.invalidConfig
        }
        let sudoRepository = DefaultSudoRepository(
            listSudosQueryLimit: clientConfig.maxSudos,
            graphQLClient: graphQLClient,
            logger: loggerInstance
        )
        let subscriberStore = SubscriberStore()
        let s3Client = try DefaultS3Client(region: clientConfig.sudoServiceConfig.region, bucket: clientConfig.sudoServiceConfig.bucket)
        let ownershipProofIssuer = DefaultOwnershipProofIssuer(graphQLClient: graphQLClient, logger: loggerInstance)
        let cryptoProvider = DefaultCryptoProvider(keyNamespace: Constants.defaultKeyNamespace)
        if (try cryptoProvider.getSymmetricKeyId()) == nil {
            _ = try cryptoProvider.generateEncryptionKey()
        }
        let sudosCache: (any CodableCache<[Sudo]>)?
        switch clientConfig.sudosCacheType {
        case .diskCache(let config):
            sudosCache = try DiskCache(name: config.name, protectionType: config.protectionType)
        case .noCache:
            sudosCache = nil
        }
        let blobCache: (any CodableCache<Data>)?
        switch clientConfig.blobCacheType {
        case .diskCache(let config):
            blobCache = try DiskCache(name: config.name, protectionType: config.protectionType)
        case .noCache:
            blobCache = nil
        }
        self.init(
            config: clientConfig,
            sudoUserClient: sudoUserClient,
            sudoRepository: sudoRepository,
            subscriberStore: subscriberStore,
            ownershipProofIssuer: ownershipProofIssuer,
            cryptoProvider: cryptoProvider,
            s3Client: s3Client,
            sudosCache: sudosCache,
            blobCache: blobCache,
            logger: loggerInstance
        )
        sudoRepository.delegate = self
    }

    // MARK: - Lifecycle: Internal

    init(
        config: SudoProfilesClientConfig,
        sudoUserClient: SudoUserClient,
        sudoRepository: SudoRepository,
        subscriberStore: SubscriberStore,
        ownershipProofIssuer: OwnershipProofIssuer,
        cryptoProvider: CryptoProvider,
        s3Client: S3Client,
        sudosCache: (any CodableCache<[Sudo]>)?,
        blobCache: (any CodableCache<Data>)?,
        logger: Logger
    ) {
        self.config = config
        self.sudoUserClient = sudoUserClient
        self.sudoRepository = sudoRepository
        self.subscriberStore = subscriberStore
        self.ownershipProofIssuer = ownershipProofIssuer
        self.cryptoProvider = cryptoProvider
        self.s3Client = s3Client
        self.sudosCache = sudosCache
        self.blobCache = blobCache
        self.logger = logger
    }

    // MARK: - Conformance: SudoProfilesClient - CRUD

    public let config: SudoProfilesClientConfig

    public func createSudo(input: SudoCreateInput) async throws -> Sudo {
        // First create the Sudo without any claims since we need the Sudo ID to create
        // the blob claims in S3.
        let createdSudo = try await sudoRepository.createSudo()
        let updateInput = SudoTransformer.transformCreateInput(input, sudoId: createdSudo.id, version: createdSudo.version)
        let updatedSudo = try await updateSudo(createdSudo, input: updateInput)
        return updatedSudo
    }

    public func updateSudo(input: SudoUpdateInput) async throws -> Sudo {
        let sudo = try await sudoRepository.getSudo(withId: input.sudoId)
        let updatedSudo = try await updateSudo(sudo, input: input)
        return updatedSudo
    }

    public func deleteSudo(input: SudoDeleteInput) async throws {
        let deletedSudo = try await sudoRepository.deleteSudo(withId: input.sudoId, version: input.version)
        let blobClaimNames = deletedSudo.objects.map(\.name)
        removeCachedBlobs(withNames: blobClaimNames, sudoId: input.sudoId)
        updateSudosCache(withChange: .delete, toSudo: deletedSudo)
        logger.info("Sudo deleted successfully.")
    }

    public func listSudos(cachePolicy: CachePolicy) async throws -> [Sudo] {
        switch cachePolicy {
        case .cacheOnly:
            guard let sudosCache else {
                logger.error("Attempted to fetch Sudos from cache but cache is not configured.")
                throw SudoProfilesClientError.invalidInput
            }
            let cachedSudos: [Sudo]
            do {
                cachedSudos = try sudosCache.object(forKey: Constants.sudosCacheKey)
            } catch CodableCacheError.notFound {
                throw SudoProfilesClientError.notFound
            } catch {
                throw SudoProfilesClientError.fatalError(description: "Failed to fetch Sudos from cache: \(error.localizedDescription)")
            }
            return cachedSudos.sorted()

        case .remoteOnly:
            let graphQLSudos = try await sudoRepository.listSudos()
            logger.info("Sudos fetched successfully. Processing the result....")
            let remoteSudos: [Sudo]
            do {
                remoteSudos = try graphQLSudos.map { try SudoTransformer.transformGraphQLSudo($0, cryptoProvider: cryptoProvider) }
            } catch {
                logger.error("Failed to process list sudos result \(error)")
                throw error
            }
            if let sudosCache {
                do {
                    try sudosCache.setObject(remoteSudos, forKey: Constants.sudosCacheKey)
                } catch {
                    logger.error("Failed to update Sudos cache with fetched Sudos: \(error.localizedDescription)")
                }
            }
            removeCachedBlobs(supersededBy: graphQLSudos)
            return remoteSudos.sorted()
        }
    }

    public func getBlob(forClaim claim: Claim, cachePolicy: CachePolicy) async throws -> Data {
        guard case .blob(let key) = claim.value else {
            throw SudoProfilesClientError.invalidInput
        }
        let blobCacheKey = getBlobCacheKey(sudoId: claim.sudoId, objectName: claim.name)
        switch cachePolicy {
        case .cacheOnly:
            guard let blobCache else {
                logger.error("Attempted to fetch blob from cache but cache is not configured.")
                throw SudoProfilesClientError.invalidInput
            }
            let data: Data
            do {
                data = try blobCache.object(forKey: blobCacheKey)
            } catch CodableCacheError.notFound {
                throw SudoProfilesClientError.notFound
            } catch {
                throw SudoProfilesClientError.fatalError(description: "Failed to fetch blob from cache: \(error.localizedDescription)")
            }
            return data

        case .remoteOnly:
            let data: Data
            do {
                logger.info("Downloading encrypted blob from S3. key: \(key)")
                data = try await s3Client.download(key: key)
                logger.info("Encrypted blob downloaded successfully.")
            } catch {
                logger.error("Failed to download the encrypted blob: \(error)")
                throw error
            }
            let decryptedData: Data
            do {
                decryptedData = try cryptoProvider.decrypt(keyId: claim.keyId, algorithm: claim.algorithm, data: data)
            } catch {
                logger.error("Failed to decrypt the encrypted blob: \(error)")
                throw error
            }
            if let blobCache {
                do {
                    try blobCache.setObject(decryptedData, forKey: blobCacheKey)
                } catch {
                    logger.error("Failed to update cache for downloaded blob claim with name: \(claim.name)")
                }
            }
            return decryptedData
        }
    }

    public func clearCache() throws {
        do {
            try blobCache?.removeAll()
        } catch {
            logger.error("Failed to clear objects from blob cache: \(error.localizedDescription)")
            throw SudoProfilesClientError.fatalError(description: "Failed to clear blob cache: \(error.localizedDescription)")
        }
        do {
            try sudosCache?.removeAll()
        } catch {
            logger.error("Failed to clear objects from Sudos cache: \(error.localizedDescription)")
            throw SudoProfilesClientError.fatalError(description: "Failed to clear Sudos cache: \(error.localizedDescription)")
        }
    }

    public func reset() async throws {
        logger.info("Resetting client state.")
        unsubscribeAll()
        try clearCache()
        do {
            try cryptoProvider.reset()
        } catch {
            logger.error("Failed to reset crypto provider: \(error.localizedDescription)")
            throw SudoProfilesClientError.fatalError(description: "Failed to reset crypto provider: \(error.localizedDescription)")
        }
    }

    // MARK: - Conformance: SudoProfilesClient - Subscriptions

    public func subscribe(id: String, changeTypes: [SudoChangeType], subscriber: SudoSubscriber) async throws {
        guard !changeTypes.isEmpty else {
            throw SudoProfilesClientError.invalidInput
        }
        guard let owner = try await sudoUserClient.getSubject() else {
            throw SudoProfilesClientError.notSignedIn
        }
        subscriberStore.replaceSubscriber(id: id, changeTypes: Set(changeTypes), subscriber: subscriber)
        let connectedChangeTypes = changeTypes.filter {
            sudoRepository.subscribe(changeType: $0, owner: owner)
        }
        DispatchQueue.main.async {
            for connectedChangeType in connectedChangeTypes {
                subscriber.connectionStatusChanged(changeType: connectedChangeType, state: .connected)
            }
        }
    }

    public func unsubscribe(id: String, changeTypes: [SudoChangeType]) {
        for changeType in changeTypes {
            if subscriberStore.removeSubscriber(id: id, changeType: changeType).isEmpty {
                sudoRepository.unsubscribe(changeType: changeType)
            }
        }
    }

    public func unsubscribeAll() {
        subscriberStore.removeAllSubscribers()
        sudoRepository.unsubscribeAll()
    }

    // MARK: - Conformance: SudoProfilesClient - Crypto

    public func getOwnershipProof(sudo: Sudo, audience: String) async throws -> String {
        try await getOwnershipProof(sudoId: sudo.id, audience: audience)
    }

    public func getOwnershipProof(sudoId: String, audience: String) async throws -> String {
        logger.info("Retrieving ownership proof.")
        guard let subject = try await sudoUserClient.getSubject() else {
            throw SudoProfilesClientError.notSignedIn
        }
        return try await ownershipProofIssuer.getOwnershipProof(ownerId: sudoId, subject: subject, audience: audience)
    }

    public func generateEncryptionKey() throws -> String {
        try cryptoProvider.generateEncryptionKey()
    }

    public func getSymmetricKeyId() throws -> String? {
        try cryptoProvider.getSymmetricKeyId()
    }

    public func importEncryptionKeys(keys: [EncryptionKey], currentKeyId: String) throws {
        try cryptoProvider.importEncryptionKeys(keys: keys, currentKeyId: currentKeyId)
    }

    public func exportEncryptionKeys() throws -> [EncryptionKey] {
        try cryptoProvider.exportEncryptionKeys()
    }

    // MARK: - Conformance: SudoRepositoryDelegate

    func sudoRepository(_ repository: any SudoRepository, didReceiveEvent changeType: SudoChangeType, forSudo sudo: any SudoModel) {
        updateSudosCache(withChange: changeType, toSudo: sudo)
        updateBlobCache(withChange: changeType, toSudo: sudo)
        notifySubscribers(of: changeType, to: sudo)
    }

    func sudoRepository(
        _ repository: any SudoRepository,
        connectionStateChanged connectionState: GraphQLClientConnectionState,
        forChangeType changeType: SudoChangeType
    ) {
        switch connectionState {
        case .connected:
            let subscribers = subscriberStore.getSubscribers(forChangeType: changeType)
            DispatchQueue.main.async {
                for subscriber in subscribers {
                    subscriber.connectionStatusChanged(changeType: changeType, state: .connected)
                }
            }
        case .disconnected:
            let subscribers = subscriberStore.getSubscribers(forChangeType: changeType)
            subscriberStore.removeSubscribers(forChangeType: changeType)
            DispatchQueue.main.async {
                for subscriber in subscribers {
                    subscriber.connectionStatusChanged(changeType: changeType, state: .disconnected)
                }
            }
        case .connecting:
            return
        }
    }

    // MARK: - Helpers: Updates

    func updateSudo(_ sudo: any SudoModel, input: SudoUpdateInput) async throws -> Sudo {
        logger.info("Updating a Sudo.")
        guard sudo.version == input.version else {
            throw SudoProfilesClientError.versionMismatch
        }
        let blobClaims: [UnencryptedBlob] = input.updatedClaims.compactMap { updatedClaim in
            guard case .blob(let dataReference) = updatedClaim.value else {
                return nil
            }
            return (updatedClaim.name, dataReference)
        }
        let stringClaims: [UnencryptedClaim] = input.updatedClaims.compactMap { updatedClaim in
            guard case .string(let stringValue) = updatedClaim.value else {
                return nil
            }
            return (updatedClaim.name, stringValue)
        }
        guard let keyId = try cryptoProvider.getSymmetricKeyId() else {
            throw SudoProfilesClientError.fatalError(description: "Symmetric key missing.")
        }
        let updatedClaims = try encryptStringClaims(stringClaims, sudoId: sudo.id, keyId: keyId)
        let uploadedBlobs = try await uploadBlobClaims(blobClaims, sudoId: sudo.id, keyId: keyId)
        let updateInput = SudoTransformer.transformUpdateInput(
            input,
            sudo: sudo,
            claims: updatedClaims,
            objects: uploadedBlobs.map(\.object)
        )
        let updatedGraphQLSudo = try await sudoRepository.updateSudo(input: updateInput)

        let deletedBlobClaimNames = input.updatedClaims.filter { $0.isBlob && $0.value == nil }.map(\.name)
        removeCachedBlobs(withNames: deletedBlobClaimNames, sudoId: input.sudoId)
        setCachedBlobs(uploadedBlobs, forSudo: updatedGraphQLSudo)
        updateSudosCache(withChange: .update, toSudo: updatedGraphQLSudo)

        let updatedSudo = try SudoTransformer.transformGraphQLSudo(updatedGraphQLSudo, cryptoProvider: cryptoProvider)
        logger.info("Sudo updated successfully.")
        return updatedSudo
    }

    func encryptStringClaims(_ claims: [UnencryptedClaim], sudoId: String, keyId: String) throws -> [SecureClaimInput] {
        try claims.map { name, value in
            guard let data = value.data(using: .utf8) else {
                throw SudoProfilesClientError.badData
            }
            let encrypted = try cryptoProvider.encrypt(
                keyId: keyId,
                algorithm: SymmetricKeyEncryptionAlgorithm.aesCBCPKCS7Padding,
                data: data
            )
            return SecureClaimInput(
                name: name,
                version: 1,
                algorithm: SymmetricKeyEncryptionAlgorithm.aesCBCPKCS7Padding.rawValue,
                keyId: keyId,
                base64Data: encrypted.base64EncodedString()
            )
        }
    }

    // MARK: - Helpers: Uploading

    func uploadBlobClaims(_ objects: [UnencryptedBlob], sudoId: String, keyId: String) async throws -> [UploadedBlob] {
        // Retrieve the federated identity's ID from the identity client. This ID is required
        // to authorize the access to S3 bucket and required to be a part of the S3 key.
        guard let identityId = try? await sudoUserClient.getIdentityId() else {
            logger.error("Identity ID is missing. The client may not be signed in yet.")
            throw SudoProfilesClientError.notSignedIn
        }
        return try await withThrowingTaskGroup(of: UploadedBlob.self) { taskGroup in
            for object in objects {
                taskGroup.addTask {
                    try await self.uploadBlobClaim(object, sudoId: sudoId, identityId: identityId, keyId: keyId)
                }
            }
            var uploadedBlobs: [UploadedBlob] = []
            for try await result in taskGroup {
                uploadedBlobs.append(result)
            }
            return uploadedBlobs
        }
    }

    func uploadBlobClaim(
        _ object: UnencryptedBlob,
        sudoId: String,
        identityId: String,
        keyId: String
    ) async throws -> UploadedBlob {
        let data: Data
        do {
            data = try object.dataReference.loadData()
        } catch {
            throw SudoProfilesClientError.fatalError(description: "Failed to load blob data from disk: \(error.localizedDescription)")
        }
        let encryptedData: Data
        do {
            encryptedData = try cryptoProvider.encrypt(keyId: keyId, algorithm: .aesCBCPKCS7Padding, data: data)
        } catch {
            throw SudoProfilesClientError.fatalError(description: "Failed to encrypt data for upload: \(error.localizedDescription)")
        }
        try Task.checkCancellation()
        do {
            // Upload the encrypted blob to S3. S3 key must be prefixed with the signed in user's federated identity
            // ID in order for the fine grained authorization to pass.
            let key = "\(identityId)/sudo/\(sudoId)/\(object.name)"
            logger.info("Uploading encrypted blob to S3 bucket: \(config.sudoServiceConfig.bucket), key: \(key)")
            try await s3Client.upload(data: encryptedData, contentType: Constants.contentType, key: key)
            logger.debug("successfully uploaded encrypted blob to key: \(key)")
            let uploadedObject = SecureS3ObjectInput(
                name: object.name,
                version: 1,
                algorithm: SymmetricKeyEncryptionAlgorithm.aesCBCPKCS7Padding.rawValue,
                keyId: keyId,
                bucket: config.sudoServiceConfig.bucket,
                region: config.sudoServiceConfig.region,
                key: key
            )
            return (uploadedObject, data)
        } catch {
            logger.error("Failed to upload the encrypted blob: \(error)")
            throw SudoProfilesClientError.requestFailed(response: nil, cause: error)
        }
    }

    // MARK: - Helpers: Caching

    func getBlobCacheKey(sudoId: String, objectName: String) -> String {
        "sudo/\(sudoId)/\(objectName)"
    }

    func getCachedSudo(withId id: String, version: Int) -> Sudo? {
        guard
            let sudosCache,
            let cachedSudos = try? sudosCache.object(forKey: Constants.sudosCacheKey),
            let cachedSudo = cachedSudos.first(where: { $0.id == id && $0.version == version })
        else {
            return nil
        }
        return cachedSudo
    }

    func updateSudosCache(withChange changeType: SudoChangeType, toSudo sudo: any SudoModel) {
        guard let sudosCache else {
            return
        }
        do {
            try sudosCache.updateObject(forKey: Constants.sudosCacheKey) { cacheEntry in
                var cachedSudos = cacheEntry?.object ?? []
                switch changeType {
                case .create, .update:
                    if let existingSudo = cachedSudos.first(where: { $0.id == sudo.id }) {
                        guard sudo.version > existingSudo.version else {
                            return .oldValue
                        }
                        cachedSudos.removeAll(where: { $0.id == sudo.id })
                    }
                    do {
                        let sudo = try SudoTransformer.transformGraphQLSudo(sudo, cryptoProvider: cryptoProvider)
                        cachedSudos.append(sudo)
                    } catch {
                        logger.error("Failed to transform Sudo to update cache after subscription event: \(error.localizedDescription)")
                        return .oldValue
                    }
                case .delete:
                    guard cachedSudos.contains(where: { $0.id == sudo.id }) else {
                        return .oldValue
                    }
                    cachedSudos.removeAll(where: { $0.id == sudo.id })
                }
                return .newValue(CodableCacheEntry(object: cachedSudos))
            }
        } catch {
            logger.error("Failed to update cache after subscription event: \(error.localizedDescription)")
        }
    }

    func updateBlobCache(withChange changeType: SudoChangeType, toSudo sudo: any SudoModel) {
        switch changeType {
        case .create:
            break
        case .update:
            removeCachedBlobs(supersededBy: [sudo])
        case .delete:
            removeCachedBlobs(withNames: sudo.objects.map(\.name), sudoId: sudo.id)
        }
    }

    func removeCachedBlobs(withNames names: [String], sudoId: String) {
        guard let blobCache else {
            return
        }
        for name in names {
            do {
                let blobCacheKey = getBlobCacheKey(sudoId: sudoId, objectName: name)
                try blobCache.removeObject(forKey: blobCacheKey)
            } catch {
                logger.error("Failed to remove blob from cache: \(error.localizedDescription)")
            }
        }
    }

    func removeCachedBlobs(supersededBy sudos: [any SudoModel]) {
        guard let blobCache else {
            return
        }
        for sudo in sudos {
            for blobClaim in sudo.objects {
                do {
                    let key = getBlobCacheKey(sudoId: sudo.id, objectName: blobClaim.name)
                    try blobCache.removeObject(forKey: key, withVersionLessThan: blobClaim.version)
                } catch {
                    logger.error("Failed to remove superseded blob from cache: \(error.localizedDescription)")
                }
            }
        }
    }

    func setCachedBlobs(_ uploadedBlobs: [UploadedBlob], forSudo sudo: any SudoModel) {
        guard let blobCache else {
            return
        }
        for object in sudo.objects {
            if let uploadedBlob = uploadedBlobs.first(where: { $0.object.name == object.name }) {
                do {
                    let blobCacheKey = getBlobCacheKey(sudoId: sudo.id, objectName: uploadedBlob.object.name)
                    try blobCache.setObject(uploadedBlob.unencryptedData, forKey: blobCacheKey, version: object.version)
                } catch {
                    logger.error("Failed to update blob cache: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helpers: Subscriptions

    func notifySubscribers(of changeType: SudoChangeType, to sudo: any SudoModel) {
        let subscribers = subscriberStore.getSubscribers(forChangeType: changeType)
        guard !subscribers.isEmpty else {
            return
        }
        do {
            let sudo = try SudoTransformer.transformGraphQLSudo(sudo, cryptoProvider: cryptoProvider)
            DispatchQueue.main.async {
                for subscriber in subscribers {
                    subscriber.sudoChanged(changeType: changeType, sudo: sudo)
                }
            }
        } catch {
            logger.error("Failed to transform Sudo to send subscription event: \(error.localizedDescription)")
        }
    }
}
