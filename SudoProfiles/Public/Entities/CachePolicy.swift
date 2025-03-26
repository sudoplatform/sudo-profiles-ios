//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Cache policy that determines how data is accessed when fetching Sudos and downloading blob claims.
public enum CachePolicy {

    /// Use the device cached data.
    case cacheOnly

    /// Query and use the data on the server.
    case remoteOnly
}
