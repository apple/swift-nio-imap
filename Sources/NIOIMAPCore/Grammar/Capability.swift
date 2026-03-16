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

/// A capability advertised by a server to indicate supported functionality.
///
/// A server advertises its capabilities in response to a CAPABILITY command or automatically in greeting and
/// response codes. Each capability name indicates a feature or extension that the server supports. Clients must not assume
/// a capability is present unless explicitly advertised by the server.
///
/// Capabilities may be simple (like `STARTTLS`) or configurable (like `AUTH=GSSAPI`). Configurable capabilities
/// contain an equals sign separating the capability name from its configuration value. Use the name and value
/// properties to parse these components.
///
/// ### Example
///
/// ```
/// S: * CAPABILITY IMAP4rev1 STARTTLS AUTH=GSSAPI XPIG-LATIN
/// ```
///
/// This server response advertises capabilities: `IMAP4rev1` (simple), `STARTTLS` (simple), `AUTH=GSSAPI`
/// (configurable with name `AUTH` and value `GSSAPI`), and `XPIG-LATIN` (custom vendor extension).
///
/// - SeeAlso: [RFC 3501 Section 7.2.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.1)
/// - SeeAlso: <doc:SupportedExtensions>
public struct Capability: Hashable, Sendable {
    /// The raw string value of the capability.
    var rawValue: String
    private var splitIndex: String.Index?

    /// The name of the capability. For simple capabilities such as `STARTTLS`, the value
    /// will simply be `STARTTLS`. For configurable capabilities such as `AUTH=GSSAPI`, the value
    /// will be `AUTH`.
    public var name: String {
        guard let index = self.splitIndex else {
            return self.rawValue
        }
        return String(self.rawValue[..<index])
    }

    /// If the capability is _simple_, e.g. `STARTTLS`, then the value will be `nil`.
    /// Otherwise, if the capability is configurable such as `AUTH=GSSAPI`, then the value will
    /// be `GSSAPI`.
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
    /// Wraps the context type component of extended search and sort capabilities.
    ///
    /// Context kinds indicate which protocol extension is being used for search operations. These are used in combination
    /// with context(_:) to form capabilities like `CONTEXT=SEARCH` or `CONTEXT=SORT`.
    ///
    /// - SeeAlso: [RFC 4731 ESEARCH Extension](https://datatracker.ietf.org/doc/html/rfc4731)
    /// - SeeAlso: [RFC 5256 SORT Extension](https://datatracker.ietf.org/doc/html/rfc5256)
    public struct ContextKind: Hashable, Sendable {
        /// Extended search context (RFC 4731).
        public static let search = Self(unchecked: "SEARCH")

        /// Extended sort context (RFC 5256).
        public static let sort = Self(unchecked: "SORT")

        /// The raw string value of the context kind.
        var rawValue: String

        /// Creates a new context kind from a string.
        ///
        /// The provided value is uppercased for consistency with IMAP protocol conventions.
        ///
        /// - parameter value: The context kind as a string (e.g., SEARCH, SORT).
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps sort algorithm variants supported by a `SORT` extension.
    ///
    /// Sort kinds indicate specific sort capabilities. A server supporting `SORT=DISPLAY` supports
    /// the `DISPLAYFROM` and `DISPLAYTO` sort criteria in addition to base `SORT` criteria.
    ///
    /// - SeeAlso: [RFC 5256 SORT Extension](https://datatracker.ietf.org/doc/html/rfc5256)
    public struct SortKind: Hashable, Sendable {
        /// Display sort kind supporting DISPLAYFROM and DISPLAYTO criteria (RFC 5256).
        public static let display = Self(unchecked: "DISPLAY")

        /// The raw string value of the sort kind.
        var rawValue: String

        /// Creates a new sort kind from a string.
        ///
        /// The provided value is uppercased for consistency with IMAP protocol conventions.
        ///
        /// - parameter value: The sort kind as a string (e.g., DISPLAY).
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps thread algorithm variants supported by a `THREAD` extension.
    ///
    /// Thread kinds specify the algorithm used to group related messages together. Different algorithms
    /// use different criteria to establish parent-child relationships.
    ///
    /// - SeeAlso: [RFC 5256 THREAD Extension](https://datatracker.ietf.org/doc/html/rfc5256)
    public struct ThreadKind: Hashable, Sendable {
        /// ORDEREDSUBJECT threading groups messages by base subject and date (RFC 5256).
        public static let orderedSubject = Self(unchecked: "ORDEREDSUBJECT")

