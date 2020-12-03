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

/// Options that do not syntactically interact with other options
public enum ListSelectIndependentOption: Equatable {
    
    /// *REMOTE* - Asks the list response to return both remote and local mailboxes
    case remote
    
    /// A catch-all to support future extensions
    case option(OptionExtension)
    
    /// *SPECIAL-USE* - Asks the list response to return special-use mailboxes. E.g. *draft* or *sent* messages.
    case specialUse
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeListSelectIndependentOption(_ option: ListSelectIndependentOption) -> Int {
        switch option {
        case .remote:
            return self.writeString("REMOTE")
        case .option(let option):
            return self.writeOptionExtension(option)
        case .specialUse:
            return self.writeString("SPECIAL-USE")
        }
    }
}
