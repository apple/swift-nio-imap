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
public struct IMAPDefaults: Sendable {
    /// The maximum recommended length of a command line.
    ///
    /// RFC 7162 Section 4 recommends that clients not send command lines longer than 8192 bytes,
    /// and that servers accept at least that much.
    ///
    /// - SeeAlso: [RFC 7162 Section 4](https://datatracker.ietf.org/doc/html/rfc7162#section-4)
    public static let lineLengthLimit: Int = 8_192

    /// The default maximum size of an unparsed response line on the client.
    ///
    /// No RFC limits response lines, and servers send long ones: 5,000 UIDs in a `SEARCH` result are
    /// about 40 KB, a `BODYSTRUCTURE` for many attachments can be tens of KB. This still caps a runaway
    /// response. Each read re-parses the line, so a larger limit costs time quadratically.
    public static let responseLineLengthLimit: Int = 256 * 1024

    /// The default maximum size for protocol literals when no other limit is specified.
    ///
    /// A conservative default (4KB) that allows reasonable literal sizes while
    /// preventing excessive memory allocation from malformed or malicious servers. Individual
    /// applications should adjust this based on their expected message sizes.
    public static let literalSizeLimit: Int = 4_096

    /// The default maximum size for message body data when no other limit is specified.
    ///
    /// Set to the maximum possible value, allowing bodies of any size. Applications
    /// that wish to limit body sizes should enforce their own limits when processing
    /// `BODY` fetch responses.
    public static let bodySizeLimit: Int = .max

    private init() {}
}
