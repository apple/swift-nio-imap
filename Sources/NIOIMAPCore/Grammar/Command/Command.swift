//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer
import struct OrderedCollections.OrderedDictionary

/// Commands are sent by clients to perform operations on the server.
///
/// In the [IMAP4rev1 protocol](https://datatracker.ietf.org/doc/html/rfc3501), a client initiates operations
/// by sending commands to the server.
///
/// Each command is identified with a unique "tag" (typically a short string like "A1") that allows the client
/// to correlate server responses with the commands that generated them. See ``TaggedCommand``.
///
/// The server responds with untagged data (prefixed with `*`) and a tagged response (using the same tag)
/// indicating success (`OK`), failure (`NO`), or protocol error (`BAD`). See ``Response`` for response types.
///
/// ## Command structure
///
/// Every IMAP command follows this basic structure:
/// ```
/// tag command-name arguments
/// ```
/// For example:
/// ```
/// A0001 LOGIN user@example.com password
/// A0002 SELECT INBOX
/// A0003 FETCH 1:* (FLAGS BODY)
/// ```
///
/// ## Protocol state requirements
///
/// Commands are restricted based on the connection's current state:
/// - **Any State**: Commands like ``capability``, ``noop``, and ``logout`` are valid at any time.
/// - **Not Authenticated**: Commands like ``authenticate(mechanism:initialResponse:)`` and ``login(username:password:)``
///   authenticate the client before entering authenticated state.
/// - **Authenticated**: Commands like ``select(_:_:)`` and ``create(_:_:)`` operate on mailboxes
///   after authentication but before selecting a specific mailbox.
/// - **Selected**: Commands like ``fetch(_:_:_:)`` and ``search(key:charset:returnOptions:)`` work with messages
///   in the currently selected mailbox.
///
/// ## Extension support
///
/// Many commands support IMAP extensions defined in RFCs beyond [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
/// For example, the ``list(_:reference:_:_:)`` command supports extensions from
/// [RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258) (LIST Extensions),
/// [RFC 5819](https://datatracker.ietf.org/doc/html/rfc5819) (RETURN option), and
/// [RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154) (SPECIAL-USE mailboxes).
///
/// ## Streaming commands
///
/// Some commands like `APPEND` involve uploading large messages and are handled separately by the
/// ``AppendCommand`` type to support streaming of data.
public enum Command: Hashable, Sendable {
    /// `CAPABILITY` – Requests the server's capabilities.
    ///
    /// The server responds with an untagged `CAPABILITY` response (``ResponsePayload/capabilityData(_:)``)
    /// listing the capabilities it supports (see ``Capability``).
    ///
    /// - SeeAlso: [RFC 3501 Section 6.1.1](https://datatracker.ietf.org/doc/html/rfc3501#section-6.1.1)
    case capability

    /// `LOGOUT` – Closes the connection after optional server notifications.
    ///
    /// Returns the session to the logged-out state. The server may send an untagged `BYE` response
    /// before closing the connection.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.1.3](https://datatracker.ietf.org/doc/html/rfc3501#section-6.1.3)
    case logout

    /// `NOOP` – Performs no operation.
    ///
    /// Used to test server responsiveness or to request that the server send any pending updates
    /// (such as new messages or mailbox changes).
    ///
    /// - SeeAlso: [RFC 3501 Section 6.1.2](https://datatracker.ietf.org/doc/html/rfc3501#section-6.1.2)
    case noop

    /// `CREATE` – Creates a new mailbox.
    ///
    /// It is an error to attempt to create `INBOX` or a mailbox with a name that refers to an existing mailbox.
    /// If the mailbox name is suffixed with a hierarchy separator, the server creates the mailbox hierarchy.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.3.3](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.3)
    case create(MailboxName, [CreateParameter])

    /// `DELETE` – Permanently deletes a mailbox.
    ///
    /// It is an error to attempt to delete `INBOX` or a mailbox name that does not exist.
    /// The server must not remove any inferior hierarchical names.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.3.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.4)
    case delete(MailboxName)

    /// `EXAMINE` – Opens a mailbox in read-only mode, returning the same responses as `SELECT`.
    ///
    /// Identical to ``select(_:_:)`` except the selected mailbox is identified as read-only.
    /// No changes to permanent mailbox state (including per-user state) are permitted.
    /// The tagged `OK` always includes the `[READ-ONLY]` response code.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A002 EXAMINE INBOX
    /// S: * 172 EXISTS
    /// S: * 1 RECENT
    /// S: * FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
    /// S: A002 OK [READ-ONLY] EXAMINE completed
    /// ```
    ///
    /// - SeeAlso: [RFC 3501 Section 6.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.2)
    case examine(MailboxName, [SelectParameter] = [])

