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

/// A run of raw message bytes, owned when it is small and borrowed-with-an-owner when it is large.
///
/// IMAP carries payloads that can be many megabytes long — an `APPEND` message, a `FETCH` body
/// literal — and copying those in and out of the library is a cost worth avoiding. `IMAPBuffer` is
/// how the library avoids it. It has two representations and the choice between them is an
/// implementation detail:
///
/// - **Copied.** The bytes are held in an `Array` this value owns.
/// - **Retained.** The bytes belong to an ``IMAPByteStorage`` — a network read, an encoder output
///   segment, a memory-mapped file — and this value holds a strong reference to it plus a range.
///
/// The two are indistinguishable through the API: ``==`` and ``hash(into:)`` compare bytes, so a
/// copied buffer and a retained buffer over the same bytes are equal and hash equally.
///
/// - Note: `IMAPBuffer` stores an *object and a range*, never a pointer. Nothing here can dangle,
///   and the type needs no unsafe machinery. What it *can* do is pin more memory than it exposes —
///   a small range of a large region keeps the whole region alive. That is the same behaviour a
///   `ByteBuffer` slice has, and ``copied()`` is the way out of it.
///
/// ## Reading the bytes
///
/// ``withUnsafeBytes(_:)`` is the zero-copy path and should be preferred:
///
/// ```swift
/// let checksum = buffer.withUnsafeBytes { bytes in
///     bytes.reduce(into: UInt8(0)) { $0 ^= $1 }
/// }
/// ```
///
/// ``copiedBytes()`` is the convenient path, and it allocates and copies on **every** call. It is a
/// method rather than a property to say so: on a value that may hold a multi-megabyte literal, a
/// property that copies reads as free.
///
/// - Note: `IMAPBuffer` is deliberately not a `Collection`. Subscripting a byte at a time through a
///   scoped accessor is a performance trap that looks free.
public struct IMAPBuffer: Sendable {
    internal enum Storage: Sendable {
        /// Bytes this value owns, plus the live sub-range of them.
        case copied([UInt8], Range<Int>)
        /// Bytes somebody else owns, plus the live sub-range within that owner.
        case retained(IMAPByteStorage, Range<Int>)
        /// Bytes in an encoder output segment or an input buffer's tail, plus the range of it this value
        /// exposes.
        ///
        /// The encoder's own bytes get their own case rather than going through an
        /// ``IMAPByteStorage``, because a box per handed-out region is a class allocation per
        /// message and the segment is already a class. What the box used to provide — a *pinned*
        /// extent, so that a region never exposes bytes the writer has not written yet — is
        /// provided here by the range, which is fixed when the region is handed out and only ever
        /// narrowed afterwards.
        case segment(OutputSegment, Range<Int>)
    }

    internal var storage: Storage

    /// Creates an empty buffer.
    public init() {
        self.storage = .copied([], 0..<0)
    }

    /// Creates a buffer holding the given bytes.
    ///
    /// The array is taken as-is; its bytes are not copied.
    ///
    /// - Parameter bytes: The bytes to hold.
    public init(_ bytes: [UInt8]) {
        self.storage = .copied(bytes, 0..<bytes.count)
    }

    /// Creates a buffer referring to a sub-range of a region somebody else owns.
    ///
    /// The bytes are not copied. `storage` stays alive for as long as this value, or any value
    /// copied from it, does.
    ///
    /// - Parameters:
    ///   - storage: The owner of the bytes.
    ///   - range: The range of `storage` to expose. Must lie within `storage`.
    public init(_ storage: IMAPByteStorage, _ range: Range<Int>) {
        precondition(
            range.lowerBound >= 0 && range.upperBound <= storage.count,
            "\(range) is out of bounds for an IMAPByteStorage of \(storage.count) bytes"
        )
        self.storage = .retained(storage, range)
    }

    /// Creates a buffer referring to all of a region somebody else owns.
    ///
    /// The bytes are not copied.
    ///
    /// - Parameter storage: The owner of the bytes.
    public init(_ storage: IMAPByteStorage) {
        self.storage = .retained(storage, 0..<storage.count)
    }

