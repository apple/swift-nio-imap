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

import DequeModule

/// A buffer for encoding IMAP protocol messages into wire format.
///
/// `EncodeBuffer` is the core infrastructure for converting Swift types into bytes
/// that can be transmitted over the network. It appends those bytes to an
/// ``EncoderOutputBuffer`` — a sink chosen by whoever created the buffer — and tracks encoding state.
///
/// Part of the internal SPI and is primarily used by:
/// - ``CommandEncodeBuffer`` for encoding client commands
/// - ``ResponseEncodeBuffer`` for encoding server responses
///
/// The buffer can operate in two modes via the ``Mode`` enum:
/// - **Client mode**: Uses ``CommandEncodingOptions`` to determine how to encode literals,
///   strings, and other protocol elements
/// - **Server mode**: Uses ``ResponseEncodingOptions`` to format server responses
///
/// ## Chunking and Continuation
///
/// The buffer supports splitting encoded data into "chunks" separated by continuation
/// points. This enables proper handling of IMAP's synchronizing literals, where the
/// server must send a `+` continuation request before the client can send more data.
/// The ``nextChunk()`` method retrieves the next chunk and indicates whether a
/// continuation response is expected.
///
/// - SeeAlso: ``CommandEncodeBuffer``, ``ResponseEncodeBuffer``
@_spi(NIOIMAPInternal) public struct EncodeBuffer {
    /// Determines whether the buffer encodes for a client or server.
    ///
    /// Affects how the buffer formats protocol elements like literals, strings,
    /// and response codes. The mode also carries encoding options specific to each role.
    public enum Mode: Hashable, Sendable {
        /// Encodes client commands using the specified options.
        ///
        /// When in client mode, the buffer formats command data according to the
        /// options, which control whether to use quoted strings, synchronizing literals,
        /// non-synchronizing literals, and binary literals.
        ///
        /// - Parameter options: Configuration for command encoding
        case client(options: CommandEncodingOptions)

        /// Encodes server responses using the specified options.
        ///
        /// - Parameter streamingAttributes: A flag tracking whether streaming attributes
        ///   are currently being written (used internally for FETCH response formatting)
        /// - Parameter options: Configuration for response encoding
        case server(streamingAttributes: Bool, options: ResponseEncodingOptions)
    }

    /// Enables logging mode, which obscures binary data for display purposes.
    ///
    /// When `true`, methods like ``writeBytes(_:)-1nrmp`` will write placeholder text like
    /// `[N bytes]` instead of the actual binary content. Useful for logging and debugging without
    /// exposing sensitive data.
    public var loggingMode: Bool

    internal var mode: Mode

    /// Where the encoded bytes go.
    @usableFromInline internal var sink: any EncoderOutputBuffer

    /// Offsets, counted in ``totalWritten``, at which chunks must be broken.
    ///
    /// These are **absolute** — bytes ever appended to this buffer — rather than positions within
    /// what the sink is currently holding, because the sink's contents shrink every time a chunk is
    /// handed out. See ``markStopPoint()``.
    @usableFromInline internal var stopPoints: Deque<Int> = []

    /// How many bytes have ever been appended, since the buffer was created or last cleared.
    @usableFromInline internal var totalWritten: Int = 0

    /// How many bytes have ever been handed out by ``nextChunk()``.
    ///
    /// `handedOut + sink.byteCount + stagedCount == totalWritten` at all times, which is the invariant
    /// that makes the absolute stop points above meaningful.
    @usableFromInline internal var handedOut: Int = 0

    /// Small writes collect here and reach the sink as one `append`: one existential call per
    /// ``stagingCapacity`` bytes instead of one per write. Flushed before any direct sink append and
    /// before the sink hands bytes out.
    @usableFromInline internal var staging = Staging(repeating: 0)

    /// How many bytes at the start of ``staging`` are waiting for the sink.
    @usableFromInline internal var stagedCount: Int = 0

    // 256: a typical command or response line, while keeping copies of `EncodeBuffer` cheap.
    @usableFromInline typealias Staging = InlineArray<256, UInt8>

    /// The most bytes ``staging`` holds. A write at least this big skips it.
    @inlinable static var stagingCapacity: Int { Staging.count }

