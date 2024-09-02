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

/// A “Command Continuation Request” from the server.
///
/// RFC 3501 section 7.5
///
/// IMAPv4 `continue-req`
public enum ContinuationRequest: Hashable, Sendable {
    /// A continuation request that contains a `ResponseText`.
    case responseText(ResponseText)

    /// A continuation request that contains some data, typically encoded as base64.
    case data(ByteBuffer)
}
