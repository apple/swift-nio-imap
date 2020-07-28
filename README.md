# swift-nio-imap

A Swift project that provides an implementation of the IMAP4rev1 protocol, built upon SwiftNIO.

### Introduction and Usage

`swift-nio-imap` implementats the IMAP4rev1 protocol described in RFC 3501 and related RFCs. It is intended as a building block to build mail clients and/or servers. It is built upon SwiftNIO v2.x.

To use the framework use `import NIOIMAP`.

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

### IMAP Extensions
| Capability | RFC | Status |
---|---|---
ACL|[RFC4314]|❌
ANNOTATE-EXPERIMENT-1|[RFC5257]|❌
APPENDLIMIT|[RFC7889]|❌
AUTH=|[RFC3501]|✅
BINARY|[RFC3516]|✅
CATENATE|[RFC4469]|❌
CHILDREN|[RFC3348]|❌
COMPRESS=DEFLATE|[RFC4978]|❌
CONDSTORE|[RFC7162]|❌
CONTEXT=SEARCH|[RFC5267]|❌
CONTEXT=SORT|[RFC5267]|❌
CONVERT|[RFC5259]|❌
CREATE-SPECIAL-USE|[RFC6154]|❌
ENABLE|[RFC5161]|✅
ESEARCH|[RFC4731]|❌
ESORT|[RFC5267]|❌
FILTERS|[RFC5466]|✅
I18NLEVEL=1|[RFC5255]|❌
I18NLEVEL=2|[RFC5255]|❌
ID|[RFC2971]|✅
IDLE|[RFC2177]|✅
IMAPSIEVE=|[RFC6785]|❌
LANGUAGE|[RFC5255]|❌
LIST-EXTENDED|[RFC5258]|❌
LIST-MYRIGHTS|[RFC8440]|❌
LIST-STATUS|[RFC5819]|❌
LITERAL+|[RFC7888]|✅
LITERAL-|[RFC7888]|✅
LOGIN-REFERRALS|[RFC2221]|❌
LOGINDISABLED|[RFC2595][RFC3501]|❌
MAILBOX-REFERRALS|[RFC2193]|❌
METADATA|[RFC5464]|❌
METADATA-SERVER|[RFC5464]|❌
MOVE|[RFC6851]|✅
MULTIAPPEND|[RFC3502]|✅
MULTISEARCH|[RFC7377]|❌
NAMESPACE|[RFC2342]|✅
NOTIFY|[RFC5465]|❌
OBJECTID|[RFC8474]|❌
QRESYNC|[RFC7162]|❌
QUOTA|[RFC2087]|❌
REPLACE|[RFC8508]|❌
RIGHTS=|[RFC4314]|❌
SASL-IR|[RFC4959]|❌
SAVEDATE|[RFC8514]|❌
SEARCH=FUZZY|[RFC6203]|❌
SEARCHRES|[RFC5182]|❌
SORT|[RFC5256]|❌
SORT=DISPLAY|[RFC5957]|❌
SPECIAL-USE|[RFC6154]|❌
STARTTLS|[RFC2595][RFC3501]|❌
STATUS=SIZE|[RFC8438]|❌
THREAD|[RFC5256]|❌
UIDPLUS|[RFC4315]|❌
UNAUTHENTICATE|[RFC8437]|❌
UNSELECT|[RFC3691]|✅
URLFETCH=BINARY|[RFC5524]|❌
URL-PARTIAL|[RFC5550]|❌
URLAUTH|[RFC4467]|❌
UTF8=ACCEPT|[RFC6855]|❌
UTF8=ALL (OBSOLETE)|[RFC5738][RFC6855]|❌
UTF8=APPEND (OBSOLETE)|[RFC5738][RFC6855]|❌
UTF8=ONLY|[RFC6855]|❌
UTF8=USER (OBSOLETE)|[RFC5738][RFC6855]|❌
WITHIN|[RFC5032]|✅
