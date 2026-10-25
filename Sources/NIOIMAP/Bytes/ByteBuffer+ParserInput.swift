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

import NIO
import NIOIMAPCore

// This file is what lets a caller holding a `ByteBuffer` hand it to the parser. `NIOIMAPCore` does not
// know about NIO, so the conformances live here; `NIOIMAP` re-exports `NIOIMAPCore`, so which of the two
// modules declares them is invisible to anyone importing `NIOIMAP`.
//
// They need no `@retroactive`: the protocols are declared in this package, so this is not a conformance
// two other modules could also add.

extension ByteBuffer: ByteRegion {
    /// Calls the given closure with a pointer to the buffer's readable bytes.
    ///
    /// This is `withUnsafeReadableBytes(_:)` under the name `ByteRegion` requires, and it is what
    /// lets a `ByteBuffer` be handed to `NIOIMAPCore` without being copied first.
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try withUnsafeReadableBytes(body)
    }
}

// A copy of a `ByteBuffer` keeps its storage alive, and while copies share storage a write through any of
// them copies it first — so the readable bytes a copy sees neither move nor change. That lets
// `makeDispatchData()` donate them rather than copy.
extension ByteBuffer: StableAddressByteRegion {}
