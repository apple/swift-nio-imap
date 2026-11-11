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

/// Keeps one run of bytes alive so that an ``IMAPBuffer`` can refer to it without copying.
///
/// This is the owner handle behind ``IMAPBuffer``'s zero-copy representation. It exists so that a
/// multi-megabyte message payload can be handed to a caller — or written back out again — as a
/// reference to somebody else's memory rather than as a copy.
///
/// It is a `final class` on purpose: it gives the wrapped region exactly one heap box with a
/// reference count, which is the whole mechanism. Wrapping a value of three words or fewer — a
/// `ByteBuffer` is 24 bytes of stride, `Data` is 16 — costs **one** allocation in total, because the
/// value fits in the existential's inline storage.
///
/// ## Immutability requirement
///
/// - Important: The wrapped region's bytes, and their count, must never change for as long as this
///   object is alive. `Sendable` carries most of that weight. For a `ByteBuffer` it additionally
///   falls out of copy-on-write: this object holds a second reference to the storage, so any write
///   to the original buffer copies instead of mutating in place.
///
///   A region that grows — an encoder output segment, say — satisfies a *refined* version of the
///   requirement instead: bytes in any range that has been handed out never change. Such a region
///   must pin the extent it exposes at the moment it is wrapped, rather than reporting a count that
///   moves.
///
/// This is a correctness contract of the same kind as `Hashable` consistency, not a memory-safety
/// assertion — nothing here stores a pointer. The exception is ``StableAddressByteRegion``:
/// ``IMAPInputBuffer`` and ``IMAPBufferList/makeDispatchData()`` let a pointer outlive the accessor on
/// its word, so a false conformance does leave one dangling.
public final class IMAPByteStorage: Sendable {
    private let region: any ByteRegion & Sendable

    /// The number of bytes in the wrapped region.
    ///
    /// Captured when the region is wrapped, and required to stay accurate for this object's
    /// lifetime.
    public let count: Int

    /// Whether the wrapped region promises a fixed address, so a pointer to its bytes may outlive a
    /// ``withUnsafeBytes(_:)`` call as long as this object stays alive.
    ///
    /// Determined once, when the region is wrapped: `true` for a ``StableAddressByteRegion``, and for
    /// an ``IMAPBuffer`` whose own bytes have a fixed address. `false` otherwise — a `Data` included,
    /// since it may flatten into a temporary buffer. `false` is the safe answer: ``IMAPInputBuffer``
    /// then copies, and ``IMAPBuffer/withUnsafeBytesAndOwner(_:)`` hands out no pointer, so its callers copy.
    internal let hasStableAddress: Bool

    /// Wraps a region, taking ownership of it.
    ///
    /// Whether the region has a fixed address is checked at run time, once. A caller whose region type
    /// is known to be a ``StableAddressByteRegion`` gets the overload that knows it statically.
    ///
    /// - Parameter region: The bytes to keep alive. Must satisfy the immutability requirement
    ///   described on ``IMAPByteStorage``.
    public convenience init(_ region: some ByteRegion & Sendable) {
        let isStable =
            region is any StableAddressByteRegion || (region as? IMAPBuffer)?.hasStableAddress == true
        self.init(region, address: isStable ? .fixed : .unknown)
    }

    /// Wraps a region whose address is fixed, taking ownership of it.
    ///
    /// Overload resolution picks this wherever the region's type is known to conform — `ByteBuffer`,
    /// the stdlib arrays — so wrapping one costs no dynamic cast. The other init is not specialized
    /// across modules, so its casts run on every call.
    ///
    /// - Parameter region: The bytes to keep alive. Must satisfy the immutability requirement
    ///   described on ``IMAPByteStorage``.
    public convenience init(_ region: some StableAddressByteRegion & Sendable) {
        self.init(region, address: .fixed)
    }

    /// Wraps an ``IMAPBuffer``, taking ownership of it.
    ///
    /// The buffer's own fixed address, if it has one, carries over, without the dynamic cast the generic
    /// init needs to find out.
    ///
    /// - Parameter buffer: The bytes to keep alive.
    public convenience init(_ buffer: IMAPBuffer) {
        self.init(buffer, address: buffer.hasStableAddress ? .fixed : .unknown)
    }

    /// What a wrapped region promises about its address.
    private enum Address {
        /// Fixed: a pointer may outlive the accessor.
        case fixed
        /// No promise: a pointer is valid only inside the accessor.
        case unknown
    }

    private init(_ region: some ByteRegion & Sendable, address: Address) {
        self.region = region
        self.count = region.withUnsafeBytes { $0.count }
        self.hasStableAddress = address == .fixed
    }

    /// Calls the given closure with a pointer to the wrapped bytes.
    ///
    /// The pointer is valid only for the duration of the call.
    ///
    /// - Parameter body: A closure that receives the wrapped bytes.
    /// - Returns: Whatever `body` returns.
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try region.withUnsafeBytes { bytes in
            assert(
                bytes.count == self.count,
                "IMAPByteStorage's region changed size: expected \(self.count) bytes, got \(bytes.count). "
                    + "A wrapped ByteRegion must not change while it is owned."
            )
            return try body(bytes)
        }
    }

    /// The wrapped region, if it has the given type.
    ///
    /// What ``IMAPBuffer/backingRegion(as:)`` recovers a concrete backing type with.
    ///
    /// - Parameter type: The type to test for.
    /// - Returns: The wrapped region, or `nil` if it has some other type.
    internal func wrappedRegion<Region: ByteRegion & Sendable>(as type: Region.Type) -> Region? {
        region as? Region
    }
}
