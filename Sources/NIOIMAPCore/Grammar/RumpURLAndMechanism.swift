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

/// Pairs an IMAP "rump" URL with an authentication mechanism
public struct RumpURLAndMechanism: Hashable, Sendable {
    /// The IMAP URL excluding the access mechanism and access token.
    public var urlRump: ByteBuffer

    /// Used to restrict the usage of a URL-AUTH authorized URL.
    public var mechanism: URLAuthenticationMechanism

    /// Creates a new `URLRumpMechanism`.
    /// - parameter urlRump: The IMAP URL excluding the access mechanism and access token.
    /// - parameter mechanism: Used to restrict the usage of a URL-AUTH authorized URL.
    public init(urlRump: ByteBuffer, mechanism: URLAuthenticationMechanism) {
        self.urlRump = urlRump
        self.mechanism = mechanism
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLRumpMechanism(_ data: RumpURLAndMechanism) -> Int {
        self.writeIMAPString(data.urlRump) + self.writeSpace() + self.writeURLAuthenticationMechanism(data.mechanism)
    }
}
