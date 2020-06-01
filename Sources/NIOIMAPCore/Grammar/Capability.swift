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

struct EncodingCapabilities: OptionSet {
    
    static let imap4 = EncodingCapabilities(rawValue: 1 << 0)
    static let imap4rev1 = EncodingCapabilities(rawValue: 1 << 1)
    static let move = EncodingCapabilities(rawValue: 1 << 2)
    static let namespace = EncodingCapabilities(rawValue: 1 << 3)
    static let id = EncodingCapabilities(rawValue: 1 << 4)
    static let binary = EncodingCapabilities(rawValue: 1 << 5)

    var rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(capabilities: [Capability]) {
        self = .init(rawValue: 0)

        let inputs: [(Capability, EncodingCapabilities)] = [
            (.move, .move),
            (.id, .id),
            (.namespace, .namespace),
            (.binary, .binary),
        ]
        for (strCap, cap) in inputs where capabilities.contains(strCap) {
            self.insert(cap)
        }
    }
}

/// IMAPv4 `capability`
public struct Capability: Equatable {
    public var rawValue: String

    public init(_ value: String) {
        self.rawValue = value.uppercased()
    }

    fileprivate init(unchecked: String) {
        self.rawValue = unchecked
    }
}

// MARK: - Convenience Types

extension Capability {
    public struct AuthType: Equatable {
        public static let token = Self(unchecked: "TOKEN")
        public static let plain = Self(unchecked: "PLAIN")
        public static let pToken = Self(unchecked: "PTOKEN")
        public static let weToken = Self(unchecked: "WETOKEN")
        public static let wsToken = Self(unchecked: "WSTOKEN")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct ContextType: Equatable {
        public static let search = Self(unchecked: "SEARCH")
        public static let sort = Self(unchecked: "SORT")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct LiteralType: Equatable {
        public static let plus = Self(unchecked: "+")
        public static let minus = Self(unchecked: "-")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct SortType: Equatable {
        public static let display = Self(unchecked: "DISPLAY")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct ThreadType: Equatable {
        public static let orderedSubject = Self(unchecked: "ORDEREDSUBJECT")
        public static let references = Self(unchecked: "REFERENCES")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct StatusType: Equatable {
        public static let size = Self(unchecked: "SIZE")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct UTF8Type: Equatable {
        public static let accept = Self(unchecked: "ACCEPT")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct RightsType: Equatable {
        public static let tekx = Self(unchecked: "tekx")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public static let acl = Self(unchecked: "ACL")
    public static let annotateExperiment1 = Self(unchecked: "ANNOTATE-EXPERIMENT-1")
    public static let binary = Self(unchecked: "BINARY")
    public static let catenate = Self(unchecked: "CATENATE")
    public static let children = Self(unchecked: "CHILDREN")
    public static let condStore = Self(unchecked: "CONDSTORE")
    public static let createSpecialUse = Self(unchecked: "CREATE-SPECIAL-USE")
    public static let enable = Self(unchecked: "ENABLE")
    public static let esearch = Self(unchecked: "ESEARCH")
    public static let esort = Self(unchecked: "ESORT")
    public static let filters = Self(unchecked: "FILTERS")
    public static let id = Self(unchecked: "ID")
    public static let idle = Self(unchecked: "IDLE")
    public static let imap4rev1 = Self(unchecked: "IMAP4REV1")
    public static let imap4 = Self(unchecked: "IMAP4")
    public static let language = Self(unchecked: "LANGUAGE")
    public static let listStatus = Self(unchecked: "LIST-STATUS")
    public static let loginReferrals = Self(unchecked: "LOGIN-REFERRALS")
    public static let metadata = Self(unchecked: "METADATA")
    public static let move = Self(unchecked: "MOVE")
    public static let multiSearch = Self(unchecked: "MULTISEARCH")
    public static let namespace = Self(unchecked: "NAMESPACE")
    public static let qresync = Self(unchecked: "QRESYNC")
    public static let quota = Self(unchecked: "QUOTA")
    public static let saslIR = Self(unchecked: "SASL-IR")
    public static let searchRes = Self(unchecked: "SEARCHRES")
    public static let specialUse = Self(unchecked: "SPECIAL-USE")
    public static let uidPlus = Self(unchecked: "UIDPLUS")
    public static let unselect = Self(unchecked: "UNSELECT")
    public static let urlPartial = Self(unchecked: "URL-PARTIAL")
    public static let urlAuth = Self(unchecked: "URLAUTH")
    public static let within = Self(unchecked: "WITHIN")

    public static func auth(_ type: AuthType) -> Self {
        Self("AUTH=\(type.rawValue)")
    }

    public static func context(_ type: ContextType) -> Self {
        Self("CONTEXT=\(type.rawValue)")
    }

    public static func literal(_ type: LiteralType) -> Self {
        Self("LITERAL\(type.rawValue)")
    }

    public static func sort(_ type: SortType?) -> Self {
        if let type = type {
            return Self("SORT=\(type.rawValue)")
        } else {
            return Self("SORT")
        }
    }

    public static func utf8(_ type: UTF8Type) -> Self {
        Self("UTF8=\(type.rawValue)")
    }

    public static func thread(_ type: ThreadType) -> Self {
        Self("THREAD=\(type.rawValue)")
    }

    public static func status(_ type: StatusType) -> Self {
        Self("STATUS=\(type.rawValue)")
    }

    public static func rights(_ type: RightsType) -> Self {
        Self("RIGHTS=\(type.rawValue)")
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeCapability(_ capability: Capability) -> Int {
        self.writeString(capability.rawValue)
    }

    @discardableResult mutating func writeCapabilityData(_ data: [Capability]) -> Int {
        self.writeString("CAPABILITY IMAP4 IMAP4rev1") +
            self.writeArray(data, separator: "", parenthesis: false) { (capability, self) -> Int in
                self.writeSpace() +
                    self.writeCapability(capability)
            }
    }
}
