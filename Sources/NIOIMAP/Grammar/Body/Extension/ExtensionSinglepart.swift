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

    /// IMAPv4 `body-ext-1part`
    public struct ExtensionSinglepart: Equatable {
        var fieldMD5: FieldMD5
        var dspLanguage: FieldDSPLanguage?

        /// Convenience function for a better experience when chaining multiple types.
        static func fieldMD5(_ fieldMD5: FieldMD5, dspLanguage: FieldDSPLanguage?) -> Self {
            return Self(fieldMD5: fieldMD5, dspLanguage: dspLanguage)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyExtensionSinglePart(_ ext: NIOIMAP.Body.ExtensionSinglepart) -> Int {
        self.writeNString(ext.fieldMD5) +
        self.writeIfExists(ext.dspLanguage) { (dspLanguage) -> Int in
            self.writeBodyFieldDSPLanguage(dspLanguage)
        }
    }
}
