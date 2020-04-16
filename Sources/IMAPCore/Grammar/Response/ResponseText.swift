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

extension IMAPCore {

    /// IMAPv4 `resp-text`
    public struct ResponseText: Equatable {
        public var code: ResponseTextCode?
        public var text: String

        /// Convenience function for a better experience when chaining multiple types.
        public static func code(_ code: ResponseTextCode?, text: String) -> Self {
            return Self(code: code, text: text)
        }
    }

}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeResponseText(_ text: IMAPCore.ResponseText) -> Int {
        self.writeIfExists(text.code) { (code) -> Int in
            self.writeString("[") +
            self.writeResponseTextCode(code) +
            self.writeString("] ")
        } +
        self.writeIMAPString(text.text)
    }

}
