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
    public struct FieldDSPData: Equatable {
        public var string: ByteBuffer
        public var parameter: [NIOIMAP.FieldParameterPair]

        public init(string: ByteBuffer, parameter: [NIOIMAP.FieldParameterPair]) {
            self.string = string
            self.parameter = parameter
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeBodyFieldDSP(_ dsp: BodyStructure.FieldDSPData?) -> Int {
        guard let dsp = dsp else {
            return self.writeNil()
        }

        return
            self.writeString("(") +
            self.writeIMAPString(dsp.string) +
            self.writeSpace() +
            self.writeBodyFieldParameters(dsp.parameter) +
            self.writeString(")")
    }
}
