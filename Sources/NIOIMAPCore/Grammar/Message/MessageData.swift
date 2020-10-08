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

/// IMAPv4 `message-data`
/// One message attribute is guaranteed
public enum MessageData: Equatable {
    case expunge(Int)

    /// RFC 7162 Condstore
    /// The VANISHED UID FETCH modifier instructs the server to report those
    /// messages from the UID set parameter that have been expunged and whose
    /// associated mod-sequence is larger than the specified mod-sequence.
    case vanished(SequenceSet)

    /// RFC 7162 Condstore
    /// The VANISHED (EARLIER) response is caused by a UID FETCH (VANISHED)
    /// or a SELECT/EXAMINE (QRESYNC) command.  This response is sent if the
    /// UID set parameter to the UID FETCH (VANISHED) command includes UIDs
    /// of messages that are no longer in the mailbox.
    case vanishedEarlier(SequenceSet)
    
    case genURLAuth([ByteBuffer])
    
    case urlFetch([URLFetchData])
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMessageData(_ data: MessageData) -> Int {
        switch data {
        case .expunge(let number):
            return self.writeString("\(number) EXPUNGE")
        case .vanished(let set):
            return self.writeString("VANISHED ") + self.writeSequenceSet(set)
        case .vanishedEarlier(let set):
            return self.writeString("VANISHED (EARLIER) ") + self.writeSequenceSet(set)
        case .genURLAuth(let array):
        return self.writeString("GENURLAUTH") +
            self.writeArray(array, separator: "", parenthesis: false, callback: { data, buffer in
                buffer.writeSpace() +
                    buffer.writeIMAPString(data)
            })
        case .urlFetch(let array):
            return self.writeString("URLFETCH") +
                self.writeArray(array, callback: { data, buffer in
                    buffer.writeURLFetchData(data)
                })
        }
    }

    @discardableResult mutating func writeMessageDataEnd(_: MessageData) -> Int {
        self.writeString(")")
    }
}
