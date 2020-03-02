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

    /// IMAPv4 `body-ext-multipart`
    struct ExtensionMultipart: Equatable {
        var parameter: FieldParameter
        var dspLanguage: FieldDSPLanguage?

        /// Convenience function for a better experience when chaining multiple types.
        static func parameter(_ parameters: FieldParameter, dspLanguage: FieldDSPLanguage?) -> Self {
            return Self(parameter: parameters, dspLanguage: dspLanguage)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyExtensionMultipart(_ ext: NIOIMAP.Body.ExtensionMultipart) -> Int {
        self.writeBodyFieldParameter(ext.parameter) +
        self.writeIfExists(ext.dspLanguage) { (dspLanguage) -> Int in
            self.writeBodyFieldDSPLanguage(dspLanguage)
        }
    }

}
