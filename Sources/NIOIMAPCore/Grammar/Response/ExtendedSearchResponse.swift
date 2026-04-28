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

/// A server response to an extended SEARCH command.
///
/// The ESEARCH extension (see [RFC 4731](https://datatracker.ietf.org/doc/html/rfc4731)) enhances
/// the base SEARCH command with additional return options, allowing clients to request specific
/// result formats (ALL, COUNT, MIN, MAX, PARTIAL) rather than receiving only the matched message
/// identifiers. Extended search responses are more efficient and flexible than base protocol search
/// results, particularly for large result sets.
///
/// ### Example
///
/// ```
/// C: A001 UID SEARCH RETURN (COUNT ALL) SINCE 1-Jan-2024
/// S: * ESEARCH (TAG "A001") UID COUNT 42 ALL 1,3,5,7,9,...
/// S: A001 OK SEARCH completed
/// ```
///
/// The line `S: * ESEARCH (TAG "A001") UID COUNT 42 ALL 1,3,5,7,9,...` is wrapped as a
/// ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/extendedSearch(_:)`` with this ``ExtendedSearchResponse``. The response
/// indicates the search matched 42 messages (COUNT 42) and provides the UIDs of all matches
/// (ALL 1,3,5,7,9,...) because UID was specified and RETURN (COUNT ALL) was requested.
///
/// ## Related types
///
/// Link to related types using DocC symbol links: ``SearchReturnOption``, ``SearchReturnData``,
/// ``SearchCorrelator``.
///
/// - SeeAlso: [RFC 4731](https://datatracker.ietf.org/doc/html/rfc4731) - ESEARCH Extension
public struct ExtendedSearchResponse: Hashable, Sendable {
    /// Identifies the search that resulted in this response.
    ///
    /// The server automatically includes the command tag from the original SEARCH command
    /// to correlate the response with the request. This is particularly useful when multiple
    /// searches are pipelined. The `correlator` property contains this tag, or `nil` if not
    /// present in the response.
    ///
    /// - SeeAlso: ``SearchCorrelator``
    public var correlator: SearchCorrelator?

    /// Indicates whether the identifiers in this response are UIDs or sequence numbers.
    ///
    /// When the client issues `SEARCH` (not `UID SEARCH`), the server returns sequence numbers.
    /// When the client issues `UID SEARCH`, the server returns UIDs. Use this property to
    /// interpret the identifiers in ``returnData`` correctly.
    ///
    /// - SeeAlso: ``Kind``, ``UID``, ``SequenceNumber``
    public var kind: Kind

    /// Data returned from the extended search.
    ///
    /// Contains the search result data in the format(s) requested by the client via the
    /// RETURN option. Typical contents include all matching identifiers (``SearchReturnData/all(_:)``),
    /// result count (``SearchReturnData/count(_:)``), minimum/maximum identifiers, and partial results.
    ///
    /// - SeeAlso: ``SearchReturnData``
    public var returnData: [SearchReturnData]

    /// Creates a new extended search response.
    ///
    /// - parameter correlator: An optional correlator to associate this response with a specific search command. Defaults to `nil`.
    /// - parameter kind: Whether this response contains UIDs or sequence numbers.
    /// - parameter returnData: The search result data in the requested format(s).
    public init(correlator: SearchCorrelator? = nil, kind: Kind, returnData: [SearchReturnData]) {
        self.correlator = correlator
        self.kind = kind
        self.returnData = returnData
    }
}

extension ExtendedSearchResponse {
    /// Indicates whether the identifiers in the response are sequence numbers or UIDs.
    ///
    /// Servers send different types of identifiers depending on whether the client issued
    /// `SEARCH` or `UID SEARCH`. Clients must use this property to correctly interpret
    /// the identifiers in the ``returnData``.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4), [RFC 4731 Section 2.1](https://datatracker.ietf.org/doc/html/rfc4731#section-2.1)
    public enum Kind: Hashable, Sendable {
        /// The response contains sequence numbers (from `SEARCH` command).
        ///
        /// Sequence numbers are relative positions in the currently selected mailbox and are
        /// only valid during the current session for this mailbox.
        case sequenceNumber

        /// The response contains UIDs (from `UID SEARCH` command).
        ///
        /// UIDs are unique, stable identifiers assigned by the server and remain valid across
        /// sessions as long as the UIDVALIDITY of the mailbox has not changed.
        ///
        /// - SeeAlso: ``UID``, ``UIDValidity``
        case uid
    }
}

// MARK: - Convenience

extension ExtendedSearchResponse {
    /// If the response is a UID response, returns the UIDs of all matched messages.
    ///
    /// Returns `nil` if this is not a UID response or if the response does not contain matched UIDs.
    /// When no matching UIDs exist, this property returns an empty set rather than `nil`.
    ///
    /// Extracts UIDs from ``SearchReturnData/all(_:)`` if present, or falls back to
    /// ``SearchReturnData/partial(_:_:)`` if only partial results are available. Per RFC 9394, a
    /// single SEARCH response should contain either ALL or PARTIAL, but not both; if both are
    /// present, ALL takes precedence.
    ///
    /// - Returns: The matched UIDs for UID search responses, or `nil` if unavailable.
    /// - SeeAlso: ``SearchReturnData/all(_:)``, ``SearchReturnData/partial(_:_:)``
    public var matchedUIDs: UIDSet? {
        guard kind == .uid else { return nil }
        return UIDSet(_matchedIdentifierSet)
    }

