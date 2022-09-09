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

// TODO: Convert to struct
/// Additional, structured status information for `UntaggedStatus` and `TaggedResponse`.
///
/// `ResponseTextCode` contains the parsed part, whereas the human-readable description
/// is captured by `ResponseText`’s `text`.
///
/// See also https://www.iana.org/assignments/imap-response-codes/imap-response-codes.xhtml
///
/// - Note: This `enum` is `indirect` to work around the compiler generating large types. (86318397)
public indirect enum ResponseTextCode: Hashable {
    /// The human-readable text contains a special alert that MUST be
    /// presented to the user in a fashion that calls the user's
    /// attention to the message.
    case alert

    /// A SEARCH failed because the given charset is not supported by
    /// this implementation.  If the optional list of charsets is
    /// given, this lists the charsets that are supported by this
    /// implementation.
    case badCharset([String])

    /// Followed by a list of capabilities.  This can appear in the
    /// initial OK or PREAUTH response to transmit an initial
    /// capabilities list.  This makes it unnecessary for a client to
    /// send a separate CAPABILITY command if it recognizes this
    /// response.
    case capability([Capability])

    /// The human-readable text represents an error in parsing the
    /// [RFC-2822] header or [MIME-IMB] headers of a message in the
    /// mailbox.
    case parse

    /// Followed by a parenthesized list of flags, indicates which of
    /// the known flags the client can change permanently.  Any flags
    /// that are in the FLAGS untagged response, but not the
    /// PERMANENTFLAGS list, can not be set permanently.  If the client
    /// attempts to STORE a flag that is not in the PERMANENTFLAGS
    /// list, the server will either ignore the change or store the
    /// state change for the remainder of the current session only.
    /// The PERMANENTFLAGS list can also include the special flag \*,
    /// which indicates that it is possible to create new keywords by
    /// attempting to store those flags in the mailbox.
    case permanentFlags([PermanentFlag])

    /// The mailbox is selected read-only, or its access while selected
    /// has changed from read-write to read-only.
    case readOnly

    /// The mailbox is selected read-write, or its access while
    /// selected has changed from read-only to read-write.
    case readWrite

    /// An APPEND or COPY attempt is failing because the target mailbox
    /// does not exist (as opposed to some other reason).  This is a
    /// hint to the client that the operation can succeed if the
    /// mailbox is first created by the CREATE command.
    case tryCreate

    /// Indicates the next unique identifier value.
    case uidNext(UID)

    /// Indicates the unique identifier validity value.
    case uidValidity(UIDValidity)

    /// Indicates the number of the first message without the \Seen flag set.
    case unseen(SequenceNumber)

    /// A command was unable to complete because it attempted to perform
    /// an option in a namespace the user does not have access.
    case namespace(NamespaceResponse)

    /// Followed by the UIDVALIDITY of the destination mailbox and the UID
    /// assigned to the appended message in the destination mailbox,
    /// indicates that the message has been appended to the destination
    /// mailbox with that UID.
    case uidAppend(ResponseCodeAppend)

    /// Followed by the UIDVALIDITY of the destination mailbox, a UID set
    /// containing the UIDs of the message(s) in the source mailbox that
    /// were copied to the destination mailbox and containing the UIDs
    /// assigned to the copied message(s) in the destination mailbox,
    /// indicates that the message(s) have been copied to the destination
    /// mailbox with the stated UID(s).
    case uidCopy(ResponseCodeCopy)

    /// The selected mailbox is supported by a mail store that does not
    /// support persistent UIDs; that is, UIDVALIDITY will be different
    /// each time the mailbox is selected.  Consequently, APPEND or COPY
    /// to this mailbox will not return an APPENDUID or COPYUID response
    /// code.
    case uidNotSticky

    /// If the server cannot create a mailbox with the designated special use
    /// defined, for whatever reason, it MUST NOT create the mailbox, and
    /// MUST respond to the CREATE command with a tagged NO response.  If the
    /// reason for the failure is related to the special-use attribute (the
    /// specified special use is not supported or cannot be assigned to the
    /// specified mailbox)
    case useAttribute

    /// A generic catch-all case to support response codes sent by future extensions.
    case other(String, String?)

    /// The server refused to save a SEARCH (SAVE) result,
    /// for example, if an internal limit on the number of saved results is
    /// reached.
    case notSaved

    /// The CLOSED response code serves as a boundary between responses for the
    /// previously opened mailbox (which was closed) and the newly selected
    /// mailbox: all responses before the CLOSED response code relate to the
    /// mailbox that was closed, and all subsequent responses relate to the
    /// newly opened mailbox.
    case closed

    /// A server that doesn't support the persistent storage of mod-sequences
    /// for the mailbox MUST send the OK untagged response including NOMODSEQ
    /// response code with every successful SELECT or EXAMINE command.
    case noModificationSequence

    /// Used with an OK response to the STORE command.  (It can also be used in a NO
    /// response.)
    case modified(LastCommandSet<MessageIdentifierSet<UnknownMessageIdentifier>>)

    /// A server supporting the persistent storage of mod-sequences for the mailbox
    /// MUST send the OK untagged response including HIGHESTMODSEQ response
    /// code with every successful SELECT or EXAMINE command:
    case highestModificationSequence(ModificationSequenceValue)

    /// If there are any entries with values
    /// larger than the MAXSIZE limit, the server MUST include the METADATA
    /// LONGENTRIES response code in the tagged OK response for the
    /// GETMETADATA command.  The METADATA LONGENTRIES response code returns
    /// the size of the biggest entry value requested by the client that
    /// exceeded the MAXSIZE limit.
    case metadataLongEntries(Int)

    /// the server is unable to set an annotation because the size of its value is too large. The maximum size
    /// is contained in the response code.
    case metadataMaxsize(Int)

    /// The server is unable to set a new annotation because the maximum
    /// number of allowed annotations has already been reached
    case metadataTooMany

    /// The server is unable to set a new annotation because it does not
    /// support private annotations on one of the specified mailboxes
    case metadataNoPrivate

    /// Returned in an untagged OK response in
    /// response to a RESETKEY, SELECT, or EXAMINE command.  In the case of
    /// the RESETKEY command, this status response code can be sent in the
    /// tagged OK response instead of requiring a separate untagged OK
    /// response.
    case urlMechanisms([MechanismBase64])

    /// An IMAP4 server MAY respond with an untagged BYE and a REFERRAL
    /// response code that contains an IMAP URL to a home server if it is not
    /// willing to accept connections and wishes to direct the client to
    /// another IMAP4 server.
    case referral(IMAPURL)

    /// Temporary failure because a subsystem is down.
    case unavailable

    /// Authentication failed for some reason on which the server
    /// is unwilling to elaborate.
    case authenticationFailed

    // Authentication succeeded in using the authentication identity,
    // but the server cannot or will not allow the authentication
    // identity to act as the requested authorization identity.  This
    // is only applicable when the authentication and authorization
    // identities are different.
    case authorizationFailed

    /// Either authentication succeeded or the server no longer had the
    /// necessary data; either way, access is no longer permitted using
    /// that passphrase.  The client or user should get a new
    /// passphrase.
    case expired

    /// The operation is not permitted due to a lack of privacy.  If
    /// Transport Layer Security (TLS) is not in use, the client could
    /// try STARTTLS (see Section 6.2.1 of [RFC3501]) and then repeat
    /// the operation.
    case privacyRequired

    /// The user should contact the system administrator or support
    /// desk.
    case contactAdmin

    /// The access control system (e.g., Access Control List (ACL), see
    /// [RFC4314]) does not permit this user to carry out an operation,
    /// such as selecting or creating a mailbox.
    case noPermission

    /// An operation has not been carried out because it involves
    /// sawing off a branch someone else is sitting on.  Someone else
    /// may be holding an exclusive lock needed for this operation, or
    /// the operation may involve deleting a resource someone else is
    /// using, typically a mailbox.
    case inUse

    /// Someone else has issued an EXPUNGE for the same mailbox.  The///
    /// client may want to issue NOOP soon.  [RFC2180] discusses this
    /// subject in depth.
    case expungeIssued

    /// The server discovered that some relevant data (e.g., the
    /// mailbox) are corrupt.  This response code does not include any
    /// information about what's corrupt, but the server can write that
    /// to its logfiles.
    case corruption

    /// The server encountered a bug in itself or violated one of its
    /// own invariants.
    case serverBug

    /// The server has detected a client bug.  This can accompany all
    /// of OK, NO, and BAD, depending on what the client bug is.
    case clientBug

    /// The operation violates some invariant of the server and can
    /// never succeed.
    case cannot

    /// The operation ran up against an implementation limit of some
    /// kind, such as the number of flags on a single message or the
    /// number of flags used in a mailbox.
    case limit

    /// The user would be over quota after the operation.  (The user
    /// may or may not be over quota already.)
    /// Note that if the server sends OVERQUOTA but doesn't support the
    /// IMAP QUOTA extension defined by [RFC2087], then there is a
    /// quota, but the client cannot find out what the quota is.
    case overQuota

    /// The operation attempts to create something that already exists,
    /// such as when the CREATE or RENAME directories attempt to create
    /// a mailbox and there is already one of that name.
    case alreadyExists

    /// The operation attempts to delete something that does not exist.
    /// Similar to ALREADYEXISTS.
    case nonExistent

    /// Compression is active.
    case compressionActive
}

