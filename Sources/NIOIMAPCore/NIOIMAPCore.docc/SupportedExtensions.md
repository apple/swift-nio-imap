# Supported IMAP Extensions

A complete list of IMAP extension capabilities NIOIMAPCore supports, with links to their RFC specifications.

For more information about IMAP capabilities, see the [IANA IMAP Capabilities Registry](https://www.iana.org/assignments/imap-capabilities/imap-capabilities.xhtml).

## Extension Capabilities

| Capability | | RFC | Title |
| --- | --- | --- | --- |
| `APPENDLIMIT` | ``Capability/mailboxSpecificAppendLimit`` + ``Capability/appendLimit(_:)`` | [RFC 7889](https://www.iana.org/go/rfc7889) | IMAP Extensions: APPENDLIMIT |
| `AUTH=` | ``Capability/authenticate(_:)`` | [RFC 3501](https://www.iana.org/go/rfc3501) | IMAP4rev1 |
| `BINARY` | ``Capability/binary`` | [RFC 3516](https://www.iana.org/go/rfc3516) | IMAP4 Binary Content Extension |
| `CATENATE` | ``Capability/catenate`` | [RFC 4469](https://www.iana.org/go/rfc4469) | IMAP CATENATE Extension |
| `CHILDREN` | ``Capability/children`` | [RFC 3348](https://www.iana.org/go/rfc3348) | IMAP4 Child Mailbox Extension |
| `CONDSTORE` | ``Capability/condStore`` | [RFC 7162](https://www.iana.org/go/rfc7162) | IMAP Extensions: CONDSTORE and QRESYNC |
| `CREATE-SPECIAL-USE` | ``Capability/createSpecialUse`` | [RFC 6154](https://www.iana.org/go/rfc6154) | IMAP LIST Extension for Special-Use Mailboxes |
| `ENABLE` | ``Capability/enable`` | [RFC 5161](https://www.iana.org/go/rfc5161) | The IMAP ENABLE Extension |
| `ESEARCH` | ``Capability/extendedSearch`` | [RFC 4731](https://www.iana.org/go/rfc4731) | IMAP4 Extension to SEARCH Command for Controlling What Kind of Information is Returned |
| `ID` | ``Capability/id`` | [RFC 2971](https://www.iana.org/go/rfc2971) | IMAP4 ID Extension |
| `IDLE` | ``Capability/idle`` | [RFC 2177](https://www.iana.org/go/rfc2177) | IMAP4 IDLE Command |
| `LIST-EXTENDED` | ``Capability/listExtended`` | [RFC 5258](https://www.iana.org/go/rfc5258) | Internet Message Access Protocol - LIST Command Extensions |
| `LIST-STATUS` | ``Capability/listStatus`` | [RFC 5819](https://www.iana.org/go/rfc5819) | IMAP4 Extension for Returning STATUS Information in Extended LIST |
| `LITERAL-` | ``Capability/literalMinus`` | [RFC 7888](https://www.iana.org/go/rfc7888) | IMAP4 Non-synchronizing Literals |
| `LITERAL+` | ``Capability/literalPlus`` | [RFC 7888](https://www.iana.org/go/rfc7888) | IMAP4 Non-synchronizing Literals |
| `LOGIN-REFERRALS` | ``Capability/loginReferrals`` | [RFC 2221](https://www.iana.org/go/rfc2221) | IMAP4 Login Referrals |
| `LOGINDISABLED` | ``Capability/loginDisabled`` | [RFC 3501](https://www.iana.org/go/rfc3501) | IMAP4rev1 |
| `MESSAGELIMIT` | ``Capability/messageLimit(_:)`` | [RFC 9738](https://www.iana.org/go/rfc9738) | IMAP4 Extension for Message Limit |
| `METADATA` | ``Capability/metadata`` | [RFC 5464](https://www.iana.org/go/rfc5464) | The IMAP METADATA Extension |
| `METADATA-SERVER` | ``Capability/metadataServer`` | [RFC 5464](https://www.iana.org/go/rfc5464) | The IMAP METADATA Extension |
| `MOVE` | ``Capability/move`` | [RFC 6851](https://www.iana.org/go/rfc6851) | IMAP4 Extension for Moving Messages (MOVE Command) |
| `MULTIAPPEND` | | [RFC 3502](https://www.iana.org/go/rfc3502) | Internet Message Access Protocol (IMAP) - MULTIAPPEND Extension |
| `MULTISEARCH` | ``Capability/multiSearch`` | [RFC 7377](https://www.iana.org/go/rfc7377) | IMAP4 Multisearch Extension |
| `NAMESPACE` | ``Capability/namespace`` | [RFC 2342](https://www.iana.org/go/rfc2342) | IMAP4 Namespace |
| `OBJECTID` | ``Capability/objectID`` | [RFC 8474](https://www.iana.org/go/rfc8474) | IMAP Extension for Object Identifiers |
| `PARTIAL` | ``Capability/partial`` | [RFC 9394](https://www.iana.org/go/rfc9394) | IMAP Partial Extension for Fetching Parts of Messages |
| `PREVIEW` | ``Capability/preview`` | [RFC 8970](https://www.iana.org/go/rfc8970) | IMAP4 PREVIEW Extension |
| `QRESYNC` | ``Capability/qresync`` | [RFC 7162](https://www.iana.org/go/rfc7162) | IMAP Extensions: CONDSTORE and QRESYNC |
| `QUOTA` | ``Capability/quota`` | [RFC 2087](https://www.iana.org/go/rfc2087) | IMAP4 Quota Extension |
| `SASL-IR` | ``Capability/saslIR`` | [RFC 4959](https://www.iana.org/go/rfc4959) | IMAP Extension for Simple Authentication and Security Layer (SASL) Initial Client Response |
| `SEARCHRES` | ``Capability/searchRes`` | [RFC 5182](https://www.iana.org/go/rfc5182) | IMAP Extension for Referencing the Last SEARCH Result |
| `SORT` | ``Capability/sort(_:)`` | [RFC 5256](https://www.iana.org/go/rfc5256) | Internet Message Access Protocol - SORT and THREAD Extensions |
| `SORT=DISPLAY` | ``Capability/sort(_:)`` | [RFC 5957](https://datatracker.ietf.org/doc/html/rfc5957) | Display-Based Address Sorting for the IMAP4 SORT Extension |
| `SPECIAL-USE` | ``Capability/specialUse`` | [RFC 6154](https://www.iana.org/go/rfc6154) | IMAP LIST Extension for Special-Use Mailboxes |
| `STARTTLS` | ``Capability/startTLS`` | [RFC 3501](https://www.iana.org/go/rfc3501) | IMAP4rev1 |
| `STATUS=SIZE` | ``Capability/status(_:)`` | [RFC 8438](https://www.iana.org/go/rfc8438) | IMAP4 STATUS Command Extension for Message Size Information |
| `UIDBATCHES` | ``Capability/uidBatches`` | [draft-ietf-mailmaint-imap-uidbatches](https://datatracker.ietf.org/doc/draft-ietf-mailmaint-imap-uidbatches/) | IMAP UID BATCH Extension |
| `UIDONLY` | ``Capability/uidOnly`` | [RFC 9586](https://www.iana.org/go/rfc9586) | IMAP4 UIDONLY Extension |
| `UIDPLUS` | ``Capability/uidPlus`` | [RFC 4315](https://www.iana.org/go/rfc4315) | Internet Message Access Protocol (IMAP) - UIDPLUS Extension |
| `UNSELECT` | ``Capability/unselect`` | [RFC 3691](https://www.iana.org/go/rfc3691) | Internet Message Access Protocol (IMAP) UNSELECT Command |
| `URLAUTH` | ``Capability/authenticatedURL`` | [RFC 4467](https://www.iana.org/go/rfc4467) | Internet Message Access Protocol (IMAP) - URLAUTH Extension |
| `WITHIN` | ``Capability/within`` | [RFC 5032](https://www.iana.org/go/rfc5032) | WITHIN Search Extension to the IMAP Protocol |

## Additional Specifications

In addition to the extension capabilities listed above, NIOIMAP also implements:

- **RFC 4466**: [Collected Extensions to IMAP4 ABNF Syntax](https://www.iana.org/go/rfc4466)
- **Gmail IMAP Extensions**: [Google Gmail IMAP Extension Documentation](https://developers.google.com/gmail/imap/imap-extensions)

## Extensions

This section describes each supported IMAP extension and RFC, organized by document. For detailed technical specifications, refer to the relevant RFC.

### RFC 3501 and RFC 9051: Base Protocol

[RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) (IMAP4rev1, March 2003) defines the core IMAP protocol, including fundamental operations for accessing and manipulating email messages. [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051) (IMAP4rev2, August 2021) is a modernized revision of the base protocol that updates and clarifies many aspects of RFC 3501.

The base protocol is implemented throughout NIOIMAPCore with types like ``Command``, ``Response``, ``Flag``, ``MailboxData``, and ``Envelope`` providing the foundation for all IMAP operations. Additional types include ``BodyStructure`` for message MIME structure, and ``MessageAttribute`` for message metadata retrieval.

### RFC 2087: QUOTA Extension

[RFC 2087](https://datatracker.ietf.org/doc/html/rfc2087) (May 1998) defines a mechanism for clients to query mailbox storage quotas on the server. Quotas help users understand their disk usage and help servers manage resources. The extension provides types ``QuotaLimit``, ``QuotaResource``, and ``QuotaRoot`` for managing quota-related requests and responses, with quota data returned via ``ResponsePayload/quota(_:_:)`` and ``ResponsePayload/quotaRoot(_:_:)``.

### RFC 2177: IDLE Extension

[RFC 2177](https://datatracker.ietf.org/doc/html/rfc2177) (June 1997) introduces the `IDLE` command, which allows a client to request real-time notifications of mailbox changes from the server instead of polling. This is particularly useful for interactive mail clients that want to display new messages immediately. Use ``Command/idleStart`` to initiate idle mode, ``Response/idleStarted`` to detect when the server has accepted the idle request, and ``CommandStreamPart/idleDone`` to exit idle mode.

### RFC 2221: LOGIN-REFERRALS Extension

[RFC 2221](https://datatracker.ietf.org/doc/html/rfc2221) (October 1997) extends authentication to support referrals, allowing servers to redirect clients to alternate servers for specific users or mailboxes. The server sends a ``ResponseTextCode/referral(_:)`` response code containing an ``IMAPURL`` pointing to the appropriate server.

### RFC 2342: NAMESPACE Extension

[RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342) (May 1998) addresses namespace discovery by defining a `NAMESPACE` command that allows clients to discover the prefixes and delimiters for personal, other users', and shared mailbox namespaces. This eliminates the need for manual client configuration. The server responds with ``NamespaceResponse`` containing ``NamespaceDescription`` entries for each namespace.

### RFC 2971: ID Extension

[RFC 2971](https://datatracker.ietf.org/doc/html/rfc2971) (August 2000) defines an `ID` command that allows clients and servers to exchange identification information such as name and version, facilitating debugging and feature detection. Clients send identification using ``Command/id(_:)`` and servers respond with ``ResponsePayload/id(_:)`` containing key-value pairs.

### RFC 3348: CHILDREN Extension

[RFC 3348](https://www.rfc-editor.org/rfc/rfc3348.txt) (July 2002) extends mailbox attributes to indicate whether a mailbox has child mailboxes, allowing clients to display appropriate folder hierarchy indicators. Mailboxes use ``MailboxInfo/Attribute/hasChildren`` and ``MailboxInfo/Attribute/hasNoChildren`` attributes to indicate their hierarchy status.

### RFC 3502: MULTIAPPEND Extension

[RFC 3502](https://datatracker.ietf.org/doc/html/rfc3502) (April 2003) extends the `APPEND` command to support appending multiple messages in a single command, improving performance for bulk uploads. The extension uses ``AppendCommand`` with support for multiple messages and the ``AppendCommand/CatenateData`` type for inline data catenation.

### RFC 3516: BINARY Extension

[RFC 3516](https://datatracker.ietf.org/doc/html/rfc3516) (October 2003) allows clients to work with message bodies in binary format rather than requiring base64 encoding. The ``AppendData`` type supports binary message content, and ``FetchAttribute`` provides access to binary message sections.

### RFC 3691: UNSELECT Extension

[RFC 3691](https://datatracker.ietf.org/doc/html/rfc3691) (February 2004) defines an `UNSELECT` command that closes the currently selected mailbox without expunging deleted messages, providing an undo-like capability. Use ``Command/unselect`` to send the command.

### RFC 4315: UIDPLUS Extension

[RFC 4315](https://datatracker.ietf.org/doc/html/rfc4315) (December 2005) extends append and copy operations to return the UIDs of newly created messages, allowing clients to track message identities after uploads. The types ``ResponseCodeAppend`` and ``ResponseCodeCopy`` capture the returned UIDs.

### RFC 4466: Collected Extensions to IMAP4 ABNF Syntax

[RFC 4466](https://datatracker.ietf.org/doc/html/rfc4466) (April 2006) is a meta-specification that defines generalized ABNF syntax for tagged extensions and recursive option values, used by many subsequent IMAP extensions. Types ``ParameterValue`` and ``OptionValueComp`` support this extensibility framework.

### RFC 4469: CATENATE Extension

[RFC 4469](https://datatracker.ietf.org/doc/html/rfc4469) (April 2006) extends the `APPEND` command to support constructing messages by concatenating existing message parts and new content. This enables efficient message composition without downloading full message bodies. The extension uses ``AppendCommand`` with ``AppendCommand/CatenateData`` for managing inline data and ``IUID`` for message references.

### RFC 4467: URLAUTH Extension

[RFC 4467](https://datatracker.ietf.org/doc/html/rfc4467) (May 2006) defines URL syntax for referencing IMAP messages and mailboxes, with an optional authorization mechanism (URLAUTH) for secure access without credentials. This enables sharing message links with restricted access. NIOIMAPCore provides comprehensive URL support through types including ``IMAPURL``, ``FullAuthenticatedURL``, ``AuthenticatedURL``, ``MessagePath``, and related URL component types.

### RFC 4731: ESEARCH Extension

[RFC 4731](https://datatracker.ietf.org/doc/html/rfc4731) (November 2006) extends the `SEARCH` command with result options that control what information is returned—including minimum/maximum UIDs, all matching message UIDs, or just the count. The ``ExtendedSearchResponse``, ``SearchReturnOption``, and ``SearchReturnData`` types support extended search functionality.

### RFC 4959: SASL-IR Extension

[RFC 4959](https://datatracker.ietf.org/doc/html/rfc4959) (September 2007) allows clients to send the initial SASL response with the `AUTHENTICATE` command, reducing round trips during authentication. The ``InitialResponse`` type captures the initial SASL response data.

### RFC 5032: WITHIN Search Extension

[RFC 5032](https://datatracker.ietf.org/doc/html/rfc5032) (September 2007) adds a `WITHIN` search criterion to find messages within a specified number of seconds of a given date, providing fine-grained temporal search capabilities. This is supported through ``SearchKey`` criteria.

### RFC 5161: ENABLE Extension

[RFC 5161](https://datatracker.ietf.org/doc/html/rfc5161) (March 2008) defines an `ENABLE` command that allows clients to explicitly enable server capabilities, helping coordinate feature support in complex deployments. The server's response is captured in ``ResponsePayload/enableData(_:)`` containing an array of enabled ``Capability`` values.

### RFC 5182: SEARCHRES Extension

[RFC 5182](https://datatracker.ietf.org/doc/html/rfc5182) (March 2008) allows search operations to reference the results of the previous search using the `$` operator, enabling efficient progressive search refinement. The ``LastCommandSet`` type supports this functionality.

### RFC 5256 and RFC 5957: SORT and THREAD Extensions

[RFC 5256](https://datatracker.ietf.org/doc/html/rfc5256) (June 2008) defines `SORT` and `UID SORT` commands for returning search results in a specified order. Use ``Command/sort(criteria:charset:key:returnOptions:)`` or ``Command/uidSort(criteria:charset:key:returnOptions:)`` with sort order defined by ``SortCriterion``. Display name sorting is also supported via [RFC 5957](https://datatracker.ietf.org/doc/html/rfc5957) (July 2010).

### RFC 5258: LIST-EXTENDED Extension

[RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258) (June 2008) significantly extends the `LIST` command with selection options and return data options, enabling sophisticated mailbox discovery. Types ``ListSelectOption``, ``ListSelectBaseOption``, and ``ListSelectIndependentOption`` provide the selection and filtering capabilities.

### RFC 5464: METADATA Extension

[RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464) (February 2009) defines a mechanism for storing and retrieving arbitrary metadata (annotations) on mailboxes and the server itself. This enables clients and servers to associate custom data with mailboxes for features like tags, colors, or sync state. Key types include ``MetadataEntryName``, ``MetadataOption``, ``MetadataResponse``, ``MetadataValue``, and related entry types.

### RFC 5819: LIST-STATUS Extension

[RFC 5819](https://datatracker.ietf.org/doc/html/rfc5819) (March 2010) combines `LIST` and `STATUS` command functionality, allowing clients to retrieve mailbox status information (message counts, unseen count) in a single `LIST` response rather than requiring separate commands. The ``ReturnOption`` type supports this combined functionality.

### RFC 6154: SPECIAL-USE Mailbox Attributes

[RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154) (March 2011) defines standard mailbox attributes for special-use mailboxes such as Drafts, Sent, Trash, and Junk, enabling clients to automatically locate these folders without configuration. Types ``UseAttribute``, ``ListSelectIndependentOption``, and ``ReturnOption`` provide special-use support.

### RFC 6851: MOVE Extension

[RFC 6851](https://datatracker.ietf.org/doc/html/rfc6851) (January 2013) introduces a `MOVE` command that atomically copies and deletes messages, providing more efficient mailbox organization than separate copy and delete operations. Use ``Command/move(_:_:)`` for sequence numbers or ``Command/uidMove(_:_:)`` for UIDs.

### RFC 7162: CONDSTORE and QRESYNC Extensions

[RFC 7162](https://datatracker.ietf.org/doc/html/rfc7162) (May 2014) defines two related extensions for efficient mailbox synchronization. CONDSTORE adds modification sequences (MODSEQs) that allow clients to efficiently detect changed message flags. QRESYNC enables quick resynchronization by allowing clients to check which messages changed since their last access. Relevant types include ``SearchModificationSequence``, ``FetchModifier``, ``StoreModifier``, ``AttributeFlag``, ``SelectParameter``, and ``ModificationSequenceValue``.

### RFC 7377: MULTIMAILBOX SEARCH Extension

[RFC 7377](https://datatracker.ietf.org/doc/html/rfc7377) (October 2014) extends the `SEARCH` command to work across multiple mailboxes in a single operation, enabling efficient enterprise-wide searches. Types ``SearchCorrelator``, ``ExtendedSearchOptions``, ``ExtendedSearchScopeOptions``, and ``ExtendedSearchSourceOptions`` support multi-mailbox search.

### RFC 7888: Non-synchronizing Literals

[RFC 7888](https://datatracker.ietf.org/doc/html/rfc7888) (May 2016) introduces `LITERAL+` and `LITERAL-` extensions that allow clients to send literal data without waiting for server synchronization, improving performance for clients that can recover from errors. The ``AppendData`` type supports non-synchronizing literal handling.

### RFC 7889: APPENDLIMIT Extension

[RFC 7889](https://datatracker.ietf.org/doc/html/rfc7889) (May 2016) allows servers to advertise maximum message size limits via a capability parameter, helping clients validate message sizes before attempting to upload. Check ``Capability/appendLimit(_:)`` or ``Capability/mailboxSpecificAppendLimit`` for limits, and retrieve limits via ``MailboxStatus/appendLimit`` in status responses.

### RFC 8438: STATUS=SIZE Extension

[RFC 8438](https://datatracker.ietf.org/doc/html/rfc8438) (August 2018) extends the `STATUS` command to return the total size of all messages in a mailbox, providing a way to determine mailbox storage consumption. Request size information using ``MailboxAttribute/size`` in status queries, and retrieve it via ``MailboxStatus/size``.

### RFC 8474: OBJECTID Extension

[RFC 8474](https://datatracker.ietf.org/doc/html/rfc8474) (September 2018) defines persistent object identifiers for messages, mailboxes, and threads, enabling reliable tracking of messages across resynchronizations even when UIDs change. Types ``EmailID``, ``ThreadID``, and ``MailboxID`` provide persistent identification for messages, threads, and mailboxes respectively.

### RFC 8970: PREVIEW Extension

[RFC 8970](https://datatracker.ietf.org/doc/html/rfc8970) (January 2021) extends `FETCH` to return a server-generated preview (snippet) of message content, allowing clients to display message previews without downloading full message bodies. The ``FetchAttribute`` type supports preview retrieval.

### RFC 9394: PARTIAL Extension

[RFC 9394](https://datatracker.ietf.org/doc/html/rfc9394) (September 2023) allows clients to fetch portions of large messages using range specifications, enabling efficient downloads of specific parts. Types ``PartialRange``, ``FetchModifier``, and ``SearchReturnData`` support partial message retrieval.

### RFC 9586: UIDONLY Extension

[RFC 9586](https://datatracker.ietf.org/doc/html/rfc9586) (August 2023) allows servers to disable sequence-number-based message access, requiring clients to use UIDs exclusively for improved reliability in multi-client scenarios. FETCH responses use ``FetchResponse/startUID(_:)`` in UID-only mode.

### RFC 9738: MESSAGELIMIT Extension

[RFC 9738](https://datatracker.ietf.org/doc/html/rfc9738) (February 2024) allows servers to advertise a maximum number of messages that can be stored in a mailbox. Check ``Capability/messageLimit(_:)`` for the server's message limit.

### draft-ietf-mailmaint-imap-uidbatches: UIDBATCHES Extension

The [UIDBATCHES extension](https://datatracker.ietf.org/doc/draft-ietf-mailmaint-imap-uidbatches/) allows the server to return ranges of UIDs more efficiently when there are large contiguous sequences of UIDs. The ``UIDBatchesResponse`` type supports this efficient UID batch representation.

### Gmail IMAP Extensions

Google's [Gmail IMAP Extensions](https://developers.google.com/gmail/imap/imap-extensions) provide additional capabilities for working with Gmail-specific features like conversation threading and labels. The extensions are indicated by the ``Capability/gmailExtensions`` capability and require the `X-GM-EXT-1` capability.

Gmail labels, which are equivalent to mailbox tags, are represented using ``GmailLabel`` and can be modified via ``StoreGmailLabels`` for add, remove, or replace operations. Messages include ``MessageAttribute/gmailMessageID(_:)`` for a stable message identifier, ``MessageAttribute/gmailThreadID(_:)`` for conversation threading, and ``MessageAttribute/gmailLabels(_:)`` for label information. Use ``FetchAttribute/gmailMessageID``, ``FetchAttribute/gmailThreadID``, and ``FetchAttribute/gmailLabels`` to retrieve these attributes in FETCH responses.