    init(_ sink: some EncoderOutputBuffer, mode: Mode, loggingMode: Bool) {
        self.sink = sink
        self.mode = mode
        self.loggingMode = loggingMode
    }
}

// MARK: - Sendability

/// `EncodeBuffer` is deliberately **not** `Sendable`.
///
/// It writes into an ``EncoderOutputBuffer``, which is not `Sendable` either: a sink belongs to one
/// encoder, which belongs to one connection handler, and it may own memory it is actively writing
/// into. What does cross a thread is a chunk that has been handed out — ``Chunk`` holds an
/// ``IMAPBufferList``, whose bytes are frozen at hand-out and so are `Sendable`.
@available(*, unavailable)
extension EncodeBuffer: Sendable {}

extension EncodeBuffer {
    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter sink: Where the encoded bytes are appended.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for client use.
    static func clientEncodeBuffer(
        sink: some EncoderOutputBuffer = IMAPOutputBuffer(),
        options: CommandEncodingOptions,
        loggingMode: Bool
    ) -> EncodeBuffer {
        EncodeBuffer(sink, mode: .client(options: options), loggingMode: loggingMode)
    }

    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter sink: Where the encoded bytes are appended.
    /// - parameter capabilities: The capabilities the server advertised, which decide the encoding
    ///     options.
    /// - returns: A new `EncodeBuffer` configured for client use.
    static func clientEncodeBuffer(
        sink: some EncoderOutputBuffer = IMAPOutputBuffer(),
        capabilities: [Capability],
        loggingMode: Bool
    ) -> EncodeBuffer {
        clientEncodeBuffer(
            sink: sink,
            options: CommandEncodingOptions(capabilities: capabilities),
            loggingMode: loggingMode
        )
    }

    /// Creates a new `EncodeBuffer` suitable for a server to write responses.
    /// - parameter sink: Where the encoded bytes are appended.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for server use.
    static func serverEncodeBuffer(
        sink: some EncoderOutputBuffer = IMAPOutputBuffer(),
        options: ResponseEncodingOptions,
        loggingMode: Bool
    ) -> EncodeBuffer {
        EncodeBuffer(sink, mode: .server(streamingAttributes: false, options: options), loggingMode: loggingMode)
    }

    /// Creates a new `EncodeBuffer` suitable for a server to write responses.
    /// - parameter sink: Where the encoded bytes are appended.
    /// - parameter capabilities: The capabilities the server advertises, which decide the encoding
    ///     options.
    /// - returns: A new `EncodeBuffer` configured for server use.
    static func serverEncodeBuffer(
        sink: some EncoderOutputBuffer = IMAPOutputBuffer(),
        capabilities: [Capability],
        loggingMode: Bool
    ) -> EncodeBuffer {
        serverEncodeBuffer(
            sink: sink,
            options: ResponseEncodingOptions(capabilities: capabilities),
            loggingMode: loggingMode
        )
    }
}

extension EncodeBuffer {
    /// Call the closure with a buffer, return the result as a String.
    ///
    /// Used for implementing ``CustomDebugStringConvertible`` conformance.
    static func makeDescription(_ closure: (inout EncodeBuffer) -> Void) -> String {
        var options = CommandEncodingOptions.rfc3501
        options.useQuotedString = true
        options.useSynchronizingLiteral = false
        options.useNonSynchronizingLiteralPlus = true
        var buffer = EncodeBuffer.clientEncodeBuffer(options: options, loggingMode: false)
        closure(&buffer)
        return String(bestEffortDecodingUTF8Bytes: buffer.makePendingBufferList().copiedBytes())
    }

    /// The bytes appended but not yet handed out, as one list.
    ///
    /// Cold path only — equality, hashing and debug descriptions. This allocates per pending region,
    /// which is why it is a method rather than a property.
    internal func makePendingBufferList() -> IMAPBufferList {
        var list = sink.withPendingRegions { regions in
            var list = IMAPBufferList()
            for index in 0..<regions.count {
                list.append(regions[index])
            }
            return list
        }
        if self.stagedCount > 0 {
            list.append(withUnsafeBytes(of: self.staging) { IMAPBuffer(Array($0.prefix(self.stagedCount))) })
        }
        return list
    }
}

