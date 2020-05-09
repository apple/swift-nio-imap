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
            
            // MARK: Login
            (#"tag LOGIN "foo" "bar""# + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            ("tag LOGIN \"\" {0}\r\n" + CRLF, [.command(.init("tag", .login("", "")))]),
            (#"tag LOGIN "foo" "bar""# + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            (#"tag LOGIN foo bar"# + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            
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
