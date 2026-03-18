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
    /// Language and content location information for a message part.
    ///
    /// This type pairs one or more language identifiers with an optional content location URI. The language values
    /// follow [BCP 47](https://datatracker.ietf.org/doc/html/bcp47) language tags and the location follows
    /// [RFC 2557](https://datatracker.ietf.org/doc/html/rfc2557) for MIME content location URIs. Both are optional
    /// fields in the body structure defined in [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2).
    ///
    /// This is an API abstraction to simplify working with the language/location pairing from the raw IMAP message.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 FETCH 1 (BODYSTRUCTURE)
    /// S: * 1 FETCH (BODYSTRUCTURE ("text" "html" NIL NIL NIL "7bit" 1024 30 NIL NIL ("en" "fr") "https://example.com/message"))
    /// S: A001 OK FETCH completed
    /// ```
    ///
    /// The language list `("en" "fr")` corresponds to a ``LanguageLocation`` with ``languages`` = `["en", "fr"]`.
    /// The location `"https://example.com/message"` corresponds to a ``LocationAndExtensions`` with that URI.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    /// - SeeAlso: [RFC 2557](https://datatracker.ietf.org/doc/html/rfc2557)
    /// - SeeAlso: [BCP 47](https://datatracker.ietf.org/doc/html/bcp47)
    public struct LanguageLocation: Hashable, Sendable {
        /// One or more language identifiers for the message part.
        ///
        /// Language values follow [BCP 47](https://datatracker.ietf.org/doc/html/bcp47) language tag format
        /// (e.g., `"en"` for English, `"en-US"` for US English, `"fr"` for French).
        public var languages: [String]

        /// Optional content location URI for the message part.
        ///
        /// If present, provides a URI where the content can be retrieved. See ``LocationAndExtensions`` for details.
        public var location: LocationAndExtensions?

        /// Creates a language and location pairing.
        ///
        /// - parameter languages: One or more language identifiers following [BCP 47](https://datatracker.ietf.org/doc/html/bcp47) format.
        /// - parameter location: Optional location and extension information. Defaults to `nil`.
        public init(languages: [String], location: BodyStructure.LocationAndExtensions? = nil) {
            self.languages = languages
            self.location = location
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyFieldLanguageLocation(_ langLoc: BodyStructure.LanguageLocation) -> Int {
        self.writeSpace() + self.writeBodyLanguages(langLoc.languages)
            + self.writeIfExists(langLoc.location) { (location) -> Int in
                self.writeBodyLocationAndExtensions(location)
            }
    }
}
