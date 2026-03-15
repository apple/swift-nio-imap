//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Requirements that must be satisfied before starting a command.
///
/// IMAP supports command pipelining, where multiple commands can be in flight simultaneously.
/// However, RFC 3501 Section 5.5 (“Multiple Commands in Progress”) restricts what command
/// combinations are valid. This enum defines constraints that a command has on what other
/// commands can currently be running.
///
/// The pipelining system uses two complementary types:
/// - `PipeliningRequirement`: Constraints a command _imposes_ on other running commands
/// - ``PipeliningBehavior``: The characteristics of a running command
///
/// To check if a command can start, verify that the current ``PipeliningBehavior``
/// (from commands already running) satisfies the new command’s `PipeliningRequirement`.
///
/// ## Examples
///
/// A `SELECT` command has the requirement ``PipeliningRequirement/noMailboxCommandsRunning``,
/// meaning no other commands that depend on or change the mailbox selection can be running
/// when `SELECT` is sent. Conversely, commands have the behavior
/// ``PipeliningBehavior/changesMailboxSelection`` to indicate they satisfy this requirement.
///
/// - SeeAlso: ``PipeliningBehavior``, ``CommandStreamPart/pipeliningRequirements``,
///   [RFC 3501 Section 5.5](https://datatracker.ietf.org/doc/html/rfc3501#section-5.5)
public enum PipeliningRequirement: Hashable, Sendable {
    /// No command that depends on or changes the mailbox selection can be running.
    ///
    /// This requirement is imposed by commands like `SELECT`, `EXAMINE`, `UNSELECT`,
    /// and `CLOSE` that establish or clear the mailbox selection context.
    case noMailboxCommandsRunning

    /// No command other than `FETCH`, `STORE`, and `SEARCH` can be running.
    ///
    /// Sequence number-based commands impose this requirement to avoid untagged `EXPUNGE`
    /// responses that would invalidate their sequence numbers mid-command.
    case noUntaggedExpungeResponse

    /// No command using UIDs to specify messages can be running.
    ///
    /// This is a requirement for sequence number-based commands, since a UID-based
    /// command might invalidate the mailbox state.
    case noUIDBasedCommandRunning

    /// No flags are being changed on these specific messages.
    ///
    /// When a command reads flags from certain messages, other commands cannot
    /// simultaneously change flags on those same messages.
    case noFlagChanges(MessageIdentifierSetNonEmpty<UID>)

    /// No command is reading flags from these specific messages.
    ///
    /// When a command modifies flags on certain messages (and is not silent), other
    /// commands cannot simultaneously read flags from those same messages.
    case noFlagReads(MessageIdentifierSetNonEmpty<UID>)

    // TODO: Add Message metadata read + write
    // TODO: Add mailbox create / delete / subscribe / metadata / quota
}

extension PipeliningRequirement {
    /// No flags are being changed on any message.
    ///
    /// Convenience static member equivalent to ``noFlagChanges(_:)`` with
    /// ``MessageIdentifierSetNonEmpty/all``.
    public static let noFlagChangesToAnyMessage = PipeliningRequirement.noFlagChanges(.all)

    /// No flags are being read from any message.
    ///
    /// Convenience static member equivalent to ``noFlagReads(_:)`` with
    /// ``MessageIdentifierSetNonEmpty/all``.
    public static let noFlagReadsFromAnyMessage = PipeliningRequirement.noFlagReads(.all)
}

/// Describes characteristics of a running command relevant to pipelining.
///
/// While ``PipeliningRequirement`` defines what constraints a command _imposes_,
/// `PipeliningBehavior` describes the characteristics of an already-running command.
/// The pipelining system checks that a new command's requirements are satisfied by
/// the behaviors of currently running commands.
///
/// Each running command contributes zero or more behaviors to the "current state".
/// To verify a new command can start, check that `Set<PipeliningBehavior>`
/// representing all running commands satisfies the new command's requirements.
///
/// ## Example
///
/// A `FETCH` command has behaviors including ``dependsOnMailboxSelection`` and
/// possibly ``readsFlagsFromAnyMessage``. A later `STORE` command with flag changes
/// (non-silent) has requirement ``PipeliningRequirement/noFlagReads`` on those messages,
/// which will conflict with the existing `FETCH` behavior.
///
/// - SeeAlso: ``PipeliningRequirement``, ``CommandStreamPart/pipeliningBehavior``,
///   [RFC 3501 Section 5.5](https://datatracker.ietf.org/doc/html/rfc3501#section-5.5)
public enum PipeliningBehavior: Hashable, Sendable {
    /// This command establishes a new mailbox selection.
    ///
    /// Commands like `SELECT`, `EXAMINE`, and `UNSELECT` change which mailbox is active.
    /// These commands satisfy the requirement ``PipeliningRequirement/noMailboxCommandsRunning``
    /// imposed by other mailbox-selection commands.
    case changesMailboxSelection

