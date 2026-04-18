# Responses

Supporting types used when interpreting and handling server responses.

## Overview

When the server sends responses, these types help you interpret the data it contains. They organize the various kinds of response payloads and the information embedded within them.

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
- ``FetchModificationResponse``
- ``ResponseCodeAppend``
- ``ResponseCodeCopy``