    /// If the response is a sequence number response, returns the sequence numbers of all matched messages.
    ///
    /// Returns `nil` if this is not a sequence number response or if the response does not contain matched sequence numbers.
    /// When no matching sequence numbers exist, this property returns an empty set rather than `nil`.
    ///
    /// Extracts sequence numbers from ``SearchReturnData/all(_:)`` if present, or falls back to
    /// ``SearchReturnData/partial(_:_:)`` if only partial results are available. Per RFC 9394, a
    /// single SEARCH response should contain either ALL or PARTIAL, but not both; if both are
    /// present, ALL takes precedence.
    ///
    /// - Returns: The matched sequence numbers for non-UID search responses, or `nil` if unavailable.
    /// - SeeAlso: ``MessageIdentifierSet``, ``SequenceNumber``, ``SearchReturnData/all(_:)``, ``SearchReturnData/partial(_:_:)``
    public var matchedSequenceNumbers: MessageIdentifierSet<SequenceNumber>? {
        guard kind == .sequenceNumber else { return nil }
        return MessageIdentifierSet(_matchedIdentifierSet)
    }

    private var _matchedIdentifierSet: MessageIdentifierSet<UnknownMessageIdentifier> {
        returnData.lazy.compactMap { data -> MessageIdentifierSet<UnknownMessageIdentifier>? in
            guard case .all(.set(let set)) = data else { return nil }
            return set.set
        }.first ?? returnData.lazy.compactMap {
            guard case .partial(_, let set) = $0 else { return nil }
            return set
        }.first ?? MessageIdentifierSet()
    }

    /// The total count of matched messages, if present in this response.
    ///
    /// Returns `nil` if the response does not contain a COUNT value.
    ///
    /// - Returns: The count of matched messages, or `nil` if not present.
    /// - SeeAlso: ``SearchReturnData/count(_:)``
    public var count: Int? {
        returnData.lazy.compactMap { data -> Int? in
            guard case .count(let c) = data else { return nil }
            return c
        }.first
    }

    /// The minimum UID in the search result, if available.
    ///
    /// Returns `nil` if this is not a UID response or if the response does not include MIN data.
    ///
    /// - Returns: The minimum UID, or `nil` if unavailable.
    /// - SeeAlso: ``SearchReturnData/min(_:)``
    public var minUID: UID? {
        guard
            kind == .uid,
            let value = returnData.lazy.compactMap({ data -> UnknownMessageIdentifier? in
                guard case .min(let value) = data else { return nil }
                return value
            }).first
        else { return nil }
        return UID(value)
    }

    /// The minimum sequence number in the search result, if available.
    ///
    /// Returns `nil` if this is not a sequence number response or if the response does not include MIN data.
    ///
    /// - Returns: The minimum sequence number, or `nil` if unavailable.
    /// - SeeAlso: ``SearchReturnData/min(_:)``
    public var minSequenceNumber: SequenceNumber? {
        guard
            kind == .sequenceNumber,
            let value = returnData.lazy.compactMap({ data -> UnknownMessageIdentifier? in
                guard case .min(let value) = data else { return nil }
                return value
            }).first
        else { return nil }
        return SequenceNumber(value)
    }

    /// The maximum UID in the search result, if available.
    ///
    /// Returns `nil` if this is not a UID response or if the response does not include MAX data.
    ///
    /// - Returns: The maximum UID, or `nil` if unavailable.
    /// - SeeAlso: ``SearchReturnData/max(_:)``
    public var maxUID: UID? {
        guard
            kind == .uid,
            let value = returnData.lazy.compactMap({ data -> UnknownMessageIdentifier? in
                guard case .max(let value) = data else { return nil }
                return value
            }).first
        else { return nil }
        return UID(value)
    }

    /// The maximum sequence number in the search result, if available.
    ///
    /// Returns `nil` if this is not a sequence number response or if the response does not include MAX data.
    ///
    /// - Returns: The maximum sequence number, or `nil` if unavailable.
    /// - SeeAlso: ``SearchReturnData/max(_:)``
    public var maxSequenceNumber: SequenceNumber? {
        guard
            kind == .sequenceNumber,
            let value = returnData.lazy.compactMap({ data -> UnknownMessageIdentifier? in
                guard case .max(let value) = data else { return nil }
                return value
            }).first
        else { return nil }
        return SequenceNumber(value)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeExtendedSearchResponse(_ response: ExtendedSearchResponse) -> Int {
        self.writeString("ESEARCH")
            + self.writeIfExists(response.correlator) { (correlator) -> Int in
                self.writeSearchCorrelator(correlator)
            }
            + self.write(if: response.kind == .uid) {
                self.writeString(" UID")
            }
            + self.write(if: response.returnData.count > 0) {
                self.writeSpace()
            }
            + self.writeArray(response.returnData, parenthesis: false) { (data, self) in
                self.writeSearchReturnData(data)
            }
    }
}
