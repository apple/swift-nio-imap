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

import struct OrderedCollections.OrderedDictionary

/// A search criterion that filters messages based on modification sequence value (RFC 7162 CONDSTORE extension).
///
/// The modification sequence (mod-sequence) is a per-message value that increments each time a message's
/// metadata (such as flags) is modified. This type allows clients to request only messages that have been
/// modified since a specific mod-sequence value, enabling efficient synchronization of mailbox state changes.
///
/// **Requires server capability:** ``Capability/condstore``
///
/// When used in a `SEARCH` or `UID SEARCH` command with the `MODSEQ` criterion, this type encapsulates
/// the search parameters including any extension-specific entry attributes and the minimum mod-sequence value
/// to match.
///
/// ### Example
///
/// ```
/// C: A001 SEARCH MODSEQ 12345
/// S: * ESEARCH (TAG "A001") ALL 2,5:7 MODSEQ 12352
/// S: A001 OK SEARCH completed
/// ```
///
/// The `SEARCH MODSEQ 12345` clause is represented by a ``SearchModificationSequence`` with
/// `sequenceValue: 12345` and empty `extensions`. The response includes the highest mod-sequence
/// value (``SearchReturnData/modificationSequence(_:)``) of all returned messages.
///
/// - SeeAlso: [RFC 7162 Section 3.1.5](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.5)
/// - SeeAlso: ``SearchKey``
/// - SeeAlso: ``ModificationSequenceValue``
public struct SearchModificationSequence: Hashable, Sendable {
    /// Extension-specific entry attributes for future CONDSTORE enhancements.
    ///
    /// This dictionary may contain additional entry attributes defined by future IMAP extensions.
    /// For basic MODSEQ searches (RFC 7162), this is typically empty.
    public var extensions: OrderedDictionary<EntryFlagName, EntryKindRequest>

    /// The minimum modification sequence value that matching messages must have.
    ///
    /// Messages returned by the search will have a mod-sequence value greater than or equal to this value.
    public var sequenceValue: ModificationSequenceValue

    /// Creates a new `SearchModificationSequence`.
    /// - parameter extensions: Extension-specific entry attributes (typically empty for RFC 7162)
    /// - parameter sequenceValue: The minimum modification sequence value to match
    public init(
        extensions: OrderedDictionary<EntryFlagName, EntryKindRequest>,
        sequenceValue: ModificationSequenceValue
    ) {
        self.extensions = extensions
        self.sequenceValue = sequenceValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchModificationSequence(_ data: SearchModificationSequence) -> Int {
        self.writeString("MODSEQ")
            + self.writeOrderedDictionary(data.extensions, separator: "", parenthesis: false) {
                (element, self) -> Int in
                self.writeSpace() + self.writeEntryFlagName(element.key) + self.writeSpace()
                    + self.writeEntryKindRequest(element.value)
            } + self.writeSpace() + self.writeModificationSequenceValue(data.sequenceValue)
    }
}
