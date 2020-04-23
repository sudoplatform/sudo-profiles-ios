//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3
import SudoUser
import SudoLogging

/// Dowloads an encrypted blob from AWS S3.
class DownloadSecureS3Object: SudoOperation {

    private unowned let sudoUserClient: SudoUserClient
    private unowned let s3Client: S3Client
    private unowned let blobCache: BlobCache

    private let bucket: String
    private let key: String
    private let algorithm: String
    private let keyId: String
    private let objectId: String

    /// Initializes an operation to download an encrypted blob from AWS S3.
    ///
    /// - Parameters:
    ///   - sudoUserClient: `SudoUserClient` to use for decryption.
    ///   - s3Client: S3 client to use for interacting with AWS S3.
    ///   - blobCache: Local blob cache.
    ///   - logger: Logger to use for logging.
    ///   - bucket: Name of S3 bucket storing the blob.
    ///   - key: S3 key associated with the blob.
    ///   - algorithm: Decryption algorithm used for decrypting the blob.
    ///   - keyId: ID of the decryption key used for decrypting the blob.
    ///   - objectId: Unique ID to be associated with the blob.
    init(sudoUserClient: SudoUserClient,
         s3Client: S3Client,
         blobCache: BlobCache,
         logger: Logger = Logger.sudoProfilesClientLogger,
         bucket: String,
         key: String,
         algorithm: String,
         keyId: String,
         objectId: String) {
        self.sudoUserClient = sudoUserClient
        self.s3Client = s3Client
        self.blobCache = blobCache
        self.bucket = bucket
        self.key = key
        self.keyId = keyId
        self.algorithm = algorithm
        self.objectId = objectId

        super.init(logger: logger)
    }

    override func execute() {
        guard let algorithm = SymmetricKeyEncryptionAlgorithm(rawValue: self.algorithm) else {
            self.logger.error("Invalid encryption algorithm specified.")
            self.error = SudoOperationError.preconditionFailure
            return self.done()
        }

        do {
            self.logger.info("Downloading encrypted blob from S3. bucket: \(self.bucket)")
            try self.s3Client.download(bucket: self.bucket, key: self.key) { (result) in
                defer {
                    self.done()
                }

                switch result {
                case let .success(data):
                    self.logger.info("Encrypted blob downloaded successfully.")

                    do {
                        // Decrypt the downloaded blob and store it in the local cache.
                        let decryptedData = try self.sudoUserClient.decrypt(keyId: self.keyId, algorithm: algorithm, data: data)
                        try _ = self.blobCache.replace(data: decryptedData, id: self.objectId)
                    } catch {
                        self.logger.error("Failed to decrypt the encrypted blob: \(error)")
                        self.error = error
                    }
                case let .failure(cause):
                    self.logger.error("Failed to download the encrypted blob: \(cause)")
                    self.error = cause
                }
            }
        } catch {
            self.logger.error("Failed to download the encrypted blob: \(error)")
            self.error = error
            self.done()
        }
    }

}