    /// This command operates within and depends on the current mailbox selection.
    ///
    /// Commands like `FETCH`, `STORE`, `SEARCH`, `EXPUNGE`, etc. require a mailbox
    /// to be selected and will fail if no selection is active.
    case dependsOnMailboxSelection

    /// This command may trigger untagged `EXPUNGE` responses.
    ///
    /// Most commands can cause the server to send untagged `EXPUNGE` responses,
    /// invalidating the sequence numbers of remaining messages. Only `FETCH`, `STORE`,
    /// and `SEARCH` guarantee no untagged `EXPUNGE`. This behavior satisfies the
    /// requirement ``PipeliningRequirement/noUntaggedExpungeResponse``.
    case mayTriggerUntaggedExpunge

    /// This command uses UIDs to identify messages or is itself a `UID` command.
    ///
    /// Commands like `UID FETCH`, `UID STORE`, etc. operate on UIDs. This behavior
    /// satisfies the requirement ``PipeliningRequirement/noUIDBasedCommandRunning``.
    case isUIDBased

    /// This command changes flags on these specific messages.
    ///
    /// For non-silent `STORE` operations and similar flag-modifying commands, this
    /// behavior indicates which messages have their flags changed. Satisfies
    /// ``PipeliningRequirement/noFlagReads(_:)`` requirements on those messages.
    case changesFlags(MessageIdentifierSetNonEmpty<UID>)

    /// This command queries flags from these specific messages.
    ///
    /// For `FETCH` commands with flag attributes and similar flag-reading commands,
    /// this behavior indicates which messages have their flags read. Satisfies
    /// ``PipeliningRequirement/noFlagChanges(_:)`` requirements on those messages.
    case readsFlags(MessageIdentifierSetNonEmpty<UID>)

    /// No other commands can be sent until this command completes.
    ///
    /// Barrier commands like `IDLE`, `AUTHENTICATE`, and `STARTTLS` can only run alone
    /// because they exchange multiple messages with the server before a completion response.
    /// If other commands were pipelined, there would be ambiguity about which command
    /// a continuation request or unsolicited response belongs to.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2) (AUTHENTICATE),
    ///   [RFC 2177](https://datatracker.ietf.org/doc/html/rfc2177) (IDLE),
    ///   [RFC 3501 Section 6.2.1](https://datatracker.ietf.org/doc/html/rfc3501#section-6.2.1) (STARTTLS)
    case barrier
}

extension PipeliningBehavior {
    /// This command is changing flags on all messages.
    ///
    /// Convenience static member equivalent to ``changesFlags(_:)`` with
    /// ``MessageIdentifierSetNonEmpty/all``.
    public static let changesFlagsOnAnyMessage = PipeliningBehavior.changesFlags(.all)

    /// This command is querying flags from all messages.
    ///
    /// Convenience static member equivalent to ``readsFlags(_:)`` with
    /// ``MessageIdentifierSetNonEmpty/all``.
    public static let readsFlagsFromAnyMessage = PipeliningBehavior.readsFlags(.all)
}

extension CommandStreamPart {
    /// The requirements that must be satisfied before this command can start.
    ///
    /// This property returns the ``PipeliningRequirement`` constraints imposed by this
    /// command. Before sending this command, verify that all currently running commands
    /// together satisfy these requirements.
    ///
    /// - Returns: A set of requirements this command imposes on other running commands.
    ///
    /// - SeeAlso: ``pipeliningBehavior``, [RFC 3501 Section 5.5](https://datatracker.ietf.org/doc/html/rfc3501#section-5.5)
    public var pipeliningRequirements: Set<PipeliningRequirement> {
        switch self {
        case .idleDone:
            return []
        case .tagged(let tagged):
            return tagged.command.pipeliningRequirements
        case .append:
            return []
        case .continuationResponse:
            return []
        }
    }
}

