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

/// Describes the requirements of a command about to be started.
///
/// IMAP supports command pipelining. But there are restrictions as to what commands can
/// be run at the same time.
///
/// This is described in RFC 3501 section 5.5. “Multiple Commands in Progress”.
///
/// 1. Commands the change the mailbox selection (`SELECT` / `UNSELECT`) can’t be run
/// while commands run that depend on the mailbox selection.
///
/// 2. Changing flags and retrieving flags (of the same messages) at the same time.
///
/// 3. Sequence number based commands can not be started while any command other than
/// `FETCH`, `STORE`, and `SEARCH` is running — since an untagged `EXPUNGE` may happen.
///
/// 4. If the client sends a UID command, it must wait for a completion result
/// response before sending a command with message sequence numbers.
///
/// - Note: This implementation with `PipeliningBehavior` and
///     `PipeliningRequirement` is intentionally _conservative_.  At the extreme case,
///     one may want to only ever run a single command at a time. That way there’d be no
///     inter-dependencies. But by being a bit more smart, certain commands can be allowed
///     to run in parallel. It’s ok for this logic not to be perfect as long as it errs on the
///     side of caution.
public enum PipeliningRequirement: CaseIterable {
    /// No command that depend on the _Selected State_ must be running.
    case noMailboxCommandsRunning
    /// No command besides `FETCH`, `STORE`, and `SEARCH` is running.
    /// This is a requirement for all sequence number based commands.
    case noUntaggedExpungeResponse
    /// No command is running that uses UIDs to specify messages.
    /// This is a requirement for all sequence number based commands.
    case noUIDBasedCommandRunning
    /// No STORE command is running.
    case noFlagChanges
    /// No command is running that retrieves flags.
    case noFlagReads

    // TODO: Add Message metadata read + write
    // TODO: Add mailbox create / delete / subscribe / metadata / quota
}

/// Describes the behavior of a running command.
///
/// See `PipeliningRequirement`.
public enum PipeliningBehavior {
    /// This command changes the _mailbox selection_.
    case changesMailboxSelection
    /// This command depends on the _mailbox selection_.
    case dependsOnMailboxSelection
    /// The server may send an untagged `EXPUNGE` while this command is running.
    ///
    /// This is true for _all_ commands except `FETCH`, `STORE`, and `SEARCH`.
    case mayTriggerUntaggedExpunge
    /// This command uses UIDs to specify messages
    /// — or its a `UID` command (e.g. `UID SEARCH`).
    case isUIDBased
    /// This command is changing flags on messages.
    case changesFlags
    /// This command is querying flags
    case readsFlags
    /// No commands may be sent until this command completes.
    ///
    /// This command may be sent while other commands are running, but it acts as a barrier itself.
    /// The connection will have to wait for it to complete.
    ///
    /// The reason for this is that the server may send zero, one, or multiple continuation
    /// requests as part of responding to this command — until finally sending the command
    /// completion response. If additional commands were sent while such a command was running,
    /// there would be no way to know if a continuation request from the server was asking for
    /// data from the _barrier_ command or from the subsequent commands.
    ///
    /// Notably, the `IDLE` and `AUTHENTICATE` commands are barrier commands.
    case barrier
}

extension CommandStreamPart {
    /// The requirements that this command (part) has wrt. what other commands are allowed
    /// to be running while it runs.
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
        case .extendedsearch(let options):
            return options.key.pipeliningRequirements

        case .fetch(_, let attribtues, _):
            return attribtues.pipeliningRequirements
                .union([.noUntaggedExpungeResponse, .noUIDBasedCommandRunning])
        case .uidFetch(_, let attribtues, _):
            return attribtues.pipeliningRequirements

        case .copy,
             .move:
            return [.noUntaggedExpungeResponse, .noUIDBasedCommandRunning]

        case .uidCopy,
             .uidMove,
             .uidExpunge,
             .expunge:
            return []
            
         case .store(_, _, let flags):
            return flags.silent ?
                [.noUntaggedExpungeResponse, .noUIDBasedCommandRunning, .noFlagReads] :
                [.noUntaggedExpungeResponse, .noUIDBasedCommandRunning, .noFlagReads, .noFlagChanges]
        case .uidStore(_, _, let flags):
            return flags.silent ?
                [.noFlagReads] :
                [.noFlagReads, .noFlagChanges]