extension EncodeBuffer {
    /// A portion of encoded data ready to be transmitted.
    ///
    /// IMAP requires careful sequencing when using synchronizing literals. After encoding
    /// a command with a literal, the buffer chunks the data into segments: one that ends
    /// before the literal, then waits for a continuation response, then sends the literal
    /// data and any remaining command.
    ///
    /// Each `Chunk` represents a portion of data that is ready to send, along with
    /// metadata about whether a continuation response is expected.
    public struct Chunk: Hashable, Sendable {
        /// The encoded bytes ready to write to the network.
        ///
        /// Contains the next portion of IMAP protocol data to transmit, as one or more regions —
        /// usually one. A networking caller writes them in order and lets the transport gather
        /// them; ``IMAPBufferList/copiedBytes()`` coalesces them where they have to be contiguous.
        public var bytes: IMAPBufferList

        /// Whether a continuation request (`+`) should be expected before sending the next chunk.
        ///
        /// When `true`, the sender must wait for the server to send a `+` continuation
        /// response before calling ``nextChunk()`` again. This synchronization is required
        /// by RFC 3501 for commands containing literals.
        ///
        /// `false` for a chunk that ends at a stop point with nothing written after it yet, e.g.
        /// APPEND's `{5}\r\n`; ``CommandEncodeBuffer/nextChunk()`` reports that one as awaiting `+`.
        ///
        /// - SeeAlso: ``ContinuationRequest``
        public var waitForContinuation: Bool
    }

    @_spi(NIOIMAPInternal) var hasChunks: Bool {
        self.stopPoints.count > 0
    }

    /// How many bytes have been written but not yet handed out by ``nextChunk()``.
    internal var pendingByteCount: Int {
        self.sink.byteCount + self.stagedCount
    }

    /// Retrieves the next chunk of encoded data ready to transmit.
    ///
    /// In client mode with synchronizing literals, this may return multiple chunks with
    /// ``Chunk/waitForContinuation`` set to `true` between chunks, requiring the caller
    /// to pause and wait for the server's `+` continuation request.
    ///
    /// In server mode, this always returns all remaining data in a single chunk with
    /// ``Chunk/waitForContinuation`` set to `false`.
    ///
    /// - Returns: The next ``Chunk`` of data to transmit.
    public mutating func nextChunk() -> Chunk {
        self.nextChunk(allowEmptyChunk: true)
    }

    /// Gets the next chunk that is ready to be written to the network.
    /// *NOTE*: Use This function with caution. You probably shouldn't be using it, using nextChunk() instead.
    /// - returns: The next chunk that is ready to be written.
    @_spi(NIOIMAPInternal) public mutating func nextChunk(allowEmptyChunk: Bool) -> Chunk {
        self.takeChunk(allowEmptyChunk: allowEmptyChunk).chunk
    }

    /// Where a chunk handed out by ``takeChunk(allowEmptyChunk:)`` ends.
    enum ChunkEnd {
        /// At a stop point: a synchronizing literal header, whose `+` the client awaits. Possibly the
        /// last byte written, e.g. APPEND's `{5}\r\n` before the message bytes are written.
        case stopPoint
        /// With everything pending; no stop point remains.
        case pendingBytes
    }

    /// ``nextChunk(allowEmptyChunk:)``, and whether the chunk ended at a stop point.
    ///
    /// ``Chunk/waitForContinuation`` can't tell: it is `false` for a stop point that is the last byte
    /// written so far.
    mutating func takeChunk(allowEmptyChunk: Bool) -> (chunk: Chunk, end: ChunkEnd) {
        switch self.mode {
        case .client:
            guard let stopPoint = self.stopPoints.popFirst() else {
                // A zero-*bytes* check, deliberately not `regionCount == 0`: a chunk carrying one
                // zero-length region holds no bytes at all.
                precondition(allowEmptyChunk || self.pendingByteCount > 0, "No next chunk to send.")
                return (.init(bytes: self.takeEverythingPending(), waitForContinuation: false), .pendingBytes)
            }
            // Both are absolute offsets, so the difference is what is pending below the stop point.
            // Comparing a stop point against the sink's own (resetting) byte count instead is the
            // mistake that deadlocks the protocol.
            let bytes = self.takeFromSink(stopPoint - self.handedOut)
            self.handedOut = stopPoint
            return (.init(bytes: bytes, waitForContinuation: stopPoint != self.totalWritten), .stopPoint)
        case .server:
            return (.init(bytes: self.takeEverythingPending(), waitForContinuation: false), .pendingBytes)
        }
    }

