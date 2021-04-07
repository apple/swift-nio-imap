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
public enum IMessageOrPartial: Equatable {
    /// Uses a mailbox reference and message UID to load a message, and optional message section and part.
    case refUidSectionPartial(ref: MailboxUIDValidity, uid: IUID, section: ISection?, partial: IPartial?)

    /// Specifies the section of a message to fetch using a message UID, and optionally a specific part of that message.
    case uidSectionPartial(uid: IUID, section: ISection?, partial: IPartial?)

    /// Specifies the section of a message to fetch, and optionally a specific part of that message.
    case sectionPartial(section: ISection, partial: IPartial?)

    /// Specifies the part of a message to fetch.
    case partialOnly(IPartial)
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeIMessageOrPartial(_ data: IMessageOrPartial) -> Int {
        switch data {
        case .refUidSectionPartial(ref: let ref, uid: let uid, section: let section, partial: let partial):
            return self.writeEncodedMailboxUIDValidity(ref) +
                self.writeIUIDOnly(uid) +
                self.writeIfExists(section) { section in
                    self._writeString("/") +
                        self.writeISectionOnly(section)
                } +
                self.writeIfExists(partial) { partial in
                    self._writeString("/") +
                        self.writeIPartialOnly(partial)
                }
        case .uidSectionPartial(uid: let uid, section: let section, partial: let partial):
            return self.writeIUIDOnly(uid) +
                self.writeIfExists(section) { section in
                    self._writeString("/") +
                        self.writeISectionOnly(section)
                } +
                self.writeIfExists(partial) { partial in
                    self._writeString("/") +
                        self.writeIPartialOnly(partial)
                }
        case .sectionPartial(section: let section, partial: let partial):
            return self.writeISectionOnly(section) +
                self.writeIfExists(partial) { partial in
                    self._writeString("/") +
                        self.writeIPartialOnly(partial)
                }
        case .partialOnly(let partial):
            return self.writeIPartialOnly(partial)
        }
    }
}
