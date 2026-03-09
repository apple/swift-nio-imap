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
/// Structured status codes sent with server responses.
///
/// Response text codes provide machine-readable status information accompanying tagged responses
/// and some untagged responses. They indicate the reason for command success or failure, provide
/// mailbox status updates, or convey extension-specific information. Servers send these codes
/// within square brackets in the response text (e.g., `[TRYCREATE]`, `[UIDVALIDITY 1234]`).
/// See [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1) for the
/// base protocol codes, and the IMAP extensions for domain-specific codes.
///
/// These codes are distinct from the human-readable text in ``ResponseText``, which is designed
/// for user display. The codes here are for programmatic use.
/// See the [IANA IMAP Response Codes registry](https://www.iana.org/assignments/imap-response-codes/imap-response-codes.xhtml)
/// for the complete list of standardized codes.
///
/// ### Examples
///
/// ```
/// S: * OK [UIDVALIDITY 1234] server response
/// S: A001 OK [UIDNEXT 42] APPEND completed
/// S: A002 NO [TRYCREATE] Mailbox does not exist
/// ```
///
/// The code `[UIDVALIDITY 1234]` is wrapped as ``ResponseTextCode/uidValidity(_:)``,
/// `[UIDNEXT 42]` as ``ResponseTextCode/uidNext(_:)``, and `[TRYCREATE]` as ``ResponseTextCode/tryCreate``.
/// The text after the code (if any) is stored separately in ``ResponseText/text``.
///
/// - Note: This `enum` is `indirect` to work around the compiler generating large types. (86318397)
public indirect enum ResponseTextCode: Hashable, Sendable {
    /// The human-readable text contains a special alert that MUST be presented to the user.
    ///
    /// This code indicates that the accompanying text is a special alert that requires user
    /// attention. The client should display this message in a way that is noticeable to the end user.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case alert

    /// The operation attempts to create something that already exists.
    ///
    /// This code indicates that the operation failed because it would create a duplicate. For example,
    /// CREATE or RENAME commands fail if the target mailbox name already exists.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case alreadyExists

    /// A SEARCH command failed because the specified character set is unsupported.
    ///
    /// This code indicates that a SEARCH command referenced a character set that the server does not
    /// support. The optional list of character sets indicates which sets are supported by the server,
    /// allowing the client to retry with a supported charset.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case badCharset([String])

    /// Followed by a list of supported capabilities.
    ///
    /// This code may appear in the initial OK or PREAUTH response to transmit the server's capability list.
    /// This allows the client to learn the server's capabilities without sending a separate CAPABILITY command.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case capability([Capability])

    /// The human-readable text represents an error in parsing message headers.
    ///
    /// This code indicates that the server encountered an error while parsing the [RFC-2822] headers
    /// or [MIME] headers of a message in the mailbox. This typically indicates message corruption.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case parse

    /// Followed by a list of flags that the client can change permanently.
    ///
    /// This code lists the flags that the client is allowed to store permanently in the selected mailbox.
    /// Flags not in this list may only be stored for the current session. The special flag `\*` indicates
    /// that new keywords can be created by attempting to store them.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case permanentFlags([PermanentFlag])

    /// The selected mailbox is read-only.
    ///
    /// This code indicates that the mailbox is selected in read-only mode, or that its access has
    /// changed from read-write to read-only. The client cannot store messages, delete messages, or
    /// modify flags in a read-only mailbox.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case readOnly

    /// The selected mailbox is read-write.
    ///
    /// This code indicates that the mailbox is selected in read-write mode, or that its access has
    /// changed from read-only to read-write. The client can store messages, delete messages, and
    /// modify flags in a read-write mailbox.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case readWrite

    /// An APPEND or COPY operation failed because the target mailbox does not exist.
    ///
    /// This code suggests that the operation can succeed if the mailbox is first created using the
    /// CREATE command. This is a hint to the client about how to recover from the failure.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case tryCreate

    /// Indicates the next unique identifier value.
    ///
    /// This code contains the UID that will be assigned to the next message appended to the selected mailbox.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case uidNext(UID)

    /// Indicates the unique identifier validity value.
    ///
    /// This code contains the UIDVALIDITY value for the selected mailbox. The client must remember this
    /// value; if it changes, all cached UIDs are invalidated.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case uidValidity(UIDValidity)

    /// Indicates the sequence number of the first message without the ``Flag/seen`` flag set.
    ///
    /// This code identifies the message number (in sequence order) of the first message in the mailbox
    /// that does not have the `\Seen` flag set, indicating an unread message.
    /// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case unseen(SequenceNumber)

    /// A command was unable to complete due to a namespace access restriction.
    ///
    /// This code indicates that the command attempted to perform an operation in a namespace that the
    /// user does not have permission to access. This is part of the NAMESPACE extension.
    /// See [RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342) (NAMESPACE Extension) for details.
    case namespace(NamespaceResponse)

    /// Indicates the UIDVALIDITY and UID assigned to an appended message.
    ///
    /// This code is returned in response to an APPEND command. It contains the UIDVALIDITY of the
    /// destination mailbox and the UID assigned to the newly appended message in that mailbox.
    /// This is part of the UIDPLUS extension.
    /// See [RFC 4315](https://datatracker.ietf.org/doc/html/rfc4315) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case uidAppend(ResponseCodeAppend)

    /// Indicates the UIDs of messages copied to a destination mailbox.
    ///
    /// This code is returned in response to a COPY command. It contains the UIDVALIDITY of the
    /// destination mailbox and the UIDs assigned to the copied message(s) in that mailbox.
    /// This is part of the UIDPLUS extension.
    /// See [RFC 4315](https://datatracker.ietf.org/doc/html/rfc4315) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case uidCopy(ResponseCodeCopy)

    /// The selected mailbox does not support persistent UIDs.
    ///
    /// This code indicates that the mail store does not support persistent UIDs; the UIDVALIDITY
    /// value will be different each time the mailbox is selected. Therefore, APPEND and COPY commands
    /// will not return APPENDUID or COPYUID codes.
    /// This is part of the UIDPLUS extension.
    /// See [RFC 4315](https://datatracker.ietf.org/doc/html/rfc4315) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case uidNotSticky

    /// The special-use attribute cannot be assigned to this mailbox.
    ///
    /// This code indicates that the CREATE command failed because the server cannot create a mailbox
    /// with the specified special-use attribute. This is part of the Special-Use Mailbox extension.
    /// See [RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154) (Special-Use Mailbox Attributes) for details.
    case useAttribute

    /// A server-specific or unknown response code.
    ///
    /// This catch-all case supports response codes that may be sent by future IMAP extensions or
    /// vendor-specific implementations. The first string is the code name, and the optional second
    /// string is any accompanying data.
    case other(String, String?)

    /// The server refused to save a SEARCH (SAVE) result.
    ///
    /// This code indicates that a SEARCH (SAVE) command failed because the server has reached an
    /// internal limit on the number of saved search results.
    /// This is part of the extended SEARCH extension.
    /// See [RFC 5182](https://datatracker.ietf.org/doc/html/rfc5182) (Last SEARCH Result Reference Extension) for details.
    case notSaved

    /// Boundary marker between responses for different mailboxes.
    ///
    /// This code appears when the server closes one mailbox and selects another. All responses
    /// before the CLOSED code relate to the previously selected mailbox, and all responses after
    /// relate to the newly selected mailbox.
    /// See [RFC 5162](https://datatracker.ietf.org/doc/html/rfc5162) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case closed

    /// The selected mailbox does not support persistent modification sequences.
    ///
    /// This code appears in the OK response to SELECT or EXAMINE commands when the server does not
    /// support persistent storage of modification sequences (mod-sequences) for the mailbox. Each
    /// successful SELECT or EXAMINE must include this code if the mailbox lacks mod-sequence support.
    /// See [RFC 4551](https://datatracker.ietf.org/doc/html/rfc4551) (CONDSTORE Extension) for details.
    case noModificationSequence

    /// Indicates which messages were modified by a STORE command.
    ///
    /// This code is returned in response to a STORE command and lists the messages that were actually
    /// modified. This allows the client to detect when the server rejected modifications for specific messages.
    /// See [RFC 4551](https://datatracker.ietf.org/doc/html/rfc4551) (CONDSTORE Extension) for details.
    case modified(LastCommandSet<UnknownMessageIdentifier>)

    /// Indicates the highest modification sequence value in the mailbox.
    ///
    /// This code appears in OK responses to SELECT or EXAMINE commands when the server supports
    /// persistent modification sequences. The value indicates the highest mod-sequence value assigned
    /// to any message in the mailbox.
    /// See [RFC 4551](https://datatracker.ietf.org/doc/html/rfc4551) (CONDSTORE Extension) for details.
    case highestModificationSequence(ModificationSequenceValue)

    /// A metadata entry value exceeded the MAXSIZE limit.
    ///
    /// This code is returned in the GETMETADATA command response when one or more entry values
    /// exceed the MAXSIZE limit. The value indicates the size of the largest entry that was requested
    /// but exceeded the limit.
    /// This is part of the METADATA extension.
    /// See [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464) (METADATA Extension) for details.
    case metadataLongEntries(Int)

    /// The server cannot set an annotation due to size limitations.
    ///
    /// This code indicates that a SETMETADATA command failed because an entry value is too large.
    /// The value indicates the maximum size allowed by the server.
    /// This is part of the METADATA extension.
    /// See [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464) (METADATA Extension) for details.
    case metadataMaxsize(Int)

    /// The maximum number of allowed annotations has been reached.
    ///
    /// This code indicates that a SETMETADATA command failed because the server has reached the
    /// maximum number of annotations allowed for the mailbox or server.
    /// This is part of the METADATA extension.
    /// See [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464) (METADATA Extension) for details.
    case metadataTooMany

    /// The server does not support private annotations on one or more specified mailboxes.
    ///
    /// This code indicates that a SETMETADATA command failed because the server does not allow
    /// private annotations on one of the specified mailboxes.
    /// This is part of the METADATA extension.
    /// See [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464) (METADATA Extension) for details.
    case metadataNoPrivate

    /// Indicates the supported authentication mechanisms for URLAUTH.
    ///
    /// This code appears in OK responses to RESETKEY, SELECT, or EXAMINE commands. For RESETKEY,
    /// it may appear in the tagged OK response instead of a separate untagged response.
    /// See [RFC 4467](https://datatracker.ietf.org/doc/html/rfc4467) for details.
    case urlMechanisms([MechanismBase64])

    /// The server directs the client to another IMAP server.
    ///
    /// This code is returned in a BYE response when the server is not accepting connections and wishes
    /// to direct the client to another server for the same account or mailbox. The IMAP URL points to
    /// the referral server.
    /// See [RFC 2221](https://datatracker.ietf.org/doc/html/rfc2221) for details.
    case referral(IMAPURL)

    /// Temporary server failure or subsystem unavailability.
    ///
    /// This code indicates that the server is temporarily unable to complete the command due to a
    /// subsystem being down or unavailable. The client may retry the command later.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case unavailable

    /// Authentication failed for unspecified reasons.
    ///
    /// This code indicates that an authentication command failed, but the server is unwilling to
    /// provide details about the reason for the failure.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case authenticationFailed

    /// Authorization identity cannot be assumed.
    ///
    /// This code indicates that authentication succeeded with the authentication identity, but the
    /// server cannot or will not allow that identity to act as the requested authorization identity.
    /// This only applies when the authentication and authorization identities are different.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case authorizationFailed

    /// The authentication or authorization passphrase has expired.
    ///
    /// This code indicates that either authentication succeeded but the server no longer has the
    /// necessary data, or the passphrase is no longer valid. The client or user should obtain a
    /// new passphrase.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case expired

    /// Privacy support is required to perform this operation.
    ///
    /// This code indicates that the operation cannot be completed without privacy protection. If
    /// TLS is not in use, the client could try STARTTLS and then retry the operation.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case privacyRequired

    /// User should contact the system administrator.
    ///
    /// This code indicates that the user should contact the system administrator or support desk
    /// to resolve the issue.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case contactAdmin

    /// Insufficient access permissions for this operation.
    ///
    /// This code indicates that the access control system (e.g., ACL) does not permit the user to
    /// perform the requested operation, such as selecting or creating a mailbox.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case noPermission

    /// Operation conflicts with resource usage by another client.
    ///
    /// This code indicates that the operation was not carried out because it involves removing a
    /// resource that another client is currently using. For example, another client may be holding
    /// an exclusive lock or using a mailbox that would be deleted.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case inUse

    /// Another client has issued an EXPUNGE command for this mailbox.
    ///
    /// This code indicates that another client has expunged messages from the selected mailbox.
    /// The client may want to issue a NOOP command soon to refresh its view.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case expungeIssued

    /// The server detected data corruption.
    ///
    /// This code indicates that the server has discovered that relevant data (such as mailbox data)
    /// is corrupt. This does not specify what is corrupt, but the server will have written details
    /// to its log files.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case corruption

    /// The server encountered an internal bug or invariant violation.
    ///
    /// This code indicates that the server encountered a bug in itself or violated one of its own
    /// invariants during command processing.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case serverBug

    /// The server detected a client protocol violation.
    ///
    /// This code indicates that the server has detected a client bug. This may accompany OK, NO, or BAD
    /// responses depending on the nature of the client bug.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case clientBug

    /// The operation violates a server invariant and cannot succeed.
    ///
    /// This code indicates that the requested operation violates some invariant of the server and
    /// can never succeed, regardless of how the client retries.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case cannot

    /// The operation exceeds a server implementation limit.
    ///
    /// This code indicates that the operation ran up against an implementation limit of some kind,
    /// such as the maximum number of flags per message or the maximum number of distinct flags
    /// used in a mailbox.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case limit

    /// The user's quota would be exceeded by this operation.
    ///
    /// This code indicates that the user would exceed their quota if the operation completed. The
    /// user may or may not already be over quota. Note that if the server sends OVERQUOTA but does
    /// not support the QUOTA extension, the client cannot determine the actual quota limits.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case overQuota

    /// The operation attempts to delete something that does not exist.
    ///
    /// This code indicates that the operation failed because it tried to delete something that does not
    /// exist. This is similar to ``alreadyExists`` but indicates a DELETE operation instead of a CREATE.
    /// See [RFC 5530](https://datatracker.ietf.org/doc/html/rfc5530) and
    /// [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) for details.
    case nonExistent

    /// Compression is currently active on the connection.
    ///
    /// This code indicates that the COMPRESS command has been issued and compression is now active
    /// on the connection. This is part of the COMPRESS=DEFLATE extension.
    /// See [RFC 4978](https://datatracker.ietf.org/doc/html/rfc4978) (COMPRESS Extension) for details.
    case compressionActive

    /// A unique identifier for the selected mailbox.
    ///
    /// This code contains the MAILBOXID value for the selected mailbox. The client should remember
    /// this value to track mailboxes across sessions.
    /// This is part of the OBJECTID extension.
    /// See [RFC 8474](https://datatracker.ietf.org/doc/html/rfc8474) (OBJECTID Extension) for details.
    case mailboxID(MailboxID)

    /// The client must not use message sequence numbers.
    ///
    /// This code indicates that the server does not support the use of message sequence numbers and
    /// requires the client to use UIDs instead. This is part of the UIDONLY extension.
    /// See [RFC 9586](https://datatracker.ietf.org/doc/html/rfc9586) (SUBMIT Extension) for details.
    case uidRequired
}

extension ResponseTextCode {
    public static func modified(_ set: UIDSetNonEmpty) -> Self {
        .modified(.set(.init(set)))
    }

    public static func modified(_ set: MessageIdentifierSetNonEmpty<SequenceNumber>) -> Self {
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
                self.writeString("PERMANENTFLAGS ") + self.writePermanentFlags(flags)
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
            return self.writeString("URLMECH INTERNAL")
                + self.writeArray(array, prefix: " ", parenthesis: false) { mechanism, buffer in
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
        case .mailboxID(let mailboxID):
            return self.writeString("MAILBOXID (")
                + self.writeMailboxID(mailboxID)
                + self.writeString(")")
        case .uidRequired:
            return self.writeString("UIDREQUIRED")
        }
    }

    private mutating func writeResponseTextCode_badCharsets(_ charsets: [String]) -> Int {
        self.writeString("BADCHARSET")
            + self.write(if: charsets.count >= 1) {
                self.writeSpace()
                    + self.writeArray(charsets) { (charset, self) in
                        self.writeString(charset)
                    }
            }
    }

    private mutating func writeResponseTextCode_other(atom: String, string: String?) -> Int {
        self.writeString(atom)
            + self.writeIfExists(string) { (string) -> Int in
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
