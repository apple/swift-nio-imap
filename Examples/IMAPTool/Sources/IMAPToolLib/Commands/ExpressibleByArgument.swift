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
import NIOIMAP
import SystemPackage

extension NIOIMAP.MailboxName: ArgumentParser.ExpressibleByArgument {
    public init?(argument: String) {
        do {
            let path = try MailboxPath.makeRootMailbox(displayName: argument)
            self = path.name
        } catch {
            return nil
        }
    }

    public var defaultValueDescription: String { "INBOX" }
}

extension FilePath: ArgumentParser.ExpressibleByArgument {
    public init?(argument: String) {
        self.init(argument)
    }

    public var defaultValueDescription: String { "path" }
}

extension UID: ArgumentParser.ExpressibleByArgument {
    public init?(argument: String) {
        guard
            let v = UInt32(argument),
            let uid = UID(exactly: v)
        else { return nil }
        self = uid
    }

    public var defaultValueDescription: String { "uid" }
}

extension NIOIMAP.MessageID: ArgumentParser.ExpressibleByArgument {
    public init?(argument: String) {
        // Reject empty / whitespace-only input rather than producing an empty "<>" id.
        guard argument.contains(where: { !$0.isWhitespace }) else { return nil }
        // MessageID should be in the format <id@domain> with angle brackets
        // If the user provides it without brackets, add them
        let normalized: String
        switch (argument.hasPrefix("<"), argument.hasSuffix(">")) {
        case (true, true): normalized = argument
        case (false, false): normalized = "<\(argument)>"
        case (false, true), (true, false): return nil
        }
        // Reject a bracketed-but-empty id such as "<>".
        guard normalized.count > 2 else { return nil }
        self.init(normalized)
    }

    public var defaultValueDescription: String { "<message-id>" }
}
