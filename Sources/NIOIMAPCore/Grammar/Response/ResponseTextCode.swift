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
/// IMAPv4 `resp-text-code`
public enum ResponseTextCode: Equatable {
    case alert
    case badCharset([String])
    case capability([Capability])
    case parse
    case permanentFlags([PermanentFlag])
    case readOnly
    case readWrite
    case tryCreate
    case uidNext(Int)
    case uidValidity(Int)
    case unseen(Int)
    case namespace(NamespaceResponse)
    case uidAppend(ResponseCodeAppend)
    case uidCopy(ResponseCodeCopy)
    case uidNotSticky
    case useAttribute
    case other(String, String?)
    case notSaved // RFC 5182
    case closed
    case noModificationSequence
    case modificationSequence(SequenceSet)
    case highestModificationSequence(ModificationSequenceValue)
    case metadataLongEntries(Int)
    case metadataMaxsize(Int)
    case metadataTooMany
    case metadataNoPrivate
    case urlMechanisms([MechanismBase64])
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
            return self.writeString("UIDNEXT \(number)")
        case .uidValidity(let number):
            return self.writeString("UIDVALIDITY \(number)")
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
                self.writeArray(array, prefix: " ", parenthesis: false, callback: { mechanism, buffer in
                    buffer.writeMechanismBase64(mechanism)
                })
        case .referral(let url):
            return self.writeString("REFERRAL ") + self.writeIMAPURL(url)
        }
    }

    private mutating func writeResponseTextCode_badCharsets(_ charsets: [String]) -> Int {
        self.writeString("BADCHARSET") +
            self.writeIfArrayHasMinimumSize(array: charsets) { (charsets, self) -> Int in
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
