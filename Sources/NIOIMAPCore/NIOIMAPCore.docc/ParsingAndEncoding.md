# Parsing and Encoding

Parse IMAP server responses and encode client commands using these streaming parsers and encode buffers.

## Overview

NIOIMAPCore provides comprehensive parsing and encoding capabilities. These types handle the conversion between the IMAP wire format and strongly-typed Swift structures, including error handling and advanced features like pipelining.

On the way in, the caller owns the received bytes and the parser borrows them. Append each read to an ``IMAPInputBuffer`` — a read of 1 KiB or more at a fixed address is not copied; a `Data` is; for a `DispatchData`, ``IMAPInputBuffer/append(contentsOf:)`` keeps large regions without copying — and pass it to ``ResponseParser/parseResponseStream(buffer:)`` or ``CommandParser/parseCommandStream(buffer:)``, which consume what they parse and leave the rest. Small fields come out as owned values such as `String` and `[UInt8]`. Large payloads — message bodies, literals — come out as ``IMAPBuffer``: a piece of 1 KiB or more taken from a read the buffer retained refers to it rather than copying it (a large `Data` is retained as the buffer's one copy); smaller pieces, and bytes from smaller reads, are copied. Other ``ConsumableParserInputBuffer`` conformers work too; whether payloads are copied depends on whether the conformer vouches for its storage.

On the way out, ``CommandEncodeBuffer`` and ``ResponseEncodeBuffer`` write into an ``EncoderOutputBuffer`` — ``IMAPOutputBuffer`` unless you pass another — and hand bytes out as an ``IMAPBufferList`` — ordered ``IMAPBuffer`` regions, usually one — from ``CommandEncodeBuffer/nextChunk()`` and ``ResponseEncodeBuffer/readBytes()``. A command chunk ends at each synchronizing literal header; its ``CommandEncodeBuffer/Chunk/nextStep`` says whether to wait for the server's `+` before sending the next. A large payload you supply as an ``IMAPBuffer`` is kept by reference, so forwarding a message costs no copy. Handed-out bytes never move or change, so a chunk is `Sendable` and can be written while encoding continues. Convert it with ``IMAPBufferList/makeDispatchData()``, `makeByteBuffers()` in NIOIMAP, or ``IMAPBufferList/copiedBytes()``.

## Topics

### Parsers

Streaming parsers for different contexts.

- ``ResponseParser``
- ``CommandParser``
- ``SynchronizingLiteralParser``

### Encoders

Buffers for encoding protocol elements back to wire format.

- ``CommandEncodeBuffer``
- ``ResponseEncodeBuffer``
- ``CommandEncodingOptions``
- ``ResponseEncodingOptions``

### Bytes

Types for carrying raw message payloads without copying them.

- ``IMAPBuffer``
- ``IMAPBufferList``
- ``IMAPByteStorage``
- ``ByteRegion``
- ``StableAddressByteRegion``

### Parser input

Where received bytes wait to be parsed, and how the parser reads them.

- ``IMAPInputBuffer``
- ``ParserInputBuffer``
- ``ConsumableParserInputBuffer``
- ``StableRegionParserInputBuffer``
- ``ParseInput``
- ``RegionSink``

### Encoder output

Where encoded bytes go.

- ``EncoderOutputBuffer``
- ``IMAPOutputBuffer``

### Pipelining

Types related to command pipelining behavior.

- ``PipeliningRequirement``
- ``PipeliningBehavior``

### Errors

Parsing and encoding errors that may occur.

- ``BadCommand``
- ``ParserError``
- ``TooMuchRecursion``
- ``ExceededMaximumMessageAttributesError``
- ``ExceededMaximumBodySizeError``
- ``ExceededLiteralSizeLimitError``

### Utilities

Utility types and protocol defaults.

- ``ModifiedUTF7``
- ``IMAPDefaults``
