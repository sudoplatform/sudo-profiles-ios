//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoApiClient

/// `SudoModel` conforming instances are returned by operations performed by the SudoRepository. 
///
/// Each GraphQL query, mutation and subscription returns a different codegen Sudo entity.  These entities are
/// conformed to this `SudoModel` protocol to reduce the duplication of transformation logic.
protocol SudoModel {

    associatedtype Claim: GraphQLClaim
    associatedtype Object: GraphQLObject
    associatedtype Metadatum: GraphQLMetadatum

    var id: String { get }
    var claims: [Claim] { get }
    var objects: [Object] { get }
    var metadata: [Metadatum] { get }
    var createdAtEpochMs: Double { get }
    var updatedAtEpochMs: Double { get }
    var version: Int { get }
}

protocol GraphQLClaim {
    var name: String { get }
    var version: Int { get }
    var algorithm: String { get }
    var keyId: String { get }
    var base64Data: String { get }
}

protocol GraphQLObject {
    var name: String { get }
    var version: Int { get }
    var algorithm: String { get }
    var keyId: String { get }
    var bucket: String { get }
    var region: String { get }
    var key: String { get }
}

protocol GraphQLMetadatum {
    var name: String { get }
    var value: String { get }
}

protocol GraphQLSubscriptionResult: GraphQLSelectionSet {
    var sudo: (any SudoModel)? { get }
}

extension CreateSudoMutation.Data.CreateSudo: SudoModel {}
extension CreateSudoMutation.Data.CreateSudo.Claim: GraphQLClaim {}
extension CreateSudoMutation.Data.CreateSudo.Object: GraphQLObject {}
extension CreateSudoMutation.Data.CreateSudo.Metadatum: GraphQLMetadatum {}

extension UpdateSudoMutation.Data.UpdateSudo: SudoModel {}
extension UpdateSudoMutation.Data.UpdateSudo.Claim: GraphQLClaim {}
extension UpdateSudoMutation.Data.UpdateSudo.Object: GraphQLObject {}
extension UpdateSudoMutation.Data.UpdateSudo.Metadatum: GraphQLMetadatum {}

extension DeleteSudoMutation.Data.DeleteSudo: SudoModel {}
extension DeleteSudoMutation.Data.DeleteSudo.Claim: GraphQLClaim {}
extension DeleteSudoMutation.Data.DeleteSudo.Object: GraphQLObject {}
extension DeleteSudoMutation.Data.DeleteSudo.Metadatum: GraphQLMetadatum {}

extension ListSudosQuery.Data.ListSudo.Item: SudoModel {}
extension ListSudosQuery.Data.ListSudo.Item.Claim: GraphQLClaim {}
extension ListSudosQuery.Data.ListSudo.Item.Object: GraphQLObject {}
extension ListSudosQuery.Data.ListSudo.Item.Metadatum: GraphQLMetadatum {}

extension GetSudoQuery.Data.GetSudo: SudoModel {}
extension GetSudoQuery.Data.GetSudo.Claim: GraphQLClaim {}
extension GetSudoQuery.Data.GetSudo.Object: GraphQLObject {}
extension GetSudoQuery.Data.GetSudo.Metadatum: GraphQLMetadatum {}

extension OnCreateSudoSubscription.Data.OnCreateSudo: SudoModel {}
extension OnCreateSudoSubscription.Data.OnCreateSudo.Claim: GraphQLClaim {}
extension OnCreateSudoSubscription.Data.OnCreateSudo.Object: GraphQLObject {}
extension OnCreateSudoSubscription.Data.OnCreateSudo.Metadatum: GraphQLMetadatum {}
extension OnCreateSudoSubscription.Data: GraphQLSubscriptionResult {
    var sudo: (any SudoModel)? { onCreateSudo }
}

extension OnUpdateSudoSubscription.Data.OnUpdateSudo: SudoModel {}
extension OnUpdateSudoSubscription.Data.OnUpdateSudo.Claim: GraphQLClaim {}
extension OnUpdateSudoSubscription.Data.OnUpdateSudo.Object: GraphQLObject {}
extension OnUpdateSudoSubscription.Data.OnUpdateSudo.Metadatum: GraphQLMetadatum {}
extension OnUpdateSudoSubscription.Data: GraphQLSubscriptionResult {
    var sudo: (any SudoModel)? { onUpdateSudo }
}

extension OnDeleteSudoSubscription.Data.OnDeleteSudo: SudoModel {}
extension OnDeleteSudoSubscription.Data.OnDeleteSudo.Claim: GraphQLClaim {}
extension OnDeleteSudoSubscription.Data.OnDeleteSudo.Object: GraphQLObject {}
extension OnDeleteSudoSubscription.Data.OnDeleteSudo.Metadatum: GraphQLMetadatum {}
extension OnDeleteSudoSubscription.Data: GraphQLSubscriptionResult {
    var sudo: (any SudoModel)? { onDeleteSudo }
}
