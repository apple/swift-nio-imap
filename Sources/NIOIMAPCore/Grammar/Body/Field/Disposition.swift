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

extension BodyStructure {
    /// IMAPv4 `body-fld-dsp`
    public struct Disposition: Equatable {
        public var string: String
        public var parameter: [ParameterPair]

        public init(string: String, parameter: [ParameterPair]) {
            self.string = string
            self.parameter = parameter
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyFieldDisposition(_ dsp: BodyStructure.Disposition?) -> Int {
        guard let dsp = dsp else {
            return self.writeNil()
        }

        return
            self.writeString("(") +
            self.writeIMAPString(dsp.string) +
            self.writeSpace() +
            self.writeBodyParameterPairs(dsp.parameter) +
            self.writeString(")")
    }
}
