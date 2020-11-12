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

/// Untagged status responses
///
/// The untagged versions in RFC 3501 section 7.1
public enum UntaggedStatus: Equatable {
    case ok(ResponseText)
    case no(ResponseText)
    case bad(ResponseText)
    case preauth(ResponseText)
    case bye(ResponseText)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUntaggedStatus(_ cond: UntaggedStatus) -> Int {
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
        case .preauth(let text):
            return
                self.writeString("PREAUTH ") +
                self.writeResponseText(text)
        case .bye(let text):
            return
                self.writeString("BYE ") +
                self.writeResponseText(text)
        }
    }
}