    /// Creates a buffer over a range of an ``OutputSegment``.
    ///
    /// The bytes are not copied, and the segment stays alive for as long as this value does — which
    /// is what lets the encoder hand out a chunk and carry on writing above it.
    ///
    /// - Important: `range` must already have been written, and nothing may write into it again. It
    ///   is the extent this value exposes forever; the segment's own `used` may keep growing, and
    ///   this value will never look at what is beyond `range`.
    ///
    /// - Parameters:
    ///   - segment: The segment holding the bytes.
    ///   - range: The range of it to expose.
    internal init(segment: OutputSegment, range: Range<Int>) {
        assert(
            range.lowerBound >= 0 && range.upperBound <= segment.used,
            "\(range) is out of bounds for a segment with \(segment.used) bytes written"
        )
        self.storage = .segment(segment, range)
    }

    /// The number of bytes.
    public var count: Int {
        switch storage {
        case .copied(_, let range), .retained(_, let range), .segment(_, let range):
            return range.count
        }
    }

    /// Whether there are no bytes.
    public var isEmpty: Bool { count == 0 }

    /// Calls the given closure with a pointer to the bytes.
    ///
    /// This is the zero-copy way to read an `IMAPBuffer`. The pointer is valid only for the
    /// duration of the call.
    ///
    /// - Parameter body: A closure that receives the bytes.
    /// - Returns: Whatever `body` returns.
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        switch storage {
        case .copied(let bytes, let range):
            return try bytes.withUnsafeBytes { try body(UnsafeRawBufferPointer(rebasing: $0[range])) }
        case .retained(let storage, let range):
            return try storage.withUnsafeBytes { try body(UnsafeRawBufferPointer(rebasing: $0[range])) }
        case .segment(let segment, let range):
            return try body(UnsafeRawBufferPointer(rebasing: UnsafeRawBufferPointer(segment.storage)[range]))
        }
    }

    /// Copies the bytes into a new array.
    ///
    /// - Complexity: O(*count*). This allocates and copies on every call — prefer
    ///   ``withUnsafeBytes(_:)`` where the bytes do not need to outlive the call.
    /// - Returns: The bytes.
    public func copiedBytes() -> [UInt8] {
        switch storage {
        case .copied(let bytes, let range) where range == bytes.indices:
            return bytes
        default:
            return withUnsafeBytes { [UInt8]($0) }
        }
    }

    /// Returns a buffer holding the same bytes, owned outright.
    ///
    /// Use this to release a large region that only a few bytes are still needed from. If the bytes
    /// are already owned, and the buffer is not a sub-range of a larger array, this returns `self`.
    ///
    /// - Complexity: O(*count*) when the bytes are borrowed, O(1) when they are already owned.
    /// - Returns: A buffer that pins nothing but its own bytes.
    public func copied() -> IMAPBuffer {
        switch storage {
        case .copied(let bytes, let range) where range == bytes.indices:
            return self
        default:
            return IMAPBuffer(copiedBytes())
        }
    }

    /// Returns a buffer over everything but the first `k` bytes.
    ///
    /// - Complexity: O(1) — this is range arithmetic, and copies nothing.
    /// - Parameter k: How many bytes to drop. Values beyond ``count`` give an empty buffer;
    ///   negative values are treated as zero.
    /// - Returns: The remaining bytes.
    public func dropFirst(_ k: Int = 1) -> IMAPBuffer {
        var result = self
        let dropped = Swift.min(Swift.max(k, 0), count)
        switch storage {
        case .copied(let bytes, let range):
            result.storage = .copied(bytes, (range.lowerBound + dropped)..<range.upperBound)
        case .retained(let storage, let range):
            result.storage = .retained(storage, (range.lowerBound + dropped)..<range.upperBound)
        case .segment(let segment, let range):
            result.storage = .segment(segment, (range.lowerBound + dropped)..<range.upperBound)
        }
        return result
    }

    /// Returns a buffer over the first `k` bytes.
    ///
    /// - Complexity: O(1) — this is range arithmetic, and copies nothing.
    /// - Parameter k: How many bytes to keep. Values beyond ``count`` give the whole buffer;
    ///   negative values give an empty one.
    /// - Returns: The leading bytes.
    public func prefix(_ k: Int) -> IMAPBuffer {
        var result = self
        let keeping = Swift.min(Swift.max(k, 0), count)
        switch storage {
        case .copied(let bytes, let range):
            result.storage = .copied(bytes, range.lowerBound..<(range.lowerBound + keeping))
        case .retained(let storage, let range):
            result.storage = .retained(storage, range.lowerBound..<(range.lowerBound + keeping))
        case .segment(let segment, let range):
            result.storage = .segment(segment, range.lowerBound..<(range.lowerBound + keeping))
        }
        return result
    }
}