    /// `LIST` command.
    ///
    /// The `LIST` command allows a client to discover what mailboxes are available on the server,
    /// with support for pattern matching and filtering.
    ///
    /// ## Base functionality ([RFC 3501 Section 6.3.8](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.8))
    ///
    /// The base `LIST` command takes two arguments:
    /// - **reference**: A mailbox name or hierarchy level that provides context for interpreting the pattern.
    ///   An empty string means the pattern is interpreted as if by the `SELECT` command.
    /// - **pattern**: A mailbox name with possible wildcards (`*` matches any substring, `%` matches up to
    ///   the next hierarchy delimiter). For example, `"*"` lists all mailboxes, `"Foo/*"` lists all mailboxes
    ///   under "Foo", and `"%"` lists mailboxes at the top level only.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 LIST "" "*"
    /// S: * LIST (\NoInferiors) "/" "INBOX"
    /// S: * LIST (\HasChildren) "/" "Drafts"
    /// S: * LIST (\HasChildren) "/" "Archive"
    /// S: A001 OK LIST Completed
    /// ```
    ///
    /// The command `C: A001 LIST "" "*"` corresponds to this case with reference as empty string and
    /// pattern as `"*"`. The server responds with zero or more `S: * LIST...` lines (each wrapped as
    /// ``MailboxData/list(_:)``), followed by the tagged response `S: A001 OK LIST Completed`.
    ///
    /// ## Selection options ([RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258))
    ///
    /// The optional `options` parameter uses ``ListSelectOptions`` to control which mailboxes are listed:
    /// - ``ListSelectBaseOption/subscribed``: Only list mailboxes that the user has subscribed to
    ///   ([RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501)).
    /// - Additional options from ``ListSelectOption`` can be combined with the base option:
    ///   - ``ListSelectOption/recursiveMatch``: Include parent mailboxes that don't match but have matching children
    ///     ([RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258)).
    ///
    /// ## Independent options ([RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258), [RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154))
    ///
    /// When syntax conflicts prevent combining options, use ``listIndependent(_:reference:_:_:)`` instead:
    /// - ``ListSelectIndependentOption/remote``: Include remote mailboxes in the results
    ///   ([RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258)).
    /// - ``ListSelectIndependentOption/specialUse``: Only return mailboxes with special-use attributes
    ///   like `\Drafts`, `\Sent`, or `\Trash` ([RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154)).
    ///
    /// ## Return options ([RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258), [RFC 5819](https://datatracker.ietf.org/doc/html/rfc5819), [RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154))
    ///
    /// The optional `returnOptions` array specifies what additional data should be returned for each mailbox:
    /// - ``ReturnOption/subscribed``: Include subscription state for each mailbox
    ///   ([RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258)).
    /// - ``ReturnOption/children``: Include child mailbox information (`\HasChildren` / `\HasNoChildren`)
    ///   ([RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258)).
    /// - ``ReturnOption/specialUse``: Include special-use attributes
    ///   ([RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154)).
    /// - ``ReturnOption/statusOption(_:)``: Request `STATUS` data (mailbox statistics like `MESSAGES`, `UNSEEN`, `UIDVALIDITY`)
    ///   be returned alongside `LIST` responses ([RFC 5819](https://datatracker.ietf.org/doc/html/rfc5819)).
    ///
    /// ### Example with return options
    ///
    /// ```
    /// C: A002 LIST "" "INBOX" RETURN (SUBSCRIBED STATUS (MESSAGES UNSEEN))
    /// S: * LIST (\Subscribed) "/" "INBOX"
    /// S: * STATUS "INBOX" (MESSAGES 42 UNSEEN 3)
    /// S: A002 OK LIST Completed
    /// ```
    ///
    /// The command shows a LIST with RETURN options. The server responds with a LIST response
    /// (``MailboxData/list(_:)``) and a STATUS response (``MailboxData/status(_:_:)``), both wrapped
    /// as untagged ``Response`` types.
    case list(ListSelectOptions?, reference: MailboxName, MailboxPatterns, [ReturnOption] = [])

    /// Similar to `.list`, but uses options that do not syntactically interact with other options.
    ///
    /// Some `LIST` extension options cannot be combined with other options due to syntactic constraints.
    /// Use this variant with ``ListSelectIndependentOption`` values (such as ``ListSelectIndependentOption/remote``
    /// or ``ListSelectIndependentOption/specialUse``) when needed.
    case listIndependent([ListSelectIndependentOption], reference: MailboxName, MailboxPatterns, [ReturnOption] = [])

    /// `LSUB` – Lists subscribed mailboxes matching the pattern.
    ///
    /// Returns a subset of mailbox names from the complete set of names that the user has marked
    /// as "active" or "subscribed". This is typically a smaller set than ``list(_:reference:_:_:)`` results.
    /// The server responds with ``MailboxData/lsub(_:)`` responses for each matching mailbox.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.3.9](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.9)
    case lsub(reference: MailboxName, pattern: ByteBuffer)

    /// `RENAME` – Changes the name of a mailbox and all its children.
    ///
    /// Renames the mailbox and all inferior hierarchical names. When renaming INBOX, all messages
    /// are moved to the new mailbox, and the original INBOX is left empty.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.3.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.5)
    case rename(from: MailboxName, to: MailboxName, parameters: OrderedDictionary<String, ParameterValue?>)

    /// `SELECT` – Selects a mailbox so that messages can be accessed using message-sequence-number based commands.
    ///
    /// Only one mailbox can be selected at a time. If another mailbox is already selected, it is
    /// implicitly closed before the new mailbox is selected. The server sends several untagged responses
    /// before the tagged `OK` to describe the mailbox state.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 SELECT INBOX
    /// S: * 172 EXISTS
    /// S: * 1 RECENT
    /// S: * OK [UNSEEN 12] Message 12 is first unseen
    /// S: * OK [UIDVALIDITY 3857529045] UIDs valid
    /// S: * FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
    /// S: A001 OK [READ-WRITE] SELECT completed
    /// ```
    ///
    /// The untagged responses include `EXISTS` (``MailboxData/exists(_:)``), `RECENT` (``MailboxData/recent(_:)``),
    /// `FLAGS` (``MailboxData/flags(_:)``), and several `OK` lines with response codes (``ResponseTextCode``).
    /// The tagged `OK` includes a `[READ-WRITE]` or `[READ-ONLY]` response code.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.3.1](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.1)
    case select(MailboxName, [SelectParameter] = [])

    /// `STATUS` – Requests the status of the specified mailbox without changing the current selection.
    ///
    /// Allows a client to access attributes (see ``MailboxAttribute``) of a mailbox other than the
    /// currently selected one. The server responds with an untagged `STATUS` response (``MailboxData/status(_:_:)``)
    /// containing the requested attributes.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.3.10](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.10)
    case status(MailboxName, [MailboxAttribute])

    /// `SUBSCRIBE` – Adds the specified mailbox name to the server's set of "active" or "subscribed" mailboxes.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.3.6](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.6)
    case subscribe(MailboxName)

    /// `UNSUBSCRIBE` – Removes the specified mailbox name from the server's set of "active" or "subscribed" mailboxes.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.3.7](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.7)
    case unsubscribe(MailboxName)

    /// `AUTHENTICATE` – Begins the process of the client authenticating against the server using the specified mechanism.
    ///
    /// The client specifies an authentication ``AuthenticationMechanism``, and the server may respond
    /// with one or more challenges (``Response/authenticationChallenge(_:)``), which the client must
    /// answer using ``CommandStreamPart/continuationResponse(_:)``.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-6.2.2)
    case authenticate(mechanism: AuthenticationMechanism, initialResponse: InitialResponse?)

    /// `LOGIN` – Authenticates the client using a plaintext username and password.
    ///
    /// Not available when the server advertises the `LOGINDISABLED` capability.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.2.3](https://datatracker.ietf.org/doc/html/rfc3501#section-6.2.3)
    case login(username: String, password: String)

    /// `STARTTLS` – Begins TLS negotiation.
    ///
    /// Initiates encryption for the connection. Only available when the server advertises
    /// the `STARTTLS` capability.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.2.1](https://datatracker.ietf.org/doc/html/rfc3501#section-6.2.1)
    case startTLS

    /// `CHECK` – Requests a checkpoint of the server's mailbox state.
    ///
    /// Allows the server to perform implementation-dependent housekeeping operations.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.1](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.1)
    case check

    /// `CLOSE` – Permanently deletes all messages with the `\Deleted` flag and deselects the mailbox.
    ///
    /// Unlike ``expunge``, this command does NOT send untagged `EXPUNGE` responses for each deleted message.
    /// Messages are removed silently, and the mailbox is closed.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.2)
    case close

