//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Protocol encapsulating APIs for issuing ownership proofs.
/// These APIs are used by other Sudo platform clients and any
/// app developed using this SDK is not expected to use these
/// APIs directly.
public protocol OwnershipProofIssuer: AnyObject {

    /// Retrieves a signed owernship proof for the specified owner. The owership
    /// proof JWT has the follow payload.
    ///
    /// {
    ///  "jti": "DBEEF4EB-F84A-4AB7-A45E-02B05B93F5A3",
    ///  "owner": "cd73a478-23bd-4c70-8c2b-1403e2085845",
    ///  "iss": "sudoplatform.sudoservice",
    ///  "aud": "sudoplatform.virtualcardservice",
    ///  "exp": 1578986266,
    ///  "sub": "da17f346-cf49-4db4-98c2-862f85515fc4",
    ///  "iat": 1578982666
    /// }
    ///
    /// "owner" is an unique ID of an identity managed by the issuing service. In
    /// case of Sudo service this represents unique reference to a Sudo.
    /// "sub" is the subject to which this proof is issued to i.e. the user.
    /// "aud" is the target audience of the proof.
    ///
    /// - Parameters:
    ///   - ownerId: Owner ID.
    ///   - subject: Subject to which the proof is issued to.
    ///   - audience: Target audience for this proof.
    /// - Returns: JSON Web Token representing Sudo ownership proof
    func getOwnershipProof(ownerId: String, subject: String, audience: String) async throws -> String
}