        /// REFERENCES threading groups messages by in-reply-to relationships (RFC 5256).
        public static let references = Self(unchecked: "REFERENCES")

        /// The raw string value of the thread kind.
        var rawValue: String

        /// Creates a new thread kind from a string.
        ///
        /// The provided value is uppercased for consistency with IMAP protocol conventions.
        ///
        /// - parameter value: The thread kind as a string (e.g., ORDEREDSUBJECT, REFERENCES).
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps additional `STATUS` response item types supported by a `STATUS` extension.
    ///
    /// Status kinds specify which additional mailbox status attributes a server can provide beyond
    /// the base RFC 3501 `MESSAGES`, `RECENT`, `UIDNEXT`, `UIDVALIDITY`, and `UNSEEN` attributes.
    ///
    /// - SeeAlso: [RFC 8438 Status Response Extension](https://datatracker.ietf.org/doc/html/rfc8438)
    public struct StatusKind: Hashable, Sendable {
        /// SIZE status kind allows retrieving total mailbox storage size (RFC 8438).
        public static let size = Self(unchecked: "SIZE")

        /// The raw string value of the status kind.
        var rawValue: String

        /// Creates a new status kind from a string.
        ///
        /// The provided value is uppercased for consistency with IMAP protocol conventions.
        ///
        /// - parameter value: The status kind as a string (e.g., SIZE).
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps UTF-8 encoding support variants.
    ///
    /// UTF-8 kinds specify the level of UTF-8 support offered by the server. When a client enables
    /// a UTF-8 capability, it informs the server that it will send and can receive UTF-8-encoded
    /// strings instead of modified UTF-7 encoding.
    ///
    /// - SeeAlso: [RFC 6855 IMAP Support for UTF-8](https://datatracker.ietf.org/doc/html/rfc6855)
    public struct UTF8Kind: Hashable, Sendable {
        /// ACCEPT UTF-8 kind allows server to send UTF-8-encoded strings (RFC 6855).
        public static let accept = Self(unchecked: "ACCEPT")

        /// The raw string value of the UTF-8 kind.
        var rawValue: String

        /// Creates a new UTF-8 kind from a string.
        ///
        /// The provided value is uppercased for consistency with IMAP protocol conventions.
        ///
        /// - parameter value: The UTF-8 kind as a string (e.g., ACCEPT).
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps access control right sets supported by the `ACL` extension.
    ///
    /// Rights kinds specify permission sets for mailbox access control lists. Each rights code is
    /// a combination of letter codes representing different allowed operations.
    ///
    /// - SeeAlso: [RFC 4314 Section 4 ACL Extension](https://datatracker.ietf.org/doc/html/rfc4314#section-4)
    public struct RightsKind: Hashable, Sendable {
        /// TEKX rights kind represents a common permission set (RFC 4314).
        public static let tekx = Self(unchecked: "TEKX")

        /// The raw string value of the rights kind.
        var rawValue: String

        /// Creates a new rights kind from a string.
        ///
        /// The provided value is uppercased for consistency with IMAP protocol conventions.
        ///
        /// - parameter value: The rights kind as a string (e.g., TEKX).
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// Wraps compression algorithm support types.
    ///
    /// Compression kinds indicate the compression algorithms supported by a server's `COMPRESS` extension.
    /// Clients can enable compression to reduce bandwidth usage on the connection.
    ///
    /// - SeeAlso: [RFC 4978 IMAP Compression](https://datatracker.ietf.org/doc/html/rfc4978)
    public struct CompressionKind: Hashable, Sendable {
        /// DEFLATE compression algorithm (RFC 1951).
        public static let deflate = Self(unchecked: "DEFLATE")

        /// The raw string value of the compression kind.
        var rawValue: String

        /// Creates a new compression kind from a string.
        ///
        /// The provided value is uppercased for consistency with IMAP protocol conventions.
        ///
        /// - parameter value: The compression kind as a string (e.g., DEFLATE).
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    /// The `ACL` capability indicates the server supports access control lists for mailbox permissions.
    ///
    /// - SeeAlso: [RFC 2086](https://datatracker.ietf.org/doc/html/rfc2086)
    public static let acl = Self(unchecked: "ACL")

