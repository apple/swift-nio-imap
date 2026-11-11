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
// `IMAPInputBuffer` keep a large one and `makeDispatchData()` donate one, rather than copy.
extension ByteBuffer: StableAddressByteRegion {}

extension ByteBuffer: ParserInputBuffer {
    /// The buffer's readable bytes, as the one region they are.
    public var byteRegions: CollectionOfOne<ByteBuffer> { CollectionOfOne(self) }

    /// The number of readable bytes.
    ///
    /// This is ``ParserInputBuffer/count`` — bytes the parser can see — which for a `ByteBuffer` means
    /// its readable bytes and not its capacity.
    public var count: Int { readableBytes }

    /// One, always: a `ByteBuffer`'s bytes are contiguous by construction.
    public var regionCount: Int { 1 }
}

extension ByteBuffer: ConsumableParserInputBuffer {
    /// Moves the reader index forward by `k`.
    ///
    /// O(1), and it satisfies ``ConsumableParserInputBuffer``'s requirement that discarding a prefix
    /// must not move the remaining bytes — a `ByteBuffer` keeps its read head as an index.
    ///
    /// - Parameter k: How many bytes to discard. Must not exceed ``count``.
    public mutating func discardFirst(_ k: Int) {
        moveReaderIndex(forwardBy: k)
    }
}

// A `ByteBuffer` deliberately does *not* conform to `StableRegionParserInputBuffer`, so a payload
// extracted from one is copied rather than referred to. Vouching for a region means handing the gather
// an `IMAPByteStorage` that outlives it, and `RegionSink.append` takes that owner *unretained* — so a
// conformer that boxes inside `withStableRegions` would hand over a box that is already dead. Only
// something that *stores* the box can promise this, which is what `IMAPInputBuffer` is for: append a
// `ByteBuffer` to one of those and a multi-megabyte literal reaches the caller uncopied.
