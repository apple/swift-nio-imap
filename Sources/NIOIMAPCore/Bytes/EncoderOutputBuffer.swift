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

/// Where encoded bytes go.
///
/// Conceptually a growable, append-only byte store that can hand out its leading bytes as
/// ``IMAPBuffer`` regions. The encoder writes into one of these and knows nothing else about it, so
/// the same encoder serves a caller who wants a `ByteBuffer`, a caller who wants a `DispatchData`,
/// and a caller who wants bytes in a file or in shared memory. That last group is the reason this is
/// a protocol rather than a concrete type: conforming costs a caller nothing beyond the six members
/// below.
///
/// ## Which type to use
///
/// A client does not write into a sink directly. It creates a ``CommandEncodeBuffer`` or a
/// ``ResponseEncodeBuffer`` — those are the encoders, and each owns a sink — and chooses the sink with
/// the `sink:` argument:
///
/// ```swift
/// // the default: segments the library allocates
/// var encoder = CommandEncodeBuffer(options: options, loggingMode: false)
/// // or, to hand a NIO Channel slices of one ByteBuffer rather than copies
/// var encoder = CommandEncodeBuffer(sink: ByteBufferOutput(), options: options, loggingMode: false)
/// ```
///
/// - ``IMAPOutputBuffer`` is the shipped conformer, the default argument, and what `NIOIMAP`'s
///   handlers use. Reach for it unless you have measured a reason not to: it never moves a byte it has
///   already written, which is what makes handing out a chunk while encoding continues free.
/// - `ByteBufferOutput`, in `NIOIMAP`, writes straight into a `ByteBuffer` and hands out slices of it,
///   so nothing is copied between the encoder and a `Channel`. It is slower on a stream of small
///   messages, and allocates a fresh `ByteBuffer` per hand-out while earlier bytes are still in
///   flight. It is a caller's choice, not the default.
/// - Conform yourself when the bytes have to land in storage this package cannot know about — a file,
///   shared memory, a ring buffer. The six members below are the whole obligation, plus value
///   semantics: copying an encoder copies its sink, so a class-backed sink would leave both copies
///   writing into one store. ``takeFirst(_:)`` carries the one requirement that is easy to get wrong.
///
/// This mirrors the read side, where ``ParserInputBuffer`` is the seam and ``IMAPInputBuffer`` is the
/// conformer to reach for.
///
/// ## Batched appends
///
/// The encoder stages small writes and appends them together, so a conformer sees fewer, larger
/// appends than there were writes, and ``byteCount`` and ``withPendingRegions(_:)`` may lag what has
/// been encoded. Bytes always arrive in order; staged ones arrive before the next ``takeFirst(_:)``.
///
/// ## What is deliberately not here
///
/// - **Stop points and chunking.** They belong to the encoder, which expresses them as offsets
///   counted in ``byteCount`` and ``takeFirst(_:)`` calls. A conformer never hears about IMAP.
/// - **An output type.** A conformer does not get to choose what ``takeFirst(_:)`` returns. It is
///   always an ``IMAPBufferList``, and converting that to a concrete backing —
///   `makeByteBuffers()`, ``IMAPBufferList/makeDispatchData()`` — happens afterwards. Making it an
///   associated type would make the encoder generic, and with it every one of the several hundred
///   methods that write IMAP grammar.
/// - **`~Copyable`.** It would be the better design — no copy-on-write box in ``IMAPOutputBuffer``,
///   and "one writer per segment" enforced statically — but a `~Copyable` sink forces a `~Copyable`
///   encoder. That breaks the closure-composition pattern of the grammar writers (`writeArray`,
///   `writeIfExists`) with exclusivity errors, and turns the client state machine's copies of its
///   stored encoder into moves.
///   Worth revisiting only as a project of its own. Byte-wise `Equatable`/`Hashable` is not the obstacle.
///
/// ## Sendability
///
/// - Note: This protocol is deliberately **not** `Sendable`. A sink never crosses a thread: it
///   belongs to one encoder, which belongs to one connection handler. What crosses a thread is a
///   handed-out chunk, so that is where `Sendable` lives — on ``IMAPBuffer`` and
///   ``IMAPBufferList``, whose bytes are immutable once handed out.
public protocol EncoderOutputBuffer {
    /// How many bytes are waiting to be handed out.
    ///
    /// This counts bytes appended since the last ``takeFirst(_:)``, so it goes **down** when bytes
    /// are handed out and it is **not** a monotonic total.
    ///
    /// - Important: This is not a substitute for "bytes ever written". An encoder that records
    ///   positions to chunk at — IMAP's synchronizing literals need exactly that — must keep its own
    ///   monotonic counter and compare against that. Comparing a position recorded before a
    ///   ``takeFirst(_:)`` against this property is wrong by however many bytes were handed out, and
    ///   the symptom is a client waiting forever for a continuation request the server has no reason
    ///   to send.
    ///
    /// - Complexity: O(1).
    var byteCount: Int { get }