// MARK: - The copy threshold

extension IMAPBuffer {
    /// Runs of bytes shorter than this are copied; runs this long or longer are referred to.
    ///
    /// Both directions use this one number. The parser decides with it whether to copy an extracted
    /// payload or to hand out a reference into the received buffer, and ``IMAPOutputBuffer`` decides
    /// with it whether to copy an appended region or to keep a reference to it. Do not change one
    /// without the other; they are the same trade seen from two sides.
    ///
    /// ## Why 1024
    ///
    /// It sits **below the smallest realistic network read**. The case that decides it is a large
    /// message arriving one Ethernet-MTU read at a time: each extraction takes essentially the whole
    /// 1448-byte read, so referring to it wastes no memory — the region is ~100% live — while copying
    /// allocates once per packet. For a 10 MB message that is ~7,240 allocations and 10 MB copied,
    /// against none and nothing.
    ///
    /// A microbenchmark comparing a `memcpy` against the cost of one extra output region argues for
    /// something nearer 16 KB, and that reading is wrong: it assumes the copy has an open segment to
    /// merge into and that the bytes are not handed out immediately, neither of which holds while
    /// streaming. What is left once those assumptions go is allocation churn, and that points below
    /// an MTU.
    ///
    /// - Note: This is not ``IMAPDefaults/lineLengthLimit``. That is a protocol and denial-of-service
    ///   limit and stays at 8192; this is a performance trade-off and has nothing to do with it.
    ///
    /// It is public so that an ``EncoderOutputBuffer`` of your own makes the same decision with the
    /// same number, as `NIOIMAP`'s `ByteBufferOutput` does. It is a tuning value and may change between
    /// releases.
    public static let copyThreshold = 1024
}

// MARK: - Representation

extension IMAPBuffer {
    /// The region backing these bytes, and their range within it, if the region has the given type.
    ///
    /// Use it to convert back to your own buffer type without copying: `NIOIMAP` turns an `IMAPBuffer`
    /// over a `ByteBuffer` back into a slice of that `ByteBuffer` this way.
    ///
    /// ```swift
    /// if let backing = buffer.backingRegion(as: MyBuffer.self) {
    ///     return backing.region.slice(backing.range)  // no copy
    /// }
    /// return buffer.withUnsafeBytes { MyBuffer(copying: $0) }
    /// ```
    ///
    /// - Parameter type: The region type to recover: the type wrapped by the ``IMAPByteStorage``
    ///   these bytes came from.
    /// - Returns: The region, and the range of it these bytes cover; `range` indexes the region's
    ///   ``ByteRegion/withUnsafeBytes(_:)`` view. `nil` when this library owns the bytes (copied, or
    ///   written by the encoder) or the region is another type.
    public func backingRegion<Region: ByteRegion & Sendable>(
        as type: Region.Type
    ) -> (region: Region, range: Range<Int>)? {
        guard let retained = retainedRegion, let region = retained.storage.wrappedRegion(as: type) else {
            return nil
        }
        return (region, retained.range)
    }

    /// Calls `body` with these bytes and an owner that keeps them at the same address while it lives.
    ///
    /// For adopting memory without copying, as ``makeDispatchData()`` does: hold `owner` for as long
    /// as you use the pointer. Bytes this library owns always have a fixed address; a foreign region
    /// has one if it conforms to ``StableAddressByteRegion``. Where there is none, copy instead.
    ///
    /// Treat `owner` as opaque. For an empty buffer `bytes` may have no base address, so check
    /// ``isEmpty`` first if the adopter needs one.
    ///
    /// - Parameter body: A closure that receives the bytes and their owner.
    /// - Returns: Whatever `body` returns, or `nil`, without calling `body`, if the bytes have no
    ///   fixed address.
    public func withUnsafeBytesAndOwner<R>(
        _ body: (_ bytes: UnsafeRawBufferPointer, _ owner: any Sendable) throws -> R
    ) rethrows -> R? {
        try withUnsafeBytesAndStableOwner { bytes, owner in try body(bytes, owner.value) }
    }

    /// What keeps a pointer from ``withUnsafeBytesAndStableOwner(_:)`` valid, by concrete type, so an
    /// adopter can capture it without boxing it in an existential.
    internal enum StableOwner {
        case array([UInt8])
        case storage(IMAPByteStorage)
        case segment(OutputSegment)

