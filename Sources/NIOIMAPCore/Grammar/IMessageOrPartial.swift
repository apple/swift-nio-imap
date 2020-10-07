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

/// RFC 5092
public enum IMessageOrPartial: Equatable {
    case refUidSectionPartial(ref: IMailboxReference, uid: IUIDOnly, section: ISectionOnly?, partial: IPartialOnly?)
    case uidSectionPartial(uid: IUIDOnly, section: ISectionOnly?, partial: IPartialOnly?)
    case sectionPartial(section: ISectionOnly, partial: IPartialOnly?)
    case partialOnly(IPartialOnly)
}

// MARK: - Encoding
extension EncodeBuffer {
    
    @discardableResult mutating func writeIMessageOrPartial(_ data: IMessageOrPartial) -> Int {
        switch data {
        case .refUidSectionPartial(ref: let ref, uid: let uid, section: let section, partial: let partial):
            return self.writeIMailboxReference(ref) +
                self.writeIUIDOnly(uid) +
                self.writeIfExists(section, callback: { section in
                    self.writeString("/") +
                        self.writeISectionOnly(section)
                }) +
                self.writeIfExists(partial, callback: { partial in
                    self.writeString("/") +
                        self.writeIPartialOnly(partial)
                })
        case .uidSectionPartial(uid: let uid, section: let section, partial: let partial):
            return self.writeIUIDOnly(uid) +
                self.writeIfExists(section, callback: { section in
                    self.writeString("/") +
                        self.writeISectionOnly(section)
                }) +
                self.writeIfExists(partial, callback: { partial in
                    self.writeString("/") +
                        self.writeIPartialOnly(partial)
                })
        case .sectionPartial(section: let section, partial: let partial):
            return self.writeISectionOnly(section) +
                self.writeIfExists(partial, callback: { partial in
                    self.writeString("/") +
                        self.writeIPartialOnly(partial)
                })
        case .partialOnly(let partial):
            return self.writeIPartialOnly(partial)
        }
    }
    
}
