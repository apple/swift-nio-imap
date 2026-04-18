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

/// Default constants for IMAP protocol limits and behavior.
///
/// These constants define default size limits and other configuration values used
/// throughout the IMAP implementation when client or server-specific limits are not
/// explicitly provided. The defaults are conservative to work with most IMAP servers
/// and clients.
///
/// - SeeAlso: [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501),
///   [RFC 7162 Section 4](https://datatracker.ietf.org/doc/html/rfc7162#section-4)
public struct IMAPDefaults {
    /// The maximum recommended line length for IMAP protocol messages.
    ///
    /// RFC 7162 Section 4 recommends that servers not send lines longer than 8192 bytes.
    /// This is the maximum recommended length, though some implementations may enforce
    /// stricter limits.
    ///
    /// - SeeAlso: [RFC 7162 Section 4](https://datatracker.ietf.org/doc/html/rfc7162#section-4)
    public static let lineLengthLimit: Int = 8_192

    /// The default maximum size for protocol literals when no other limit is specified.
    ///
    /// This is a conservative default (4KB) that allows reasonable literal sizes while
    /// preventing excessive memory allocation from malformed or malicious servers. Individual
    /// applications should adjust this based on their expected message sizes.
    public static let literalSizeLimit: Int = 4_096

    /// The default maximum size for message body data when no other limit is specified.
    ///
    /// This is set to the maximum possible value, allowing bodies of any size. Applications
    /// that wish to limit body sizes should enforce their own limits when processing
    /// `BODY` fetch responses.
    public static let bodySizeLimit: Int = .max

    private init() {}
}