extension Command {
    var pipeliningRequirements: Set<PipeliningRequirement> {
        switch self {
        case .select,
            .unselect,
            .close,
            .examine:
            return [.noMailboxCommandsRunning]

        case .search(key: let key, charset: _, returnOptions: _):
            return key.pipeliningRequirements
        case .uidSearch(key: let key, charset: _, returnOptions: _):
            return key.pipeliningRequirements
        case .extendedSearch(let options):
            return options.key.pipeliningRequirements

        case .fetch(_, let attributes, _):
            return attributes.pipeliningRequirements
                .union([.noUntaggedExpungeResponse, .noUIDBasedCommandRunning])
        case .uidFetch(.lastCommand, let attributes, _):
            return attributes.pipeliningRequirements
        case .uidFetch(.set(let uids), let attributes, _):
            return attributes.makePipeliningRequirements(uids)

        case .copy,
            .move:
            return [.noUntaggedExpungeResponse, .noUIDBasedCommandRunning]

        case .uidCopy,
            .uidMove,
            .uidExpunge,
            .expunge,
            .uidBatches:
            return []

        case .store(_, _, let data):
            switch data {
            case .flags(let flags):
                return flags.silent
                    ? [.noUntaggedExpungeResponse, .noUIDBasedCommandRunning, .noFlagReadsFromAnyMessage]
                    : [
                        .noUntaggedExpungeResponse, .noUIDBasedCommandRunning, .noFlagReadsFromAnyMessage,
                        .noFlagChangesToAnyMessage,
                    ]
            case .gmailLabels(let labels):
                return labels.silent
                    ? [.noUntaggedExpungeResponse, .noUIDBasedCommandRunning, .noFlagReadsFromAnyMessage]
                    : [
                        .noUntaggedExpungeResponse, .noUIDBasedCommandRunning, .noFlagReadsFromAnyMessage,
                        .noFlagChangesToAnyMessage,
                    ]
            }
        case .uidStore(.lastCommand, _, let data):
            switch data {
            case .flags(let flags):
                return flags.silent
                    ? [.noFlagReadsFromAnyMessage] : [.noFlagReadsFromAnyMessage, .noFlagChangesToAnyMessage]
            case .gmailLabels(let labels):
                return labels.silent
                    ? [.noFlagReadsFromAnyMessage] : [.noFlagReadsFromAnyMessage, .noFlagChangesToAnyMessage]
            }
        case .uidStore(.set(let uids), _, let data):
            switch data {
            case .flags(let flags):
                return flags.silent ? [.noFlagReads(uids)] : [.noFlagReads(uids), .noFlagChanges(uids)]
            case .gmailLabels(let labels):
                return labels.silent ? [.noFlagReads(uids)] : [.noFlagReads(uids), .noFlagChanges(uids)]
            }

        case .capability,
            .logout,
            .noop,
            .check,
            .authenticate,
            .login,
            .startTLS,
            .enable,
            .getJMAPAccess,
            .idleStart,
            .id,
            .namespace,
            .compress,

            // Mailbox:
            .status,
            .create,
            .list,
            .listIndependent,
            .lsub,
            .subscribe,
            .unsubscribe,
            .delete,
            .rename,

            // Quota:
            .getQuota,
            .getQuotaRoot,
            .setQuota,

            // Metadata:
            .getMetadata,
            .setMetadata,

            // URL Auth:
            .resetKey,
            .generateAuthorizedURL,
            .urlFetch:
            return []
        case .custom:
            return [
                .noMailboxCommandsRunning,
                .noUntaggedExpungeResponse,
                .noUIDBasedCommandRunning,
                .noFlagChanges(.all),
                .noFlagReads(.all),
            ]
        }
    }
}

