//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

/// A `Capability` is advertised as a piece of functionality that a server supports. If the
/// server does not explicitly advertise a capability then the client should not assume the functionality
/// is present.
public struct Capability: Hashable, Sendable {
    /// The raw string value of the capability.
    var rawValue: String
    private var splitIndex: String.Index?

    /// The name of the capability. For simple capabilities such as *STARTTLS*, the value
    /// will simply be *STARTTLS*. For configurable capabilities such as *AUTH=GSSAPI*, the value
    /// will be *AUTH*.
    public var name: String {
        guard let index = self.splitIndex else {
            return self.rawValue
        }
        return String(self.rawValue[..<index])
    }

    /// If the capability is _simple_, e.g. *STARTTTLS*, then the value will be `nil`.
    /// Otherwise, if the capability is configurable such as *AUTH=GSSAPI*` then the value will
    /// be *GSSAPI*.
    public var value: String? {
        guard var index = self.splitIndex else {
            return nil
        }
        index = self.rawValue.index(after: index)

        return String(self.rawValue[index...])
    }

    /// Creates a new capability from a `String`, and parses any configuration if present.
    /// - parameter value: The raw `String` value of the capability, e.g. *STARTTLS* or *AUTH=GSSAPI*.
    public init(_ value: String) {
        self.init(unchecked: value)
    }

    fileprivate init(unchecked: String) {
        self.rawValue = unchecked
        self.splitIndex = self.rawValue.firstIndex(of: "=")
    }
}

// MARK: - Convenience Types

extension Capability {
    /// Wraps supported contexts including *SEARCH* and *SORT*.
    public struct ContextKind: Hashable, Sendable {
        /// Support extended search commands and accepts new return options.
        public static let search = Self(unchecked: "SEARCH")

        /// Support the extended SORT command syntax and accepts new return options.
        public static let sort = Self(unchecked: "SORT")

        /// The raw string value of the capability.
        var rawValue: String

        /// Creates a new `ContextKind`  from a `String`.
        /// - parameter value: The raw `String`. Will be uppercased.
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps *SORT=* extensions.
    public struct SortKind: Hashable, Sendable {
        /// A server that supports the full SORT extension as well as both the
        /// DISPLAYFROM and DISPLAYTO sort criteria indicates this by returning
        /// "SORT=DISPLAY" in its CAPABILITY response.
        public static let display = Self(unchecked: "DISPLAY")

        /// The raw string value of the capability.
        var rawValue: String

        /// Creates a new `SortKind`  from a `String`.
        /// - parameter value: The raw `String`. Will be uppercased.
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps *THREAD=* extensions.
    public struct ThreadKind: Hashable, Sendable {
        /// The searched messages are sorted by base subject and then
        /// by the sent date.  The messages are then split into separate
        /// threads, with each thread containing messages with the same
        /// base subject text.  Finally, the threads are sorted by the sent
        /// date of the first message in the thread.
        public static let orderedSubject = Self(unchecked: "ORDEREDSUBJECT")

        /// Threads the searched messages by grouping them together in parent/child
        /// relationships based on which messages are replies to others.
        public static let references = Self(unchecked: "REFERENCES")

        /// The raw string value of the capability.
        var rawValue: String

        /// Creates a new `ThreadKind`  from a `String`.
        /// - parameter value: The raw `String`. Will be uppercased.
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps *STATUS=* extensions.
    public struct StatusKind: Hashable, Sendable {
        /// Allows retrieving the total storage size of a mailbox with
        /// a single STATUS command rather than retrieving and
        /// summing the sizes of all individual messages in that mailbox.
        public static let size = Self(unchecked: "SIZE")

        /// The raw string value of the capability.
        var rawValue: String

        /// Creates a new `StatusKind`  from a `String`.
        /// - parameter value: The raw `String`. Will be uppercased.
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps *UTF8=* extensions
    public struct UTF8Kind: Hashable, Sendable {
        /// Enabling this extension will tell the server that the client accepts
        /// UTF8-encoded strings.
        public static let accept = Self(unchecked: "ACCEPT")

