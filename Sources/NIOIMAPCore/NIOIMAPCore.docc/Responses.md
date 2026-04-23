# Responses

Interpret server response payloads and message data using these supporting types.

## Overview

When the server sends responses, these types help you interpret the data they contain.
They organize the response payload types and the information embedded in them.

## Topics

### Response Payloads

Core response structures and status information.

- ``ResponsePayload``
- ``UntaggedStatus``
- ``TaggedResponse/State``

### Mailbox Data

Information about mailboxes and their properties.

- ``MailboxData``

### Message Data

Metadata and attributes about individual messages.

- ``MessageData``
- ``MessageAttribute``

### Search Results

Results returned from search operations, including extended search formats.

- ``SearchReturnData``
- ``ExtendedSearchResponse``
- ``UIDBatchesResponse``

### Metadata & Modifications

Metadata responses and modification tracking.

- ``MetadataResponse``
- ``ModificationSequenceValue``
- ``ResponseCodeAppend``
- ``ResponseCodeCopy``