extension CommandStreamPart {
    /// The pipelining characteristics of this command.
    ///
    /// This property returns the ``PipeliningBehavior`` values that describe how this
    /// command behaves with respect to pipelining. These behaviors affect what new
    /// commands can be sent while this command is running.
    ///
    /// Multiple behaviors can be combined in the returned set. For example, a `FETCH`
    /// command might return behaviors for depending on mailbox selection, being UID-based,
    /// and reading flags, all of which constrain what other commands can run concurrently.
    ///
    /// - Returns: A set of behaviors describing this command's pipelining characteristics.
    ///
    /// - SeeAlso: ``pipeliningRequirements``, [RFC 3501 Section 5.5](https://datatracker.ietf.org/doc/html/rfc3501#section-5.5)
    public var pipeliningBehavior: Set<PipeliningBehavior> {
        switch self {
        case .idleDone:
            return [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .barrier]
        case .tagged(let tagged):
            return tagged.command.pipeliningBehavior
        case .append(.start):
            return [.mayTriggerUntaggedExpunge]
        case .append(.catenateURL):
            return [.isUIDBased]
        case .append:
            return []
        case .continuationResponse:
            return []
        }
    }
}

extension Command {
    var pipeliningBehavior: Set<PipeliningBehavior> {
        switch self {
        case .select,
            .unselect,
            .examine,
            .close:
            return [.changesMailboxSelection, .mayTriggerUntaggedExpunge]

        case .expunge:
            return [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge]
        case .uidExpunge:
            return [.dependsOnMailboxSelection, .isUIDBased, .mayTriggerUntaggedExpunge]

        case .fetch(_, let attributes, _):
            return attributes.readsFlags
                ? [.dependsOnMailboxSelection, .readsFlagsFromAnyMessage] : [.dependsOnMailboxSelection]
        case .uidFetch(.lastCommand, let attributes, _):
            return attributes.readsFlags
                ? [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .readsFlagsFromAnyMessage]
                : [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased]
        case .uidFetch(.set(let uids), let attributes, _):
            return attributes.readsFlags
                ? [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .readsFlags(uids)]
                : [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased]

        case .copy, .move:
            return [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge]
        case .uidCopy, .uidMove:
            return [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased]

        case .search(key: let key, charset: _, returnOptions: _):
            return key.pipeliningBehavior.union(
                [.dependsOnMailboxSelection]
            )
        case .uidSearch(key: let key, charset: _, returnOptions: _):
            return key.pipeliningBehavior.union(
                [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased]
            )
        case .extendedSearch(let options):
            return options.key.pipeliningBehavior.union(
                [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased]
            )

        case .store(_, _, let data):
            switch data {
            case .flags(let storeFlags):
                return storeFlags.silent
                    ? [.dependsOnMailboxSelection, .changesFlagsOnAnyMessage]
                    : [.dependsOnMailboxSelection, .changesFlagsOnAnyMessage, .readsFlagsFromAnyMessage]
            case .gmailLabels(let storeGmailLabels):
                return storeGmailLabels.silent
                    ? [.dependsOnMailboxSelection, .changesFlagsOnAnyMessage]
                    : [.dependsOnMailboxSelection, .changesFlagsOnAnyMessage, .readsFlagsFromAnyMessage]
            }
        case .uidStore(.lastCommand, _, let data):
            switch data {
            case .flags(let storeFlags):
                return storeFlags.silent
                    ? [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .changesFlagsOnAnyMessage]
                    : [
                        .dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .changesFlagsOnAnyMessage,
                        .readsFlagsFromAnyMessage,
                    ]
            case .gmailLabels(let storeGmailLabels):
                return storeGmailLabels.silent
                    ? [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .changesFlagsOnAnyMessage]
                    : [
                        .dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .changesFlagsOnAnyMessage,
                        .readsFlagsFromAnyMessage,
                    ]
            }
        case .uidStore(.set(let uids), _, let data):
            switch data {
            case .flags(let storeFlags):
                return storeFlags.silent
                    ? [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .changesFlags(uids)]
                    : [
                        .dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .changesFlags(uids),
                        .readsFlags(uids),
                    ]
            case .gmailLabels(let storeGmailLabels):
                return storeGmailLabels.silent
                    ? [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .changesFlags(uids)]
                    : [
                        .dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .changesFlags(uids),
                        .readsFlags(uids),
                    ]
            }

        case .noop,
            .check:
            return [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge]

        case .startTLS,
            .logout,
            .authenticate,
            .compress:
            return [.barrier]

        case .idleStart:
            return [.barrier, .dependsOnMailboxSelection, .mayTriggerUntaggedExpunge]

        case .login:
            return []

        case .capability,
            .create,
            .delete,
            .rename,
            .list,
            .listIndependent,
            .lsub,
            .status,
            .getJMAPAccess,
            .id,
            .namespace,
            .enable,
            .resetKey:
            return [.mayTriggerUntaggedExpunge]

        case .generateAuthorizedURL,
            .urlFetch:
            return [.mayTriggerUntaggedExpunge, .isUIDBased]

        case .subscribe,
            .unsubscribe:
            // TODO: Subscribe vs. LIST / LSUB ?!?
            return [.mayTriggerUntaggedExpunge]

        case .getQuota,
            .getQuotaRoot,
            .setQuota:
            // TODO: Quota dependencies?
            return [.mayTriggerUntaggedExpunge]

        case .getMetadata,
            .setMetadata:
            // TODO: Metadata dependencies?
            return [.mayTriggerUntaggedExpunge]

        case .uidBatches:
            return [.isUIDBased, .mayTriggerUntaggedExpunge]

        case .custom:
            return [.barrier]
        }
    }
}

