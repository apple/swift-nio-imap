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
/// Used to help tell a client why a command failed. Machine readable, not guaranteed to
/// be human readable.
public enum ResponseTextCode: Equatable {
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
    case unseen(Int)

    ///
    case namespace(NamespaceResponse)

    ///  Followed by the UIDVALIDITY of the destination mailbox and the UID
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
    case modificationSequence(SequenceSet)

    ///  A server supporting the persistent storage of mod-sequences for the mailbox
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
            return self.writeString("UIDNEXT ") + self.writeUID(number)
        case .uidValidity(let number):
            return self.writeString("UIDVALIDITY ") + self.writeUIDValidity(number)
        case .unseen(let number):
            return self.writeString("UNSEEN \(number)")
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
        case .modificationSequence(let set):
            return self.writeString("MODIFIED ") + self.writeSequenceSet(set)
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
