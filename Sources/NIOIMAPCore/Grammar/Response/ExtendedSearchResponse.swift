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

/// Sent from a server in response to an extended search.
public struct ExtendedSearchResponse: Hashable {
    /// Identifies the search that resulted in this response.
    public var correlator: SearchCorrelator?

    /// Is this a UID or a sequence number response?
    public var kind: Kind

    /// Data returned from the search.
    public var returnData: [SearchReturnData]

    /// Creates a new `ExtendedSearchResponse`.
    /// - parameter correlator: Identifies the search that resulted in this response. Defaults to `nil`.
    /// - parameter kind: Is this a response to `UID SEARCH` or `SEARCH`?
    /// - parameter returnData: Data returned from the search.
    public init(correlator: SearchCorrelator? = nil, kind: Kind, returnData: [SearchReturnData]) {
        self.correlator = correlator
        self.kind = kind
        self.returnData = returnData
    }
}

extension ExtendedSearchResponse {
    /// The kind of search response.
    ///
    /// Describes if the `UnknownMessageIdentifier` in the `returnData`’s `SearchReturnData` are `UID` or `SequenceNumber`.
    public enum Kind: Hashable {
        case sequenceNumber
        case uid
    }
}

// MARK: - Convenience

extension ExtendedSearchResponse {
    /// If the response is a UID response, it returns the UIDs of this response, _assuming_ that
    /// `SearchReturnOption.all` was specified.
    ///
    /// If the response is a sequence number response, this will return `nil`.
    ///
    /// If the response does not contain `.all` but contains `.partial`, the UIDs from
    /// the partial result will be returned. Note that the returned value is thus ambiguous in
    /// the (unlikely) case where the search specified both `.all` and `.partial`.
    ///
    /// Note: The response will not contain an `.all` item if there are no matching UIDs. In this
    /// case, though, this property will return an empty `UIDSet`.
    public var matchedUIDs: UIDSet? {
        guard kind == .uid else { return nil }
        return UIDSet(_matchedIdentifierSet)
    }

    /// If the response is a _sequence number_ response, it returns the sequence numbers of
    /// this response, _assuming_ that `SearchReturnOption.all` was specified.
    ///
    /// If the response is a UID response, this will return `nil`.
    ///
    /// If the response does not contain `.all` but contains `.partial`, the UIDs from
    /// the partial result will be returned. Note that the returned value is thus ambiguous in
    /// the (unlikely) case where the search specified both `.all` and `.partial`.
    ///
    /// Note: The response will not contain an `.all` item if there are no matching UIDs. In this
    /// case, though, this property will return an empty `UIDSet`.
    public var matchedSequenceNumbers: MessageIdentifierSet<SequenceNumber>? {
        guard kind == .sequenceNumber else { return nil }
        return MessageIdentifierSet(_matchedIdentifierSet)
    }

    private var _matchedIdentifierSet: MessageIdentifierSet<UnknownMessageIdentifier> {
        returnData.lazy.compactMap { data -> MessageIdentifierSet<UnknownMessageIdentifier>? in
            guard case .all(.set(let set)) = data else { return nil }
            return set.set
        }.first ??
            returnData.lazy.compactMap {
                guard case .partial(_, let set) = $0 else { return nil }
                return set
            }.first ??
            MessageIdentifierSet()
    }

    /// Returns the count value in the response.
    public var count: Int? {
        returnData.lazy.compactMap { data -> Int? in
            guard case .count(let c) = data else { return nil }
            return c
        }.first
    }

    /// Returns the `MIN` value in the response, if the result contains it and is a UID response.
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

    /// Returns the `MIN` value in the response, if the result contains it and is a sequence number response.
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

    /// Returns the `MAX` value in the response, if the result contains it and is a UID response.
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

    /// Returns the `MAX` value in the response, if the result contains it and is a sequence number response.
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
        self.writeString("ESEARCH") +
            self.writeIfExists(response.correlator) { (correlator) -> Int in
                self.writeSearchCorrelator(correlator)
            } +
            self.write(if: response.kind == .uid) {
                self.writeString(" UID")
            } +
            self.write(if: response.returnData.count > 0) {
                self.writeSpace()
            } +
            self.writeArray(response.returnData, parenthesis: false) { (data, self) in
                self.writeSearchReturnData(data)
            }
    }
}