// MARK: -

extension Array where Element == FetchAttribute {
    func makePipeliningRequirements(_ uids: MessageIdentifierSetNonEmpty<UID>) -> Set<PipeliningRequirement> {
        reduce(into: Set<PipeliningRequirement>()) { $0.formUnion($1.makePipeliningRequirements(uids)) }
    }

    var pipeliningRequirements: Set<PipeliningRequirement> {
        reduce(into: Set<PipeliningRequirement>()) { $0.formUnion($1.pipeliningRequirements) }
    }

    var readsFlags: Bool {
        contains { $0.readsFlags }
    }
}

extension FetchAttribute {
    func makePipeliningRequirements(_ uids: MessageIdentifierSetNonEmpty<UID>) -> Set<PipeliningRequirement> {
        guard self.readsFlags else { return [] }
        return [.noFlagChanges(uids)]
    }

    var pipeliningRequirements: Set<PipeliningRequirement> {
        guard self.readsFlags else { return [] }
        return [.noFlagChangesToAnyMessage]
    }

    var readsFlags: Bool {
        switch self {
        case .flags:
            return true
        case .envelope,
            .internalDate,
            .rfc822,
            .rfc822Header,
            .rfc822Size,
            .rfc822Text,
            .bodyStructure,
            .bodySection,
            .uid,
            .modificationSequence,
            .modificationSequenceValue,
            .binary,
            .binarySize,
            .gmailMessageID,
            .gmailThreadID,
            .gmailLabels,
            .preview,
            .emailID,
            .threadID:
            return false
        }
    }
}

extension SearchKey {
    var pipeliningRequirements: Set<PipeliningRequirement> {
        var result = Set<PipeliningRequirement>()
        if self.referencesSequenceNumbers {
            result.insert(.noUntaggedExpungeResponse)
            result.insert(.noUIDBasedCommandRunning)
        }
        if self.referencesFlags {
            result.insert(.noFlagChangesToAnyMessage)
        }
        return result
    }

    var pipeliningBehavior: Set<PipeliningBehavior> {
        var result = Set<PipeliningBehavior>()
        if self.referencesUIDs {
            result.insert(.isUIDBased)
        }
        if self.referencesFlags {
            result.insert(.readsFlagsFromAnyMessage)
        }
        return result
    }

