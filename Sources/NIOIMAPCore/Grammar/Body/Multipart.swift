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
    /// Represents a *multipart* body as defined in RFC 3501.
    /// Recommended reading: RFC 3501 § 6.4.5.
    public struct Multipart: Equatable {
        /// The parts of the body. Each part is assigned a consecutive part number.
        public var parts: [BodyStructure]

        /// The subtype of the message, e.g. *multipart/mixed*
        public var mediaSubtype: MediaSubtype

        /// Optional additional fields that are not required to form a valid `Multipart`
        public var `extension`: Extension?

        /// Creates a new `Multipart`.
        /// - parameter parts: The sub-parts that form the `Multipart`
        /// - parameter mediaSubtype: The subtype of the message, e.g. *multipart/mixed*
        /// - parameter extension: Optional additional fields that are not required to form a valid `Multipart` body
        public init(parts: [BodyStructure], mediaSubtype: MediaSubtype, extension: Extension? = nil) {
            self.parts = parts
            self.mediaSubtype = mediaSubtype
            self.extension = `extension`
        }
    }
}

extension BodyStructure.Multipart {
    /// Optional fields that are not required to form a valid `Multipart`. Links an array of `ParameterPair` with a `DispositionAndLanguage.
    /// Partially simplified to make the API nice, for example `DispositionAndLanguage` pairs a disposition and a language.
    public struct Extension: Equatable {
        /// An array of *key/value* pairs.
        public var parameters: [BodyStructure.ParameterPair]

        /// A disposition paired to an array of languages.
        public var dispositionAndLanguage: BodyStructure.DispositionAndLanguage?

        /// Creates a new `Multipart.Extension`.
        /// - parameter parameters : An array of *key/value* pairs.
        /// - parameter dispositionAndLanguage: A disposition paired to an array of languages.
        public init(parameters: [BodyStructure.ParameterPair], dispositionAndLanguage: BodyStructure.DispositionAndLanguage?) {
            self.parameters = parameters
            self.dispositionAndLanguage = dispositionAndLanguage
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyMultipart(_ part: BodyStructure.Multipart) -> Int {
        part.parts.reduce(into: 0) { (result, body) in
            result += self.writeBody(body)
        } +
            self.writeSpace() +
            self.writeMediaSubtype(part.mediaSubtype) +
            self.writeIfExists(part.extension) { (ext) -> Int in
                self.writeSpace() +
                    self.writeBodyExtensionMultipart(ext)
            }
    }

    @discardableResult mutating func writeBodyExtensionMultipart(_ ext: BodyStructure.Multipart.Extension) -> Int {
        self.writeBodyParameterPairs(ext.parameters) +
            self.writeIfExists(ext.dispositionAndLanguage) { (dspLanguage) -> Int in
                self.writeBodyDispositionAndLanguage(dspLanguage)
            }
    }

    @discardableResult mutating func writeMediaSubtype(_ type: BodyStructure.MediaSubtype) -> Int {
        self.writeString("\"\(type.stringValue)\"")
    }
}