        /// The owner, type-erased.
        var value: any Sendable {
            switch self {
            case .array(let bytes): return bytes
            case .storage(let storage): return storage
            case .segment(let segment): return segment
            }
        }
    }

    /// ``withUnsafeBytesAndOwner(_:)`` with the owner's concrete type, for ``makeDispatchData()``.
    internal func withUnsafeBytesAndStableOwner<R>(
        _ body: (_ bytes: UnsafeRawBufferPointer, _ owner: StableOwner) throws -> R
    ) rethrows -> R? {
        switch storage {
        case .copied(let bytes, let range):
            // An `Array`'s buffer does not move while the array is alive, and the owner is a copy of
            // the array, so the bytes stay put. Any write to another copy copies instead.
            return try bytes.withUnsafeBytes { try body(UnsafeRawBufferPointer(rebasing: $0[range]), .array(bytes)) }
        case .retained(let storage, let range):
            // The owner will not promise that this pointer outlives the accessor.
            guard storage.hasStableAddress else { return nil }
            return try storage.withUnsafeBytes {
                try body(UnsafeRawBufferPointer(rebasing: $0[range]), .storage(storage))
            }
        case .segment(let segment, let range):
            // A segment is one `malloc`'d block that is never resized or moved, so its address is
            // fixed by construction — there is no promise to check here.
            return try body(
                UnsafeRawBufferPointer(rebasing: UnsafeRawBufferPointer(segment.storage)[range]),
                .segment(segment)
            )
        }
    }

    /// The owner and range backing these bytes, if they are borrowed rather than owned.
    ///
    /// Returns `nil` for a buffer that owns its bytes, which is not a failure: it means there is no
    /// foreign owner to recover, and copying is the only option.
    internal var retainedRegion: (storage: IMAPByteStorage, range: Range<Int>)? {
        switch storage {
        case .copied, .segment:
            return nil
        case .retained(let storage, let range):
            return (storage, range)
        }
    }

    /// Whether these bytes stay at one address for as long as this value is alive: an array and a
    /// segment never move; a retained region does if its owner promises it.
    internal var hasStableAddress: Bool {
        switch storage {
        case .copied, .segment:
            return true
        case .retained(let storage, _):
            return storage.hasStableAddress
        }
    }
}

// MARK: - Equatable & Hashable

extension IMAPBuffer: Hashable {

    /// Compares two buffers byte by byte.
    ///
    /// Equality is independent of representation: a copied buffer and a retained buffer holding the
    /// same bytes are equal.
    ///
    /// - Complexity: O(*count*).
    public static func == (lhs: IMAPBuffer, rhs: IMAPBuffer) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return lhs.withUnsafeBytes { left in
            rhs.withUnsafeBytes { right in
                left.baseAddress == right.baseAddress || left.elementsEqual(right)
            }
        }
    }

    /// Hashes the bytes.
    ///
    /// - Complexity: O(*count*) — worth knowing before hashing a multi-megabyte literal.
    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes { hasher.combine(bytes: $0) }
        hasher.combine(count)
    }
}

// MARK: - Literals

extension IMAPBuffer: ExpressibleByArrayLiteral {
    /// Creates a buffer from a byte-array literal.
    public init(arrayLiteral elements: UInt8...) {
        self.init(elements)
    }
}

extension IMAPBuffer: ExpressibleByStringLiteral {
    /// Creates a buffer from the UTF-8 bytes of a string literal.
    public init(stringLiteral value: String) {
        self.init(Array(value.utf8))
    }
}

// MARK: - ByteRegion

extension IMAPBuffer: ByteRegion {}

// MARK: - Debugging

extension IMAPBuffer: CustomDebugStringConvertible {
    /// A description showing the byte count and, for short buffers, the bytes in hex.
    public var debugDescription: String {
        let limit = 16
        let hex = withUnsafeBytes { bytes in
            bytes.prefix(limit).map { String($0, radix: 16, uppercase: false).leftPadded(to: 2, with: "0") }
                .joined(separator: " ")
        }
        let ellipsis = count > limit ? " …" : ""
        return "IMAPBuffer(\(count) bytes: \(hex)\(ellipsis))"
    }
}

extension String {
    fileprivate func leftPadded(to width: Int, with pad: Character) -> String {
        count >= width ? self : String(repeating: pad, count: width - count) + self
    }
}
