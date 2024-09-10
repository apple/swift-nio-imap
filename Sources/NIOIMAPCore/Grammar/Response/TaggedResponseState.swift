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

extension TaggedResponse {
    /// Tagged status responses
    ///
    /// The tagged versions in RFC 3501 section 7.1
    public enum State: Hashable, Sendable {
        /// The command executed successfully.
        case ok(ResponseText)

        /// The command was valid, but the server rejected it.
        case no(ResponseText)

        /// The command was likely invalid.
        case bad(ResponseText)

        init?(code: String, responseText: ResponseText) {
            switch code.lowercased() {
            case "ok": self = .ok(responseText)
            case "no": self = .no(responseText)
            case "bad": self = .bad(responseText)
            default: return nil
            }
        }
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
