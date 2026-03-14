# Commands

Supporting types used when constructing and sending IMAP commands.

## Overview

When composing IMAP commands, you use these types to specify what action to perform and with what parameters. They provide a type-safe API for building commands that the server can understand.

## Topics

### Appending

Types for uploading messages to a mailbox.

- ``AppendMessage``
- ``AppendOptions``
- ``AppendData``

### Fetching

Attributes and modifiers for retrieving message data.

- ``FetchAttribute``
- ``FetchModifier``

### Searching

Keys and options for finding messages based on criteria.

- ``SearchKey``
- ``SearchReturnOption``
- ``ExtendedSearchOptions``
- ``ExtendedSearchScopeOptions``
- ``ExtendedSearchSourceOptions``

### Storing Flags

Types for modifying message flags and attributes.

- ``StoreData``
- ``StoreOperation``
- ``StoreFlags``
- ``StoreGmailLabels``
- ``StoreModifier``

### Listing

Options and parameters for listing mailboxes.

- ``ListSelectBaseOption``
- ``ListSelectOption``
- ``ListSelectIndependentOption``
- ``ListSelectOptions``
- ``ReturnOption``

### Mailbox Selection

Parameters used when selecting or creating mailboxes.

- ``SelectParameter``
- ``QResyncParameter``
- ``CreateParameter``
