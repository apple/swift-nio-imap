//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

extension NIOIMAP {
    
    /// IMAPv4 `response-done`
    public enum ResponseDone: Equatable {
        case tagged(ResponseTagged)
        case fatal(ResponseText)
    }
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeResponseDone(_ response: NIOIMAP.ResponseDone) -> Int {
        switch response {
        case .tagged(let tagged):
            return self.writeResponseTagged(tagged)
        case .fatal(let fatal):
            return self.writeResponseFatal(fatal)
        }
    }

}
