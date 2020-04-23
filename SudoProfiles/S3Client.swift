//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoLogging
import AWSS3

/// List of possible errors thrown by `S3Client` implementation.
///
/// - fatalError: Indicates that a fatal error occurred. This could be due to coding error, out-of-memory
///     condition or other conditions that is beyond control of `S3Client` implementation.
public enum S3ClientError: Error, Hashable {
    case fatalError(description: String)
}

/// Result of downloading a blob from AWS S3.
///
/// - success: Download completed successfully.
/// - failure: Download failed with an error.
public enum S3DownloadResult {
    case success(data: Data)
    case failure(cause: Error)
}

/// Result of uploading a blob to AWS S3.
///
/// - success: Upload completed successfully.
/// - failure: Upload failed with an error.
public enum S3UploadResult {
    case success
    case failure(cause: Error)
}

/// Result of calling an AWS S3 administration API.
///
/// - success: API call completed successfully.
/// - failure: API call failed with an error.
public enum S3ApiResult {
    case success
    case failure(cause: Error)
}

/// S3 client wrapper protocol mainly used for providing an abstraction layer on top of
/// AWS S3 SDK.
public protocol S3Client: class {

    /// Uploads a blob to AWS S3.
    ///
    /// - Parameters:
    ///   - data: Blob to upload.
    ///   - contentType: Content type of the blob.
    ///   - bucket: Name of S3 bucket to store the blob.
    ///   - key: S3 key to be associated with the blob.
    ///   - completion: Completion handler to invoke to pass upload result.
    /// - Throws: `S3ClientError`
    func upload(data: Data, contentType: String, bucket: String, key: String, completion: @escaping (S3UploadResult) -> Void) throws

    /// Downloads a blob from AWS S3.
    ///
    /// - Parameters:
    ///   - bucket: Name of S3 bucket to storing the blob.
    ///   - key: S3 key associated with the blob.
    ///   - completion: Completion handler to invoke to pass download result.
    /// - Throws: `S3ClientError`
    func download(bucket: String, key: String, completion: @escaping (S3DownloadResult) -> Void) throws

    /// Deletes a blob stored AWS S3.
    ///
    /// - Parameters:
    ///   - bucket: Name of S3 bucket to storing the blob.
    ///   - key: S3 key associated with the blob.
    ///   - completion: Completion handler to invoke to pass deletion result.
    /// - Throws: `S3ClientError`
    func delete(bucket: String, key: String, completion: @escaping (S3ApiResult) -> Void) throws

}

/// Default S3 client implementation.
class DefaultS3Client: S3Client {

    private let s3ClientKey: String

    /// Initializes a `DefaultS3Client`.
    ///
    /// - Parameters:
    ///   - s3ClientKey: Key used for locating AWS S3 SDK clients in the shared service registry.
    init(s3ClientKey: String) {
        self.s3ClientKey = s3ClientKey
    }

    func upload(data: Data, contentType: String, bucket: String, key: String, completion: @escaping (S3UploadResult) -> Void) throws {
        guard let s3Client = AWSS3TransferUtility.s3TransferUtility(forKey: self.s3ClientKey) else {
            throw S3ClientError.fatalError(description: "Cannot find S3 client registered with key: \(self.s3ClientKey).")
        }

        s3Client.uploadData(
            data,
            bucket: bucket,
            key: key,
            contentType: contentType,
            expression: nil,
            completionHandler: { (_, error) -> Void in
                if let error = error {
                    completion(.failure(cause: error))
                } else {
                    completion(.success)
                }
        }).continueWith { (task) -> AnyObject? in
            if let error = task.error {
                completion(.failure(cause: error))
            }
            return nil
        }
    }

    func download(bucket: String, key: String, completion: @escaping (S3DownloadResult) -> Void) throws {
        guard let s3Client = AWSS3TransferUtility.s3TransferUtility(forKey: self.s3ClientKey) else {
            throw S3ClientError.fatalError(description: "Cannot find S3 client registered with key: \(self.s3ClientKey).")
        }

        s3Client.downloadData(
            fromBucket: bucket,
            key: key,
            expression: nil,
            completionHandler: { (_, _, data, error) -> Void in
                if let error = error {
                    return completion(.failure(cause: error))
                }

                guard let data = data else {
                    return completion(.failure(cause: S3ClientError.fatalError(description: "S3 download completed successfully but no data was found.")))
                }

                completion(.success(data: data))
        }).continueWith { (task) -> AnyObject? in
            if let error = task.error {
                completion(.failure(cause: error))
            }

            return nil
        }
    }

    func delete(bucket: String, key: String, completion: @escaping (S3ApiResult) -> Void) throws {
        let s3Client = AWSS3.s3(forKey: self.s3ClientKey)

        guard let deleteRequest = AWSS3DeleteObjectRequest() else {
            return completion(.failure(cause: S3ClientError.fatalError(description: "Failed to create a request to delete a S3 object.")))
        }

        deleteRequest.bucket = bucket
        deleteRequest.key = key
        s3Client.deleteObject(deleteRequest).continueWith { (task: AWSTask) -> AnyObject? in
            if let error = task.error {
                completion(.failure(cause: error))
            } else {
                completion(.success)
            }

            return nil
        }
    }

}