    /// Copies bytes onto the end.
    ///
    /// - Parameter bytes: The bytes to append. Always copied.
    mutating func append(_ bytes: UnsafeRawBufferPointer)

    /// Appends a region that somebody else owns.
    ///
    /// A conformer that can retain the region **should**, rather than copy it: this is the path a
    /// multi-megabyte `APPEND` payload or a forwarded `FETCH` literal takes, and retaining is what
    /// makes forwarding one free. Copying is always correct, just not free.
    ///
    /// - Parameter region: The region to append.
    mutating func append(_ region: IMAPBuffer)

    /// Removes the first `byteCount` pending bytes and returns them, in order.
    ///
    /// - Important: The returned regions must stay valid, and their bytes unchanged, however much is
    ///   appended afterwards. A conformer therefore must not rewrite, move or reallocate bytes it has
    ///   handed out. Appending into a growable *contiguous* buffer cannot satisfy this, which is why
    ///   ``IMAPOutputBuffer`` is built out of fixed segments.
    ///
    /// - Parameter byteCount: How many bytes to take. Must not exceed ``byteCount``.
    /// - Returns: The bytes taken, as one or more regions.
    mutating func takeFirst(_ byteCount: Int) -> IMAPBufferList

    /// Calls the given closure with the pending regions, in order.
    ///
    /// This is a cold path: equality, hashing and debug descriptions. Nothing on the encode path
    /// reads bytes back.
    ///
    /// The regions arrive as a `Span` rather than a collection so that the signature itself says they
    /// must not escape the closure, while still allowing the indexed access a pairwise comparison
    /// needs.
    ///
    /// - Parameter body: A closure that receives the pending regions.
    /// - Returns: Whatever `body` returns.
    func withPendingRegions<R>(_ body: (Span<IMAPBuffer>) -> R) -> R

    /// Discards everything pending, and releases whatever memory was backing it.
    ///
    /// - Important: This must actually release storage, not just reset a position. A long-lived
    ///   encoder — a server handler reuses one for the lifetime of a connection — calls this after
    ///   every response, so anything retained here is retained forever.
    mutating func removeAll()
}

// MARK: - Strings

extension EncoderOutputBuffer {
    /// Copies a string's UTF-8 bytes onto the end.
    ///
    /// - Parameter string: The string to append.
    /// - Returns: The number of bytes appended.
    @discardableResult
    public mutating func append(_ string: String) -> Int {
        // Take the contiguous UTF-8 bytes if the string already has them, which is the case for
        // every native Swift string, including small ones.
        //
        // Deliberately NOT `var copy = string; copy.withUTF8 { … }`: `withUTF8` reaches contiguity
        // for a foreign string by heap-allocating and transcoding, not by spilling to the stack, and
        // writing it against a local `var` throws that work away and redoes it on the next call.
        let appended = string.utf8.withContiguousStorageIfAvailable { buffer -> Int in
            guard let base = buffer.baseAddress else { return 0 }
            self.append(UnsafeRawBufferPointer(start: base, count: buffer.count))
            return buffer.count
        }
        if let appended { return appended }

        // A foreign string — on Apple platforms, typically a bridged non-ASCII `NSString`, which is
        // exactly what a non-ASCII mailbox name arrives as. There is no way to reach its UTF-8 bytes
        // without transcoding them somewhere, so this allocates. Known and unavoidable.
        let bytes = Array(string.utf8)
        bytes.withUnsafeBytes { self.append($0) }
        return bytes.count
    }
}
