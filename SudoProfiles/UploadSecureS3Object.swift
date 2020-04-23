//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3
import SudoUser
import SudoLogging

/// Uploads an encrypted blob to AWS S3.
class UploadSecureS3Object: SudoOperation {

    struct Constants {
        static let contentType = "binary/octet-stream"
    }

    private unowned let sudoUserClient: SudoUserClient
    private unowned let s3Client: S3Client
    private unowned let blobCache: BlobCache

    private let region: String
    private let bucket: String
    private let identityId: String
    private let objectId: String

    /// Initializes an operation to upload an encrypted blob to AWS S3.
    ///
    /// - Parameters:
    ///   - sudoUserClient: `SudoUserClient` to use for encryption.
    ///   - s3Client: S3 client to use for interacting with AWS S3.
    ///   - blobCache: Local blob cache.
    ///   - logger: Logger to use for logging.
    ///   - region: AWS region hosting the S3 bucket to store the blob.
    ///   - bucket: Name of S3 bucket to store the blob.
    ///   - identityId: ID of identity to own the S3 object.
    ///   - objectId: Unique ID to be associated with the upload blob.
    init(sudoUserClient: SudoUserClient,
         s3Client: S3Client,
         blobCache: BlobCache,
         logger: Logger = Logger.sudoProfilesClientLogger,
         region: String,
         bucket: String,
         identityId: String,
         objectId: String) {
        self.sudoUserClient = sudoUserClient
        self.s3Client = s3Client
        self.blobCache = blobCache
        self.region = region
        self.bucket = bucket
        self.identityId = identityId
        self.objectId = objectId
        super.init(logger: logger)
    }

    override func execute() {
        // Retrieve the symmetric key ID required for encryption.
        let keyId: String
        do {
            keyId = try self.sudoUserClient.getSymmetricKeyId()
        } catch {
            self.logger.error("Failed to retrieve symmetric key: \(error)")
            self.error = SudoOperationError.preconditionFailure
            return self.done()
        }

        // Check that the S3 object to upload has been saved to the cache.
        guard let cacheEntry = self.blobCache.get(id: objectId) else {
            self.logger.error("Cannot find the S3 object to upload in the cache.")
            self.error = SudoOperationError.preconditionFailure
            return self.done()
        }

        let encryptedS3Data: Data
        do {
            // Load the data from the cache and encrypt it.
            let data = try cacheEntry.load()
            encryptedS3Data = try self.sudoUserClient.encrypt(keyId: keyId, algorithm: .aesCBCPKCS7Padding, data: data)
        } catch {
            self.error = error
            return self.done()
        }

        do {
            // Upload the encrypted blob to S3. S3 key must be prefixed with the signed in user's federeated identity
            // ID in order for the fine grained authorization to pass.
            self.logger.info("Uploading encrypted blob to S3 bucket: \(self.bucket)")
            try self.s3Client.upload(data: encryptedS3Data, contentType: Constants.contentType, bucket: self.bucket, key: "\(self.identityId)/\(self.objectId)") { (result) in
                defer {
                    self.done()
                }

                switch result {
                case .success:
                    self.logger.info("Encrypted blob uploaded successfully.")
                case let .failure(cause):
                    self.logger.error("Failed to upload the encrypted blob: \(cause)")
                    self.error = cause
                }
            }
        } catch {
            self.logger.error("Failed to upload the encrypted blob: \(error)")
            self.error = error
            self.done()
        }
    }

    override func done() {
        // If there was an error uploading to S3 then remove the cache entry.
        if self.error != nil {
            do {
                try self.blobCache.remove(id: objectId)
            } catch {
                self.logger.error("Failed to remove cache entry \(objectId): \(error)")
            }
        }
        super.done()
    }

}
