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

extension NIOIMAP.BodyStructure {
    /// IMAPv4 `body-fields`
    public struct Fields: Equatable {
        public var parameter: [NIOIMAP.FieldParameterPair]
        public var id: NIOIMAP.NString
        public var description: NIOIMAP.NString
        public var encoding: Encoding
        public var octets: Int

        /// Convenience function for a better experience when chaining multiple types.
        public static func parameter(_ parameters: [NIOIMAP.FieldParameterPair], id: NIOIMAP.NString, description: NIOIMAP.NString, encoding: Encoding, octets: Int) -> Self {
            Self(parameter: parameters, id: id, description: description, encoding: encoding, octets: octets)
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeBodyFields(_ fields: NIOIMAP.BodyStructure.Fields) -> Int {
        self.writeBodyFieldParameters(fields.parameter) +
            self.writeSpace() +
            self.writeNString(fields.id) +
            self.writeSpace() +
            self.writeNString(fields.description) +
            self.writeSpace() +
            self.writeBodyEncoding(fields.encoding) +
            self.writeString(" \(fields.octets)")
    }
}
