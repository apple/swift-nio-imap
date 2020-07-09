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

/// IMAPv4 `capability`
public struct Capability: Equatable {
    public var rawValue: String
    private var splitIndex: String.Index?

    public var name: String {
        guard let index = self.splitIndex else {
            return self.rawValue
        }
        return String(self.rawValue[..<index])
    }

    public var value: String? {
        guard var index = self.splitIndex else {
            return nil
        }
        index = self.rawValue.index(after: index)

        return String(self.rawValue[index...])
    }

    public init(_ value: String) {
        self.init(unchecked: value)
    }

    fileprivate init(unchecked: String) {
        self.rawValue = unchecked
        self.splitIndex = self.rawValue.firstIndex(of: "=")
    }
}

// MARK: - Convenience Types

extension Capability {
    public struct AuthKind: Equatable {
        public static let token = Self(unchecked: "TOKEN")
        public static let plain = Self(unchecked: "PLAIN")
        public static let pToken = Self(unchecked: "PTOKEN")
        public static let weToken = Self(unchecked: "WETOKEN")
        public static let wsToken = Self(unchecked: "WSTOKEN")
        public static let gsAPI = Self(unchecked: "GSAPI")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct ContextKind: Equatable {
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

    public struct SortKind: Equatable {
        public static let display = Self(unchecked: "DISPLAY")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct ThreadKind: Equatable {
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

    public struct StatusKind: Equatable {
        public static let size = Self(unchecked: "SIZE")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct UTF8Kind: Equatable {
        public static let accept = Self(unchecked: "ACCEPT")

        public var rawValue: String

        public init(_ value: String) {
            self.rawValue = value.uppercased()
        }

        fileprivate init(unchecked: String) {
            self.rawValue = unchecked
        }
    }

    public struct RightsKind: Equatable {
        public static let tekx = Self(unchecked: "TEKX")

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
    public static let imap4rev1 = Self(unchecked: "IMAP4rev1")
    public static let imap4 = Self(unchecked: "IMAP4")
    public static let language = Self(unchecked: "LANGUAGE")
    public static let listStatus = Self(unchecked: "LIST-STATUS")

    public static let listExtended = Self(unchecked: "LIST-EXTENDED")
    public static let loginDisabled = Self(unchecked: "LOGINDISABLED")
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
    public static let startTLS = Self(unchecked: "STARTTLS")
    public static let uidPlus = Self(unchecked: "UIDPLUS")
    public static let unselect = Self(unchecked: "UNSELECT")
    public static let urlPartial = Self(unchecked: "URL-PARTIAL")
    public static let urlAuth = Self(unchecked: "URLAUTH")
    public static let within = Self(unchecked: "WITHIN")

    /// RFC 7888 LITERAL+
    public static let literalPlus = Self(unchecked: "LITERAL+")

    /// RFC 7888 LITERAL-
    public static let literalMinus = Self(unchecked: "LITERAL-")

    public static func auth(_ type: AuthKind) -> Self {
        Self("AUTH=\(type.rawValue)")
    }

    public static func context(_ type: ContextKind) -> Self {
        Self("CONTEXT=\(type.rawValue)")
    }

    public static func sort(_ type: SortKind?) -> Self {
        if let type = type {
            return Self("SORT=\(type.rawValue)")
        } else {
            return Self("SORT")
        }
    }

    public static func utf8(_ type: UTF8Kind) -> Self {
        Self("UTF8=\(type.rawValue)")
    }

    public static func thread(_ type: ThreadKind) -> Self {
        Self("THREAD=\(type.rawValue)")
    }

    public static func status(_ type: StatusKind) -> Self {
        Self("STATUS=\(type.rawValue)")
    }

    public static func rights(_ type: RightsKind) -> Self {
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
