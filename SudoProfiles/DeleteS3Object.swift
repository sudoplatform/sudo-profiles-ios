//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3
import SudoLogging

// Operation to delete a blob stored in AWS S3.
class DeleteS3Object: SudoOperation {

    private unowned let s3Client: S3Client
    private unowned let blobCache: BlobCache

    private let region: String
    private let bucket: String
    private let identityId: String
    private let objectId: String

    /// Initializes an operation to delete a blob from AWS S3.
    ///
    /// - Parameters:
    ///   - s3Client: S3 client to use for interacting with AWS S3.
    ///   - blobCache: Local blob cache.
    ///   - logger: Logger to use for logging.
    ///   - bucket: Name of S3 bucket storing the blob.
    ///   - identityId: ID of identity owning the S3 object.
    ///   - objectId: Unique ID associated with the blob.
    init(s3Client: S3Client,
         blobCache: BlobCache,
         logger: Logger = Logger.sudoProfilesClientLogger,
         region: String,
         bucket: String,
         identityId: String,
         objectId: String) {
        self.s3Client = s3Client
        self.blobCache = blobCache
        self.region = region
        self.bucket = bucket
        self.identityId = identityId
        self.objectId = objectId

        super.init(logger: logger)
    }

    override func execute() {
        do {
            try self.s3Client.delete(bucket: self.bucket, key: "\(self.identityId)/\(self.objectId)") { (result) in
                defer {
                    self.done()
                }

                switch result {
                case .success:
                    self.logger.info("Blob deleted successfully from S3.")

                    // Remove the blob from the local cache as well.
                    do {
                        try self.blobCache.remove(id: self.objectId)
                    } catch {
                        self.logger.error("Failed to remove the blob from the local cache.")
                        self.error = error
                    }
                case let .failure(cause):
                    self.logger.error("Failed to delete the blob from S3: \(cause)")
                    self.error = cause
                }
            }
        } catch {
            self.logger.error("Failed to delete the blob from S3: \(error)")
            self.error = error
            self.done()
        }
    }

}
