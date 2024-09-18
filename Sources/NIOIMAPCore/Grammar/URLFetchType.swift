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

/// Provides a variety of ways to load message data.
public enum URLFetchType: Hashable, Sendable {
    /// Uses a mailbox reference and message UID to load a message, and optional message section and part.
    case refUidSectionPartial(ref: MailboxUIDValidity, uid: IUID, section: URLMessageSection?, partial: MessagePath.ByteRange?)

    /// Specifies the section of a message to fetch using a message UID, and optionally a specific part of that message.
    case uidSectionPartial(uid: IUID, section: URLMessageSection?, partial: MessagePath.ByteRange?)

    /// Specifies the section of a message to fetch, and optionally a specific part of that message.
    case sectionPartial(section: URLMessageSection, partial: MessagePath.ByteRange?)

    /// Specifies the part of a message to fetch.
    case partialOnly(MessagePath.ByteRange)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLFetchType(_ data: URLFetchType) -> Int {
        switch data {
        case .refUidSectionPartial(ref: let ref, uid: let uid, section: let section, partial: let range):
            return self.writeEncodedMailboxUIDValidity(ref) +
                self.writeIUIDOnly(uid) +
                self.writeIfExists(section) { section in
                    self.writeString("/") +
                        self.writeURLMessageSectionOnly(section)
                } +
                self.writeIfExists(range) { range in
                    self.writeString("/") +
                        self.writeMessagePathByteRangeOnly(range)
                }
        case .uidSectionPartial(uid: let uid, section: let section, partial: let range):
            return self.writeIUIDOnly(uid) +
                self.writeIfExists(section) { section in
                    self.writeString("/") +
                        self.writeURLMessageSectionOnly(section)
                } +
                self.writeIfExists(range) { range in
                    self.writeString("/") +
                        self.writeMessagePathByteRangeOnly(range)
                }
        case .sectionPartial(section: let section, partial: let partial):
            return self.writeURLMessageSectionOnly(section) +
                self.writeIfExists(partial) { partial in
                    self.writeString("/") +
                        self.writeMessagePathByteRangeOnly(partial)
                }
        case .partialOnly(let partial):
            return self.writeMessagePathByteRangeOnly(partial)
        }
    }
}
