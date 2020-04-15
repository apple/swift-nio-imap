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

import XCTest
import NIO
@testable import IMAPCore
@testable import NIOIMAP

class AddressTests: EncodeTestClass {

}

// MARK: - Address init
extension AddressTests {
    
    func testInit() {
        let name: IMAPCore.NString = "a"
        let adl: IMAPCore.NString = "b"
        let mailbox: IMAPCore.NString = "c"
        let host: IMAPCore.NString = "d"
        let address = IMAPCore.Address(name: name, adl: adl, mailbox: mailbox, host: host)
        
        XCTAssertEqual(address.name, name)
        XCTAssertEqual(address.adl, adl)
        XCTAssertEqual(address.mailbox, mailbox)
        XCTAssertEqual(address.host, host)
    }
    
}

// MARK: - Address imapEncoded
extension AddressTests {
    
    func testAllNil() {
        let address = IMAPCore.Address(name: nil, adl: nil, mailbox: nil, host: nil)
        let expected = "(NIL NIL NIL NIL)"
        let size = self.testBuffer.writeAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
    func testNoneNil() {
        let address = IMAPCore.Address(name: "somename", adl: "someadl", mailbox: "somemailbox", host: "someaddress")
        let expected = "(\"somename\" \"someadl\" \"somemailbox\" \"someaddress\")"
        let size = self.testBuffer.writeAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
    func testMixture() {
        let address = IMAPCore.Address(name: nil, adl: "some", mailbox: "thing", host: nil)
        let expected = "(NIL \"some\" \"thing\" NIL)"
        let size = self.testBuffer.writeAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
}
