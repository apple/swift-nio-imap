//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// The characters a percent-encoded URL component may contain besides `pct-encoded` triplets.
///
/// IMAP URL components are written verbatim, so these classes are what keeps a component from
/// ending the URL (space, `]`, `"`) or the line (CR, LF).
enum URLCharacterClass {
    /// [RFC 5092](https://datatracker.ietf.org/doc/html/rfc5092#section-11), e.g. `enc-user`:
    /// ```
    /// achar         = uchar / "&" / "="
    /// uchar         = unreserved / sub-delims-sh / pct-encoded
    /// sub-delims-sh = "!" / "$" / "'" / "(" / ")" / "*" / "+" / ","
    /// ```
    case achar

    /// [RFC 5092](https://datatracker.ietf.org/doc/html/rfc5092#section-11), e.g. `enc-mailbox`:
    /// ```
    /// bchar = achar / ":" / "@" / "/"
    /// ```
    case bchar

    /// [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986#section-3.2.2):
    /// ```
    /// reg-name = *( unreserved / pct-encoded / sub-delims )
    /// ```
    case registeredName

    /// Whether `byte` is in this class. `%` is not: it only appears as part of `pct-encoded`.
    func contains(_ byte: UInt8) -> Bool {
        switch self {
        case .achar:
            return byte.isUnreserved || byte.isSubDelimsSh || byte == UInt8(ascii: "&") || byte == UInt8(ascii: "=")
        case .bchar:
            switch byte {
            case UInt8(ascii: ":"), UInt8(ascii: "@"), UInt8(ascii: "/"):
                return true
            default:
                return Self.achar.contains(byte)
            }
        case .registeredName:
            return byte.isUnreserved || byte.isSubDelims
        }
    }
}

extension StringProtocol {
    /// This string with the hex digits of each `pct-encoded` triplet uppercased, if it consists of
    /// `characterClass` characters and `pct-encoded` triplets only; `nil` otherwise.
    ///
    /// For example, `Fr%c3%a9d` becomes `Fr%C3%A9d`; `a%2` and `a%zz` are `nil`.
    /// [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986#section-2.1):
    /// ```
    /// pct-encoded = "%" HEXDIG HEXDIG
    /// ```
    ///
    /// - parameter characterClass: The characters allowed outside `pct-encoded` triplets.
    /// - parameter emptiness: Whether the empty string is valid.
    func validatedAndNormalizedURLComponent(
        _ characterClass: URLCharacterClass,
        emptiness: URLComponentEmptiness = .rejected
    ) -> String? {
        guard !self.isEmpty || emptiness == .allowed else { return nil }
        var result: [UInt8] = []
        result.reserveCapacity(self.utf8.count)
        var bytes = self.utf8.makeIterator()
        while let byte = bytes.next() {
            guard byte == UInt8(ascii: "%") else {
                guard characterClass.contains(byte) else { return nil }
                result.append(byte)
                continue
            }
            guard
                let high = bytes.next(), high.isHexCharacter,
                let low = bytes.next(), low.isHexCharacter
            else { return nil }
            result.append(contentsOf: [byte, high.uppercasedASCII, low.uppercasedASCII])
        }
        return String(decoding: result, as: UTF8.self)
    }
}

/// Whether a URL component may be empty, e.g. `reg-name = *( … )` versus `enc-user = 1*achar`.
enum URLComponentEmptiness {
    case allowed
    case rejected
}

extension UInt8 {
    /// `a`–`z` mapped to `A`–`Z`; any other byte unchanged.
    fileprivate var uppercasedASCII: UInt8 {
        guard (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(self) else { return self }
        return self - (UInt8(ascii: "a") - UInt8(ascii: "A"))
    }
}