    private mutating func takeEverythingPending() -> IMAPBufferList {
        let bytes = self.takeFromSink(self.pendingByteCount)
        self.handedOut = self.totalWritten
        return bytes
    }

    /// Takes pending bytes, staged ones included, capped at ``IMAPBufferList/maximumRegionsPerChunk``
    /// regions whatever the sink returned.
    ///
    /// The cap is here rather than in each sink so that a sink of the caller's own gets it too. Checking
    /// is O(1); only a list over the cap is rebuilt.
    private mutating func takeFromSink(_ byteCount: Int) -> IMAPBufferList {
        self.flushStaging()
        let bytes = self.sink.takeFirst(byteCount)
        guard bytes.regionCount > IMAPBufferList.maximumRegionsPerChunk else { return bytes }
        return IMAPBufferList(cappingRegionCount: bytes.regions)
    }

    /// Marks the end of a command, potentially creating a stop point for chunking.
    ///
    /// In client mode, this sets a stop point that ``nextChunk()`` uses to determine
    /// chunk boundaries. This is necessary for proper handling of synchronizing literals,
    /// where each chunk must be separated by a continuation request/response cycle.
    ///
    /// In server mode, this call has no effect (server responses don't use stop points).
    ///
    /// - Returns: Always returns `0` (for compatibility with writer method conventions).
    @discardableResult
    public mutating func markStopPoint() -> Int {
        if case .client = mode {
            stopPoints.append(totalWritten)
        }
        return 0
    }
}

extension EncodeBuffer {
    /// Writes a string to the buffer in UTF-8 encoding.
    ///
    /// - Parameter string: The string to write.
    /// - Returns: The number of bytes written (equals `string.utf8.count`).
    @discardableResult
    @inlinable
    public mutating func writeString(_ string: String) -> Int {
        // Contiguous for every native string. A foreign one, e.g. a bridged non-ASCII `NSString`,
        // has to be transcoded, which allocates.
        let written = string.utf8.withContiguousStorageIfAvailable { self.appendBytes(UnsafeRawBufferPointer($0)) }
        if let written { return written }
        return Array(string.utf8).withUnsafeBytes { self.appendBytes($0) }
    }

    /// Writes a single byte to the buffer.
    ///
    /// Prefer this over ``writeString(_:)`` with a one-character literal: it skips the `String`
    /// machinery entirely.
    ///
    /// - Parameter byte: The byte to write.
    /// - Returns: The number of bytes written, always 1.
    @discardableResult
    @inlinable
    public mutating func writeByte(_ byte: UInt8) -> Int {
        // `withUnsafeBytes(of:)` on a trivial local, rather than `writeBytes(CollectionOfOne(byte))`:
        // the sink takes a pointer, so a one-element collection would have to be materialised first.
        withUnsafeBytes(of: byte) { self.appendBytes($0) }
    }

    /// The widest integer ``writeDecimal(_:minimumDigits:)`` accepts, in bits: the widest standard
    /// library integer.
    @inlinable
    static var maximumDecimalBitWidth: Int { 128 }

    /// The most bytes ``writeDecimal(_:minimumDigits:)`` writes: the digits of the widest
    /// ``maximumDecimalBitWidth``-bit magnitude, plus a sign.
    @inlinable
    static var maximumDecimalLength: Int { 39 + 1 }  // digits in UInt128.max + sign

