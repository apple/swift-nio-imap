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
    
    /// Pairs languages with a `Location`. An abstraction from RFC 3501
    /// to make the API slightly easier to work with and enforce validity.
    public struct LanguageLocation: Equatable {
        /// The body language value(s) as defined in BCP 47 and RFC 3066.
        public var languages: [String]
        /// A string list giving the body content URI as defined in RFC 2557.
        public var location: LocationAndExtensions?

        /// Pairs an array of language strings with a location.
        /// - parameter languages: The body language value(s) as defined in BCP 47 and RFC 3066.
        /// - parameter location: A *location/extension* pairing.
        public init(languages: [String], location: BodyStructure.LocationAndExtensions? = nil) {
            self.languages = languages
            self.location = location
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyFieldLanguageLocation(_ langLoc: BodyStructure.LanguageLocation) -> Int {
        self.writeSpace() +
            self.writeBodyLanguages(langLoc.languages) +
            self.writeIfExists(langLoc.location) { (location) -> Int in
                self.writeBodyLocationAndExtensions(location)
            }
    }
}
