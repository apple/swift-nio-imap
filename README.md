# swift-nio-imap

A Swift project that provides an implementation of the IMAP4rev1 protocol, built upon SwiftNIO.

### Introduction and Usage

`swift-nio-imap` implements the IMAP4rev1 protocol described in RFC 3501 and related RFCs. It is intended as a building block to build mail clients and/or servers. It is built upon SwiftNIO v2.x.

To use the framework use `import NIOIMAP`. We support a variety of IMAP extensions, check `EXTENSIONS.md` for full details.

### Commands

Commands are what an IMAP client sends to a server.

A command consists of a `Tag` and a `Command`.

#### Examples
`Command("tag1", .noop)` => `tag1 NOOP`
`Command("tag2", .capability)` => `tag1 CAPABILITY`
`Command("tag3", .login("email@apple.com", "password"))` => `tag3 LOGIN "email@apple.com" "password"`

To send a command we recommend using a `MessageToByteHandler` with `CommandEncoder` as the encoder:

```
ClientBootstrap(group: context.eventLoop).channelInitializer { channel in
  channel.addHandler(MessageToByteHandler(CommandEncoder()))
}
```

Alternatively, you can write a command manually to a `ByteBuffer` manually like this:
```
let command = ...
var buffer = ...
let writtenSize = buffer.writeCommand(command)
```

### Sample applications
#### Proxy
We provide a simple proxy that can be placed between some mail client and server. The mail server *must* support TLS.

`swift run Proxy <local_address> <local_port> <server_address> <server_port>`

#### CLI
The CLI allows you (the user) to connect to a mail server and enter commands. The mail server *must* support TLS. The CLI will always attempt to connect to the server on port 993.

`swift run CLI`