    /// `EXPUNGE` – Permanently deletes all messages with the `\Deleted` flag set.
    ///
    /// Before returning `OK`, the server sends one untagged `EXPUNGE` response per deleted message.
    /// Each untagged response is a ``MessageData/expunge(_:)`` containing the sequence number of the deleted message.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A006 EXPUNGE
    /// S: * 3 EXPUNGE
    /// S: * 3 EXPUNGE
    /// S: * 5 EXPUNGE
    /// S: A006 OK EXPUNGE completed
    /// ```
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.3](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.3)
    case expunge

    /// `ENABLE` – Enables specified capabilities on the server.
    ///
    /// Enables each listed capability, providing the server has advertised support for those capabilities.
    /// The server responds with an untagged `ENABLED` response (``ResponsePayload/enableData(_:)``)
    /// listing the capabilities that were successfully enabled.
    ///
    /// - SeeAlso: [RFC 5161](https://datatracker.ietf.org/doc/html/rfc5161)
    case enable([Capability])

    /// `UNSELECT` – Closes the currently selected mailbox without expunging messages.
    ///
    /// Deselects the mailbox and returns to the authenticated state. Unlike ``close``, this does not
    /// remove messages with the `\Deleted` flag set.
    ///
    /// - SeeAlso: [RFC 3691](https://datatracker.ietf.org/doc/html/rfc3691)
    case unselect

    /// `IDLE` – Enters the IDLE state.
    ///
    /// Moves the server into an idle state where it may send periodic updates on mailbox changes.
    /// No more commands may be sent until ``CommandStreamPart/idleDone`` has been sent to exit IDLE mode.
    ///
    /// - SeeAlso: [RFC 2177](https://datatracker.ietf.org/doc/html/rfc2177)
    case idleStart

    /// `COPY` – Copies each message in the given sequence number set to the destination mailbox.
    ///
    /// The original messages remain in the current mailbox. The `\Seen` flag is not changed,
    /// and the internal date is preserved. If the destination mailbox does not exist, the server
    /// returns a `[TRYCREATE]` response code in the `NO` response.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A005 COPY 1:3 "Saved"
    /// S: A005 OK COPY completed
    /// ```
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.7](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.7)
    case copy(LastCommandSet<SequenceNumber>, MailboxName)

    /// `FETCH` – Retrieves message data for each message in the given sequence number set.
    ///
    /// The `attributes` array specifies which data items to fetch (see ``FetchAttribute``), and
    /// the server sends one untagged `FETCH` response per message. Responses are delivered
    /// as ``FetchResponse`` values (potentially as a streaming sequence for large data like body content).
    ///
    /// ### Example
    ///
    /// ```
    /// C: A003 FETCH 1:3 (FLAGS BODY[])
    /// S: * 1 FETCH (FLAGS (\Seen) BODY[] {1234}
    /// S: ...message content...
    /// S: )
    /// S: * 2 FETCH (FLAGS () BODY[] {5678}
    /// S: ...message content...
    /// S: )
    /// S: A003 OK FETCH completed
    /// ```
    ///
    /// Each `* N FETCH ...` line is a ``FetchResponse`` value containing one or more ``MessageAttribute`` values.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5)
    case fetch(LastCommandSet<SequenceNumber>, [FetchAttribute], [FetchModifier])

    /// `STORE` – Modifies flags or other data for messages in the given sequence number set.
    ///
    /// The `data` parameter specifies what to set, add, or remove (see ``StoreData``).
    /// Unless the `.SILENT` variant is used, the server returns untagged `FETCH` responses
    /// reflecting the updated flags for each affected message.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A004 STORE 1:3 +FLAGS (\Deleted)
    /// S: * 1 FETCH (FLAGS (\Deleted \Seen))
    /// S: * 2 FETCH (FLAGS (\Deleted))
    /// S: * 3 FETCH (FLAGS (\Deleted \Flagged))
    /// S: A004 OK STORE completed
    /// ```
    ///
    /// Each `* N FETCH ...` line is a ``FetchResponse`` containing the updated ``Flag`` values.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.6](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.6)
    case store(LastCommandSet<SequenceNumber>, [StoreModifier], StoreData)

    /// Searches the currently-selected mailbox for messages that match the search criteria.
    ///
    /// Uses RFC 3501 / RFC 4731 style search. RFC 7377 style searches use `.extendedSearch`.
    ///
    /// If `returnOptions` is empty, this is a RFC 3501 style search. But note that the empty
    /// RFC 7377 `RETURN ()` maps to `[.all]` — as it’s equivalent to `RETURN (ALL)`.
    ///
    /// * `SEARCH ANSWERED` is `.search(key:. answered, returnOptions: [])`
    /// * `SEARCH RETURN () ANSWERED` is `.search(key:. answered, returnOptions: [.all])`
    case search(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = [])

    /// `MOVE` – Moves each message in the given sequence number set to the destination mailbox.
    ///
    /// Copies the specified messages to the end of the destination mailbox and removes the copies from the current mailbox.
    /// Equivalent to performing ``copy(_:_:)`` followed by ``store(_:_:_:)`` with `\Deleted` flag.
    ///
    /// - SeeAlso: [RFC 6851](https://datatracker.ietf.org/doc/html/rfc6851)
    case move(LastCommandSet<SequenceNumber>, MailboxName)

    /// `ID` – Identifies the client to the server.
    ///
    /// Sends identification parameters to the server (typically client name and version).
    /// The server responds with an untagged `ID` response (``ResponsePayload/id(_:)``).
    ///
    /// - SeeAlso: [RFC 2971](https://datatracker.ietf.org/doc/html/rfc2971)
    case id(OrderedDictionary<String, String?>)

    /// `NAMESPACE` – Retrieves the namespaces available to the user.
    ///
    /// The server responds with an untagged `NAMESPACE` response (``MailboxData/namespace(_:)``)
    /// describing the personal, shared, and public namespace hierarchies.
    ///
    /// - SeeAlso: [RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342)
    case namespace

    /// `UIDBATCHES` – Partitions a UID range into batches of a given size.
    ///
    /// **Requires server capability:** ``Capability/uidBatches``
    ///
    /// - SeeAlso: [UIDBATCHES Internet-Draft](https://datatracker.ietf.org/doc/draft-ietf-mailmaint-imap-uidbatches/)
    case uidBatches(batchSize: Int, batchRange: ClosedRange<Int>?)

    /// `UID COPY` – Similar to ``copy(_:_:)``, but uses unique identifier instead of sequence numbers to identify messages.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.8](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.8)
    case uidCopy(LastCommandSet<UID>, MailboxName)

    /// `UID MOVE` – Similar to ``move(_:_:)``, but uses unique identifier instead of sequence numbers to identify messages.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.8](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.8)
    case uidMove(LastCommandSet<UID>, MailboxName)

    /// `UID FETCH` – Similar to ``fetch(_:_:_:)``, but uses unique identifier instead of sequence numbers to identify messages.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.8](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.8)
    case uidFetch(LastCommandSet<UID>, [FetchAttribute], [FetchModifier])

    /// `SORT` – Returns message sequence numbers of messages matching a search key, sorted by the given criteria.
    ///
    /// Unlike ``search(key:charset:returnOptions:)``, the `SORT` command requires a charset parameter
    /// and returns results in the order specified by the sort criteria rather than message sequence order.
    ///
    /// The server responds with an untagged `SORT` response containing the sorted message sequence numbers.
    /// If `returnOptions` are specified, the response format follows the ESORT extension (RFC 5267).
    ///
    /// - Parameters:
    ///   - criteria: One or more ``SortCriterion`` values defining the sort order. Later criteria
    ///     are used as tie-breakers when earlier criteria produce equal values.
    ///   - charset: The character set for string comparisons (for example, `"UTF-8"` or `"US-ASCII"`). Required.
    ///   - key: The ``SearchKey`` filtering which messages to include in the result.
    ///   - returnOptions: Optional ``SearchReturnOption`` values controlling the response format.
    ///
    /// - SeeAlso: [RFC 5256](https://datatracker.ietf.org/doc/html/rfc5256), [RFC 5267](https://datatracker.ietf.org/doc/html/rfc5267)
    case sort(criteria: [SortCriterion], charset: String, key: SearchKey, returnOptions: [SearchReturnOption] = [])

    /// `UID SORT` – Returns UIDs of messages matching a search key, sorted by the given criteria.
    ///
    /// Similar to ``sort(criteria:charset:key:returnOptions:)``, but returns unique identifiers
    /// instead of message sequence numbers.
    ///
    /// - SeeAlso: [RFC 5256](https://datatracker.ietf.org/doc/html/rfc5256)
    case uidSort(criteria: [SortCriterion], charset: String, key: SearchKey, returnOptions: [SearchReturnOption] = [])

    /// `UID SEARCH` – Similar to ``search(key:charset:returnOptions:)``, but uses unique identifier instead of sequence numbers to identify messages.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.8](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.8)
    case uidSearch(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = [])

    /// `UID STORE` – Similar to ``store(_:_:_:)``, but uses unique identifier instead of sequence numbers to identify messages.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.8](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.8)
    case uidStore(LastCommandSet<UID>, [StoreModifier], StoreData)

    /// `UID EXPUNGE` – Similar to ``expunge``, but uses unique identifier instead of sequence numbers to identify messages.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.8](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.8)
    case uidExpunge(LastCommandSet<UID>)

    /// `GETQUOTA` – Retrieves quota information for a quota root.
    ///
    /// The server responds with an untagged `QUOTA` response (``ResponsePayload/quota(_:_:)``)
    /// containing the quota root's resource usage and limits.
    ///
    /// - SeeAlso: [RFC 9208](https://datatracker.ietf.org/doc/html/rfc9208)
    case getQuota(QuotaRoot)

    /// `GETQUOTAROOT` – Retrieves quota roots for a mailbox.
    ///
    /// The server responds with an untagged `QUOTAROOT` response (``ResponsePayload/quotaRoot(_:_:)``)
    /// listing the quota roots that control quotas for the specified mailbox.
    ///
    /// - SeeAlso: [RFC 9208](https://datatracker.ietf.org/doc/html/rfc9208)
    case getQuotaRoot(MailboxName)

    /// `SETQUOTA` – Sets resource limits for a quota root.
    ///
    /// Modifies the resource limits (such as storage and message count) for a specific quota root.
    ///
    /// - SeeAlso: [RFC 9208](https://datatracker.ietf.org/doc/html/rfc9208)
    case setQuota(QuotaRoot, [QuotaLimit])

    /// `GETMETADATA` – Retrieves metadata entries.
    ///
    /// When the mailbox name is empty, retrieves server annotations. When non-empty,
    /// retrieves metadata entries on the specified mailbox. The server responds with
    /// `METADATA` responses containing the requested entry values.
    ///
    /// - SeeAlso: [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464)
    case getMetadata(options: [MetadataOption], mailbox: MailboxName, entries: [MetadataEntryName])

    /// `SETMETADATA` – Sets metadata entries.
    ///
    /// Adds or replaces metadata entry values on the specified mailbox or server
    /// (if the mailbox argument is the empty string).
    ///
    /// - SeeAlso: [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464)
    case setMetadata(mailbox: MailboxName, entries: OrderedDictionary<MetadataEntryName, MetadataValue>)

    /// Performs a “multimailbox” search as defined in RFC 7377.
    ///
    /// Enables searching across multiple mailboxes in a single request. The search results are
    /// returned using the `ESEARCH` response format defined in RFC 4731, which includes optional `MIN`, `MAX`,
    /// `COUNT`, and `ALL` return options. This command is equivalent to the extended `SEARCH` command but can
    /// target multiple mailboxes via the ``MailboxFilter`` and ``Mailboxes`` filters.
    case extendedSearch(ExtendedSearchOptions)

    /// When sent with no arguments: removes all mailbox access keys
    /// in the user's mailbox access key table, revoking all URLs currently
    /// authorized using URLAUTH by the user.
    /// When sent with arguments: generates a
    /// new mailbox access key for the given mailbox in the user's mailbox
    /// access key table, replacing any previous mailbox access key (and
    /// revoking any URLs that were authorized with a URLAUTH using that key)
    /// in that table.
    case resetKey(mailbox: MailboxName?, mechanisms: [URLAuthenticationMechanism])

    /// Requests that the server generate a URLAUTH-
    /// authorized URL for each of the given URLs using the given URL
    /// authorization mechanism.
    case generateAuthorizedURL([RumpURLAndMechanism])

    /// `URLFETCH` – Retrieves message data from IMAP URLs.
    ///
    /// Requests that the server return the text data associated with the specified IMAP URLs.
    ///
    /// - SeeAlso: [RFC 4467](https://datatracker.ietf.org/doc/html/rfc4467)
    case urlFetch([ByteBuffer])

    /// Instructs the server to use the specified compression mechanism.
    ///
    /// - SeeAlso: [RFC 4978](https://datatracker.ietf.org/doc/html/rfc4978)
    case compress(Capability.CompressionKind)

    /// Retrieves the JMAP session URL.
    ///
    /// - SeeAlso: [RFC 9698](https://datatracker.ietf.org/doc/html/rfc9698)
    case getJMAPAccess

    /// A custom command that’s not defined in any RFC.
    ///
    /// If `payload` contains multiple elements, no spaces or other separators will be output
    /// between them. A `.verbatim` element must be used to output spaces if desired.
    case custom(name: String, payloads: [CustomCommandPayload])
}

