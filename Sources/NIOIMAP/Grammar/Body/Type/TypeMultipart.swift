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

    /// IMAPv4 `body-type-mpart`
    public struct TypeMultipart: Equatable {
        public var bodies: [NIOIMAP.Body]
        public var mediaSubtype: String
        public var multipartExtension: ExtensionMultipart?

        /// Convenience function for a better experience when chaining multiple types.
        public static func bodies(_ bodies: [NIOIMAP.Body], mediaSubtype: String, multipartExtension: ExtensionMultipart?) -> Self {
            return Self(bodies: bodies, mediaSubtype: mediaSubtype, multipartExtension: multipartExtension)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyTypeMultipart(_ part: NIOIMAP.Body.TypeMultipart) -> Int {
        part.bodies.reduce(into: 0) { (result, body) in
            result += self.writeBody(body)
        } +
        self.writeSpace() +
        self.writeIMAPString(part.mediaSubtype) +
        self.writeIfExists(part.multipartExtension) { (ext) -> Int in
            self.writeSpace() +
            self.writeBodyExtensionMultipart(ext)
        }
    }

}
