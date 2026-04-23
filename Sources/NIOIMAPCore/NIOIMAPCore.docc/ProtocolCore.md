# Protocol Core

The core types for IMAP client-server communication: commands, responses, capabilities, and authentication.

## Overview

The protocol core encompasses the fundamental types exchanged between clients and servers: the commands you send, the responses you receive, and the elements that comprise them. These types form the backbone of IMAP communication.

## Topics

### Commands

Use these types to send commands to the server and request actions or retrieve data.

- ``Command``
- ``CommandStreamPart``
- ``AppendCommand``
- ``TaggedCommand``

### Responses

Use these types to handle the server's responses, from simple confirmations to complex streaming data.

- ``Response``
- ``FetchResponse``
- ``StreamingKind``
- ``ResponseOrContinuationRequest``
- ``TaggedResponse``
- ``ContinuationRequest``

### Response Text

These types appear within response messages and convey status information and additional context.

- ``ResponseText``
- ``ResponseTextCode``
- ``ResponseCodeAppend``
- ``ResponseCodeCopy``

### Capabilities & Authentication

Discover server capabilities and authenticate with these types.

- ``Capability``
- ``AuthenticationMechanism``
- ``InitialResponse``
