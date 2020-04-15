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

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeSection(_ section: NIOIMAP.SectionSpec?) -> Int {
        self.writeString("[") +
        self.writeIfExists(section) { (spec) -> Int in
            self.writeSectionSpec(spec)
        } +
        self.writeString("]")
    }
    
    @discardableResult mutating func writeSectionSpec(_ spec: NIOIMAP.SectionSpec?) -> Int {
        
        guard let spec = spec else {
            return 0 // do nothing
        }
        
        switch spec {
        case .text(let text):
            return self.writeSectionMessageText(text)
        case .part(let part, text: let text):
            return
                self.writeSectionPart(part) +
                self.writeIfExists(text) { (text) -> Int in
                    self.writeString(".") +
                    self.writeSectionText(text)
                }
        }
    }
}
