# Zero-copy with ByteBuffer and DispatchData

Move message bytes between your transport, the parser, and the encoder without copying large payloads.

## Overview

NIOIMAPCore interoperates with SwiftNIO's `ByteBuffer` and Dispatch's `DispatchData` without copying, in both directions. This is a design goal, not an optimization added later. The library doesn't copy a multi-megabyte message body on its way from a network read to your code, or from your code to a network write.

The library keeps large payloads by reference and copies small ones. Copying a small run costs less than tracking it.

The `IMAPClientHandler` and `IMAPServerHandler` types in `NIOIMAP` already do all of this. Read on if you drive the parser and encoder yourself, for example over `DispatchIO` or Network.framework.

### Append received bytes

Append each read to an ``IMAPInputBuffer``. Then pass the buffer to ``ResponseParser/parseResponseStream(buffer:)``, ``CommandParser/parseCommandStream(buffer:)``, or ``SynchronizingLiteralParser/parseContinuationsNecessary(_:)``. The parser consumes what it parses and leaves the rest for the next call.

```swift
import Dispatch
import NIOIMAPCore

struct ResponseReader {
    var input = IMAPInputBuffer()
    var parser = ResponseParser()

    mutating func received(_ data: DispatchData) throws -> [ResponseOrContinuationRequest] {
        input.append(contentsOf: data)
        var elements: [ResponseOrContinuationRequest] = []
        while let element = try parser.parseResponseStream(buffer: &input) {
            elements.append(element)
        }
        return elements
    }
}
```

With `NIOIMAP`, call `input.append(byteBuffer)` for a `ByteBuffer`.

``IMAPInputBuffer`` copies a read under 1 KiB into a shared tail. It keeps a larger read by reference if the read has a fixed address:

| Appended value | Under 1 KiB | 1 KiB or more |
| --- | --- | --- |
| `ByteBuffer` | Copied | Kept |
| `[UInt8]` | Copied | Kept |
| `DispatchData`, through ``IMAPInputBuffer/append(contentsOf:)`` | Copied, per region | Kept, per region |
| `Data` | Copied | Copied |
| Your ``StableAddressByteRegion`` | Copied | Kept |

Appending never moves bytes already in the buffer, and consuming them is O(1). A kept `DispatchData` region keeps the whole `DispatchData` alive.

### Receive large literals by reference

The parser delivers message bodies and other literals as ``IMAPBuffer`` values, in ``FetchResponse/streamingBytes(_:)`` and ``AppendCommand/messageBytes(_:)``. It keeps a literal by reference, rather than copying it, when both of these are true:

- The literal is at least 512 bytes.
- The literal is at least a third of the memory its owner keeps alive.

The owner is the value you appended. A `ByteBuffer` keeps its storage capacity alive, an array its capacity, and a `DispatchData` region the whole `DispatchData`.

A kept literal keeps its owner alive for as long as you hold the ``IMAPBuffer``. That's the trade-off, and the one-third rule caps it: the owner is never more than three times the size of the literal. A literal that spans several reads arrives in pieces, and each piece follows the same rule. To release the owner, call ``IMAPBuffer/copied()``.

### Read an IMAPBuffer

Use ``IMAPBuffer/withUnsafeBytes(_:)`` to read bytes in place. It never copies:

```swift
import CryptoKit

var hash = SHA256()
body.withUnsafeBytes { hash.update(bufferPointer: $0) }
```

Use ``IMAPBuffer/backingRegion(as:)`` to get back the value you appended, plus the range the literal covers. In `NIOIMAP`, the `byteBuffer` property uses it to return a slice of your `ByteBuffer`, and copies only if the bytes came from elsewhere.

``IMAPBuffer/copiedBytes()`` returns an array, and copies on every call.

### Send encoded bytes

``CommandEncodeBuffer`` and ``ResponseEncodeBuffer`` write into an ``IMAPOutputBuffer``. They hand bytes out as ``IMAPBufferList`` chunks from ``CommandEncodeBuffer/nextChunk()`` and ``ResponseEncodeBuffer/readBytes()``. Handed-out bytes never move or change, so you can send a chunk while encoding continues.

```swift
var encoder = CommandEncodeBuffer(capabilities: capabilities, loggingMode: false)
for part in parts {
    encoder.writeCommandStream(part)
}
while let chunk = encoder.nextChunk() {
    try await send(chunk.bytes.makeDispatchData())
    if chunk.nextStep == .awaitContinuationRequest {
        try await waitForContinuationRequest()
    }
}
```

The encoder keeps an ``IMAPBuffer`` you pass it, such as ``AppendCommand/messageBytes(_:)``, by reference if it's 1 KiB or more, and copies it otherwise. A literal received from a `ByteBuffer` can be forwarded and leave as a slice of that same `ByteBuffer`.

Convert a chunk for your transport:

| Conversion | Kept | Copied |
| --- | --- | --- |
| ``IMAPBufferList/makeDispatchData()`` | Regions of 512 bytes or more with a fixed address: the encoder's own bytes, arrays, and ``StableAddressByteRegion`` values | Each run of other regions, into one allocation |
| `makeByteBuffers()`, in `NIOIMAP` | Regions backed by a `ByteBuffer`, as slices | Every other region, once |

A `DispatchData` adopts a kept region's memory and keeps its owner alive. Dispatch releases the owner asynchronously, so peak memory lags slightly behind.

### Conform your own buffer type

Conform to ``ByteRegion`` so the library can read your type. Its one requirement, ``ByteRegion/withUnsafeBytes(_:)``, matches Foundation's `ContiguousBytes`. The library copies a plain ``ByteRegion``.

Conform to ``StableAddressByteRegion`` to have large values kept instead. Conforming promises that ``ByteRegion/withUnsafeBytes(_:)`` yields the actual storage, at a fixed address. Those bytes must not move or change while any copy of the value is alive. The library can't check this promise. Breaking it leaves a dangling pointer.

```swift
extension MyBuffer: StableAddressByteRegion {
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try storage.withUnsafeReadableBytes(body)
    }

    // The memory a kept value keeps alive. Defaults to the number of bytes.
    var pinnedByteCount: Int { storage.capacity }
}
```

Implement ``StableAddressByteRegion/pinnedByteCount`` if a value keeps more memory alive than it exposes, so the one-third rule sees the real cost. Append your type to an ``IMAPInputBuffer``, and recover it with ``IMAPBuffer/backingRegion(as:)``.
