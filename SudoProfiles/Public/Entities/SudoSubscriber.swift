//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Sudo change type.
///
/// - create: Sudo creation.
/// - update: Sudo update.
/// - delete: Sudo delete.
public enum SudoChangeType: Equatable, CaseIterable {
    case create
    case update
    case delete
}

/// Connection state of the subscription.
///
/// - connected: Connected and receiving updates.
/// - disconnected: Disconnected and won't receive any updates. When disconnected all subscribers will be
///     unsubscribed so the consumer must re-subscribe.
public enum SubscriptionConnectionState: Equatable {
    case connected
    case disconnected
}

/// Subscriber for receiving notifications about new, updated or deleted Sudo.
public protocol SudoSubscriber: AnyObject {

    /// Notifies the subscriber of a new, updated or deleted Sudo.
    /// - Parameters:
    ///   - changeType: Change type. Please refer to `SudoChangeType`.
    ///   - sudo: New, updated or deleted Sudo.
    func sudoChanged(changeType: SudoChangeType, sudo: Sudo)

    /// Notifies the subscriber that the subscription connection state has changed for the specified change type.
    /// The subscriber won't be notified of Sudo changes until the connection status changes to `connected`.
    /// The subscriber will stop receiving Sudo change notifications when the connection state changes to `disconnected`.
    /// - Parameters:
    ///   - changeType: Change type. Please refer to `SudoChangeType`.
    ///   - state: Connection state.
    func connectionStatusChanged(changeType: SudoChangeType, state: SubscriptionConnectionState)
}
