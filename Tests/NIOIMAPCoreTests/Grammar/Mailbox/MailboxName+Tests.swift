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

import NIO
@testable import NIOIMAPCore
import XCTest

class MailboxName_Tests: EncodeTestClass {}

// MARK: - displayStringComponents

extension MailboxName_Tests {
    func testSplitting() {
        let inputs: [(MailboxName, Character, Bool, [String], UInt)] = [
            (.init("ABC"), .init("B"), true, ["A", "C"], #line),
            (.init("ABC"), .init("D"), true, ["ABC"], #line),
            (.init(""), .init("D"), true, [], #line),
            (.init("some/real/mailbox"), .init("/"), true, ["some", "real", "mailbox"], #line),
            (.init("mailbox#test"), .init("#"), true, ["mailbox", "test"], #line),
            (.init("//test1//test2//"), .init("/"), true, ["test1", "test2"], #line),
            (.init("//test1//test2//"), .init("/"), false, ["", "", "test1", "", "test2", "", ""], #line),
        ]
        for (name, character, ommitEmpty, expected, line) in inputs {
            XCTAssertEqual(name.displayStringComponents(separator: character, omittingEmptySubsequences: ommitEmpty), expected, line: line)
        }
    }
}

// MARK: - MailboxPath

extension MailboxName_Tests {
    
    func testInit() {
        let test1 = MailboxPath(name: .init("box"), pathSeparator: nil)
        XCTAssertEqual(test1.name, .init("box"))
        XCTAssertEqual(test1.pathSeparator, nil)
        
        let test2 = MailboxPath(name: .init("box"))
        XCTAssertEqual(test2.name, .init("box"))
        XCTAssertEqual(test2.pathSeparator, nil)
        
        let test3 = MailboxPath(name: .init("box"), pathSeparator: "/")
        XCTAssertEqual(test3.name, .init("box"))
        XCTAssertEqual(test3.pathSeparator, "/")
    }
    
    func testCreateSubMailboxWithDisplayName() {
        let inputs: [(MailboxPath, String, MailboxPath, UInt)] = [
            (
                .init(name: .init("box1"), pathSeparator: nil),
                "box2",
                .init(name: .init("box1box2"), pathSeparator: nil),
                #line
            ),
            (
                .init(name: .init("box1"), pathSeparator: "/"),
                "box2",
                .init(name: .init("box1/box2"), pathSeparator: "/"),
                #line
            )
        ]
        for (path, newName, newPath, line) in inputs {
            XCTAssertEqual(path.createSubMailboxWithDisplayName(newName), newPath, line: line)
        }
    }
    
}
