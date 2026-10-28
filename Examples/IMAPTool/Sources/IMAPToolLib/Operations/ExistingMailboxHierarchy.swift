//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOIMAP

/// Represents the existing mailbox hierarchy on the server.
struct ExistingMailboxHierarchy: Sendable {
    var paths: [Path]

    struct Path: Sendable {
        var mailboxPath: MailboxPath
        var displayStringComponents: [String]
    }
}

/// A mailbox display name with its associated special-use parameters.
struct MailboxDisplayNameWithSpecialUse: Hashable, Sendable {
    /// The path components of the mailbox display name.
    var namePath: [String]
    /// The `CREATE` parameters including special-use attributes.
    var parameters: [CreateParameter]

    /// Creates a display name with the given path and parameters.
    init(
        namePath: [String],
        parameters: [CreateParameter]
    ) {
        self.namePath = namePath
        self.parameters = parameters
    }
}

/// Describes whether a mailbox already exists or needs creation.
enum NewMailboxAction: Hashable, Sendable {
    /// The mailbox already exists with the given name.
    case alreadyExists(MailboxName)
    /// The mailbox needs creation with the given name and parameters.
    case create(MailboxName, [CreateParameter])
}

extension ExistingMailboxHierarchy {
    /// Returns the mailbox actions needed to create the given display paths.
    ///
    /// The returned array orders parent mailboxes before their nested children.
    func makeMailboxNamesForCreation(
        _ displayNames: [MailboxDisplayNameWithSpecialUse]
    ) throws -> [NewMailboxAction] {
        var existing = self
        let sortedNames =
            displayNames
            .sorted(by: {
                // We sort primarily so that shorter paths come before longer ones; this
                // guarantees parents are created before their children. For two paths of
                // equal length we still need a deterministic tiebreaker (so tests are
                // stable), but we can't sort by lexicographic `String` order — IMAP
                // mailbox names are byte sequences (RFC 3501 §5.1) and a Unicode-aware
                // compare can re-order names that differ only in normalization. XOR of
                // `hashValue`s gives a tiebreaker that doesn't pretend names are strings.
                let lhs = $0.namePath.count
                let rhs = $1.namePath.count
                if lhs < rhs {
                    return true
                } else if rhs < lhs {
                    return false
                }
                return $0.namePath.reduce(into: 0, { $0 = $0 ^ $1.hashValue })
                    < $1.namePath.reduce(into: 0, { $0 = $0 ^ $1.hashValue })
            })
        return try sortedNames.map { name in
            let path = try existing.makeMailboxPath(displayStrings: name.namePath)
            guard
                !existing.paths.contains(where: { $0.mailboxPath.name == path.name })
            else { return .alreadyExists(path.name) }
            existing.insert(mailboxPath: path)
            return .create(path.name, name.parameters)
        }
    }
}

// MARK: -

extension ExistingMailboxHierarchy {
    /// Creates a new hierarchy from the given mailbox paths.
    init(
        mailboxPaths: some Sequence<MailboxPath>
    ) {
        self.paths = []
        for p in mailboxPaths {
            insert(mailboxPath: p)
        }
    }

    mutating func insert(
        mailboxPath new: MailboxPath
    ) {
        guard
            !paths.contains(where: { $0.mailboxPath.name == new.name })
        else { return }
        paths.append(
            Path(
                mailboxPath: new,
                displayStringComponents: new.displayStringComponents(omittingEmptySubsequences: false)
            )
        )
    }

    var inbox: Path? {
        paths.first(where: { $0.mailboxPath.name.isInbox })
    }

    func bestParent(
        displayStrings _displayStrings: [String]
    ) -> Path? {
        let displayStrings =
            _displayStrings
            .map { $0.precomposedStringWithCanonicalMapping }
        guard
            !displayStrings.isEmpty
        else { return nil }
        guard
            2 <= displayStrings.count
        else {
            return nil
        }
        return
            paths
            .filter { path in
                guard
                    path.displayStringComponents.count < displayStrings.count
                else { return false }
                return Array(displayStrings.prefix(path.displayStringComponents.count)) == path.displayStringComponents
            }
            .sorted(by: { $0.displayStringComponents.count > $1.displayStringComponents.count })
            .first
    }

    /// Constructs a `MailboxPath` from the given display-name path components.
    func makeMailboxPath(
        displayStrings _displayStrings: [String]
    ) throws -> MailboxPath {
        let displayStrings =
            _displayStrings
            .map { $0.precomposedStringWithCanonicalMapping }
        guard
            let firstName = displayStrings.first
        else { throw Error.emptyMailboxPath }
        guard
            1 < displayStrings.count
        else {
            return try MailboxPath.makeRootMailbox(
                displayName: firstName,
                pathSeparator: self.inbox?.mailboxPath.pathSeparator
            )
        }

        guard
            let parent = bestParent(
                displayStrings: displayStrings
            )
        else {
            guard
                let pathSeparator = self.inbox?.mailboxPath.pathSeparator
            else { throw Error.noExistingInbox }

            var result = try MailboxPath.makeRootMailbox(
                displayName: firstName,
                pathSeparator: pathSeparator
            )
            for name in displayStrings.suffix(from: 1) {
                result = try result.makeSubMailbox(displayName: name)
            }
            return result
        }

        var result = parent.mailboxPath
        for name in displayStrings.suffix(from: parent.displayStringComponents.count) {
            result = try result.makeSubMailbox(displayName: name)
        }
        return result
    }
}

extension ExistingMailboxHierarchy {
    enum Error: Swift.Error {
        case emptyMailboxPath
        case noExistingInbox
    }
}
