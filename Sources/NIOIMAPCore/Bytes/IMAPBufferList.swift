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

/// One or more ``IMAPBuffer`` regions, in order — the bytes of one encoded chunk.
///
/// A chunk of encoded output is usually one contiguous run of bytes, and `IMAPBufferList` stores
/// that case without allocating. It becomes several regions when the encoder appends a caller's
/// payload by reference rather than copying it, or when a chunk spans more than one output segment.
/// Realistic region counts are one to three.
///
/// ## Two quantities, both named
///
/// This type counts two different things — bytes and regions — so it offers ``byteCount`` and
/// ``regionCount`` and **no bare `count`**, and no `isEmpty`. That is deliberate. A `count` on this
/// type would be ambiguous at every call site, and an `isEmpty` meaning "no regions" would read as
/// "no bytes" in exactly the preconditions where the difference matters: a chunk carrying a single
/// zero-length region has no bytes but is not regionless. Write `byteCount == 0` or
/// `regionCount == 0` and say which one is meant.
///
/// For the same reason this is not a `Collection`. Nothing that consumes a chunk wants indices,
/// slicing or a `SubSequence`; they want to iterate the regions and know how many there are, which
/// is what ``regions`` gives.
///
/// ## Getting the bytes out
///
/// Iterate ``regions`` and use ``IMAPBuffer/withUnsafeBytes(_:)`` on each — that is the zero-copy
/// path, and for a networking caller it is also the vectored-write path, one write per region:
///
/// ```swift
/// for region in chunk.bytes.regions {
///     region.withUnsafeBytes { … }
/// }
/// ```
///
/// ``copiedBytes()`` coalesces everything into one array. Like ``IMAPBuffer/copiedBytes()`` it is a
/// method because it allocates and copies on every call.
///
/// That is the convention across the byte types: anything that copies payload bytes or allocates per
/// region — ``copiedBytes()``, ``makeDispatchData()``, `makeByteBuffers()` — is a method, never a
/// computed property, because a property on a value that may hold a multi-megabyte literal reads as
/// free. Properties (``byteCount``, ``regionCount``, ``regions``) stay O(1).
public struct IMAPBufferList: Sendable {
    internal enum Storage: Sendable {
        case empty
        case one(IMAPBuffer)
        case many([IMAPBuffer])
    }

    internal var storage: Storage

    /// The total number of bytes across all regions.
    ///
    /// - Complexity: O(1).
    public private(set) var byteCount: Int

    /// Creates an empty list, holding no regions and no bytes.
    public init() {
        self.storage = .empty
        self.byteCount = 0
    }

    /// Creates a list holding one region.
    ///
    /// The region is kept even if it is empty, so ``regionCount`` is 1.
    ///
    /// - Parameter region: The region.
    public init(_ region: IMAPBuffer) {
        self.storage = .one(region)
        self.byteCount = region.count
    }

    /// Creates a list holding the given regions, in order.
    ///
    /// Empty regions are kept, so ``regionCount`` always matches what was passed in.
    ///
    /// - Parameter regions: The regions.
    public init(_ regions: some Sequence<IMAPBuffer>) {
        self.init()
        for region in regions {
            self.append(region)
        }
    }

    /// Appends a region to the end.
    ///
    /// The region is kept even if it is empty, so this always increases ``regionCount``.
    ///
    /// - Parameter region: The region to append.
    public mutating func append(_ region: IMAPBuffer) {
        switch storage {
        case .empty:
            storage = .one(region)
        case .one(let existing):
            storage = .many([existing, region])
        case .many(var regions):
            // Avoid a copy-on-write copy of the array while the enum still holds a reference.
            storage = .empty
            regions.append(region)
            storage = .many(regions)
        }
        byteCount += region.count
    }

    /// The number of regions.
    ///
    /// - Complexity: O(1).
    public var regionCount: Int {
        switch storage {
        case .empty: return 0
        case .one: return 1
        case .many(let regions): return regions.count
        }
    }

    /// The regions, in order.
    ///
    /// - Complexity: O(1) to obtain; iteration is O(``regionCount``).
    public var regions: Regions { Regions(list: self) }

    /// Copies every region's bytes into one array.
    ///
    /// - Complexity: O(``byteCount``). This allocates and copies on every call — prefer iterating
    ///   ``regions`` where the bytes do not need to be contiguous.
    /// - Returns: All of the bytes, in order.
    public func copiedBytes() -> [UInt8] {
        if case .one(let region) = storage {
            return region.copiedBytes()
        }
        var result = [UInt8]()
        result.reserveCapacity(byteCount)
        for region in regions {
            region.withUnsafeBytes { result.append(contentsOf: $0) }
        }
        return result
    }
}

// MARK: - Regions