        /// The raw string value of the capability.
        var rawValue: String

        /// Creates a new `UTF8Kind`  from a `String`.
        /// - parameter value: The raw `String`. Will be uppercased.
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps *RIGHTS=* extensions. For more information on what each
    /// letter means see RFC 4314 section 4.
    public struct RightsKind: Hashable, Sendable {
        /// Allowed operations in auth state: *DELETE*, *APPEND*, *CREATE*, *RENAME*,
        /// Allowed operations in selected state: *COPY*, *STORE flags*, *EXPUNGE* (required)
        public static let tekx = Self(unchecked: "TEKX")

        /// The raw string value of the capability.
        var rawValue: String

        /// Creates a new `RightsKind`  from a `String`.
        /// - parameter value: The raw `String`. Will be uppercased.
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// The type of compression used in IMAP  responses.
    public struct CompressionKind: Hashable, Sendable {
        /// The `DEFLATE` algorithm is used. RFC 4978
        public static let deflate = Self(unchecked: "DEFLATE")

        /// The raw string value of the capability.
        var rawValue: String

        /// Creates a new `CompressionKind` from a `String`.
        /// - parameter value: The raw `String`. Will be uppercased.
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Permits access control lists to be retrieved and manipulated - RFC 2086.
    public static let acl = Self(unchecked: "ACL")

    /// Enables clients and server to maintain metadata for messages or individual message parts - RFC 5257.
    public static let annotateExperiment1 = Self(unchecked: "ANNOTATE-EXPERIMENT-1")

    /// The server supports sending binary message data - RFC 3516
    public static let binary = Self(unchecked: "BINARY")

    /// Allows clients to create messages containing a combination of new and existing data/messages - RFC 5550.
    public static let catenate = Self(unchecked: "CATENATE")

    /// Provides a mechanism for a client to efficiently determine if a particular mailbox has children - RFC 3348.
    public static let children = Self(unchecked: "CHILDREN")

    /// Provides a protected update mechanism to fully resynchronise a mailbox as part of a `.select` or `.examine` command - RFC 7162.
    public static let condStore = Self(unchecked: "CONDSTORE")

    /// Allows clients to designate mailboxes as being for a dedicated purpose, e.g. the "sent" mailbox - RFC 6154.
    public static let createSpecialUse = Self(unchecked: "CREATE-SPECIAL-USE")

    /// Allows clients to tell servers which capabilities they support and should be used  - RFC 5161.
    public static let enable = Self(unchecked: "ENABLE")

    /// Extends normal search to control what type of data is returned - RFC 4731.
    public static let extendedSearch = Self(unchecked: "ESEARCH")

    /// Allows search responses to be sorted according to e.g. *MIN*, *MAX*, etc - RFC 5465.
    public static let esort = Self(unchecked: "ESORT")

    /// Allows searches to be persistently stored on the server - RFC 5466.
    public static let filters = Self(unchecked: "FILTERS")

    /// Allows the server and client to exchange implementation identifier information - RFC 2971.
    public static let id = Self(unchecked: "ID")

    /// The server can be put into an IDLE state without terminating the connection - RFC 2177
    public static let idle = Self(unchecked: "IDLE")

    /// The specific rev1 revision of IMAP 4 - RFC 3501.
    public static let imap4rev1 = Self(unchecked: "IMAP4rev1")

    /// Default IMAP CAPABILITY - every server should advertise this.
    public static let imap4 = Self(unchecked: "IMAP4")

    /// Allows the client and server to decide which language the server should use when sending human-readable text - RFC 5255.
    public static let language = Self(unchecked: "LANGUAGE")

    /// Allows a `.list` command to also respond status information for each mailbox - RFC 5819.
    public static let listStatus = Self(unchecked: "LIST-STATUS")

    /// Provides an interface for additional `.list` command options to prevent an exponential API increase - RFC 5258.
    public static let listExtended = Self(unchecked: "LIST-EXTENDED")

