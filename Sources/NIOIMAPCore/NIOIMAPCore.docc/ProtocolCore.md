# Protocol Core

Essential types for the IMAP communication lifecycle.

## Overview

The protocol core encompasses the fundamental types exchanged between clients and servers: the commands you send, the responses you receive, and the elements that comprise them. These types form the backbone of IMAP communication.

## Topics

### Commands

Commands are what the client sends to the server to request actions or retrieve data.

- ``Command``
- ``CommandStreamPart``
- ``AppendCommand``
- ``TaggedCommand``

### Responses

Responses are what the server sends back, ranging from simple confirmations to complex streaming data.

- ``Response``
- ``FetchResponse``
- ``StreamingKind``
- ``ResponseOrContinuationRequest``
- ``TaggedResponse``
- ``ContinuationRequest``

### Response Text

These types are used within response messages to convey status information and additional context.

- ``ResponseText``
- ``ResponseTextCode``
- ``ResponseCodeAppend``
- ``ResponseCodeCopy``

### Capabilities & Authentication

Types related to server capabilities and client authentication.

- ``Capability``
- ``AuthenticationMechanism``
- ``InitialResponse``
