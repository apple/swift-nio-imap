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
import IMAPCore

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult public mutating func writeSectionMessageText(_ text: IMAPCore.SectionMessageText) -> Int {
        switch text {
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
