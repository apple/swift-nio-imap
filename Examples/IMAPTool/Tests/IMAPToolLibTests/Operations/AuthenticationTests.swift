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

import ArgumentParser
@testable import IMAPCommands
import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing

@Suite("Authentication", .timeLimit(.minutes(1)))
private struct AuthenticationTests {
    @Test
    func testLogin() async throws {
        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                .init(
                    command: .capability,
                    untagged: [
                        .capabilityData([.imap4rev1, .imap4, .authenticate(AuthenticationMechanism("FOOBAR")!)])
                    ],
                    completion: .ok(.init(text: "Done"))
                ),
                .init(
                    command: .login(username: "john", password: "secret"),
                    completion: .ok(.init(text: "Welcome to the test server"))
                ),
                .init(
                    command: .capability,
                    untagged: [.capabilityData([.imap4rev1, .imap4, .move])],
                    completion: .ok(.init(text: "Done"))
                ),
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                let result = try await authenticate(
                    connection: connection,
                    greeting: greeting,
                    credential: .username("john", password: "secret"),
                    disableSASLIR: false,
                    forceLogin: false
                )

                #expect(result.responseText == "Welcome to the test server")
                #expect(result.capabilities == [.imap4rev1, .imap4, .move])
            }
        }
    }

    @Test
    func testSASL() async throws {
        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                .init(
                    command: .capability,
                    untagged: [
                        .capabilityData([.imap4rev1, .imap4, .saslIR, .authenticate(.plain)])
                    ],
                    completion: .ok(.init(text: "Capabilities Done"))
                ),
                .init(
                    command: .authenticate(
                        mechanism: .plain,
                        initialResponse: InitialResponse(
                            ByteBuffer(bytes: [
                                0x0, 0x6a, 0x6f, 0x68, 0x6e, 0x0, 0x73, 0x65, 0x63, 0x72, 0x65, 0x74,
                            ])
                        )
                    ),
                    completion: .ok(.init(text: "Welcome to the test server"))
                ),
                .init(
                    command: .capability,
                    untagged: [.capabilityData([.imap4rev1, .imap4, .move])],
                    completion: .ok(.init(text: "Capabilities Done 2"))
                ),
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                let result = try await authenticate(
                    connection: connection,
                    greeting: greeting,
                    credential: .username("john", password: "secret"),
                    disableSASLIR: false,
                    forceLogin: false
                )

                #expect(result.responseText == "Welcome to the test server")
                #expect(result.capabilities == [.imap4rev1, .imap4, .move])
            }
        }
    }

    @Test
    func testSASL_capabilitiesInResponse() async throws {
        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                .init(
                    command: .capability,
                    untagged: [
                        .capabilityData([.imap4rev1, .imap4, .saslIR, .authenticate(.plain)])
                    ],
                    completion: .ok(.init(text: "Capabilities Done"))
                ),
                .init(
                    command: .authenticate(
                        mechanism: .plain,
                        initialResponse: InitialResponse(
                            ByteBuffer(bytes: [
                                0x0, 0x6a, 0x6f, 0x68, 0x6e, 0x0, 0x73, 0x65, 0x63, 0x72, 0x65, 0x74,
                            ])
                        )
                    ),
                    completion: .ok(
                        .init(
                            code: .capability([.imap4rev1, .imap4, .move]),
                            text: "Welcome to the test server"
                        )
                    )
                ),
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                let result = try await authenticate(
                    connection: connection,
                    greeting: greeting,
                    credential: .username("john", password: "secret"),
                    disableSASLIR: false,
                    forceLogin: false
                )

                #expect(result.responseText == "Welcome to the test server")
                #expect(result.capabilities == [.imap4rev1, .imap4, .move])
            }
        }
    }

    @Test
    func testSASL_capabilitiesInGreetingAndResponse() async throws {
        await TestServer.runSingleConnectionServer(
            greeting: .ok(
                .init(
                    code: .capability([.imap4rev1, .imap4, .saslIR, .authenticate(.plain)]),
                    text: "Hello"
                )
            ),
            expectedCommands: [
                .init(
                    command: .authenticate(
                        mechanism: .plain,
                        initialResponse: InitialResponse(
                            ByteBuffer(bytes: [
                                0x0, 0x6a, 0x6f, 0x68, 0x6e, 0x0, 0x73, 0x65, 0x63, 0x72, 0x65, 0x74,
                            ])
                        )
                    ),
                    completion: .ok(
                        .init(
                            code: .capability([.imap4rev1, .imap4, .move]),
                            text: "Welcome to the test server"
                        )
                    )
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                let result = try await authenticate(
                    connection: connection,
                    greeting: greeting,
                    credential: .username("john", password: "secret"),
                    disableSASLIR: false,
                    forceLogin: false
                )

                #expect(result.responseText == "Welcome to the test server")
                #expect(result.capabilities == [.imap4rev1, .imap4, .move])
            }
        }
    }

    @Test
    func testSASL_noIR() async throws {
        // If the server doesn’t support SASL-IR, we’ll have to wait
        // for an authentication challenge and then send the IR
        // in the continuation response:
        await TestServer.runSingleConnectionServer(
            greeting: .ok(
                .init(
                    code: .capability([.imap4rev1, .imap4, .authenticate(.plain)]),
                    text: "Hello"
                )
            ),
            expectedCommands: [
                .init(
                    part: .command(
                        .authenticate(
                            mechanism: .plain,
                            initialResponse: nil
                        )
                    ),
                    responses: [
                        .authenticationChallenge(ByteBuffer(string: "Go ahead"))
                    ],
                    completion: nil
                ),
                .init(
                    part: .continuationResponse(
                        ByteBuffer(bytes: [
                            0x0, 0x6a, 0x6f, 0x68, 0x6e, 0x0, 0x73, 0x65, 0x63, 0x72, 0x65, 0x74,
                        ])
                    ),
                    responses: [],
                    completion: .ok(
                        .init(
                            code: .capability([.imap4rev1, .imap4, .move]),
                            text: "Welcome to the test server"
                        )
                    )
                ),
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                let result = try await authenticate(
                    connection: connection,
                    greeting: greeting,
                    credential: .username("john", password: "secret"),
                    disableSASLIR: false,
                    forceLogin: false
                )

                #expect(result.responseText == "Welcome to the test server")
                #expect(result.capabilities == [.imap4rev1, .imap4, .move])
            }
        }
    }

    @Test
    func testThatItFailsWhenTheServerDoesNotReturnCapabilities() async throws {
        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                .init(
                    command: .capability,
                    untagged: [],  // <--- no capabilities
                    completion: .ok(.init(text: "Done"))
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                _ = await #expect(
                    throws: AuthenticationError(message: "Server did not return Capabilities")
                ) {
                    try await authenticate(
                        connection: connection,
                        greeting: greeting,
                        credential: .username("john", password: "secret"),
                        disableSASLIR: false,
                        forceLogin: false
                    )
                }
            }
        }
    }

    @Test
    func login() async throws {
        // If the server doesn’t support SASL PLAIN, we’ll have
        // use LOGIN
        await TestServer.runSingleConnectionServer(
            greeting: .ok(
                .init(
                    code: .capability([.imap4rev1, .imap4]),
                    text: "Hello"
                )
            ),
            expectedCommands: [
                .init(
                    part: .command(.login(username: "john", password: "secret")),
                    responses: [],
                    completion: .ok(
                        .init(
                            code: .capability([.imap4rev1, .imap4, .move]),
                            text: "Welcome to the test server"
                        )
                    )
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                let result = try await authenticate(
                    connection: connection,
                    greeting: greeting,
                    credential: .username("john", password: "secret"),
                    disableSASLIR: false,
                    forceLogin: false
                )

                #expect(result.responseText == "Welcome to the test server")
                #expect(result.capabilities == [.imap4rev1, .imap4, .move])
            }
        }
    }
}
