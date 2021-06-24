//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3
import SudoLogging

// Operation to delete a blob stored in S3 blob cache.
class DeleteS3Object: SudoOperation {

    private unowned let blobCache: BlobCache

    private let objectId: String

    /// Initializes an operation to delete a blob from S3 blob cache.
    ///
    /// - Parameters:
    ///   - blobCache: Local blob cache.
    ///   - logger: Logger to use for logging.
    ///   - objectId: Unique ID associated with the blob.
    init(blobCache: BlobCache,
         logger: Logger = Logger.sudoProfilesClientLogger,
         objectId: String) {
        self.blobCache = blobCache
        self.objectId = objectId

        super.init(logger: logger)
    }

    override func execute() {
        do {
            try self.blobCache.remove(id: self.objectId)
        } catch {
            self.logger.error("Failed to remove the blob from the local cache.")
            self.error = error
        }

        self.done()
    }

}
