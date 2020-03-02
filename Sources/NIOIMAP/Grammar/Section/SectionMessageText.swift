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
    
    /// IMAPv4 `section-msgtext`
    public enum SectionMessageText: Equatable {
        case header
        case headerFields(_ fields: HeaderList)
        case notHeaderFields(_ fields: HeaderList)
        case text
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeSectionMessageText(_ text: NIOIMAP.SectionMessageText) -> Int {
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
