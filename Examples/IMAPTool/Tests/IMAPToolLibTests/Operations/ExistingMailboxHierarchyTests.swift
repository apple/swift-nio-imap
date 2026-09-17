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

@testable import IMAPToolLib
import Testing
import NIOIMAP

@Suite
private enum ExistingMailboxHierarchyTests {
    @Test
    static func makeMailboxPath_basics() throws {
        let sut = try ExistingMailboxHierarchy(
            mailboxPaths: [
                .init(
                    name: .inbox,
                    pathSeparator: "/"
                ),
                .init(
                    name: "a/b",
                    pathSeparator: "/"
                ),
                .init(
                    name: "a",
                    pathSeparator: "/"
                ),
            ]
        )

        #expect(sut.bestParent(displayStrings: ["c"]) == nil)
        #expect(try sut.makeMailboxPath(displayStrings: ["c"]) == MailboxPath(name: "c", pathSeparator: "/"))

        #expect(sut.bestParent(displayStrings: ["a", "c"])?.mailboxPath.name == "a")
        #expect(try sut.makeMailboxPath(displayStrings: ["a", "c"]) == MailboxPath(name: "a/c", pathSeparator: "/"))

        #expect(sut.bestParent(displayStrings: ["a", "b", "c"])?.mailboxPath.name == "a/b")
        #expect(
            try sut.makeMailboxPath(displayStrings: ["a", "b", "c"]) == MailboxPath(name: "a/b/c", pathSeparator: "/")
        )

        #expect(sut.bestParent(displayStrings: ["foo", "bar"]) == nil)
        #expect(
            try sut.makeMailboxPath(displayStrings: ["foo", "bar"]) == MailboxPath(name: "foo/bar", pathSeparator: "/")
        )
    }

    @Test
    static func makeMailboxPath_differentPathSeparators() throws {
        let sut = try ExistingMailboxHierarchy(
            mailboxPaths: [
                .init(
                    name: .inbox,
                    pathSeparator: "/"
                ),
                .init(
                    name: "a",
                    pathSeparator: "."
                ),
                .init(
                    name: "b",
                    pathSeparator: "-"
                ),
            ]
        )

        #expect(sut.bestParent(displayStrings: ["c"]) == nil)
        #expect(try sut.makeMailboxPath(displayStrings: ["c"]) == MailboxPath(name: "c", pathSeparator: "/"))

        #expect(sut.bestParent(displayStrings: ["a", "c"])?.mailboxPath.name == "a")
        #expect(try sut.makeMailboxPath(displayStrings: ["a", "c"]) == MailboxPath(name: "a.c", pathSeparator: "."))

        #expect(sut.bestParent(displayStrings: ["b", "c"])?.mailboxPath.name == "b")
        #expect(try sut.makeMailboxPath(displayStrings: ["b", "c"]) == MailboxPath(name: "b-c", pathSeparator: "-"))

        #expect(sut.bestParent(displayStrings: ["a", "c", "d"])?.mailboxPath.name == "a")
        #expect(
            try sut.makeMailboxPath(displayStrings: ["a", "c", "d"]) == MailboxPath(name: "a.c.d", pathSeparator: ".")
        )
    }

    @Test
    static func makeMailboxNamesForCreation() throws {
        let sut = try ExistingMailboxHierarchy(
            mailboxPaths: [
                .init(
                    name: .inbox,
                    pathSeparator: "/"
                ),
                .init(
                    name: "a",
                    pathSeparator: "/"
                ),
                .init(
                    name: "b",
                    pathSeparator: "."
                ),
            ]
        )

        let result = try sut.makeMailboxNamesForCreation([
            .init(namePath: ["a", "b", "c"], parameters: []),
            .init(namePath: ["a", "b"], parameters: []),
            .init(namePath: ["b", "a"], parameters: []),
        ])
        #expect(
            result == [
                .create("a/b", []),
                .create("b.a", []),
                .create("a/b/c", []),
            ]
        )
    }

    @Test
    static func makeMailboxNamesForCreation_withExisting() throws {
        let sut = try ExistingMailboxHierarchy(
            mailboxPaths: [
                .init(
                    name: .inbox,
                    pathSeparator: "/"
                ),
                .init(
                    name: "a",
                    pathSeparator: "/"
                ),
                .init(
                    name: "a/b",
                    pathSeparator: "/"
                ),
                .init(
                    name: "b",
                    pathSeparator: "."
                ),
            ]
        )

        let result = try sut.makeMailboxNamesForCreation([
            .init(namePath: ["a", "b", "c"], parameters: []),
            .init(namePath: ["a", "b"], parameters: []),
            .init(namePath: ["b", "a"], parameters: []),
            .init(namePath: ["b", "a"], parameters: []),
        ])
        #expect(
            result == [
                .alreadyExists("a/b"),
                .create("b.a", []),
                .alreadyExists("b.a"),
                .create("a/b/c", []),
            ]
        )
    }
}