extension Command: CustomDebugStringConvertible {
    public var debugDescription: String {
        CommandEncodeBuffer.makeDescription {
            $0.writeCommand(self)
        }
    }
}

// MARK: - IMAP

extension CommandEncodeBuffer {
    @discardableResult mutating func writeCommand(_ command: Command) -> Int {
        switch command {
        case .capability:
            return self.writeCommandKind_capability()
        case .logout:
            return self.writeCommandKind_logout()
        case .noop:
            return self.writeCommandKind_noop()
        case .create(let mailbox, let params):
            return self.writeCommandKind_create(mailbox: mailbox, parameters: params)
        case .delete(let mailbox):
            return self.writeCommandKind_delete(mailbox: mailbox)
        case .examine(let mailbox, let params):
            return self.writeCommandKind_examine(mailbox: mailbox, parameters: params)
        case .list(let selectOptions, let mailbox, let mailboxPatterns, let returnOptions):
            return self.writeCommandKind_list(
                selectOptions: selectOptions,
                mailbox: mailbox,
                mailboxPatterns: mailboxPatterns,
                returnOptions: returnOptions
            )
        case .listIndependent(let selectOptions, let mailbox, let mailboxPatterns, let returnOptions):
            return self.writeCommandKind_listIndependent(
                selectOptions: selectOptions,
                mailbox: mailbox,
                mailboxPatterns: mailboxPatterns,
                returnOptions: returnOptions
            )
        case .lsub(let mailbox, let listMailbox):
            return self.writeCommandKind_lsub(mailbox: mailbox, listMailbox: listMailbox)
        case .rename(let from, let to, let params):
            return self.writeCommandKind_rename(from: from, to: to, parameters: params)
        case .select(let mailbox, let params):
            return self.writeCommandKind_select(mailbox: mailbox, parameters: params)
        case .status(let mailbox, let attributes):
            return self.writeCommandKind_status(mailbox: mailbox, attributes: attributes)
        case .subscribe(let mailbox):
            return self.writeCommandKind_subscribe(mailbox: mailbox)
        case .unsubscribe(let mailbox):
            return self.writeCommandKind_unsubscribe(mailbox: mailbox)
        case .authenticate(let mechanism, let initialResponse):
            return self.writeCommandKind_authenticate(mechanism: mechanism, initialResponse: initialResponse)
        case .login(let userid, let password):
            return self.writeCommandKind_login(userID: userid, password: password)
        case .startTLS:
            return self.writeCommandKind_startTLS()
        case .check:
            return self.writeCommandKind_check()
        case .close:
            return self.writeCommandKind_close()
        case .expunge:
            return self.writeCommandKind_expunge()
        case .uidExpunge(let set):
            return self.writeCommandKind_uidExpunge(set)
        case .enable(let capabilities):
            return self.writeCommandKind_enable(capabilities: capabilities)
        case .unselect:
            return self.writeCommandKind_unselect()
        case .idleStart:
            return self.writeCommandKind_idleStart()
        case .copy(let set, let mailbox):
            return self.writeCommandKind_copy(set: set, mailbox: mailbox)
        case .uidCopy(let set, let mailbox):
            return self.writeCommandKind_uidCopy(set: set, mailbox: mailbox)
        case .fetch(let set, let atts, let modifiers):
            return self.writeCommandKind_fetch(set: set, atts: atts, modifiers: modifiers)
        case .uidFetch(let set, let atts, let modifiers):
            return self.writeCommandKind_uidFetch(set: set, atts: atts, modifiers: modifiers)
        case .store(let set, let modifiers, let data):
            return self.writeCommandKind_store(set: set, modifiers: modifiers, data: data)
        case .uidStore(let set, let modifiers, let data):
            return self.writeCommandKind_uidStore(set: set, modifiers: modifiers, data: data)
        case .search(let key, let charset, let returnOptions):
            return self.writeCommandKind_search(key: key, charset: charset, returnOptions: returnOptions)
        case .uidSearch(let key, let charset, let returnOptions):
            return self.writeCommandKind_uidSearch(key: key, charset: charset, returnOptions: returnOptions)
        case .sort(let criteria, let charset, let key, let returnOptions):
            return self.writeCommandKind_sort(
                criteria: criteria,
                charset: charset,
                key: key,
                returnOptions: returnOptions
            )
        case .uidSort(let criteria, let charset, let key, let returnOptions):
            return self.writeCommandKind_uidSort(
                criteria: criteria,
                charset: charset,
                key: key,
                returnOptions: returnOptions
            )
        case .move(let set, let mailbox):
            return self.writeCommandKind_move(set: set, mailbox: mailbox)
        case .uidMove(let set, let mailbox):
            return self.writeCommandKind_uidMove(set: set, mailbox: mailbox)
        case .id(let id):
            return self.writeCommandKind_id(id)
        case .namespace:
            return self.writeCommandKind_namespace()
        case .getQuota(let quotaRoot):
            return self.writeCommandKind_getQuota(quotaRoot: quotaRoot)
        case .getQuotaRoot(let mailbox):
            return self.writeCommandKind_getQuotaRoot(mailbox: mailbox)
        case .setQuota(let quotaRoot, let quotaLimits):
            return self.writeCommandKind_setQuota(quotaRoot: quotaRoot, resourceLimits: quotaLimits)
        case .getMetadata(options: let options, mailbox: let mailbox, entries: let entries):
            return self.writeCommandKind_getMetadata(options: options, mailbox: mailbox, entries: entries)
        case .setMetadata(mailbox: let mailbox, entries: let entries):
            return self.writeCommandKind_setMetadata(mailbox: mailbox, entries: entries)
        case .extendedSearch(let options):
            return self.writeCommandKind_extendedSearch(options: options)
        case .resetKey(mailbox: let mailbox, mechanisms: let mechanisms):
            return self.writeCommandKind_resetKey(mailbox: mailbox, mechanisms: mechanisms)
        case .generateAuthorizedURL(let mechanisms):
            return self.writeCommandKind_generateAuthorizedURL(mechanisms: mechanisms)
        case .urlFetch(let urls):
            return self.writeCommandKind_urlFetch(urls: urls)
        case .compress(let kind):
            return self.writeCommandKind_compress(kind: kind)
        case .uidBatches(batchSize: let size, batchRange: let range):
            return self.writeCommandKind_uidBatches(batchSize: size, batchRange: range)
        case .getJMAPAccess:
            return self.writeCommandKind_getJMAPAccess()
        case .custom(name: let name, payloads: let payloads):
            return self.writeCommandKind_custom(name: name, payloads: payloads)
        }
    }

