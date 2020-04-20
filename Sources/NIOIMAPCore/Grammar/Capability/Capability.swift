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

import struct NIO.ByteBuffer

extension NIOIMAP {
    
    /// IMAPv4 `capability`
    public struct Capability: Equatable, ExpressibleByStringLiteral {
        
        public typealias StringLiteralType = String
        
        var rawValue: String
        
        public init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
        
    }
    
}

// MARK: - Convenience Types
extension NIOIMAP.Capability {
    
    struct AuthType: Equatable, ExpressibleByStringLiteral {
        static let token = Self(stringLiteral: "TOKEN")
        static let plain = Self(stringLiteral: "PLAIN")
        static let pToken = Self(stringLiteral: "PTOKEN")
        static let weToken = Self(stringLiteral: "WETOKEN")
        static let wsToken = Self(stringLiteral: "WSTOKEN")
        
        var rawValue: String
        
        init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }
    
    struct ContextType: Equatable, ExpressibleByStringLiteral {
        static let search = Self(stringLiteral: "SEARCH")
        static let sort = Self(stringLiteral: "SORT")
        
        var rawValue: String
        
        init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }
    
    struct LiteralType: Equatable, ExpressibleByStringLiteral {
        static let plus = Self(stringLiteral: "+")
        static let minus = Self(stringLiteral: "-")
        
        var rawValue: String
        
        init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }
    
    struct SortType: Equatable, ExpressibleByStringLiteral {
        static let display = Self(stringLiteral: "DISPLAY")
        
        var rawValue: String
        
        init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }
    
    struct ThreadType: Equatable, ExpressibleByStringLiteral {
        static let orderedSubject = Self(stringLiteral: "ORDEREDSUBJECT")
        static let references = Self(stringLiteral: "REFERENCES")
        
        var rawValue: String
        
        init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }
    
    struct StatusType: Equatable, ExpressibleByStringLiteral {
        static let size = Self(stringLiteral: "SIZE")
        
        var rawValue: String
        
        init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }
    
    struct UTF8Type: Equatable, ExpressibleByStringLiteral {
        static let accept = Self(stringLiteral: "ACCEPT")
        
        var rawValue: String
        
        init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }
    
    struct  RightsType: Equatable, ExpressibleByStringLiteral {
        static let tekx = Self(stringLiteral: "tekx")
        
        var rawValue: String
        
        init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }
    
    static let acl = Self(stringLiteral: "ACL")
    static let annotateExperiment1 = Self(stringLiteral: "")
    static let binary = Self(stringLiteral: "BINARY")
    static let catenate = Self(stringLiteral: "CATENATE")
    static let children = Self(stringLiteral: "CHILDREN")
    static let condStore = Self(stringLiteral: "CONDSTORE")
    static let createSpecialUse = Self(stringLiteral: "CREATE-SPECIAL-USE")
    static let enable = Self(stringLiteral: "ENABLE")
    static let esearch = Self(stringLiteral: "ESEARCH")
    static let esort = Self(stringLiteral: "ESORT")
    static let filters = Self(stringLiteral: "FILTERS")
    static let id = Self(stringLiteral: "ID")
    static let idle = Self(stringLiteral: "IDLE")
    static let IMAP4rev1 = Self(stringLiteral: "IMAP4rev1")
    static let language = Self(stringLiteral: "LANGUAGE")
    static let listStatus = Self(stringLiteral: "LIST-STATUS")
    static let loginReferrals = Self(stringLiteral: "LOGIN-REFERRALS")
    static let metadata = Self(stringLiteral: "METADATA")
    static let move = Self(stringLiteral: "MOVE")
    static let multiSearch = Self(stringLiteral: "MULTISEARCH")
    static let namespace = Self(stringLiteral: "NAMESAPCE")
    static let qresync = Self(stringLiteral: "QRESYNC")
    static let quote = Self(stringLiteral: "QUOTA")
    static let saslIR = Self(stringLiteral: "SASL-IR")
    static let searchRes = Self(stringLiteral: "SEARCHRES")
    static let specialUse = Self(stringLiteral: "SPECIAL-USE")
    static let uidPlus = Self(stringLiteral: "UIDPLUS")
    static let unselect = Self(stringLiteral: "UNSELECT")
    static let urlPartial = Self(stringLiteral: "URL-PARTIAL")
    static let urlAuth = Self(stringLiteral: "URLAUTH")
    static let within = Self(stringLiteral: "WITHIN")
    
    static func auth(_ type: AuthType) -> Self {
        return Self(stringLiteral: "AUTH=\(type.rawValue)")
    }
    
    static func context(_ type: ContextType) -> Self {
        return Self(stringLiteral: "CONTEXT=\(type.rawValue)")
    }
    
    static func literal(_ type: LiteralType) -> Self {
        return Self(stringLiteral: "LITERAL\(type.rawValue)")
    }
    
    static func sort(_ type: SortType?) -> Self {
        if let type = type {
            return Self(stringLiteral: "SORT=\(type.rawValue)")
        } else {
            return Self(stringLiteral: "SORT")
        }
    }
    
    static func utf8(_ type: UTF8Type) -> Self {
        return Self(stringLiteral: "UTF8=\(type.rawValue)")
    }
    
    static func thread(_ type: ThreadType) -> Self {
        return Self(stringLiteral: "THREAD=\(type.rawValue)")
    }
    
    static func status(_ type: StatusType) -> Self {
        return Self(stringLiteral: "STATUS=\(type.rawValue)")
    }
    
    static func rights(_ type: RightsType) -> Self {
        return Self(stringLiteral: "RIGHTS=\(type.rawValue)")
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeCapability(_ capability: NIOIMAP.Capability) -> Int {
        self.writeString(capability.rawValue)
    }
    
    @discardableResult mutating func writeCapabilityData(_ data: [NIOIMAP.Capability]) -> Int {
        self.writeString("CAPABILITY IMAP4 IMAP4rev1") +
        self.writeArray(data, separator: "", parenthesis: false) { (capability, self) -> Int in
            self.writeSpace() +
            self.writeCapability(capability)
        }
    }
    
}
