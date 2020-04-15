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

    @discardableResult mutating func writeMessageAttributes(_ atts: [IMAPCore.MessageAttributeType]) -> Int {
        return self.writeArray(atts) { (element, self) in
            return self.writeMessageAttributeType(element)
        }
    }
    
    @discardableResult mutating func writeMessageAttributeType(_ type: IMAPCore.MessageAttributeType) -> Int {
        switch type {
        case .dynamic(let att):
            return self.writeMessageAttributeDynamic(att)
        case .static(let att):
            return self.writeMessageAttributeStatic(att)
        }
    }

}
