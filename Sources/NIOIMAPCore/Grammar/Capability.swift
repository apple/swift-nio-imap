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
    public struct Capability: Equatable {
        
        public var rawValue: String
        
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }
        
        fileprivate init(uppercased: String) {
            self.rawValue = uppercased
        }
        
    }
    
}

// MARK: - Convenience Types
extension NIOIMAP.Capability {
    
    public struct AuthType: Equatable {
        public static let token = Self(uppercased: "TOKEN")
        public static let plain = Self(uppercased: "PLAIN")
        public static let pToken = Self(uppercased: "PTOKEN")
        public static let weToken = Self(uppercased: "WETOKEN")
        public static let wsToken = Self(uppercased: "WSTOKEN")
        
        public var rawValue: String
        
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }
        
        fileprivate init(uppercased: String) {
            self.rawValue = uppercased
        }
    }
    
    public struct ContextType: Equatable {
        public static let search = Self(uppercased: "SEARCH")
        public static let sort = Self(uppercased: "SORT")
        
        public var rawValue: String
        
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }
        
        fileprivate init(uppercased: String) {
            self.rawValue = uppercased
        }
    }
    
    public struct LiteralType: Equatable {
        public static let plus = Self(uppercased: "+")
        public static let minus = Self(uppercased: "-")
        
        public var rawValue: String
        
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }
        
        fileprivate init(uppercased: String) {
            self.rawValue = uppercased
        }
    }
    
    public struct SortType: Equatable {
        public static let display = Self(uppercased: "DISPLAY")
        
        public var rawValue: String
        
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }
        
        fileprivate init(uppercased: String) {
            self.rawValue = uppercased
        }
    }
    
    public struct ThreadType: Equatable {
        public static let orderedSubject = Self(uppercased: "ORDEREDSUBJECT")
        public static let references = Self(uppercased: "REFERENCES")
        
        public var rawValue: String
        
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }
        
        fileprivate init(uppercased: String) {
            self.rawValue = uppercased
        }
    }
    
    public struct StatusType: Equatable {
        public static let size = Self(uppercased: "SIZE")
        
        public var rawValue: String
        
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }
        
        fileprivate init(uppercased: String) {
            self.rawValue = uppercased
        }
    }
    
    public struct UTF8Type: Equatable {
        public static let accept = Self(uppercased: "ACCEPT")
        
        public var rawValue: String
        
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }
        
        fileprivate init(uppercased: String) {
            self.rawValue = uppercased
        }
    }
    
    public struct  RightsType: Equatable {
        public static let tekx = Self(uppercased: "tekx")
        
        public var rawValue: String
        
        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }
        
        fileprivate init(uppercased: String) {
            self.rawValue = uppercased
        }
    }
    
    public static let acl = Self(uppercased: "ACL")
    public static let annotateExperiment1 = Self(uppercased: "")
    public static let binary = Self(uppercased: "BINARY")
    public static let catenate = Self(uppercased: "CATENATE")
    public static let children = Self(uppercased: "CHILDREN")
    public static let condStore = Self(uppercased: "CONDSTORE")
    public static let createSpecialUse = Self(uppercased: "CREATE-SPECIAL-USE")
    public static let enable = Self(uppercased: "ENABLE")
    public static let esearch = Self(uppercased: "ESEARCH")
    public static let esort = Self(uppercased: "ESORT")
    public static let filters = Self(uppercased: "FILTERS")
    public static let id = Self(uppercased: "ID")
    public static let idle = Self(uppercased: "IDLE")
    public static let IMAP4rev1 = Self(uppercased: "IMAP4rev1")
    public static let language = Self(uppercased: "LANGUAGE")
    public static let listStatus = Self(uppercased: "LIST-STATUS")
    public static let loginReferrals = Self(uppercased: "LOGIN-REFERRALS")
    public static let metadata = Self(uppercased: "METADATA")
    public static let move = Self(uppercased: "MOVE")
    public static let multiSearch = Self(uppercased: "MULTISEARCH")
    public static let namespace = Self(uppercased: "NAMESAPCE")
    public static let qresync = Self(uppercased: "QRESYNC")
    public static let quote = Self(uppercased: "QUOTA")
    public static let saslIR = Self(uppercased: "SASL-IR")
    public static let searchRes = Self(uppercased: "SEARCHRES")
    public static let specialUse = Self(uppercased: "SPECIAL-USE")
    public static let uidPlus = Self(uppercased: "UIDPLUS")
    public static let unselect = Self(uppercased: "UNSELECT")
    public static let urlPartial = Self(uppercased: "URL-PARTIAL")
    public static let urlAuth = Self(uppercased: "URLAUTH")
    public static let within = Self(uppercased: "WITHIN")
    
    public static func auth(_ type: AuthType) -> Self {
        return Self("AUTH=\(type.rawValue)")
    }
    
    public static func context(_ type: ContextType) -> Self {
        return Self("CONTEXT=\(type.rawValue)")
    }
    
    public static func literal(_ type: LiteralType) -> Self {
        return Self("LITERAL\(type.rawValue)")
    }
    
    public static func sort(_ type: SortType?) -> Self {
        if let type = type {
            return Self("SORT=\(type.rawValue)")
        } else {
            return Self("SORT")
        }
    }
    
    public static func utf8(_ type: UTF8Type) -> Self {
        return Self("UTF8=\(type.rawValue)")
    }
    
    public static func thread(_ type: ThreadType) -> Self {
        return Self("THREAD=\(type.rawValue)")
    }
    
    public static func status(_ type: StatusType) -> Self {
        return Self("STATUS=\(type.rawValue)")
    }
    
    public static func rights(_ type: RightsType) -> Self {
        return Self("RIGHTS=\(type.rawValue)")
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
