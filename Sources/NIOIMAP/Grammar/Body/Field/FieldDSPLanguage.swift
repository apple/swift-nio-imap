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

    /// Extracted from IMAPv4 `body-ext-`1part
    public struct FieldDSPLanguage: Equatable {
        public var fieldDSP: FieldDSP
        public var fieldLanguage: FieldLanguageLocation?
        
        public static func fieldDSP(_ fieldDSP: FieldDSP, fieldLanguage: FieldLanguageLocation?) -> Self {
            return Self(fieldDSP: fieldDSP, fieldLanguage: fieldLanguage)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyFieldDSPLanguage(_ desc: NIOIMAP.Body.FieldDSPLanguage) -> Int {
        self.writeSpace() +
        self.writeBodyFieldDSP(desc.fieldDSP)
    }

}