extension IMAPBufferList {
    /// The regions of an ``IMAPBufferList``, in order.
    public struct Regions: RandomAccessCollection, Sendable {
        public typealias Element = IMAPBuffer
        public typealias Index = Int

        internal let list: IMAPBufferList

        public var startIndex: Int { 0 }
        public var endIndex: Int { list.regionCount }

        public subscript(position: Int) -> IMAPBuffer {
            precondition(position >= 0 && position < endIndex, "region index \(position) is out of bounds")
            switch list.storage {
            case .empty:
                fatalError("unreachable: the bounds check above rejects every index")
            case .one(let region):
                return region
            case .many(let regions):
                return regions[position]
            }
        }
    }
}

// MARK: - The region cap

extension IMAPBufferList {
    /// The most regions any one chunk is handed out as.
    ///
    /// Realistic chunks have one to three regions, and nothing in the library can produce more than a
    /// handful: a chunk of copied bytes is a protocol line, bounded well below one output segment, and
    /// at most one payload is appended by reference per command or response.
    ///
    /// The cap is insurance against a direct user of the public encode API, which accumulates until
    /// drained — a caller that writes a thousand payloads before asking for a chunk would otherwise
    /// get a thousand-region chunk, and 1024 is the most vectors a single `writev` can take.
    ///
    /// The encoder applies it to every chunk, whatever the sink handed it, so no
    /// ``EncoderOutputBuffer`` has to.
    internal static let maximumRegionsPerChunk = 64

    /// Creates a list of at most ``maximumRegionsPerChunk`` regions, coalescing the tail if there are
    /// more.
    ///
    /// The leading regions are kept as they are — those are the ones most likely to be large payloads
    /// worth not copying — and everything past the cap is copied into one region. Nothing is ever
    /// dropped, so this only ever trades zero-copy for a bounded region count.
    ///
    /// - Parameter regions: The regions, in order.
    internal init(cappingRegionCount regions: some Collection<IMAPBuffer>) {
        guard regions.count > Self.maximumRegionsPerChunk else {
            self.init(regions)
            return
        }

        let keeping = Self.maximumRegionsPerChunk - 1
        self.init(regions.prefix(keeping))
        let tail = regions.dropFirst(keeping)
        var coalesced: [UInt8] = []
        coalesced.reserveCapacity(tail.reduce(0) { $0 + $1.count })
        for region in tail {
            region.withUnsafeBytes { coalesced.append(contentsOf: $0) }
        }
        self.append(IMAPBuffer(coalesced))
    }
}

// MARK: - Equatable & Hashable

extension IMAPBufferList: Hashable {
    /// Compares two lists byte by byte, ignoring how the bytes are split into regions.
    ///
    /// Two lists holding the same bytes are equal whether one holds them as a single region and the
    /// other as five, and whether the regions are copied or retained. Encoders choose their own
    /// segmentation, so equality has to be independent of it.
    ///
    /// - Complexity: O(``byteCount``).
    public static func == (lhs: IMAPBufferList, rhs: IMAPBufferList) -> Bool {
        guard lhs.byteCount == rhs.byteCount else { return false }

        var rhsRegions = rhs.regions.makeIterator()
        var rhsCurrent = rhsRegions.next()
        var rhsOffset = 0

        for left in lhs.regions {
            var leftOffset = 0
            while leftOffset < left.count {
                // Skip past any exhausted or empty region on the right.
                while let current = rhsCurrent, rhsOffset >= current.count {
                    rhsCurrent = rhsRegions.next()
                    rhsOffset = 0
                }
                guard let right = rhsCurrent else {
                    // Cannot happen: the byte counts matched. Belt and braces.
                    return false
                }
                let shared = Swift.min(left.count - leftOffset, right.count - rhsOffset)
                let equal = left.withUnsafeBytes { leftBytes in
                    right.withUnsafeBytes { rightBytes in
                        UnsafeRawBufferPointer(rebasing: leftBytes[leftOffset..<(leftOffset + shared)])
                            .elementsEqual(
                                UnsafeRawBufferPointer(rebasing: rightBytes[rhsOffset..<(rhsOffset + shared)])
                            )
                    }
                }
                guard equal else { return false }
                leftOffset += shared
                rhsOffset += shared
            }
        }
        return true
    }

    /// Hashes the bytes, ignoring how they are split into regions.
    ///
    /// - Complexity: O(``byteCount``).
    public func hash(into hasher: inout Hasher) {
        for region in regions {
            region.withUnsafeBytes { hasher.combine(bytes: $0) }
        }
        hasher.combine(byteCount)
    }
}

// MARK: - Debugging

extension IMAPBufferList: CustomDebugStringConvertible {
    /// A description showing the byte and region counts.
    public var debugDescription: String {
        "IMAPBufferList(\(byteCount) bytes in \(regionCount) region\(regionCount == 1 ? "" : "s"))"
    }
}