    /// Clients must not send a `.login` command if this capability is advertised - RFC 3501.
    public static let loginDisabled = Self(unchecked: "LOGINDISABLED")

    /// Allow clients to transparently connect to an alternate IMAP4 server, if their home IMAP4 server has changed - RFC 2221.
    public static let loginReferrals = Self(unchecked: "LOGIN-REFERRALS")

    /// Permits clients and servers to maintain "annotations" or "metadata" on IMAP servers - RFC 5464.
    public static let metadata = Self(unchecked: "METADATA")

    /// Permits clients and servers to maintain "annotations" or "metadata" on IMAP servers.
    /// A server that supports only server annotations indicates the presence of this extension
    /// by returning "METADATA-SERVER" - RFC 5464.
    public static let metadataServer = Self(unchecked: "METADATA-SERVER")

    /// The server supports moving messages from one mailbox to another - RFC 6851.
    public static let move = Self(unchecked: "MOVE")

    /// Allows a client to search multiple mailboxes with one command - RFC 7377.
    public static let multiSearch = Self(unchecked: "MULTISEARCH")

    /// Enables managing mailbox namespaces to provide support for shared mailboxes - RFC 4466.
    public static let namespace = Self(unchecked: "NAMESPACE")

    /// Each mailbox that supports persistent storage of mod-sequences, i.e., for which the server would
    /// send a HIGHESTMODSEQ untagged OK response code on a successful
    /// SELECT/EXAMINE, MUST increment the per-mailbox mod-sequence when one
    /// or more messages are expunged due to EXPUNGE, UID EXPUNGE, CLOSE, or
    /// MOVE [RFC6851]; the server MUST associate the incremented mod-
    /// sequence with the UIDs of the expunged messages - RFC 4466.
    public static let qresync = Self(unchecked: "QRESYNC")

    /// The server supports administrative limits on resource usage - RFC 2087.
    public static let quota = Self(unchecked: "QUOTA")

    /// Allows an initial client response argument to the IMAP AUTHENTICATE command - RFC 4959.
    public static let saslIR = Self(unchecked: "SASL-IR")

    /// Allows a client to tell a server to use the result of a SEARCH (or Unique Identifier (UID)
    /// SEARCH) command as an input to any subsequent command - RFC 5182.
    public static let searchRes = Self(unchecked: "SEARCHRES")

    /// Adds new optional mailbox attributes that a server may include in IMAP LIST
    /// command responses to identify special-use mailboxes to the client,
    /// easing configuration - RFC 6154.
    public static let specialUse = Self(unchecked: "SPECIAL-USE")

    /// Part of the core IMAP4rev1 specification, enables upgrading plaintext connections to TLS - RFC 3501.
    public static let startTLS = Self(unchecked: "STARTTLS")

    /// Provides a set of features intended to reduce the amount of time and
    /// resources used by some client operations - RFC 4315.
    public static let uidPlus = Self(unchecked: "UIDPLUS")

    /// Allows closing the current mailbox without expunging it - RFC 3691.
    public static let unselect = Self(unchecked: "UNSELECT")

    /// If an IMAP server supports PARTIAL in IMAP URL used in CATENATE and
    /// URLAUTH extensions, then it MUST advertise the URL-PARTIAL capability
    /// in both the CAPABILITY response and the equivalent response-code - RFC 5550.
    public static let partialURL = Self(unchecked: "URL-PARTIAL")

    /// Paged SEARCH and FETCH, RFC 9394.
    ///
    /// Allows clients to limit the number of results returned.
    public static let partial = Self(unchecked: "PARTIAL")

    /// Provides a means by which an IMAP client can use URLs carrying authorization
    /// to access limited message data on the IMAP server - RFC 4467.
    public static let authenticatedURL = Self(unchecked: "URLAUTH")

    /// Provides additional mechanisms to `.search` such as *OLDER*, *YOUNGER* to reduce
    /// network traffic and the computation required by clients.
    public static let within = Self(unchecked: "WITHIN")

    /// Enables GMail-specific features.
    /// https://developers.google.com/gmail/imap/imap-extensions
    public static let gmailExtensions = Self(unchecked: "X-GM-EXT-1")

