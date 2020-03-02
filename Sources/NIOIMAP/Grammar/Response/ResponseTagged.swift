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

    /// IMAPv4 `response-tagged`
    struct ResponseTagged: Equatable {
        var tag: Tag
        var state: ResponseConditionalState
    }
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeResponseTagged(_ response: NIOIMAP.ResponseTagged) -> Int {
        self.writeString("\(response.tag) ") +
        self.writeResponseConditionalState(response.state) +
        self.writeString("\r\n")
    }

}
