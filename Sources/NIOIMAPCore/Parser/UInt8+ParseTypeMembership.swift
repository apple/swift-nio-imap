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

// TODO: Remove these
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import func Darwin.isalnum
import func Darwin.isalpha
#elseif os(Linux) || os(FreeBSD) || os(Android)
import func Glibc.isalnum
import func Glibc.isalpha
#else
let badOS = { fatalError("unsupported OS") }()
#endif

extension UInt8 {
    var isCR: Bool {
        self == UInt8(ascii: "\r")
    }

    var isLF: Bool {
        self == UInt8(ascii: "\n")
    }

    var isResponseSpecial: Bool {
        self == UInt8(ascii: "]")
    }

    var isListWildcard: Bool {
        switch self {
        case UInt8(ascii: "%"), UInt8(ascii: "*"):
            return true
        default:
            return false
        }
    }

    var isQuotedSpecial: Bool {
        switch self {
        case UInt8(ascii: "\""), UInt8(ascii: "\\"):
            return true
        default:
            return false
        }
    }

    var isQuotedChar: Bool {
        self.isTextChar && !self.isQuotedSpecial
    }

    var isAtomSpecial: Bool {
        switch self {
        case UInt8(ascii: "("), UInt8(ascii: ")"), UInt8(ascii: " "), UInt8(ascii: "^"):
            return true
        case _ where self.isListWildcard, _ where self.isResponseSpecial, _ where self.isQuotedSpecial:
            return true
        default:
            return false
        }
    }

    var isTextChar: Bool {
        switch self {
        case _ where self.isCR, _ where isLF, _ where self > 0x7F, 0:
            return false
        default:
            return true
        }
    }

    var isAStringChar: Bool {
        switch self {
        case _ where self.isResponseSpecial, _ where isAtomChar:
            return true
        default:
            return false
        }
    }

    var isAtomChar: Bool {
        switch self {
        case _ where self.isAtomSpecial, _ where self > 0x7F:
            return false
        default:
            return self >= 32
        }
    }

    var isListChar: Bool {
        switch self {
        case _ where self.isAtomChar, _ where self.isListWildcard, _ where self.isResponseSpecial:
            return true
        default:
            return false
        }
    }

    var isBase64Char: Bool {
        switch self {
        case UInt8(ascii: "+"), UInt8(ascii: "-"):
            return true
        default:
            return isalnum(Int32(self)) != 0
        }
    }

    var isAlpha: Bool {
        (self >= 65 && self <= 90) || (self >= 97 && self <= 122)
    }

    var isAlphaNum: Bool {
        isalnum(Int32(self)) != 0
    }

    /// tagged-label-fchar  = ALPHA / "-" / "_" / "."
    var isTaggedLabelFchar: Bool {
        switch self {
        case UInt8(ascii: "-"), UInt8(ascii: "_"), UInt8(ascii: "."):
            return true
        case UInt8(ascii: "a") ... UInt8(ascii: "z"):
            return true
        case UInt8(ascii: "A") ... UInt8(ascii: "Z"):
            return true
        default:
            return false
        }
    }

    /// tagged-label-char   = tagged-label-fchar / DIGIT / ":"
    var isTaggedLabelChar: Bool {
        switch self {
        case UInt8(ascii: ":"):
            return true
        case UInt8(ascii: "0") ... UInt8(ascii: "9"):
            return true
        default:
            return self.isTaggedLabelFchar
        }
    }
    
    /// RFC 5092
    var isSubDelimsSh: Bool {
        switch self {
        case UInt8(ascii: "!"),
             UInt8(ascii: "$"),
             UInt8(ascii: "'"),
             UInt8(ascii: "("),
             UInt8(ascii: ")"),
             UInt8(ascii: "*"),
             UInt8(ascii: "+"),
             UInt8(ascii: ","):
            return true
        default:
            return false
        }
    }
    
    /// RFC 3986
    var isUnreserved: Bool {
        switch self {
        case _ where self.isAlphaNum,
             UInt8(ascii: "-"),
             UInt8(ascii: "."),
             UInt8(ascii: "_"),
             UInt8(ascii: "~"):
            return true
        default:
            return false
        }
    }
}
