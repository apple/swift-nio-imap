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
    /// Content disposition and language information for a message part.
    ///
    /// This type pairs optional content disposition (indicating how the part should be handled) with optional
    /// language and location information. Both are optional fields in the body structure defined in
    /// [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2).
    ///
    /// This is an API abstraction to simplify working with the disposition and language/location pairing from the raw IMAP message.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 FETCH 1 (BODYSTRUCTURE)
    /// S: * 1 FETCH (BODYSTRUCTURE ("text" "plain" NIL NIL NIL "7bit" 1024 30 ("attachment" (("filename" "document.txt"))) ("en" "fr")))
    /// S: A001 OK FETCH completed
    /// ```
    ///
    /// The disposition `("attachment" (("filename" "document.txt")))` corresponds to a ``Disposition`` with
    /// kind ``DispositionKind/attachment`` and filename parameter. The language list `("en" "fr")` corresponds to
    /// a ``LanguageLocation`` with those language tags.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    /// - SeeAlso: ``Disposition``
    /// - SeeAlso: ``LanguageLocation``
    public struct DispositionAndLanguage: Hashable, Sendable {
        /// Optional content disposition indicating how the part should be handled.
        ///
        /// When `nil`, no disposition is specified (defaults to ``DispositionKind/inline``).
        /// See ``Disposition`` for details on disposition types and parameters.
        public var disposition: Disposition?

        /// Optional language and location information for the part.
        ///
        /// When `nil`, no language or location is specified.
        /// See ``LanguageLocation`` for details.
        public var language: LanguageLocation?

        /// Creates a disposition and language pairing.
        ///
        /// - parameter disposition: Optional disposition indicating how the part should be handled.
        /// - parameter language: Optional language and location information. Defaults to `nil`.
        public init(disposition: Disposition?, language: LanguageLocation? = nil) {
            self.disposition = disposition
            self.language = language
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyDispositionAndLanguage(
        _ desc: BodyStructure.DispositionAndLanguage
    ) -> Int {
        self.writeSpace() + self.writeBodyDisposition(desc.disposition)
    }
}
