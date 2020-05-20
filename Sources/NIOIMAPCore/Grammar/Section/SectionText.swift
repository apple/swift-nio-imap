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

/// IMAPv4 `section-text`
public enum SectionText: Equatable {
    case mime
    case header
    case headerFields(_ fields: [String])
    case notHeaderFields(_ fields: [String])
    case text
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSectionText(_ text: SectionText) -> Int {
        switch text {
        case .mime:
            return self.writeString("MIME")
        case .header:
            return self.writeString("HEADER")
        case .headerFields(let list):
            return
                self.writeString("HEADER.FIELDS ") +
                self.writeHeaderList(list)
        case .notHeaderFields(let list):
            return
                self.writeString("HEADER.FIELDS.NOT ") +
                self.writeHeaderList(list)
        case .text:
            return self.writeString("TEXT")
        }
    }
}
