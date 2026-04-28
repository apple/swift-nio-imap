# ``NIOIMAPCore``

Parse and encode IMAP4rev1 protocol messages with type safety.

## Overview

NIOIMAPCore is the foundation of the swift-nio-imap project. It provides comprehensive, type-safe parsing and encoding of IMAP4rev1 protocol messages as described in RFC 3501 and related RFCs.

Use this module as a building block for creating IMAP clients and servers. It handles the complexity of the IMAP wire protocol, converting between byte streams and strongly-typed Swift data structures.

### Key Features

- **Type-Safe Protocol Representation**: IMAP commands, responses, and all protocol elements are represented as type-safe Swift enums and structures
- **Complete Protocol Support**: Full IMAP4rev1 implementation with extensive support for common extensions (see <doc:SupportedExtensions>)
- **Bidirectional Conversion**: Convert between IMAP wire format and Swift data structures in both directions
- **Streaming Support**: Handle large messages and streaming responses efficiently
- **Parser Combinator Architecture**: Composable, maintainable parsing logic built on reusable parser primitives

### How It Works

The IMAP protocol is text-based and involves continuous streams of commands and responses. NIOIMAPCore abstracts this complexity:

1. **Commands**: Client commands are represented as strongly-typed values (e.g., `Command.login(username:password:)`)
2. **Responses**: Server responses are parsed into comprehensive response types (e.g., `Response.untagged(.mailboxData(.exists(count)))`)
3. **Encoding**: Swift types are automatically encoded back to proper IMAP wire format

### Example

Here's an example of parsing and encoding an IMAP response:

```swift
// Parse: "* 18 EXISTS"
let response: Response = .untagged(.mailboxData(.exists(18)))

// Encode back to wire format
var buffer = ResponseEncodeBuffer()
buffer.writeResponse(response)
// Result: "* 18 EXISTS\r\n"
```

### Module Separation

NIOIMAPCore focuses purely on protocol parsing and encoding. For SwiftNIO integration (channel handlers, async/await APIs), see the NIOIMAP module, which builds on top of NIOIMAPCore.

## Topics

### Guides

- <doc:SupportedExtensions>

### Collections

- <doc:ProtocolCore>
- <doc:Commands>
- <doc:Responses>
- <doc:ParsingAndEncoding>
- <doc:GrammarTypes>