    /// The `ANNOTATE-EXPERIMENT-1` capability indicates experimental support for message annotations and metadata.
    ///
    /// - SeeAlso: [RFC 5257](https://datatracker.ietf.org/doc/html/rfc5257)
    public static let annotateExperiment1 = Self(unchecked: "ANNOTATE-EXPERIMENT-1")

    /// The `BINARY` capability indicates the server supports sending binary message data without encoding.
    ///
    /// - SeeAlso: [RFC 3516](https://datatracker.ietf.org/doc/html/rfc3516)
    public static let binary = Self(unchecked: "BINARY")

    /// The `CATENATE` capability indicates the server supports creating messages by combining new and existing message data.
    ///
    /// - SeeAlso: [RFC 4469](https://datatracker.ietf.org/doc/html/rfc4469)
    public static let catenate = Self(unchecked: "CATENATE")

    /// The `CHILDREN` capability indicates the server can determine whether a mailbox has children without listing them.
    ///
    /// - SeeAlso: [RFC 3348](https://datatracker.ietf.org/doc/html/rfc3348)
    public static let children = Self(unchecked: "CHILDREN")

    /// The `CONDSTORE` capability indicates the server maintains modification sequence values for tracking changes.
    ///
    /// - SeeAlso: [RFC 7162](https://datatracker.ietf.org/doc/html/rfc7162)
    /// - SeeAlso: ``qresync``
    public static let condStore = Self(unchecked: "CONDSTORE")

    /// The `CREATE-SPECIAL-USE` capability indicates the server supports creating mailboxes with special-use attributes.
    ///
    /// - SeeAlso: [RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154)
    /// - SeeAlso: ``specialUse``
    public static let createSpecialUse = Self(unchecked: "CREATE-SPECIAL-USE")

    /// The `ENABLE` capability indicates the server supports the `ENABLE` command for capability negotiation.
    ///
    /// - SeeAlso: [RFC 5161](https://datatracker.ietf.org/doc/html/rfc5161)
    public static let enable = Self(unchecked: "ENABLE")

    /// The `ESEARCH` capability indicates the server supports the ESEARCH command (RFC 4731).
    ///
    /// This capability indicates server support for the `SEARCH` command with extended result options
    /// (like `RETURN (MIN MAX COUNT ALL)`), as defined in RFC 4731. Note: This capability is **not**
    /// about the ESEARCH response format itself. The `ESEARCH` response format can be returned by
    /// RFC 7377 MULTIMAILBOX SEARCH commands even without this capability.
    ///
    /// - SeeAlso: [RFC 4731](https://datatracker.ietf.org/doc/html/rfc4731) - ESEARCH Command Extension
    /// - SeeAlso: [RFC 7377](https://datatracker.ietf.org/doc/html/rfc7377) - MULTIMAILBOX SEARCH (may return `ESEARCH` responses without requiring this capability)
    public static let extendedSearch = Self(unchecked: "ESEARCH")

    /// The `ESORT` capability indicates the server supports extended sort result forms.
    ///
    /// - SeeAlso: [RFC 7377](https://datatracker.ietf.org/doc/html/rfc7377)
    public static let esort = Self(unchecked: "ESORT")

    /// The `FILTERS` capability indicates the server supports persistent server-side searches.
    ///
    /// - SeeAlso: [RFC 5466](https://datatracker.ietf.org/doc/html/rfc5466)
    public static let filters = Self(unchecked: "FILTERS")

    /// The `ID` capability indicates the server supports the ID command for exchanging implementation information.
    ///
    /// - SeeAlso: [RFC 2971](https://datatracker.ietf.org/doc/html/rfc2971)
    public static let id = Self(unchecked: "ID")

    /// The `IDLE` capability indicates the server supports the `IDLE` command for real-time message notifications.
    ///
    /// - SeeAlso: [RFC 2177](https://datatracker.ietf.org/doc/html/rfc2177)
    public static let idle = Self(unchecked: "IDLE")

    /// The `IMAP4rev1` capability indicates the server implements IMAP protocol version 4 revision 1.
    ///
    /// - SeeAlso: [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501)
    public static let imap4rev1 = Self(unchecked: "IMAP4rev1")

    /// The `IMAP4` capability is a legacy identifier that servers may advertise. Use `IMAP4rev1` instead.
    ///
    /// - SeeAlso: [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501)
    public static let imap4 = Self(unchecked: "IMAP4")