extension ResponseTextCode {
    public static func modified(_ set: MessageIdentifierSet<UID>) -> Self {
        .modified(.set(.init(set)))
    }

    public static func modified(_ set: MessageIdentifierSet<SequenceNumber>) -> Self {
        .modified(.set(.init(set)))
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeResponseTextCode(_ code: ResponseTextCode) -> Int {
        switch code {
        case .alert:
            return self.writeString("ALERT")
        case .badCharset(let charsets):
            return self.writeResponseTextCode_badCharsets(charsets)
        case .capability(let data):
            return self.writeCapabilityData(data)
        case .parse:
            return self.writeString("PARSE")
        case .permanentFlags(let flags):
            return
                self.writeString("PERMANENTFLAGS ") +
                self.writePermanentFlags(flags)
        case .readOnly:
            return self.writeString("READ-ONLY")
        case .readWrite:
            return self.writeString("READ-WRITE")
        case .tryCreate:
            return self.writeString("TRYCREATE")
        case .uidNext(let number):
            return self.writeString("UIDNEXT ") + self.writeMessageIdentifier(number)
        case .uidValidity(let number):
            return self.writeString("UIDVALIDITY ") + self.writeUIDValidity(number)
        case .unseen(let number):
            return self.writeString("UNSEEN ") + self.writeSequenceNumber(number)
        case .other(let atom, let string):
            return self.writeResponseTextCode_other(atom: atom, string: string)
        case .namespace(let namesapce):
            return self.writeNamespaceResponse(namesapce)
        case .uidCopy(let data):
            return self.writeResponseCodeCopy(data)
        case .uidAppend(let data):
            return self.writeResponseCodeAppend(data)
        case .uidNotSticky:
            return self.writeString("UIDNOTSTICKY")
        case .useAttribute:
            return self.writeString("USEATTR")
        case .notSaved:
            return self.writeString("NOTSAVED")
        case .closed:
            return self.writeString("CLOSED")
        case .noModificationSequence:
            return self.writeString("NOMODSEQ")
        case .modified(let set):
            return self.writeString("MODIFIED ") + self.writeLastCommandSet(set)
        case .highestModificationSequence(let val):
            return self.writeString("HIGHESTMODSEQ ") + self.writeModificationSequenceValue(val)
        case .metadataLongEntries(let num):
            return self.writeString("METADATA LONGENTRIES \(num)")
        case .metadataMaxsize(let num):
            return self.writeString("METADATA MAXSIZE \(num)")
        case .metadataTooMany:
            return self.writeString("METADATA TOOMANY")
        case .metadataNoPrivate:
            return self.writeString("METADATA NOPRIVATE")
        case .urlMechanisms(let array):
            return self.writeString("URLMECH INTERNAL") +
                self.writeArray(array, prefix: " ", parenthesis: false) { mechanism, buffer in
                    buffer.writeMechanismBase64(mechanism)
                }
        case .referral(let url):
            return self.writeString("REFERRAL ") + self.writeIMAPURL(url)
        case .unavailable:
            return self.writeString("UNAVAILABLE")
        case .authenticationFailed:
            return self.writeString("AUTHENTICATIONFAILED")
        case .authorizationFailed:
            return self.writeString("AUTHORIZATIONFAILED")
        case .expired:
            return self.writeString("EXPIRED")
        case .privacyRequired:
            return self.writeString("PRIVACYREQUIRED")
        case .contactAdmin:
            return self.writeString("CONTACTADMIN")
        case .noPermission:
            return self.writeString("NOPERM")
        case .inUse:
            return self.writeString("INUSE")
        case .expungeIssued:
            return self.writeString("EXPUNGEISSUED")
        case .corruption:
            return self.writeString("CORRUPTION")
        case .serverBug:
            return self.writeString("SERVERBUG")
        case .clientBug:
            return self.writeString("CLIENTBUG")
        case .cannot:
            return self.writeString("CANNOT")
        case .limit:
            return self.writeString("LIMIT")
        case .overQuota:
            return self.writeString("OVERQUOTA")
        case .alreadyExists:
            return self.writeString("ALREADYEXISTS")
        case .nonExistent:
            return self.writeString("NONEXISTENT")
        case .compressionActive:
            return self.writeString("COMPRESSIONACTIVE")
        }
    }

    private mutating func writeResponseTextCode_badCharsets(_ charsets: [String]) -> Int {
        self.writeString("BADCHARSET") +
            self.write(if: charsets.count >= 1) {
                self.writeSpace() +
                    self.writeArray(charsets) { (charset, self) in
                        self.writeString(charset)
                    }
            }
    }

    private mutating func writeResponseTextCode_other(atom: String, string: String?) -> Int {
        self.writeString(atom) +
            self.writeIfExists(string) { (string) -> Int in
                self.writeString(" \(string)")
            }
    }
}

extension ResponseTextCode: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeResponseTextCode(self)
        }
    }
}