    private mutating func writeCommandKind_urlFetch(urls: [ByteBuffer]) -> Int {
        self.buffer.writeString("URLFETCH")
            + self.buffer.writeArray(urls, prefix: " ", parenthesis: false) { url, buffer in
                buffer.writeBytes(url.readableBytesView)
            }
    }

    private mutating func writeCommandKind_generateAuthorizedURL(mechanisms: [RumpURLAndMechanism]) -> Int {
        self.buffer.writeString("GENURLAUTH")
            + self.buffer.writeArray(mechanisms, prefix: " ", parenthesis: false) { mechanism, buffer in
                buffer.writeURLRumpMechanism(mechanism)
            }
    }

    private mutating func writeCommandKind_resetKey(
        mailbox: MailboxName?,
        mechanisms: [URLAuthenticationMechanism]
    ) -> Int {
        self.buffer.writeString("RESETKEY")
            + self.buffer.writeIfExists(mailbox) { mailbox in
                self.buffer.writeSpace() + self.buffer.writeMailbox(mailbox)
                    +

                    self.buffer.writeArray(mechanisms, prefix: " ", parenthesis: false) { mechanism, buffer in
                        buffer.writeURLAuthenticationMechanism(mechanism)
                    }
            }
    }

    private mutating func writeCommandKind_getMetadata(
        options: [MetadataOption],
        mailbox: MailboxName,
        entries: [MetadataEntryName]
    ) -> Int {
        self.buffer.writeString("GETMETADATA")
            + self.buffer.write(if: options.count >= 1) {
                buffer.writeSpace() + buffer.writeMetadataOptions(options)
            } + self.buffer.writeSpace() + self.buffer.writeMailbox(mailbox) + self.buffer.writeSpace()
            + self.buffer.writeEntries(entries)
    }

