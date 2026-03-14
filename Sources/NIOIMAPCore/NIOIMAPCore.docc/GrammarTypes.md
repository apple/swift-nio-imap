# Grammar Types

The complete type vocabulary of the IMAP protocol, organized by domain.

## Overview

The IMAP protocol defines many domain-specific types for representing everything from mailbox names to message bodies. This collection organizes these grammar types into logical groups based on their role in the protocol.

## Topics

### Mailboxes

Types representing mailbox names, paths, and properties.

- ``MailboxName``
- ``MailboxPath``
- ``MailboxInfo``
- ``MailboxInfo/Attribute``
- ``MailboxStatus``
- ``MailboxID``
- ``MailboxPatterns``

### Messages & UIDs

Types for identifying and tracking messages.

- ``UID``
- ``UIDValidity``
- ``SequenceNumber``
- ``MessageIdentifier``
- ``MessageIdentifierRange``
- ``MessageIdentifierSet``
- ``MessageIdentifierSetNonEmpty``
- ``MessageID``
- ``EmailID``
- ``ThreadID``
- ``LastCommandSet``
- ``IUID``

### Flags

Message flags and flag management.

- ``Flag``
- ``Flag/Keyword``
- ``PermanentFlag``
- ``UseAttribute``

### Body Structure

MIME body structure representation.

- ``BodyStructure``
- ``BodyStructure/Singlepart``
- ``BodyStructure/Multipart``
- ``BodyStructure/Fields``
- ``BodyStructure/Encoding``
- ``BodyStructure/Disposition``
- ``BodyExtension``

### Envelope & Addresses

Message envelope and email address information.

- ``Envelope``
- ``EmailAddress``
- ``EmailAddressGroup``

### Dates

Date and time types used in IMAP messages.

- ``ServerMessageDate``
- ``IMAPCalendarDay``
- ``InternetMessageDate``
- ``FullDateTime``

### Quota

Quota management types.

- ``QuotaRoot``
- ``QuotaResource``
- ``QuotaLimit``

### Namespace

Namespace description and negotiation.

- ``NamespaceDescription``
- ``NamespaceResponse``

### Metadata

Metadata entry names, options, and values.

- ``MetadataEntryName``
- ``MetadataOption``
- ``MetadataValue``

### URLs

IMAP URL representation and components.

- ``IMAPURL``
- ``AuthenticatedURL``
- ``FullAuthenticatedURL``
- ``IMAPServer``
- ``MessagePath``
- ``NetworkPath``
- ``EncodedMailbox``
- ``EncodedSection``
- ``URLCommand``

### Modification Sequences

Types for tracking and managing message modifications.

- ``ModificationSequenceValue``
- ``ChangedSinceModifier``
- ``UnchangedSinceModifier``
- ``SequenceMatchData``

### Sections & Ranges

Message section and byte range specifications.

- ``SectionSpecifier``
- ``ByteRange``
- ``PartialRange``

### Other

Additional protocol types.

- ``KeyValue``
- ``GmailLabel``
- ``PreviewText``
- ``SortData``
- ``SearchCorrelator``
