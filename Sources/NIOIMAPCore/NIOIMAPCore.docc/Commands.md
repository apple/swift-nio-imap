# Commands

The IMAP protocol is built on a command-response model where clients send tagged commands to perform operations, and servers respond with updates and status.

## Overview

When composing IMAP commands, you use these types to specify what action to perform and with what parameters. Commands can be simple (executed in a single round trip) or streaming (involving multiple message parts or continued data uploads).

The ``Command`` enum includes 40+ cases covering:
- **Authentication**: Login, AUTHENTICATE, STARTTLS
- **Mailbox operations**: SELECT, CREATE, DELETE, RENAME, LIST, STATUS
- **Message operations**: FETCH, STORE, COPY, MOVE, SEARCH
- **Extensions**: IDLE, NAMESPACE, QUOTA, METADATA, and many others

All commands are wrapped with a tag in ``TaggedCommand`` for request/response correlation, or streamed with lifecycle parts in ``CommandStreamPart``.

## Topics

### Core Command Types

The fundamental types for sending commands to the server.

- ``Command``
- ``TaggedCommand``
- ``CommandStreamPart``

### Appending Messages

Types for uploading messages to a mailbox with support for flags, dates, and streaming.

- ``AppendMessage``
- ``AppendOptions``
- ``AppendData``

### Fetching Message Data

Attributes and modifiers for retrieving specific message data items.

- ``FetchAttribute``
- ``FetchModifier``

### Searching Messages

Search criteria and options for finding messages by various criteria.

- ``SearchKey``
- ``SearchReturnOption``
- ``ExtendedSearchOptions``
- ``ExtendedSearchScopeOptions``
- ``ExtendedSearchSourceOptions``

### Storing Message Attributes

Types for modifying message flags and other attributes.

- ``StoreData``
- ``StoreOperation``
- ``StoreFlags``
- ``StoreGmailLabels``
- ``StoreModifier``

### Listing Mailboxes

Options and parameters for discovering and filtering available mailboxes.

- ``ListSelectBaseOption``
- ``ListSelectOption``
- ``ListSelectIndependentOption``
- ``ListSelectOptions``
- ``ReturnOption``

### Mailbox Selection and Creation

Parameters for selecting, examining, or creating mailboxes.

- ``SelectParameter``
- ``QResyncParameter``
- ``CreateParameter``

### Other Command Support Types

Additional specialized types used in command processing.

- ``Command/CustomCommandPayload``
- ``LastCommandMessageID``
- ``SynchronizedCommand``