    /// The `JMAPACCESS` capability indicates the server provides access to JMAP resources via IMAP.
    ///
    /// - SeeAlso: [RFC 9698](https://datatracker.ietf.org/doc/html/rfc9698)
    public static let jmapAccess = Self(unchecked: "JMAPACCESS")

    /// The `LANGUAGE` capability indicates the server supports the LANGUAGE command for selecting response language.
    ///
    /// - SeeAlso: [RFC 5255](https://datatracker.ietf.org/doc/html/rfc5255)
    public static let language = Self(unchecked: "LANGUAGE")

    /// The `LIST-STATUS` capability indicates the server supports returning mailbox status in LIST responses.
    ///
    /// - SeeAlso: [RFC 5819](https://datatracker.ietf.org/doc/html/rfc5819)
    public static let listStatus = Self(unchecked: "LIST-STATUS")

    /// The `LIST-EXTENDED` capability indicates the server supports the extended LIST command with additional options.
    ///
    /// - SeeAlso: [RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258)
    public static let listExtended = Self(unchecked: "LIST-EXTENDED")

    /// The `LOGINDISABLED` capability indicates the server does not support the LOGIN command (use AUTHENTICATE instead).
    ///
    /// - SeeAlso: [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501)
    public static let loginDisabled = Self(unchecked: "LOGINDISABLED")

    /// The `LOGIN-REFERRALS` capability indicates the server may redirect clients to an alternate IMAP server.
    ///
    /// - SeeAlso: [RFC 2221](https://datatracker.ietf.org/doc/html/rfc2221)
    public static let loginReferrals = Self(unchecked: "LOGIN-REFERRALS")

    /// The `APPENDLIMIT` capability advertises the maximum size of messages that can be appended to the mailbox.
    ///
    /// - SeeAlso: [RFC 7889](https://datatracker.ietf.org/doc/html/rfc7889)
    /// - SeeAlso: ``appendLimit(_:)``
    public static let mailboxSpecificAppendLimit = Self(unchecked: "APPENDLIMIT")

    /// The `METADATA` capability indicates the server supports storing and retrieving user and server annotations.
    ///
    /// - SeeAlso: [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464)
    /// - SeeAlso: ``metadataServer``
    public static let metadata = Self(unchecked: "METADATA")

    /// The `METADATA-SERVER` capability indicates the server supports server-level (not per-mailbox) annotations.
    ///
    /// - SeeAlso: [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464)
    /// - SeeAlso: ``metadata``
    public static let metadataServer = Self(unchecked: "METADATA-SERVER")

    /// The `MOVE` capability indicates the server supports the `MOVE` command for atomic message relocation.
    ///
    /// - SeeAlso: [RFC 6851](https://datatracker.ietf.org/doc/html/rfc6851)
    public static let move = Self(unchecked: "MOVE")

    /// The `MULTISEARCH` capability indicates the server supports searching across multiple mailboxes in one command.
    ///
    /// - SeeAlso: [RFC 7377](https://datatracker.ietf.org/doc/html/rfc7377)
    public static let multiSearch = Self(unchecked: "MULTISEARCH")

    /// The `NAMESPACE` capability indicates the server supports the `NAMESPACE` command for accessing multiple mailbox namespaces.
    ///
    /// - SeeAlso: [RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342)
    public static let namespace = Self(unchecked: "NAMESPACE")

    /// The `OBJECTID` capability indicates the server supports object identifiers for messages and mailboxes.
    ///
    /// - SeeAlso: [RFC 8474](https://datatracker.ietf.org/doc/html/rfc8474)
    public static let objectID = Self(unchecked: "OBJECTID")

    /// The `QRESYNC` capability indicates the server supports quick resynchronization for mailbox reconciliation.
    ///
    /// - SeeAlso: [RFC 7162](https://datatracker.ietf.org/doc/html/rfc7162)
    /// - SeeAlso: ``condStore``
    public static let qresync = Self(unchecked: "QRESYNC")

    /// The `QUOTA` capability indicates the server supports resource quota management for mailboxes.
    ///
    /// - SeeAlso: [RFC 2087](https://datatracker.ietf.org/doc/html/rfc2087)
    public static let quota = Self(unchecked: "QUOTA")

    /// The `SASL-IR` capability indicates the server supports initial response data with the `AUTHENTICATE` command.
    ///
    /// - SeeAlso: [RFC 4959](https://datatracker.ietf.org/doc/html/rfc4959)
    public static let saslIR = Self(unchecked: "SASL-IR")

