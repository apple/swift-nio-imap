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

import IMAPCommands
import NIOIMAP
import Testing

/// The public error surface.
///
/// Imports `IMAPCommands` without `@testable` on purpose: an error a caller cannot name is the
/// defect these tests prevent.
@Suite private enum ErrorSurfaceTests {

    // MARK: - Typed throws

    /// Binding `.state` with no cast only compiles under typed throws.
    @Test static func taggedResponseFailureIsTyped() {
        let response = TaggedResponse(tag: "A1", state: .no(ResponseText(text: "nope")))
        do {
            try response.checkOK()
            Issue.record("NO should not pass checkOK()")
        } catch {
            #expect(error.state == .no(ResponseText(text: "nope")))
        }
    }

    @Test static func untaggedStatusFailureIsTyped() {
        let status = UntaggedStatus.bad(ResponseText(text: "bad"))
        do {
            _ = try status.getOK()
            Issue.record("BAD should not pass getOK()")
        } catch {
            #expect(error.status == .bad(ResponseText(text: "bad")))
        }
    }

    @Test static func configurationParseFailureIsTyped() {
        do {
            _ = try IMAPConnection.Configuration(serverText: "not a server", logging: .noLogging)
            Issue.record("'not a server' should not parse")
        } catch {
            #expect(error.description.contains("not a server"))
        }
    }

    @Test(
        arguments: [
            (nil, nil, nil, IMAPCredential.ParseError.noCredentials),
            ("imap://u:p@example.com", nil, "u:p", .conflictingCredentials),
            (nil, "PLAIN", nil, .unableToParseSASL),
            (nil, nil, "no-colon", .unableToParseUsernamePassword),
        ] as [(String?, String?, String?, IMAPCredential.ParseError)]
    )
    static func credentialParseFailureIsTyped(
        url: String?,
        sasl: String?,
        username: String?,
        expected: IMAPCredential.ParseError
    ) {
        do {
            _ = try IMAPCredential(url: url, sasl: sasl, username: username)
            Issue.record("Expected \(expected)")
        } catch {
            #expect(error == expected)
        }
    }

    // MARK: - Nameability

    /// Every case constructible and matchable from outside the module.
    @Test static func everyCaseIsPubliclyMatchable() {
        let errors: [IMAPConnection.Error] = [
            .connectionClosed,
            .connectionFailed(TestFailure()),
            .unexpectedGreeting(.untagged(.id([:]))),
            .missingTaggedResponse,
            .unknownTag("A7"),
        ]

        for error in errors {
            switch error {
            case .connectionClosed, .missingTaggedResponse:
                break
            case .connectionFailed(let underlying):
                #expect(underlying is TestFailure)
            case .unexpectedGreeting(let response):
                #expect(response == .untagged(.id([:])))
            case .unknownTag(let tag):
                #expect(tag == "A7")
            }
        }
    }

    @Test static func descriptionsAreHumanReadable() {
        #expect("\(IMAPConnection.Error.connectionClosed)" == "The connection was closed.")
        #expect("\(IMAPConnection.Error.unknownTag("A7"))".contains("A7"))
        #expect("\(IMAPConnection.Error.connectionFailed(TestFailure()))".contains("TestFailure"))
    }

    /// Catching one case out of an untyped `throws` — the idiom the docs promise.
    @Test static func aSingleCaseCanBeCaughtFromUntypedThrows() {
        func failsUntyped() throws {
            throw IMAPConnection.Error.connectionClosed
        }

        do {
            try failsUntyped()
            Issue.record("Expected a throw")
        } catch IMAPConnection.Error.connectionClosed {
            // Expected.
        } catch {
            Issue.record("Expected .connectionClosed, got \(error)")
        }
    }

    private struct TestFailure: Swift.Error {}
}
