//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoConfigManager

/// Configuration for the Sudo Profiles Client, defining caching strategies and service parameters.
public struct SudoProfilesClientConfig: Equatable {

    // MARK: - Supplementary
    
    /// Default values to use on initialization.
    public enum Default {
        public static let sudosCacheType: CacheType = .diskCache(DiskCacheConfig(name: "sudoProfilesClientSudosCache"))
        public static let blobCacheType: CacheType = .diskCache(DiskCacheConfig(name: "sudoProfilesClientBlobCache"))
        public static let maxSudos = 10
    }

    /// Constants used for configuration key names.
    enum Constants {
        static let sudoService = "sudoService"
        static let identityService = "identityService"
        static let region = "region"
        static let bucket = "bucket"
    }

    /// Represents different types of caches that can be initialized to store Sudos or blob claim data.
    public enum CacheType: Equatable {
        /// A disk-based cache with configurable storage properties.
        case diskCache(DiskCacheConfig)
        /// No caching.
        case noCache
    }

    /// Configuration for a disk-based cache.
    public struct DiskCacheConfig: Equatable {

        /// The name of the disk storage folder within the caches directory.
        public let name: String

        /// Data protection level for encrypting files on disk.
        public let protectionType: FileProtectionType?

        /// Initializes a disk cache configuration.
        /// - Parameters:
        ///   - name: The name of the cache folder.
        ///   - protectionType: The file protection type.
        public init(name: String, protectionType: FileProtectionType? = nil) {
            self.name = name
            self.protectionType = protectionType
        }
    }

    /// Configuration for the Sudo service, specifying the region and storage bucket.
    public struct SudoServiceConfig: Equatable {

        /// The AWS region where the service is hosted.
        public let region: String

        /// The S3 bucket used for storing claim data.
        public let bucket: String

        /// Initializes a Sudo service configuration.
        /// - Parameters:
        ///   - region: The AWS region.
        ///   - bucket: The storage bucket.
        public init(region: String, bucket: String) {
            self.region = region
            self.bucket = bucket
        }
    }

    // MARK: - Properties

    /// The maximum number of Sudos that can be stored.
    public let maxSudos: Int

    /// The caching strategy for Sudo objects.
    public let sudosCacheType: CacheType

    /// The caching strategy for blob claim data.
    public let blobCacheType: CacheType

    /// The configuration for the Sudo service.
    public let sudoServiceConfig: SudoServiceConfig

    // MARK: - Lifecycle

    /// Initializes a Sudo Profiles Client configuration.
    /// - Parameters:
    ///   - maxSudos: The maximum number of Sudos (default: 10).
    ///   - sudosCacheType: The caching strategy for Sudos (default: disk cache).
    ///   - blobCacheType: The caching strategy for blobs (default: disk cache).
    ///   - sudoServiceConfig: The Sudo service configuration.
    public init(
        maxSudos: Int = Default.maxSudos,
        sudosCacheType: CacheType = Default.sudosCacheType,
        blobCacheType: CacheType = Default.blobCacheType,
        sudoServiceConfig: SudoServiceConfig
    ) {
        self.maxSudos = maxSudos
        self.sudosCacheType = sudosCacheType
        self.blobCacheType = blobCacheType
        self.sudoServiceConfig = sudoServiceConfig
    }

    /// Initializes a Sudo Profiles Client configuration using values from the default configuration manager.
    /// - Parameters:
    ///   - maxSudos: The maximum number of Sudos (default: 10).
    ///   - sudosCacheType: The caching strategy for Sudos (default: hybrid memory/disk cache).
    ///   - blobCacheType: The caching strategy for blobs (default: disk cache).
    /// - Throws: `SudoProfilesClientError.invalidConfig` or `sudoServiceConfigNotFound`
    /// if the configuration is invalid or missing.
    public init(
        maxSudos: Int = Default.maxSudos,
        sudosCacheType: CacheType = Default.sudosCacheType,
        blobCacheType: CacheType = Default.blobCacheType
    ) throws {
        let defaultConfigManagerName = SudoConfigManagerFactory.Constants.defaultConfigManagerName
        guard
            let configManager = SudoConfigManagerFactory.instance.getConfigManager(name: defaultConfigManagerName),
            let idServiceConfig = configManager.getConfigSet(namespace: Constants.identityService)
        else {
            throw SudoProfilesClientError.invalidConfig
        }
        guard let sudoServiceConfig = configManager.getConfigSet(namespace: Constants.sudoService) else {
            throw SudoProfilesClientError.sudoServiceConfigNotFound
        }
        guard
            let region = sudoServiceConfig[Constants.region] as? String,
            let bucket = sudoServiceConfig[Constants.bucket] as? String ?? idServiceConfig[Constants.bucket] as? String
        else {
            throw SudoProfilesClientError.invalidConfig
        }
        let serviceConfig = SudoServiceConfig(region: region, bucket: bucket)
        self.init(maxSudos: maxSudos, sudosCacheType: sudosCacheType, blobCacheType: blobCacheType, sudoServiceConfig: serviceConfig)
    }
}
