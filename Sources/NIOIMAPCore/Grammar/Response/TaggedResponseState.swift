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

import struct NIO.ByteBuffer

/// Tagged status responses
///
/// The tagged versions in RFC 3501 section 7.1
extension TaggedResponse {
    /// IMAPv4 `resp-cond-state`
    public enum State: Equatable {
        case ok(ResponseText)
        case no(ResponseText)
        case bad(ResponseText)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeTaggedResponseState(_ cond: TaggedResponse.State) -> Int {
        switch cond {
        case .ok(let text):
            return
                self.writeString("OK ") +
                self.writeResponseText(text)
        case .no(let text):
            return
                self.writeString("NO ") +
                self.writeResponseText(text)
        case .bad(let text):
            return
                self.writeString("BAD ") +
                self.writeResponseText(text)
        }
    }
}
