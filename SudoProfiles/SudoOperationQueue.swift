//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoLogging

/// Custom operation queue used for Sudo operations. Mainly used to
/// ensure serial execution and to record useful debugging information.
class SudoOperationQueue: OperationQueue {

    override init() {
        super.init()
        self.qualityOfService = .default
        self.maxConcurrentOperationCount = 1
    }

    override func addOperation(_ op: Operation) {
        if let sudoOp = op as? SudoOperation {
            sudoOp.queuedTime = Date()
        }

        super.addOperation(op)
    }

    override func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool) {
        for op in ops {
            if let sudoOp = op as? SudoOperation {
                sudoOp.queuedTime = Date()
            }
        }
        super.addOperations(ops, waitUntilFinished: wait)
    }

}
