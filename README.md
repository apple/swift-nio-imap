# swift-nio-imap

A Swift project that provides an implementation of the IMAP4rev1 protocol, built upon SwiftNIO.

This project implements:
 * Parsing IMAPv4 wire-format to type-safe Swift data structures
 * Encoding these Swift data structures to the IMAPv4 wire format
 * Extensive support for common IMAP extensions
 * Integration with SwiftNIO

For a list of IMAP extensions, see [EXTENSIONS.md](EXTENSIONS.md). 

*Note:* This is still a prototype and not quite production ready, yet.

### Introduction and Usage

`swift-nio-imap` implements the IMAP4rev1 protocol described in RFC 3501 and related RFCs. It is intended as a building block to build mail clients and/or servers. It is built upon SwiftNIO v2.x.

To use the framework use `import NIOIMAP`. NIOIMAP supports a variety of IMAP extensions, check `EXTENSIONS.md` for full details.

### Example Exchange

As a quick example, here’s part of the the exchange listed in RFC 3501 section 8, where lines starting with S: and C: are from the server and client respectively:

```text
S: * OK IMAP4rev1 Service Ready
C: a001 login mrc secret
S: a001 OK LOGIN completed
C: a002 select inbox
S: * 18 EXISTS
S: * FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
S: * 2 RECENT
S: * OK [UNSEEN 17] Message 17 is the first unseen message
S: * OK [UIDVALIDITY 3857529045] UIDs valid
S: a002 OK [READ-WRITE] SELECT completed```
```

The first 3 lines would correspond to the following in SwiftNIO IMAP:
```swift
Response.untagged(.conditionalState(.ok(ResponseText(text: "IMAP4rev1 Service Ready"))))
CommandStreamPart.tagged(TaggedCommand(tag: "a001", command: .login(username: "mrc", password: "secret")))
Response.tagged(.init(tag: "a001", state: .ok(ResponseText(text: "LOGIN completed"))))
```

Next, up is the SELECT command and its responses, which are more interesting:
```swift
CommandStreamPart.tagged(TaggedCommand(tag: "a002", command: .select(MailboxName("box1"), [])))
Response.untagged(.mailboxData(.exists(18)))
Response.untagged(.mailboxData(.flags([.answered, .flagged, .deleted, .seen, .draft])))
Response.untagged(.mailboxData(.recent(2)))
Response.untagged(.conditionalState(.ok(ResponseText(code: .unseen(17), text: "Message 17 is the first unseen message"))))
Response.untagged(.conditionalState(.ok(ResponseText(code: .uidValidity(3857529045), text: "UIDs valid"))))
Response.tagged(.init(tag: "a002", state: .ok(ResponseText(code: .readWrite, text: "SELECT completed"))))
```

There’s more going on here than this example shows. But this gives a general idea of how the types look and feel.

### Integration with SwiftNIO

SwiftNIO IMAP provides a pair of ChannelHandler objects that can be integrated into a SwiftNIO ChannelPipeline. This allows sending IMAP commands using NIO Channels.

The two handlers SwiftNIO IMAP provides are IMAPClientHandler and IMAPServerHandler. Each of these can be inserted into the ChannelPipeline. They can then be used to encode and decode messages. For example:
```swift
let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let channel = try await ClientBootstrap(group).channelInitializer { channel in
    channel.pipeline.addHandler(IMAPClientHandler())
}.connect(host: example.com, port: 143).get()

try await channel.writeAndFlush(CommandStreamPart.tagged(TaggedCommand(tag: "a001", command: .login(username: "mrc", password: "secret"))), promise: nil)
```
