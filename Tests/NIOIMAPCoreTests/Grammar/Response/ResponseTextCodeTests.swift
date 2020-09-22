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

import NIO
@testable import NIOIMAPCore
import XCTest

class ResponseTextCodeTests: EncodeTestClass {}

// MARK: - Encoding

extension ResponseTextCodeTests {
    func testEncode() {
        let inputs: [(ResponseTextCode, String, UInt)] = [
            (.alert, "ALERT", #line),
            (.parse, "PARSE", #line),
            (.readOnly, "READ-ONLY", #line),
            (.readWrite, "READ-WRITE", #line),
            (.tryCreate, "TRYCREATE", #line),
            (.uidNext(123), "UIDNEXT 123", #line),
            (.uidValidity(234), "UIDVALIDITY 234", #line),
            (.unseen(345), "UNSEEN 345", #line),
            (.badCharset(["some", "string"]), "BADCHARSET (some string)", #line),
            (.permanentFlags([.wildcard]), #"PERMANENTFLAGS (\*)"#, #line),
            (.permanentFlags([.wildcard, .wildcard]), #"PERMANENTFLAGS (\* \*)"#, #line),
            (.permanentFlags([.flag(.deleted), .flag(.draft)]), #"PERMANENTFLAGS (\Deleted \Draft)"#, #line),
            (.other("some", nil), "some", #line),
            (.other("some", "thing"), "some thing", #line),
            (.capability([]), "CAPABILITY IMAP4 IMAP4rev1", #line),
            (.capability([.unselect]), "CAPABILITY IMAP4 IMAP4rev1 UNSELECT", #line),
            (.capability([.unselect, .binary, .children]), "CAPABILITY IMAP4 IMAP4rev1 UNSELECT BINARY CHILDREN", #line),
            (.namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])), "NAMESPACE NIL NIL NIL", #line),
            (.useAttribute, "USEATTR", #line),
            (.notSaved, "NOTSAVED", #line),
            (.closed, "CLOSED", #line),
            (.noModificationSequence, "NOMODSEQ", #line),
            (.modified([1]), "MODIFIED 1", #line),
            (.highestModifierSequence(1), "HIGHESTMODSEQ 1", #line),
            (.metadataMaxsize(123), "METADATA MAXSIZE 123", #line),
            (.metadataLongEntries(456), "METADATA LONGENTRIES 456", #line),
            (.metadataTooMany, "METADATA TOOMANY", #line),
            (.metadataNoPrivate, "METADATA NOPRIVATE", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeResponseTextCode($0) })
    }
}
