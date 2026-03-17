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
- ``MailboxAttribute``
- ``MailboxStatus``
- ``MailboxID``
- ``MailboxPatterns``
- ``MailboxUIDValidity``

### Messages & UIDs

Types for identifying and tracking messages.

- ``UID``
- ``UIDValidity``
- ``UIDRange``
- ``UIDSet``
- ``UIDSetNonEmpty``
- ``SequenceNumber``
- ``SequenceRange``
- ``SequenceSet``
- ``MessageIdentifier``
- ``UnknownMessageIdentifier``
- ``MessageIdentifierRange``
- ``MessageIdentifierSet``
- ``MessageIdentifierSetNonEmpty``
- ``MessageID``
- ``EmailID``
- ``ThreadID``
- ``LastCommandSet``
- ``LastCommandMessageID``
- ``IUID``

### Flags

Message flags and flag management.

- ``Flag``
- ``Flag/Keyword``
- ``PermanentFlag``
- ``UseAttribute``
- ``AttributeFlag``

### Body Structure

MIME body structure representation.

- ``BodyStructure``
- ``BodyStructure/Singlepart``
- ``BodyStructure/Multipart``
- ``BodyStructure/Fields``
- ``BodyStructure/Encoding``
- ``BodyStructure/Disposition``
- ``BodyExtension``
- ``Media``

### Envelope & Addresses

Message envelope and email address information.

- ``Envelope``
- ``EmailAddress``
- ``EmailAddressGroup``
- ``EmailAddressListElement``

### Dates & Times

Date and time types used in IMAP messages.

- ``ServerMessageDate``
- ``IMAPCalendarDay``
- ``InternetMessageDate``
- ``FullDateTime``
- ``FullDate``
- ``FullTime``

### Quota

Quota management types.

- ``QuotaRoot``
- ``QuotaResource``
- ``QuotaLimit``

### Namespace

Namespace description and negotiation.

- ``NamespaceDescription``
- ``NamespaceResponse``

### Metadata & Entries

Metadata entry names, options, and values.

- ``MetadataEntryName``
- ``MetadataOption``
- ``MetadataValue``
- ``EntryFlagName``
- ``EntryKindRequest``
- ``EntryKindResponse``

### URLs & IMAP Paths

IMAP URL representation and components.

- ``IMAPURL``
- ``RelativeIMAPURL``
- ``AuthenticatedURL``
- ``FullAuthenticatedURL``
- ``AuthenticatedURLRump``
- ``AuthenticatedURLVerifier``
- ``RumpAuthenticatedURL``
- ``RumpURLAndMechanism``
- ``IMAPServer``
- ``AbsoluteMessagePath``
- ``NetworkMessagePath``
- ``NetworkPath``
- ``MessagePath``
- ``EncodedMailbox``
- ``EncodedSection``
- ``EncodedAuthenticatedURL``
- ``EncodedAuthenticationType``
- ``EncodedUser``
- ``EncodedSearch``
- ``EncodedSearchQuery``
- ``URLCommand``
- ``URLMessageSection``
- ``URLFetchData``
- ``URLFetchType``

### Modification Sequences

Types for tracking and managing message modifications.

- ``ModificationSequenceValue``
- ``ChangedSinceModifier``
- ``UnchangedSinceModifier``
- ``SequenceMatchData``
- ``SearchModificationSequence``

### Sections & Ranges

Message section and byte range specifications.

- ``SectionSpecifier``
- ``ByteRange``
- ``PartialRange``

### Search & Notification

Advanced search and notification filtering types.

- ``MailboxFilter``
- ``Mailboxes``
- ``ScopeOption``

### Authentication & SASL

Authentication mechanisms and SASL-related types.

- ``AuthenticationMechanism``
- ``IMAPURLAuthenticationMechanism``
- ``URLAuthenticationMechanism``
- ``UserAuthenticationMechanism``
- ``MechanismBase64``
- ``InitialResponse``

### Specialized Extensions

Additional specialized types for protocol extensions.

- ``CreateParameter``
- ``SelectParameter``
- ``QResyncParameter``
- ``SynchronizedCommand``
- ``Expire``
- ``KeyValue``
- ``GmailLabel``
- ``PreviewText``
- ``SortData``
- ``SearchCorrelator``
- ``OptionExtensionKind``
- ``OptionValueComp``
- ``ParameterValue``
- ``Access``

### Errors & Exceptions

Error types for protocol violations and constraints.

- ``InvalidUID``
- ``InvalidMailboxNameError``
- ``InvalidPathSeparatorError``
- ``MailboxTooBigError``
