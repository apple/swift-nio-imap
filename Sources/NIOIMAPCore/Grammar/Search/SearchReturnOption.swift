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

/// Used to control what data is sent back as part of a search response.
public enum SearchReturnOption: Hashable {
    /// Return the lowest message number/UID that satisfies the SEARCH criteria.
    case min

    /// Return the highest message number/UID that satisfies the SEARCH criteria.
    case max

    /// Return all message numbers/UIDs that satisfy the SEARCH criteria.
    case all

    /// Return number of the messages that satisfy the SEARCH criteria.
    case count

    /// Tells the server to remember the result of the SEARCH or UID SEARCH command (as well as any command based on
    /// SEARCH, e.g., SORT and THREAD [SORT]) and store it
    case save

    /// Implemented as a catch-all to support future extensions.
    case optionExtension(KeyValue<String, ParameterValue?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchReturnOption(_ option: SearchReturnOption) -> Int {
        switch option {
        case .min:
            return self.writeString("MIN")
        case .max:
            return self.writeString("MAX")
        case .all:
            return self.writeString("ALL")
        case .count:
            return self.writeString("COUNT")
        case .save:
            return self.writeString("SAVE")
        case .optionExtension(let option):
            return self.writeSearchReturnOptionExtension(option)
        }
    }

    @discardableResult mutating func writeSearchReturnOptions(_ options: [SearchReturnOption]) -> Int {
        guard options.count > 0 else {
            return 0
        }
        return
            self.writeString(" RETURN (") +
            self.writeIfExists(options) { (options) -> Int in
                self.writeArray(options, parenthesis: false) { (option, self) in
                    self.writeSearchReturnOption(option)
                }
            } +
            self.writeString(")")
    }
}
