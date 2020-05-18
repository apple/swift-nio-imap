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
        public var multipartExtension: Extension?

        public init(parts: [BodyStructure], mediaSubtype: MediaSubtype, multipartExtension: Extension? = nil) {
            self.parts = parts
            self.mediaSubtype = mediaSubtype
            self.multipartExtension = multipartExtension
        }
    }
}

extension BodyStructure.Multipart {
    /// IMAPv4 `body-ext-multipart`
    public struct Extension: Equatable {
        public var parameter: [FieldParameterPair]
        public var dspLanguage: BodyStructure.FieldDSPLanguage?

        /// Convenience function for a better experience when chaining multiple types.
        public init(parameters: [FieldParameterPair], dspLanguage: BodyStructure.FieldDSPLanguage?) {
            self.parameter = parameters
            self.dspLanguage = dspLanguage
        }
    }
    
    public struct MediaSubtype: Equatable {
        
        var _backing: String
        
        public static var alternative: Self {
            return .init("multipart/alternative")
        }
        
        public static var related: Self {
            return .init("multipart/related")
        }
        
        public static var mixed: Self {
            return .init("multipart/mixed")
        }
        
        public init(_ string: String) {
            self._backing = string
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
            self.writeIfExists(part.multipartExtension) { (ext) -> Int in
                self.writeSpace() +
                    self.writeBodyExtensionMultipart(ext)
            }
    }

    @discardableResult mutating func writeBodyExtensionMultipart(_ ext: BodyStructure.Multipart.Extension) -> Int {
        self.writeBodyFieldParameters(ext.parameter) +
            self.writeIfExists(ext.dspLanguage) { (dspLanguage) -> Int in
                self.writeBodyFieldDSPLanguage(dspLanguage)
            }
    }
    
    @discardableResult mutating func writeMediaSubtype(_ type: BodyStructure.Multipart.MediaSubtype) -> Int {
        self.writeString("\"\(type._backing)\"")
    }
}
