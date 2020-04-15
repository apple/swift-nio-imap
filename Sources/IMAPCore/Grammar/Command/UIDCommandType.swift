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



extension IMAPCore {

    public enum UIDCommandType: Equatable {
        case copy([IMAPCore.SequenceRange], Mailbox)
        case move([IMAPCore.SequenceRange], Mailbox)
        case fetch([IMAPCore.SequenceRange], FetchType, [FetchModifier])
        case search(returnOptions: [SearchReturnOption], program: SearchProgram)
        case store([IMAPCore.SequenceRange], [StoreModifier], StoreAttributeFlags)
        case uidExpunge([IMAPCore.SequenceRange])

        init?(commandType: CommandType) {
            switch commandType {
            case .copy(let arg1, let arg2):
                self = .copy(arg1, arg2)
            case .fetch(let arg1, let arg2, let arg3):
                self = .fetch(arg1, arg2, arg3)
            case .store(let arg1, let arg2, let arg3):
                self = .store(arg1, arg2, arg3)
            case .search(returnOptions: let options, program: let program):
                self = .search(returnOptions: options, program: program)
            case .move(let arg1, let arg2):
                self = .move(arg1, arg2)
            default:
                return nil
            }
        }
    }

}