    /// The `SEARCHRES` capability indicates the server supports the `$` reference to the last search result.
    ///
    /// - SeeAlso: [RFC 5182](https://datatracker.ietf.org/doc/html/rfc5182)
    public static let searchRes = Self(unchecked: "SEARCHRES")

    /// The `SPECIAL-USE` capability indicates the server supports special-use mailbox attributes like Drafts and Sent.
    ///
    /// - SeeAlso: [RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154)
    /// - SeeAlso: ``createSpecialUse``
    public static let specialUse = Self(unchecked: "SPECIAL-USE")

    /// The `STARTTLS` capability indicates the server supports the `STARTTLS` command to upgrade to an encrypted connection.
    ///
    /// - SeeAlso: [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501)
    public static let startTLS = Self(unchecked: "STARTTLS")

    /// The `UIDPLUS` capability indicates the server supports UIDPLUS extensions for UID responses and UID EXPUNGE.
    ///
    /// - SeeAlso: [RFC 4315](https://datatracker.ietf.org/doc/html/rfc4315)
    public static let uidPlus = Self(unchecked: "UIDPLUS")

    /// The `UIDBATCHES` capability indicates the server supports partitioning messages into evenly-sized UID batches.
    ///
    /// - SeeAlso: [RFC 9618](https://datatracker.ietf.org/doc/html/draft-ietf-mailmaint-imap-uidbatches-22)
    public static let uidBatches = Self(unchecked: "UIDBATCHES")

    /// The `UNSELECT` capability indicates the server supports the `UNSELECT` command to close without expunging.
    ///
    /// - SeeAlso: [RFC 3691](https://datatracker.ietf.org/doc/html/rfc3691)
    public static let unselect = Self(unchecked: "UNSELECT")

    /// The `URL-PARTIAL` capability indicates the server supports partial IMAP URLs in `CATENATE` and `URLAUTH` extensions.
    ///
    /// - SeeAlso: [RFC 5092](https://datatracker.ietf.org/doc/html/rfc5092)
    public static let partialURL = Self(unchecked: "URL-PARTIAL")

    /// The `PARTIAL` capability indicates the server supports paged SEARCH and FETCH results.
    ///
    /// - SeeAlso: [RFC 9394](https://datatracker.ietf.org/doc/html/rfc9394)
    public static let partial = Self(unchecked: "PARTIAL")

    /// The `URLAUTH` capability indicates the server supports IMAP URLs with authorization data.
    ///
    /// - SeeAlso: [RFC 4467](https://datatracker.ietf.org/doc/html/rfc4467)
    public static let authenticatedURL = Self(unchecked: "URLAUTH")

    /// The `WITHIN` capability indicates the server supports the `OLDER` and `YOUNGER` search criteria.
    ///
    /// - SeeAlso: [RFC 5032](https://datatracker.ietf.org/doc/html/rfc5032)
    public static let within = Self(unchecked: "WITHIN")

    /// The `X-GM-EXT-1` capability indicates the server supports Gmail-specific IMAP extensions.
    ///
    /// - SeeAlso: [Gmail IMAP Extensions](https://developers.google.com/gmail/imap/imap-extensions)
    public static let gmailExtensions = Self(unchecked: "X-GM-EXT-1")

    /// The `XYMHIGHESTMODSEQ` capability indicates the server tracks the highest modification sequence for Yahoo Mail.
    ///
    /// - SeeAlso: [Yahoo Mail IMAP](https://help.yahoo.com/kb/SLN6556.html)
    public static let yahooMailHighestModificationSequence = Self(unchecked: "XYMHIGHESTMODSEQ")

    /// The `LITERAL+` capability indicates the server supports non-synchronizing literals for efficient transmission.
    ///
    /// - SeeAlso: [RFC 7888](https://datatracker.ietf.org/doc/html/rfc7888)
    /// - SeeAlso: ``literalMinus``
    public static let literalPlus = Self(unchecked: "LITERAL+")

    /// The `LITERAL-` capability indicates the server supports literal minus for selective synchronizing.
    ///
    /// - SeeAlso: [RFC 7888](https://datatracker.ietf.org/doc/html/rfc7888)
    /// - SeeAlso: ``literalPlus``
    public static let literalMinus = Self(unchecked: "LITERAL-")