    /// Yahoo Mail Highest Modification-Sequence
    public static let yahooMailHighestModificationSequence = Self(unchecked: "XYMHIGHESTMODSEQ")

    /// The server supports non-synchronising literals - RFC 7888.
    public static let literalPlus = Self(unchecked: "LITERAL+")

    /// RFC 7888 LITERAL-
    public static let literalMinus = Self(unchecked: "LITERAL-")

    /// RFC 8970 - IMAP4 Extension: Message Preview Generation
    ///
    /// Allows a client to request a server-generated abbreviated text representation of message data.
    public static let preview = Self(unchecked: "PREVIEW")

    /// RFC 9586 UIDONLY
    ///
    /// Message numbers are not returned in responses and cannot be used in requests once this extension is enabled.
    public static let uidOnly = Self(unchecked: "UIDONLY")

    /// MESSAGELIMIT
    ///
    /// Allows servers to announce a limit on the number of messages that can be processed in a single command.
    public static func messageLimit(_ count: Int) -> Self {
        Self("MESSAGELIMIT=\(count)")
    }

    /// SAVELIMIT
    ///
    /// Allows servers to announce a limit on the number of messages that can be processed in a single command.
    public static func saveLimit(_ count: Int) -> Self {
        Self("SAVELIMIT=\(count)")
    }

    /// Creates a new *AUTH* capability.
    /// - parameter type: The `AuthenticationMechanism`.
    /// - returns: A new `Capability`.
    public static func authenticate(_ type: AuthenticationMechanism) -> Self {
        Self("AUTH=\(type.rawValue)")
    }

    /// Creates a new *CONTEXT* capability.
    /// - parameter type: The `ContextKind`.
    /// - returns: A new `Capability`.
    public static func context(_ type: ContextKind) -> Self {
        Self("CONTEXT=\(type.rawValue)")
    }

    /// Creates a new *SORT* capability.
    /// - parameter type: The `SortKind`.
    /// - returns: A new `Capability`.
    public static func sort(_ type: SortKind?) -> Self {
        if let type = type {
            return Self("SORT=\(type.rawValue)")
        } else {
            return Self("SORT")
        }
    }

    /// Creates a new *UTF8* capability.
    /// - parameter type: The `UTF8Kind`.
    /// - returns: A new `Capability`.
    public static func utf8(_ type: UTF8Kind) -> Self {
        Self("UTF8=\(type.rawValue)")
    }

    /// Creates a new *THREAD* capability.
    /// - parameter type: The `ThreadKind`.
    /// - returns: A new `Capability`.
    public static func thread(_ type: ThreadKind) -> Self {
        Self("THREAD=\(type.rawValue)")
    }

    /// Creates a new *STATUS* capability.
    /// - parameter type: The `STATUSKind`.
    /// - returns: A new `Capability`.
    public static func status(_ type: StatusKind) -> Self {
        Self("STATUS=\(type.rawValue)")
    }

    /// Creates a new *RIGHTS* capability.
    /// - parameter type: The `RightsKind`.
    /// - returns: A new `Capability`.
    public static func rights(_ type: RightsKind) -> Self {
        Self("RIGHTS=\(type.rawValue)")
    }

    /// Creates a new *COMPRESSION* capability.
    /// - parameter type: The `CompressionKind`.
    /// - returns: A new `Capability`.
    public static func compression(_ type: CompressionKind) -> Self {
        Self("COMPRESS=\(type.rawValue)")
    }
}

// MARK: - Capability to String conversion

extension String {
    public init(_ capability: Capability) {
        self = capability.rawValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeCapability(_ capability: Capability) -> Int {
        self.writeString(capability.rawValue)
    }

    @discardableResult mutating func writeCapabilityData(_ data: [Capability]) -> Int {
        self.writeString("CAPABILITY") +
            self.writeArray(data, prefix: " ", parenthesis: false) { (capability, self) -> Int in
                self.writeCapability(capability)
            }
    }
}
