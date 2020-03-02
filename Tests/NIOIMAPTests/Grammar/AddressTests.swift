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
@testable import NIOIMAP

class AddressTests: EncodeTestClass {

}

// MARK: - Address init
extension AddressTests {
    
    func testInit() {
        let name: NIOIMAP.NString = TestUtilities.createTestByteBuffer(for: "a")
        let adl: NIOIMAP.NString = TestUtilities.createTestByteBuffer(for: "b")
        let mailbox: NIOIMAP.NString = TestUtilities.createTestByteBuffer(for: "c")
        let host: NIOIMAP.NString = TestUtilities.createTestByteBuffer(for: "d")
        let address = NIOIMAP.Address(name: name, adl: adl, mailbox: mailbox, host: host)
        
        XCTAssertEqual(address.name, name)
        XCTAssertEqual(address.adl, adl)
        XCTAssertEqual(address.mailbox, mailbox)
        XCTAssertEqual(address.host, host)
    }
    
}

// MARK: - Address imapEncoded
extension AddressTests {
    
    func testAllNil() {
        let address = NIOIMAP.Address(name: nil, adl: nil, mailbox: nil, host: nil)
        let expected = "(NIL NIL NIL NIL)"
        let size = self.testBuffer.writeAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
    func testNoneNil() {
        let address = NIOIMAP.Address(name: "somename", adl: "someadl", mailbox: "somemailbox", host: "someaddress")
        let expected = "(\"somename\" \"someadl\" \"somemailbox\" \"someaddress\")"
        let size = self.testBuffer.writeAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
    func testMixture() {
        let address = NIOIMAP.Address(name: nil, adl: "some", mailbox: "thing", host: nil)
        let expected = "(NIL \"some\" \"thing\" NIL)"
        let size = self.testBuffer.writeAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
}