    /// The `PREVIEW` capability indicates the server can generate server-side message preview text.
    ///
    /// - SeeAlso: [RFC 8970](https://datatracker.ietf.org/doc/html/rfc8970)
    public static let preview = Self(unchecked: "PREVIEW")

    /// The `UIDONLY` capability indicates the server does not return message sequence numbers when enabled.
    ///
    /// - SeeAlso: [RFC 9586](https://datatracker.ietf.org/doc/html/rfc9586)
    /// - SeeAlso: ``saveLimit(_:)``
    public static let uidOnly = Self(unchecked: "UIDONLY")

    /// Creates an `APPENDLIMIT=<count>` capability advertising the maximum message size for the mailbox.
    ///
    /// - SeeAlso: [RFC 7889](https://datatracker.ietf.org/doc/html/rfc7889)
    public static func appendLimit(_ count: Int) -> Self {
        Self("APPENDLIMIT=\(count)")
    }

    /// Creates a `MESSAGELIMIT=<count>` capability advertising the maximum message count for operations.
    ///
    /// - SeeAlso: [RFC 9738](https://datatracker.ietf.org/doc/html/rfc9738)
    public static func messageLimit(_ count: Int) -> Self {
        Self("MESSAGELIMIT=\(count)")
    }

    /// Creates a `SAVELIMIT=<count>` capability advertising the maximum message count for SAVE operations.
    ///
    /// - SeeAlso: [RFC 9586](https://datatracker.ietf.org/doc/html/rfc9586)
    /// - SeeAlso: ``uidOnly``
    public static func saveLimit(_ count: Int) -> Self {
        Self("SAVELIMIT=\(count)")
    }

    /// Creates an `AUTH=<mechanism>` capability for the specified SASL mechanism.
    ///
    /// - SeeAlso: [RFC 4959](https://datatracker.ietf.org/doc/html/rfc4959)
    public static func authenticate(_ type: AuthenticationMechanism) -> Self {
        Self("AUTH=\(type.rawValue)")
    }

    /// Creates a `CONTEXT=<kind>` capability for the specified search or sort context.
    ///
    /// - SeeAlso: [RFC 4731](https://datatracker.ietf.org/doc/html/rfc4731)
    public static func context(_ type: ContextKind) -> Self {
        Self("CONTEXT=\(type.rawValue)")
    }

    /// Creates a `SORT` or `SORT=<kind>` capability for the specified sort algorithm.
    ///
    /// - SeeAlso: [RFC 5256](https://datatracker.ietf.org/doc/html/rfc5256)
    public static func sort(_ type: SortKind?) -> Self {
        guard let type = type else {
            return Self("SORT")
        }
        return Self("SORT=\(type.rawValue)")
    }

    /// Creates a `UTF8=<kind>` capability for the specified UTF-8 support level.
    ///
    /// - SeeAlso: [RFC 6855](https://datatracker.ietf.org/doc/html/rfc6855)
    public static func utf8(_ type: UTF8Kind) -> Self {
        Self("UTF8=\(type.rawValue)")
    }

    /// Creates a `THREAD=<kind>` capability for the specified threading algorithm.
    ///
    /// - SeeAlso: [RFC 5256](https://datatracker.ietf.org/doc/html/rfc5256)
    public static func thread(_ type: ThreadKind) -> Self {
        Self("THREAD=\(type.rawValue)")
    }

    /// Creates a `STATUS=<kind>` capability for the specified status attribute type.
    ///
    /// - SeeAlso: [RFC 8438](https://datatracker.ietf.org/doc/html/rfc8438)
    public static func status(_ type: StatusKind) -> Self {
        Self("STATUS=\(type.rawValue)")
    }

    /// Creates a `RIGHTS=<kind>` capability for the specified access control right set.
    ///
    /// - SeeAlso: [RFC 4314](https://datatracker.ietf.org/doc/html/rfc4314)
    public static func rights(_ type: RightsKind) -> Self {
        Self("RIGHTS=\(type.rawValue)")
    }

    /// Creates a `COMPRESS=<kind>` capability for the specified compression algorithm.
    ///
    /// - SeeAlso: [RFC 4978](https://datatracker.ietf.org/doc/html/rfc4978)
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
        self.writeString("CAPABILITY")
            + self.writeArray(data, prefix: " ", parenthesis: false) { (capability, self) -> Int in
                self.writeCapability(capability)
            }
    }
}
