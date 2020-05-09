//
//  File.swift
//  
//
//  Created by David Evans on 09/05/2020.
//

import Foundation
import XCTest

import NIOIMAPCore
import NIOIMAP
import NIO
import NIOTestUtils

final class B2MV_Tests: XCTestCase {
 
    
    
}


// MARK: - Command
extension B2MV_Tests {

    func testCommand() {
        let inoutPairs: [(String, [NIOIMAP.CommandStream])] = [
            
            // MARK: Capability
            ("tag CAPABILITY" + CRLF, [.command(.init("tag", .capability))]),
            
            // MARK: Noop
            ("tag NOOP" + CRLF, [.command(.init("tag", .noop))]),
            
            // MARK: Logout
            ("tag LOGOUT" + CRLF, [.command(.init("tag", .logout))]),
            
            // MARK: StartTLS
            ("tag STARTTLS" + CRLF, [.command(.init("tag", .starttls))]),
            
            // MARK: Authenticate
            // this tests causes nothing but trouble
            // ("tag AUTHENTICATE PLAIN" + CRLF, [.command(.init("tag", .authenticate("PLAIN", nil, [])))]),
            
            // MARK: Login
            (#"tag LOGIN "foo" "bar""# + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            ("tag LOGIN \"\" {0}\r\n" + CRLF, [.command(.init("tag", .login("", "")))]),
            (#"tag LOGIN "foo" "bar""# + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            (#"tag LOGIN foo bar"# + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            
            // MARK: Select
            ("tag SELECT box1" + CRLF, [.command(.init("tag", .select(.init("box1"), [])))]),
            ("tag SELECT \"box2\"" + CRLF, [.command(.init("tag", .select(.init("box2"), [])))]),
            ("tag SELECT {4}\r\nbox3" + CRLF, [.command(.init("tag", .select(.init("box3"), [])))]),
            ("tag SELECT box4 (k1 1 k2 2)" + CRLF, [.command(.init("tag", .select(.init("box4"), [.name("k1", value: .simple(.sequence([1]))), .name("k2", value: .simple(.sequence([1])))])))]),

            // MARK: Examine
            ("tag EXAMINE box1" + CRLF, [.command(.init("tag", .examine(.init("box1"), [])))]),
            ("tag EXAMINE \"box2\"" + CRLF, [.command(.init("tag", .examine(.init("box2"), [])))]),
            ("tag EXAMINE {4}\r\nbox3" + CRLF, [.command(.init("tag", .examine(.init("box3"), [])))]),
            ("tag EXAMINE box4 (k3 1 k4 2)" + CRLF, [.command(.init("tag", .examine(.init("box1"), [.name("k3", value: .simple(.sequence([1]))), .name("k4", value: .simple(.sequence([1])))])))]),
            
            // MARK: Rename
            (#"tag RENAME "foo" "bar""# + CRLF, [.command(NIOIMAP.TaggedCommand("tag", .rename(from: NIOIMAP.MailboxName("foo"), to: NIOIMAP.MailboxName("bar"), params: [])))]),
            (#"tag RENAME InBoX "inBOX""# + CRLF, [.command(NIOIMAP.TaggedCommand("tag", .rename(from: .inbox, to: .inbox, params: [])))]),
            ("tag RENAME {1}\r\n1 {1}\r\n2" + CRLF, [.command(NIOIMAP.TaggedCommand("tag", .rename(from: NIOIMAP.MailboxName("1"), to: NIOIMAP.MailboxName("2"), params: [])))]),
            
        ]
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs,
                decoderFactory: { () -> NIOIMAP.CommandDecoder in
                    NIOIMAP.CommandDecoder(autoSendContinuations: false)
                }
            )
        } catch {
            switch error as? ByteToMessageDecoderVerifier.VerificationError<NIOIMAP.CommandStream> {
            case .some(let error):
                for input in error.inputs {
                    print(" input: \(String(decoding: input.readableBytesView, as: Unicode.UTF8.self))")
                }
                switch error.errorCode {
                case .underProduction(let command):
                    print("UNDER PRODUCTION")
                    print(command)
                case .wrongProduction(actual: let actualCommand, expected: let expectedCommand):
                    print("WRONG PRODUCTION")
                    print(actualCommand)
                    print(expectedCommand)
                default:
                    print(error)
                }
            case .none:
                ()
            }
            XCTFail("unhandled error: \(error)")
        }
    }
    
}

// MARK: - Response
extension B2MV_Tests {
    
    func testResponse() {
        
    }
    
}