    /// Writes an integer as ASCII decimal digits.
    ///
    /// Prefer this over interpolating a number into a string: `writeString("{\(count)}")` runs the
    /// interpolation machinery and heap-allocates as soon as the result exceeds 15 UTF-8 bytes,
    /// whereas this formats the digits into a stack buffer and copies them once.
    ///
    /// Unlike ``writeBytes(_:)-1nrmp``, this is never redacted in ``loggingMode`` — the numbers
    /// written here are lengths, offsets and identifiers, not payload.
    ///
    /// - Parameters:
    ///   - number: The number to write, at most `maximumDecimalBitWidth` bits wide. A negative number is
    ///     written with a leading `-`.
    ///   - minimumDigits: Pad with leading zeros up to this many digits. The sign, if any, doesn't
    ///     count towards it. Must be less than `maximumDecimalLength`.
    /// - Returns: The number of bytes written.
    @discardableResult
    @inlinable
    public mutating func writeDecimal<Number: FixedWidthInteger>(_ number: Number, minimumDigits: Int = 1) -> Int {
        precondition(minimumDigits < Self.maximumDecimalLength, "minimumDigits must be less than maximumDecimalLength")
        // A wider magnitude can have more digits than the buffer holds. Folds away when specialized.
        precondition(Number.bitWidth <= Self.maximumDecimalBitWidth, "Number is wider than maximumDecimalBitWidth")
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: Self.maximumDecimalLength) { digits in
            var index = digits.endIndex
            var magnitude = number.magnitude
            var written = 0
            repeat {
                let (quotient, remainder) = magnitude.quotientAndRemainder(dividingBy: 10)
                index -= 1
                digits[index] = UInt8(ascii: "0") + UInt8(truncatingIfNeeded: remainder)
                magnitude = quotient
                written += 1
            } while magnitude != 0
            while written < minimumDigits, index > digits.startIndex {
                index -= 1
                digits[index] = UInt8(ascii: "0")
                written += 1
            }
            if number < 0, index > digits.startIndex {
                index -= 1
                digits[index] = UInt8(ascii: "-")
            }
            return self.appendBytes(UnsafeRawBufferPointer(UnsafeBufferPointer(rebasing: digits[index...])))
        }
    }

    /// Writes raw bytes to the buffer.
    ///
    /// When ``loggingMode`` is enabled, this writes a placeholder like `[N bytes]`
    /// instead of the actual binary data, useful for debugging without exposing sensitive content.
    ///
    /// - Parameter bytes: The bytes to write.
    /// - Returns: The number of bytes written (in logging mode, this is the length of the placeholder).
    @discardableResult
    @inlinable
    public mutating func writeBytes(_ bytes: some Collection<UInt8>) -> Int {
        guard !loggingMode else {
            return self.writeRedactedByteCount(bytes.count)
        }
        // Every caller in the encoder passes an array, an `ArraySlice`, or a `String.UTF8View`, all
        // of which take the contiguous path.
        if let written = bytes.withContiguousStorageIfAvailable({ buffer -> Int in
            guard let base = buffer.baseAddress else { return 0 }
            return self.appendBytes(UnsafeRawBufferPointer(start: base, count: buffer.count))
        }) {
            return written
        }
        let contiguous = ContiguousArray(bytes)
        return contiguous.withUnsafeBytes { self.appendBytes($0) }
    }

    /// Writes raw message bytes to the buffer.
    ///
    /// This is the overload the four raw-payload model cases use — `messageBytes`, `catenateData`,
    /// `continuationResponse` and `streamingBytes`. It exists so that a multi-megabyte literal can be
    /// handed to the encoder without being copied, which is what an ``IMAPBuffer`` gives a caller
    /// that received it from the parser or wrapped its own memory in it.
    ///
    /// Whether the bytes are actually copied is the sink's decision: ``IMAPOutputBuffer`` keeps a
    /// large region by reference and copies a small one, so forwarding a `FETCH` literal into an
    /// `APPEND` costs nothing.
    ///
    /// When ``loggingMode`` is enabled, this writes a placeholder like `[N bytes]` instead of the
    /// payload, matching the other byte-writing primitives.
    ///
    /// - Parameter region: The bytes to write.
    /// - Returns: The number of bytes written (in logging mode, this is the length of the placeholder).
    @discardableResult
    @inlinable
    public mutating func writeBytes(_ region: IMAPBuffer) -> Int {
        guard !loggingMode else {
            return self.writeRedactedByteCount(region.count)
        }
        // Flush first: the sink must see the bytes in order, and gets the region itself, uncopied.
        self.flushStaging()
        self.sink.append(region)
        self.totalWritten += region.count
        return region.count
    }

    /// Appends bytes with no redaction: into ``staging`` if they fit, else to the sink.
    ///
    /// The primitive the redaction-exempt writers (``writeByte(_:)``,
    /// ``writeDecimal(_:minimumDigits:)``) and the already-redacted ones build on. A caller that
    /// writes payload has to consult ``loggingMode`` before reaching this.
    ///
    /// - Parameter bytes: The bytes to append.
    /// - Returns: The number of bytes appended.
    @discardableResult
    @inlinable
    mutating func appendBytes(_ bytes: UnsafeRawBufferPointer) -> Int {
        let count = bytes.count
        self.totalWritten += count
        guard count < Self.stagingCapacity else {
            self.flushStaging()
            self.sink.append(bytes)
            return count
        }
        guard let source = bytes.baseAddress else { return count }
        if count > Self.stagingCapacity - self.stagedCount {
            self.flushStaging()
        }
        let offset = self.stagedCount
        withUnsafeMutableBytes(of: &self.staging) { staging in
            staging.baseAddress!.advanced(by: offset).copyMemory(from: source, byteCount: count)
        }
        self.stagedCount += count
        return count
    }

    /// Hands the staged bytes to the sink.
    @inlinable
    mutating func flushStaging() {
        guard self.stagedCount > 0 else { return }
        let count = self.stagedCount
        self.stagedCount = 0
        withUnsafeBytes(of: &self.staging) { self.sink.append(UnsafeRawBufferPointer(rebasing: $0.prefix(count))) }
    }

    /// Writes the `[123 bytes]` placeholder that ``loggingMode`` substitutes for payload bytes.
    ///
    /// - Parameter byteCount: The number of bytes that were redacted.
    /// - Returns: The number of bytes written.
    @discardableResult
    @inlinable
    mutating func writeRedactedByteCount(_ byteCount: Int) -> Int {
        self.writeByte(UInt8(ascii: "[")) + self.writeDecimal(byteCount) + self.writeString(" bytes]")
    }

    /// Erases all data from the buffer and resets the chunk tracking.
    ///
    /// - Note: This invalidates any previously obtained ``Chunk`` values.
    @inlinable
    public mutating func clear() {
        self.stopPoints.removeAll()
        self.sink.removeAll()
        self.stagedCount = 0
        self.totalWritten = 0
        self.handedOut = 0
    }
}

