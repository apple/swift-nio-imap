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
    public struct FieldDispositionLanguage: Equatable {
        public var fieldDisposition: FieldDispositionData?
        public var fieldLanguage: FieldLanguageLocation?

        public init(fieldDisposition: FieldDispositionData? = nil, fieldLanguage: FieldLanguageLocation? = nil) {
            self.fieldDisposition = fieldDisposition
            self.fieldLanguage = fieldLanguage
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyFieldDispositionLanguage(_ desc: BodyStructure.FieldDispositionLanguage) -> Int {
        self.writeSpace() +
            self.writeBodyFieldDSP(desc.fieldDisposition)
    }
}