        case .capability,
             .logout,
             .noop,
             .check,
             .authenticate,
             .login,
             .starttls,
             .enable,
             .idleStart,
             .id,
             .namespace,

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
        }
    }
}

extension CommandStreamPart {
    /// The behavior of this command (part) wrt. pipelining.
    ///
    /// Certain `PipeliningBehavior` prevent certain (other) commands from running.
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
            return attributes.readsFlags ?
                [.dependsOnMailboxSelection, .readsFlags] :
                [.dependsOnMailboxSelection]
        case .uidFetch(_, let attributes, _):
            return attributes.readsFlags ?
                [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .readsFlags] :
                [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased]

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
        case .extendedsearch(let options):
            // TODO: Figure out how this is supposed to work.
            // https://github.com/apple/swift-nio-imap/issues/572
            return options.key.pipeliningBehavior.union(
                [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge]
            )

        case .store(_, _, let flags):
            return flags.silent ?
                [.dependsOnMailboxSelection, .changesFlags] :
                [.dependsOnMailboxSelection, .changesFlags, .readsFlags]
        case .uidStore(_, _, let flags):
            return flags.silent ?
                [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .changesFlags] :
                [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge, .isUIDBased, .changesFlags, .readsFlags]

        case .noop,
             .check:
            return [.dependsOnMailboxSelection, .mayTriggerUntaggedExpunge]

        case .starttls,
             .logout,
             .authenticate:
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
        }
    }
}

// MARK: -

extension Array where Element == FetchAttribute {
    var pipeliningRequirements: Set<PipeliningRequirement> {
        reduce(into: Set<PipeliningRequirement>()) { $0.formUnion($1.pipeliningRequirements) }
    }
    var readsFlags: Bool {
        contains { $0.readsFlags }
    }
}

extension FetchAttribute {
    var pipeliningRequirements: Set<PipeliningRequirement> {
        var result = Set<PipeliningRequirement>()
        if readsFlags {
            result.insert(.noFlagChanges)
        }
        return result
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
             .gmailLabels:
            return false
        }
    }
}

extension SearchKey {
    var pipeliningRequirements: Set<PipeliningRequirement> {
        var result = Set<PipeliningRequirement>()
        if referencesSequenceNumbers {
            result.insert(.noUntaggedExpungeResponse)
            result.insert(.noUIDBasedCommandRunning)
        }
        if referencesFlags {
            result.insert(.noFlagChanges)
        }
        return result
    }

    var pipeliningBehavior: Set<PipeliningBehavior> {
        var result = Set<PipeliningBehavior>()
        if referencesUIDs {
            result.insert(.isUIDBased)
        }
        if referencesFlags {
            result.insert(.readsFlags)
        }
        return result
    }

    fileprivate var referencesSequenceNumbers: Bool {
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
             .undraft,
             .younger:
            return false
        case .filter, // Have to assume yes, since we can't know
            .sequenceNumbers:
            return true
        case let .and(keys):
            return keys.contains(where: \.referencesSequenceNumbers)
        case .not(let key):
            return key.referencesSequenceNumbers
        case .or(let keyA, let keyB):
            return keyA.referencesSequenceNumbers || keyB.referencesSequenceNumbers
        }
    }

    fileprivate var referencesUIDs: Bool {
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
             .younger:
            return false
        case .filter, // Have to assume yes, since we can't know
             .uid:
             return true
        case let .and(keys):
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
             .younger:
            return false
        case .answered,
             .deleted,
             .filter, // Have to assume yes, since we can't know
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
        case let .and(keys):
            return keys.contains(where: \.referencesFlags)
        case .not(let key):
            return key.referencesFlags
        case .or(let keyA, let keyB):
            return keyA.referencesFlags || keyB.referencesFlags
        case let .modificationSequence(sequence):
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
        case .noFlagChanges:
            return !self.contains(.changesFlags)
        case .noFlagReads:
            return !self.contains(.readsFlags)
        }
    }
}
