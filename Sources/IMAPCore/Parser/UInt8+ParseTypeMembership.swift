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

import Darwin

extension UInt8 {
    
    public var isCR: Bool {
        return self == UInt8(ascii: "\r")
    }
    
    public var isLF: Bool {
        return self == UInt8(ascii: "\n")
    }
    
    public var isResponseSpecial: Bool {
        return self == UInt8(ascii: "]")
    }
    
    public var isListWildcard: Bool {
        switch self {
        case UInt8(ascii: "%"), UInt8(ascii: "*"):
            return true
        default:
            return false
        }
    }
    
    public var isQuotedSpecial: Bool {
        switch self {
        case UInt8(ascii: "\""), UInt8(ascii: "\\"):
            return true
        default:
            return false
        }
    }
    
    public var isQuotedChar: Bool {
        return self.isTextChar && !self.isQuotedSpecial
    }
    
    public var isAtomSpecial: Bool {
        switch self {
        case UInt8(ascii: "("), UInt8(ascii: ")"), UInt8(ascii: " "), UInt8(ascii: "^"):
            return true
        case _ where self.isListWildcard, _ where self.isResponseSpecial, _ where self.isQuotedSpecial:
            return true
        default:
            return false
        }
    }
    
    public var isTextChar: Bool {
        switch self {
        case _ where self.isCR, _ where isLF, 0:
            return false
        default:
            return true
        }
    }
    
    public var isAStringChar: Bool {
        switch self {
        case _ where self.isResponseSpecial, _ where isAtomChar:
            return true
        default:
            return false
        }
    }
    
    public var isAtomChar: Bool {
        switch self {
        case _ where self.isAtomSpecial:
            return false
        default:
            return self >= 32
        }
    }
    
    public var isListChar: Bool {
        switch self {
        case _ where self.isAtomChar, _ where self.isListWildcard, _ where self.isResponseSpecial:
            return true
        default:
            return false
        }
    }
    
    public var isBase64Char: Bool {
        switch self {
        case UInt8(ascii: "+"), UInt8(ascii: "-"):
            return true
        default:
            return isalnum(Int32(self)) != 0
        }
    }

    public var isAlpha: Bool {
        return (self >= 65 && self <= 90) || (self >= 97 && self <= 122)
    }

    /// tagged-label-fchar  = ALPHA / "-" / "_" / "."
    public var isTaggedLabelFchar: Bool {
        switch self {
        case UInt8(ascii: "-"), UInt8(ascii: "_"), UInt8(ascii: "."):
            return true
        case UInt8(ascii: "a")...UInt8(ascii: "z"):
            return true
        case UInt8(ascii: "A")...UInt8(ascii: "Z"):
            return true
        default:
            return false
        }
    }

    /// tagged-label-char   = tagged-label-fchar / DIGIT / ":"
    public var isTaggedLabelChar: Bool {
        switch self {
        case UInt8(ascii: ":"):
            return true
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return true
        default:
            return self.isTaggedLabelFchar
        }
    }
}

func isalnum(_ value: Int32) -> Int32 {
    return Darwin.isalnum(value)
}

func isalpha(_ value: Int32) -> Int32 {
    return Darwin.isalpha(value)
}