    private mutating func writeCommandKind_setMetadata(
        mailbox: MailboxName,
        entries: OrderedDictionary<MetadataEntryName, MetadataValue>
    ) -> Int {
        self.buffer.writeString("SETMETADATA ") + self.buffer.writeMailbox(mailbox) + self.buffer.writeSpace()
            + self.buffer.writeEntryValues(entries)
    }

    private mutating func writeCommandKind_capability() -> Int {
        self.buffer.writeString("CAPABILITY")
    }

    private mutating func writeCommandKind_logout() -> Int {
        self.buffer.writeString("LOGOUT")
    }

    private mutating func writeCommandKind_noop() -> Int {
        self.buffer.writeString("NOOP")
    }

    private mutating func writeCommandKind_create(mailbox: MailboxName, parameters: [CreateParameter]) -> Int {
        self.buffer.writeString("CREATE ") + self.buffer.writeMailbox(mailbox)
            + self.buffer.write(if: parameters.count > 0) {
                self.buffer.writeSpace()
                    + self.buffer.writeArray(parameters, separator: "", parenthesis: true) { (param, buffer) -> Int in
                        buffer.writeCreateParameter(param)
                    }
            }
    }

    private mutating func writeCommandKind_delete(mailbox: MailboxName) -> Int {
        self.buffer.writeString("DELETE ") + self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_examine(mailbox: MailboxName, parameters: [SelectParameter]) -> Int {
        self.buffer.writeString("EXAMINE ") + self.buffer.writeMailbox(mailbox)
            + self.buffer.writeSelectParameters(parameters)
    }

    private mutating func writeCommandKind_list(
        selectOptions: ListSelectOptions?,
        mailbox: MailboxName,
        mailboxPatterns: MailboxPatterns,
        returnOptions: [ReturnOption]
    ) -> Int {
        self.buffer.writeString("LIST")
            + self.buffer.writeIfExists(selectOptions) { (options) -> Int in
                self.buffer.writeSpace() + self.buffer.writeListSelectOptions(options)
            } + self.buffer.writeSpace() + self.buffer.writeMailbox(mailbox) + self.buffer.writeSpace()
            + self.buffer.writeMailboxPatterns(mailboxPatterns)
            + self.buffer.write(if: returnOptions.count >= 1) {
                self.buffer.writeSpace() + self.buffer.writeListReturnOptions(returnOptions)
            }
    }

    private mutating func writeCommandKind_listIndependent(
        selectOptions: [ListSelectIndependentOption],
        mailbox: MailboxName,
        mailboxPatterns: MailboxPatterns,
        returnOptions: [ReturnOption]
    ) -> Int {
        self.buffer.writeString("LIST")
            + self.buffer.write(if: selectOptions.count >= 1) {
                self.buffer.writeArray(selectOptions) { element, buffer in
                    buffer.writeListSelectIndependentOption(element)
                }
            } + self.buffer.writeSpace() + self.buffer.writeMailbox(mailbox) + self.buffer.writeSpace()
            + self.buffer.writeMailboxPatterns(mailboxPatterns)
            + self.buffer.write(if: returnOptions.count >= 1) {
                self.buffer.writeSpace() + self.buffer.writeListReturnOptions(returnOptions)
            }
    }

    private mutating func writeCommandKind_lsub(mailbox: MailboxName, listMailbox: ByteBuffer) -> Int {
        self.buffer.writeString("LSUB ") + self.buffer.writeMailbox(mailbox) + self.buffer.writeSpace()
            + self.buffer.writeIMAPString(listMailbox)
    }

    private mutating func writeCommandKind_rename(
        from: MailboxName,
        to: MailboxName,
        parameters: OrderedDictionary<String, ParameterValue?>
    ) -> Int {
        self.buffer.writeString("RENAME ") + self.buffer.writeMailbox(from) + self.buffer.writeSpace()
            + self.buffer.writeMailbox(to)
            + self.buffer.writeIfExists(parameters) { (params) -> Int in
                self.buffer.writeParameters(params)
            }
    }

    private mutating func writeCommandKind_select(mailbox: MailboxName, parameters: [SelectParameter]) -> Int {
        self.buffer.writeString("SELECT ") + self.buffer.writeMailbox(mailbox)
            + self.buffer.writeSelectParameters(parameters)
    }

    private mutating func writeCommandKind_status(mailbox: MailboxName, attributes: [MailboxAttribute]) -> Int {
        self.buffer.writeString("STATUS ") + self.buffer.writeMailbox(mailbox) + self.buffer.writeString(" (")
            + self.buffer.writeMailboxAttributes(attributes) + self.buffer.writeString(")")
    }

    private mutating func writeCommandKind_subscribe(mailbox: MailboxName) -> Int {
        self.buffer.writeString("SUBSCRIBE ") + self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_unsubscribe(mailbox: MailboxName) -> Int {
        self.buffer.writeString("UNSUBSCRIBE ") + self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_compress(kind: Capability.CompressionKind) -> Int {
        self.buffer.writeString("COMPRESS \(kind.rawValue)")
    }

    private mutating func writeCommandKind_uidBatches(batchSize: Int, batchRange: ClosedRange<Int>?) -> Int {
        self.buffer.writeString("UIDBATCHES \(batchSize)")
            + self.buffer.writeIfExists(batchRange) {
                let range =
                    UnknownMessageIdentifier(exactly: $0.lowerBound)!...UnknownMessageIdentifier(
                        exactly: $0.upperBound
                    )!
                return self.buffer
                    .writeString(" ")
                    + self.buffer
                    .writeMessageIdentifierRange(range)
            }
    }

    private mutating func writeCommandKind_custom(name: String, payloads: [Command.CustomCommandPayload]) -> Int {
        self.buffer.writeString("\(name)")
            + self.buffer.writeArray(payloads, prefix: " ", separator: "", parenthesis: false) { (payload, self) in
                self.writeCustomCommandPayload(payload)
            }
    }

    private mutating func writeCommandKind_authenticate(
        mechanism: AuthenticationMechanism,
        initialResponse: InitialResponse?
    ) -> Int {
        self.buffer.writeString("AUTHENTICATE ") + self.buffer.writeAuthenticationMechanism(mechanism)
            + self.buffer.writeIfExists(initialResponse) { resp in
                var c = self.buffer.writeSpace()
                if self.buffer.loggingMode {
                    c += self.buffer.writeString("∅")
                } else {
                    c += self.buffer.writeInitialResponse(resp)
                }
                return c
            }
    }

    private mutating func writeCommandKind_login(userID: String, password: String) -> Int {
        self.buffer.writeString("LOGIN ") + self.buffer.writeIMAPString(userID) + self.buffer.writeSpace()
            + self.buffer.writeIMAPString(password)
    }

    private mutating func writeCommandKind_startTLS() -> Int {
        self.buffer.writeString("STARTTLS")
    }

    private mutating func writeCommandKind_check() -> Int {
        self.buffer.writeString("CHECK")
    }

    private mutating func writeCommandKind_close() -> Int {
        self.buffer.writeString("CLOSE")
    }

    private mutating func writeCommandKind_expunge() -> Int {
        self.buffer.writeString("EXPUNGE")
    }

    private mutating func writeCommandKind_uidExpunge(_ set: LastCommandSet<UID>) -> Int {
        self.buffer.writeString("UID EXPUNGE ") + self.buffer.writeLastCommandSet(set)
    }

    private mutating func writeCommandKind_unselect() -> Int {
        self.buffer.writeString("UNSELECT")
    }

    private mutating func writeCommandKind_idleStart() -> Int {
        self.buffer.writeString("IDLE")
    }

    private mutating func writeCommandKind_idleFinish() -> Int {
        self.buffer.writeString("DONE")
    }

    private mutating func writeCommandKind_enable(capabilities: [Capability]) -> Int {
        self.buffer.writeString("ENABLE ")
            + self.buffer.writeArray(capabilities, parenthesis: false) { (element, self) in
                self.writeCapability(element)
            }
    }

    private mutating func writeCommandKind_copy(set: LastCommandSet<SequenceNumber>, mailbox: MailboxName) -> Int {
        self.buffer.writeString("COPY ") + self.buffer.writeLastCommandSet(set) + self.buffer.writeSpace()
            + self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_uidCopy(set: LastCommandSet<UID>, mailbox: MailboxName) -> Int {
        self.buffer.writeString("UID COPY ") + self.buffer.writeLastCommandSet(set) + self.buffer.writeSpace()
            + self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_fetch(
        set: LastCommandSet<SequenceNumber>,
        atts: [FetchAttribute],
        modifiers: [FetchModifier]
    ) -> Int {
        self.buffer.writeString("FETCH ") + self.buffer.writeLastCommandSet(set) + self.buffer.writeSpace()
            + self.buffer.writeFetchAttributeList(atts) + self.buffer.writeFetchModifiers(modifiers)
    }

    private mutating func writeCommandKind_uidFetch(
        set: LastCommandSet<UID>,
        atts: [FetchAttribute],
        modifiers: [FetchModifier]
    ) -> Int {
        self.buffer.writeString("UID FETCH ") + self.buffer.writeLastCommandSet(set) + self.buffer.writeSpace()
            + self.buffer.writeFetchAttributeList(atts) + self.buffer.writeFetchModifiers(modifiers)
    }

    private mutating func writeCommandKind_store(
        set: LastCommandSet<SequenceNumber>,
        modifiers: [StoreModifier],
        data: StoreData
    ) -> Int {
        self.buffer.writeString("STORE ") + self.buffer.writeLastCommandSet(set)
            + self.buffer.write(if: modifiers.count >= 1) {
                self.buffer.writeSpace()
                    + self.buffer.writeArray(modifiers) { (element, buffer) -> Int in
                        buffer.writeStoreModifier(element)
                    }
            } + self.buffer.writeSpace() + self.buffer.writeStoreData(data)
    }

    private mutating func writeCommandKind_uidStore(
        set: LastCommandSet<UID>,
        modifiers: [StoreModifier],
        data: StoreData
    ) -> Int {
        self.buffer.writeString("UID STORE ") + self.buffer.writeLastCommandSet(set)
            + self.buffer.write(if: modifiers.count >= 1) {
                self.buffer.writeStoreModifiers(modifiers)
            } + self.buffer.writeSpace() + self.buffer.writeStoreData(data)
    }

    private mutating func writeCommandKind_search(
        key: SearchKey,
        charset: String? = nil,
        returnOptions: [SearchReturnOption] = []
    ) -> Int {
        self.buffer.writeString("SEARCH")
            + self.buffer.writeIfExists(returnOptions) { (options) -> Int in
                self.buffer.writeSearchReturnOptions(options)
            } + self.buffer.writeSpace()
            + self.buffer.write(if: key.usesString && options.useSearchCharset) {
                self.buffer.writeIfExists(charset) { (charset) -> Int in
                    self.buffer.writeString("CHARSET \(charset) ")
                }
            } + self.buffer.writeSearchKey(key)
    }

    private mutating func writeCommandKind_uidSearch(
        key: SearchKey,
        charset: String? = nil,
        returnOptions: [SearchReturnOption] = []
    ) -> Int {
        self.buffer.writeString("UID ")
            + self.writeCommandKind_search(key: key, charset: charset, returnOptions: returnOptions)
    }

    private mutating func writeCommandKind_sort(
        criteria: [SortCriterion],
        charset: String,
        key: SearchKey,
        returnOptions: [SearchReturnOption] = []
    ) -> Int {
        self.buffer.writeString("SORT")
            + self.buffer.writeIfExists(returnOptions) { (options) -> Int in
                self.buffer.writeSearchReturnOptions(options)
            } + self.buffer.writeSpace()
            + self.buffer.writeSortCriteria(criteria)
            + self.buffer.writeSpace()
            + self.buffer.writeString(charset)
            + self.buffer.writeSpace()
            + self.buffer.writeSearchKey(key)
    }

    private mutating func writeCommandKind_uidSort(
        criteria: [SortCriterion],
        charset: String,
        key: SearchKey,
        returnOptions: [SearchReturnOption] = []
    ) -> Int {
        self.buffer.writeString("UID ")
            + self.writeCommandKind_sort(criteria: criteria, charset: charset, key: key, returnOptions: returnOptions)
    }

    private mutating func writeCommandKind_move(set: LastCommandSet<SequenceNumber>, mailbox: MailboxName) -> Int {
        self.buffer.writeString("MOVE ") + self.buffer.writeLastCommandSet(set) + self.buffer.writeSpace()
            + self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_uidMove(set: LastCommandSet<UID>, mailbox: MailboxName) -> Int {
        self.buffer.writeString("UID MOVE ") + self.buffer.writeLastCommandSet(set) + self.buffer.writeSpace()
            + self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_namespace() -> Int {
        self.buffer.writeNamespaceCommand()
    }

    @discardableResult mutating func writeCommandKind_id(_ id: OrderedDictionary<String, String?>) -> Int {
        self.buffer.writeString("ID ") + self.buffer.writeIDParameters(id)
    }

    private mutating func writeCommandKind_getQuota(quotaRoot: QuotaRoot) -> Int {
        self.buffer.writeString("GETQUOTA ") + self.buffer.writeQuotaRoot(quotaRoot)
    }

    private mutating func writeCommandKind_getQuotaRoot(mailbox: MailboxName) -> Int {
        self.buffer.writeString("GETQUOTAROOT ") + self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_setQuota(quotaRoot: QuotaRoot, resourceLimits: [QuotaLimit]) -> Int {
        self.buffer.writeString("SETQUOTA ") + self.buffer.writeQuotaRoot(quotaRoot) + self.buffer.writeSpace()
            + self.buffer.writeArray(resourceLimits) { (limit, self) in
                self.writeQuotaLimit(limit)
            }
    }

    private mutating func writeCommandKind_extendedSearch(options: ExtendedSearchOptions) -> Int {
        self.buffer.writeString("ESEARCH") + self.buffer.writeExtendedSearchOptions(options)
    }

    private mutating func writeCommandKind_getJMAPAccess() -> Int {
        self.buffer.writeString("GETJMAPACCESS")
    }
}

// MARK: - Conveniences

extension Command {
    /// Convenience for creating a `UIDBATCHES` command.
    ///
    /// https://datatracker.ietf.org/doc/draft-ietf-mailmaint-imap-uidbatches/
    public static func uidBatches(batchSize: Int) -> Command {
        return .uidBatches(batchSize: batchSize, batchRange: nil)
    }

    /// Convenience for creating a *UID MOVE* command.
    /// Pass in a `UIDSet`, and if that set is valid (that is, non-empty) then a command is returned.
    /// - parameter messages: The set of message UIDs to use.
    /// - parameter mailbox: The destination mailbox.
    /// - returns: `nil` if `messages` is empty, otherwise a `Command`.
    public static func uidMove(messages: UIDSet, mailbox: MailboxName) -> Command? {
        guard let set = MessageIdentifierSetNonEmpty(set: messages) else {
            return nil
        }
        return .uidMove(.set(set), mailbox)
    }

    /// Convenience for creating a *UID COPY* command.
    /// Pass in a `UIDSet`, and if that set is valid (that is, non-empty) then a command is returned.
    /// - parameter messages: The set of message UIDs to use.
    /// - parameter mailbox: The destination mailbox.
    /// - returns: `nil` if `messages` is empty, otherwise a `Command`.
    public static func uidCopy(messages: UIDSet, mailbox: MailboxName) -> Command? {
        guard let set = MessageIdentifierSetNonEmpty(set: messages) else {
            return nil
        }
        return .uidCopy(.set(set), mailbox)
    }

    /// Convenience for creating a *UID FETCH* command.
    /// Pass in a `UIDSet`, and if that set is valid (that is, non-empty) then a command is returned.
    /// - parameter messages: The set of message UIDs to use.
    /// - parameter attributes: Which attributes to retrieve.
    /// - parameter modifiers: Fetch modifiers.
    /// - returns: `nil` if `messages` is empty, otherwise a `Command`.
    public static func uidFetch(messages: UIDSet, attributes: [FetchAttribute], modifiers: [FetchModifier]) -> Command?
    {
        guard let set = MessageIdentifierSetNonEmpty(set: messages) else {
            return nil
        }
        return .uidFetch(.set(set), attributes, modifiers)
    }

    /// Convenience for creating a *UID STORE* command.
    /// Pass in a `UIDSet`, and if that set is valid (that is, non-empty) then a command is returned.
    /// - parameter messages: The set of message UIDs to use.
    /// - parameter modifiers: Store modifiers.
    /// - parameter data: The store data to apply.
    /// - returns: `nil` if `messages` is empty, otherwise a `Command`.
    public static func uidStore(messages: UIDSet, modifiers: [StoreModifier], data: StoreData) -> Command? {
        guard let set = MessageIdentifierSetNonEmpty(set: messages) else {
            return nil
        }
        return .uidStore(.set(set), modifiers, data)
    }

    /// Convenience for creating a *UID EXPUNGE* command.
    /// Pass in a `UIDSet`, and if that set is valid (that is, non-empty) then a command is returned.
    /// - parameter messages: The set of message UIDs to use.
    /// - parameter mailbox: The mailbox on which to perform the expunge.
    /// - returns: `nil` if `messages` is empty, otherwise a `Command`.
    public static func uidExpunge(messages: UIDSet, mailbox: MailboxName) -> Command? {
        guard let set = MessageIdentifierSetNonEmpty(set: messages) else {
            return nil
        }
        return .uidExpunge(.set(set))
    }
}