    private var referencesSequenceNumbers: Bool {
        switch self {
        case .all,
            .answered,
            .bcc,
            .before,
            .body,
            .cc,
            .deleted,
            .flagged,
            .from,
            .keyword,
            .modificationSequence,
            .new,
            .old,
            .on,
            .recent,
            .seen,
            .since,
            .subject,
            .text,
            .to,
            .unanswered,
            .undeleted,
            .unflagged,
            .unkeyword,
            .unseen,
            .draft,
            .header,
            .messageSizeLarger,
            .messageSizeSmaller,
            .older,
            .sentBefore,
            .sentOn,
            .sentSince,
            .uid,
            .uidAfter,
            .uidBefore,
            .undraft,
            .younger,
            .emailID,
            .threadID:
            return false
        case .filter,  // Have to assume yes, since we can't know
            .sequenceNumbers:
            return true
        case .and(let keys):
            return keys.contains(where: \.referencesSequenceNumbers)
        case .not(let key):
            return key.referencesSequenceNumbers
        case .or(let keyA, let keyB):
            return keyA.referencesSequenceNumbers || keyB.referencesSequenceNumbers
        }
    }

    private var referencesUIDs: Bool {
        switch self {
        case .all,
            .answered,
            .bcc,
            .before,
            .body,
            .cc,
            .deleted,
            .flagged,
            .from,
            .keyword,
            .modificationSequence,
            .new,
            .old,
            .on,
            .recent,
            .seen,
            .since,
            .subject,
            .text,
            .to,
            .unanswered,
            .undeleted,
            .unflagged,
            .unkeyword,
            .unseen,
            .draft,
            .header,
            .messageSizeLarger,
            .messageSizeSmaller,
            .older,
            .sentBefore,
            .sentOn,
            .sentSince,
            .sequenceNumbers,
            .undraft,
            .younger,
            .emailID,
            .threadID:
            return false
        case .filter,  // Have to assume yes, since we can't know
            .uid,
            .uidAfter,
            .uidBefore:
            return true
        case .and(let keys):
            return keys.contains(where: \.referencesUIDs)
        case .not(let key):
            return key.referencesUIDs
        case .or(let keyA, let keyB):
            return keyA.referencesUIDs || keyB.referencesUIDs
        }
    }

    var referencesFlags: Bool {
        switch self {
        case .all,
            .bcc,
            .before,
            .body,
            .cc,
            .from,
            .sequenceNumbers,
            .new,
            .old,
            .on,
            .recent,
            .since,
            .subject,
            .text,
            .to,
            .header,
            .messageSizeLarger,
            .messageSizeSmaller,
            .older,
            .sentBefore,
            .sentOn,
            .sentSince,
            .uid,
            .uidAfter,
            .uidBefore,
            .younger,
            .emailID,
            .threadID:
            return false
        case .answered,
            .deleted,
            .filter,  // Have to assume yes, since we can't know
            .flagged,
            .keyword,
            .unanswered,
            .undeleted,
            .unflagged,
            .unkeyword,
            .seen,
            .unseen,
            .draft,
            .undraft:
            return true
        case .and(let keys):
            return keys.contains(where: \.referencesFlags)
        case .not(let key):
            return key.referencesFlags
        case .or(let keyA, let keyB):
            return keyA.referencesFlags || keyB.referencesFlags
        case .modificationSequence(let sequence):
            return !sequence.extensions.isEmpty
        }
    }
}

extension Set where Element == PipeliningBehavior {
    func satisfies(_ requirements: Set<PipeliningRequirement>) -> Bool {
        guard !self.contains(.barrier) else { return false }
        return requirements.isEmpty || requirements.allSatisfy { satisfies($0) }
    }

    private func satisfies(_ requirement: PipeliningRequirement) -> Bool {
        switch requirement {
        case .noMailboxCommandsRunning:
            return !self.contains(.changesMailboxSelection) && !self.contains(.dependsOnMailboxSelection)
        case .noUntaggedExpungeResponse:
            return !self.contains(.mayTriggerUntaggedExpunge)
        case .noUIDBasedCommandRunning:
            return !self.contains(.isUIDBased)
        case .noFlagChangesToAnyMessage:
            return !self.contains(.changesFlagsOnAnyMessage)
        case .noFlagReadsFromAnyMessage:
            return !self.contains(.readsFlagsFromAnyMessage)
        case .noFlagChanges(let uids):
            return !self.contains(where: { behavior in
                guard case .changesFlags(let other) = behavior else { return false }
                return !other.set.isDisjoint(with: uids.set)
            })
        case .noFlagReads(let uids):
            return !self.contains(where: { behavior in
                guard case .readsFlags(let other) = behavior else { return false }
                return !other.set.isDisjoint(with: uids.set)
            })
        }
    }
}
