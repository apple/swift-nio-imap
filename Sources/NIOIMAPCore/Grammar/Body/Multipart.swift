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
    /// IMAPv4 `body-type-mpart`
    public struct Multipart: Equatable {
        public var parts: [BodyStructure]
        public var mediaSubtype: MediaSubtype
        public var `extension`: Extension?

        public init(parts: [BodyStructure], mediaSubtype: MediaSubtype, extension: Extension? = nil) {
            self.parts = parts
            self.mediaSubtype = mediaSubtype
            self.`extension` = `extension`
        }
    }
}

extension BodyStructure.Multipart {
    /// IMAPv4 `body-ext-multipart`
    public struct Extension: Equatable {
        public var parameter: [BodyStructure.ParameterPair]
        public var dispositionAndLanguage: BodyStructure.DispositionAndLanguage?

        /// Convenience function for a better experience when chaining multiple types.
        public init(parameters: [BodyStructure.ParameterPair], dispositionAndLanguage: BodyStructure.DispositionAndLanguage?) {
            self.parameter = parameters
            self.dispositionAndLanguage = dispositionAndLanguage
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyTypeMultipart(_ part: BodyStructure.Multipart) -> Int {
        part.parts.reduce(into: 0) { (result, body) in
            result += self.writeBody(body)
        } +
            self.writeSpace() +
            self.writeMediaSubtype(part.mediaSubtype) +
            self.writeIfExists(part.`extension`) { (ext) -> Int in
                self.writeSpace() +
                    self.writeBodyExtensionMultipart(ext)
            }
    }

    @discardableResult mutating func writeBodyExtensionMultipart(_ ext: BodyStructure.Multipart.Extension) -> Int {
        self.writeBodyParameterPairs(ext.parameter) +
            self.writeIfExists(ext.dispositionAndLanguage) { (dspLanguage) -> Int in
                self.writeBodyDispositionAndLanguage(dspLanguage)
            }
    }

    @discardableResult mutating func writeMediaSubtype(_ type: BodyStructure.MediaSubtype) -> Int {
        self.writeString("\"\(type._backing)\"")
    }
}
