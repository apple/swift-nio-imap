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
    /// IMAPv4 `body-fields`
    public struct Fields: Equatable {
        public var parameter: [BodyStructure.ParameterPair]
        public var id: NString
        public var description: NString
        public var encoding: Encoding
        public var octetCount: Int

        public init(parameter: [BodyStructure.ParameterPair], id: NString, description: NString, encoding: BodyStructure.Encoding, octetCount: Int) {
            self.parameter = parameter
            self.id = id
            self.description = description
            self.encoding = encoding
            self.octetCount = octetCount
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyFields(_ fields: BodyStructure.Fields) -> Int {
        self.writeBodyParameterPairs(fields.parameter) +
            self.writeSpace() +
            self.writeNString(fields.id) +
            self.writeSpace() +
            self.writeNString(fields.description) +
            self.writeSpace() +
            self.writeBodyEncoding(fields.encoding) +
            self.writeString(" \(fields.octetCount)")
    }
}