// MARK: - Equatable & Hashable

extension EncodeBuffer: Hashable {
    /// Compares two buffers by their state and by the bytes they are holding.
    ///
    /// The bytes are compared byte by byte rather than region by region, so two buffers holding the
    /// same bytes are equal however their sinks happened to split them up. That matters because the
    /// split depends on segment sizes and on whether a payload was retained or copied.
    ///
    /// - Complexity: O(``pendingByteCount``).
    public static func == (lhs: EncodeBuffer, rhs: EncodeBuffer) -> Bool {
        lhs.mode == rhs.mode && lhs.loggingMode == rhs.loggingMode && lhs.stopPoints == rhs.stopPoints
            && lhs.totalWritten == rhs.totalWritten && lhs.handedOut == rhs.handedOut
            && lhs.makePendingBufferList() == rhs.makePendingBufferList()
    }

    /// Hashes the buffer's state and the bytes it is holding.
    ///
    /// - Complexity: O(``pendingByteCount``).
    public func hash(into hasher: inout Hasher) {
        hasher.combine(mode)
        hasher.combine(loggingMode)
        hasher.combine(stopPoints)
        hasher.combine(totalWritten)
        hasher.combine(handedOut)
        hasher.combine(makePendingBufferList())
    }
}

extension EncodeBuffer {
    mutating func withoutLoggingMode<R>(_ closure: (inout EncodeBuffer) -> R) -> R {
        let old = self.loggingMode
        defer {
            self.loggingMode = old
        }
        self.loggingMode = false
        return closure(&self)
    }
}
