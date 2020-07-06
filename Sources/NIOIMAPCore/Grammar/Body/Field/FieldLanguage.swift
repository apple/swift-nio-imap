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

extension BodyStructure {}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyFieldLanguages(_ languages: [String]) -> Int {
        guard languages.count > 0 else {
            return self.writeNil()
        }

        return self.writeArray(languages) { (element, self) in
            self.writeIMAPString(element)
        }
    }
}
