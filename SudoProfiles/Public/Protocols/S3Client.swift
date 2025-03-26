//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// S3 client wrapper protocol mainly used for providing an abstraction layer on top of
/// AWS S3 SDK.
public protocol S3Client: AnyObject {

    /// Uploads a blob to AWS S3.
    /// - Parameters:
    ///   - data: Blob to upload.
    ///   - contentType: Content type of the blob.
    ///   - key: S3 key to be associated with the blob.
    /// - Throws: `S3ClientError`
    func upload(data: Data, contentType: String, key: String) async throws

    /// Downloads a blob from AWS S3.
    /// - Parameter key: S3 key associated with the blob.
    /// - Returns: The data in the bucket
    /// - Throws: `S3ClientError`
    func download(key: String) async throws -> Data

    /// Deletes a blob stored AWS S3.
    /// - Parameter key: S3 key associated with the blob.
    /// - Throws: `S3ClientError`
    func delete(key: String) async throws
    
    /// Will reset the S3Client and cancel any jobs in progress.
    func reset() async
}
