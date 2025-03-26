//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import AWSS3StoragePlugin
import Foundation
import SudoLogging

/// Default S3 client implementation.
class DefaultS3Client: S3Client {

    // MARK: - Properties

    let storagePlugin: AWSS3StoragePlugin

    // MARK: - Lifecycle

    /// Initializes a `DefaultS3Client`.
    /// - Parameters:
    ///   - region: The AWS region.
    ///   - bucket: The S3 storage bucket.
    init(region: String, bucket: String) throws {
        let storageConfig: [String: String] = [
            "region": region,
            "bucket": bucket,
            "defaultAccessLevel": "private"
        ]
        let config = JSONValue.object(storageConfig.mapValues(JSONValue.string))
        storagePlugin = AWSS3StoragePlugin()
        try storagePlugin.configure(using: config)
    }

    // MARK: - Conformance: S3Client

    func upload(data: Data, contentType: String, key: String) async throws {
        do {
            let options = StorageUploadDataOperation.Request.Options(contentType: contentType)
            let uploadTask = storagePlugin.uploadData(key: key, data: data, options: options)
            _ = try await uploadTask.value
        } catch {
            throw SudoProfilesClientError.fromStorageError(error: error)
        }
    }

    func download(key: String) async throws -> Data {
        do {
            let downloadTask = storagePlugin.downloadData(key: key, options: nil)
            return try await downloadTask.value
        } catch {
            throw SudoProfilesClientError.fromStorageError(error: error)
        }
    }

    func delete(key: String) async throws {
        do {
            try await storagePlugin.remove(key: key, options: nil)
        } catch {
            throw SudoProfilesClientError.fromStorageError(error: error)
        }
    }

    func reset() async {
        await storagePlugin.reset()
    }
}
