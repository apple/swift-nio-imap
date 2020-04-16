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

extension IMAPCore.Body {

    /// IMAPv4 `body-ext-multipart`
    public struct ExtensionMultipart: Equatable {
        public var parameter: [IMAPCore.FieldParameterPair]
        public var dspLanguage: FieldDSPLanguage?

        /// Convenience function for a better experience when chaining multiple types.
        public static func parameter(_ parameters: [IMAPCore.FieldParameterPair], dspLanguage: FieldDSPLanguage?) -> Self {
            return Self(parameter: parameters, dspLanguage: dspLanguage)
        }
    }

}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeBodyExtensionMultipart(_ ext: IMAPCore.Body.ExtensionMultipart) -> Int {
        self.writeBodyFieldParameters(ext.parameter) +
        self.writeIfExists(ext.dspLanguage) { (dspLanguage) -> Int in
            self.writeBodyFieldDSPLanguage(dspLanguage)
        }
    }

}
