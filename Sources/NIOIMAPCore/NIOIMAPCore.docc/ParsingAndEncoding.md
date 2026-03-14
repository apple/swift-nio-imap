# Parsing and Encoding

Parser and encoder infrastructure for IMAP protocol streams.

## Overview

NIOIMAPCore provides comprehensive parsing and encoding capabilities. These types handle the conversion between the IMAP wire format and strongly-typed Swift structures, including error handling and advanced features like pipelining.

## Topics

### Parsers

Streaming parsers for different contexts.

- ``ResponseParser``
- ``CommandParser``
- ``SynchronizingLiteralParser``

### Encoders

Buffers for encoding protocol elements back to wire format.

- ``CommandEncodeBuffer``
- ``ResponseEncodeBuffer``
- ``CommandEncodingOptions``
- ``ResponseEncodingOptions``

### Pipelining

Types related to command pipelining behavior.

- ``PipeliningRequirement``
- ``PipeliningBehavior``

### Errors

Parsing and encoding errors that may occur.

- ``BadCommand``
- ``ParserError``
- ``TooMuchRecursion``
- ``ExceededMaximumMessageAttributesError``
- ``ExceededMaximumBodySizeError``
- ``ExceededLiteralSizeLimitError``

### Utilities

Utility types and protocol defaults.

- ``ModifiedUTF7``
- ``IMAPDefaults``
