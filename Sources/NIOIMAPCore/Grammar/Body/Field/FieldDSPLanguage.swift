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
    /// Extracted from IMAPv4 `body-ext-`1part
    public struct FieldDSPLanguage: Equatable {
        public var fieldDSP: FieldDSPData?
        public var fieldLanguage: FieldLanguageLocation?

        public init(fieldDSP: BodyStructure.FieldDSPData? = nil, fieldLanguage: BodyStructure.FieldLanguageLocation? = nil) {
            self.fieldDSP = fieldDSP
            self.fieldLanguage = fieldLanguage
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyFieldDSPLanguage(_ desc: BodyStructure.FieldDSPLanguage) -> Int {
        self.writeSpace() +
            self.writeBodyFieldDSP(desc.fieldDSP)
    }
}
