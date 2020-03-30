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

extension NIOIMAP.Body {

    /// IMAPv4 `body-fields`
    public struct Fields: Equatable {
        public var parameter: FieldParameter
        public var id: FieldID
        public var description: FieldDescription
        public var encoding: FieldEncoding
        public var octets: Int

        /// Convenience function for a better experience when chaining multiple types.
        public static func parameter(_ parameters: FieldParameter, id: FieldID, description: FieldDescription, encoding: FieldEncoding, octets: Int) -> Self {
            return Self(parameter: parameters, id: id, description: description, encoding: encoding, octets: octets)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyFields(_ fields: NIOIMAP.Body.Fields) -> Int {
        self.writeBodyFieldParameter(fields.parameter) +
        self.writeSpace() +
        self.writeNString(fields.id) +
        self.writeSpace() +
        self.writeNString(fields.description) +
        self.writeSpace() +
        self.writeBodyFieldEncoding(fields.encoding) +
        self.writeString(" \(fields.octets)")
    }

}
