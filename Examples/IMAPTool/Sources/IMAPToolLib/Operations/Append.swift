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

import IMAPCommands
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOIMAP
import NIO
import Synchronization
import System

/// Uploads (`APPEND`s) the given messages into the given mailbox.
///
/// Selects the target mailbox first to receive any updates to it.
func append<ID: Sendable>(
    connection: IMAPConnection,
    createMailbox: SelectCreateOption,
    messages: some AsyncSequence<MessageToAppend<ID>, any Swift.Error>,
    into mailbox: MailboxName
) async throws -> [AppendedMessageInfo<ID>] {
    let info = try await select(
        connection: connection,
        createMailbox: createMailbox,
        mailbox: mailbox
    )

    var result: [AppendedMessageInfo<ID>] = []

    var messageCount = 0
    for try await message in messages {
        messageCount += 1

        let uidAppend = try await append(
            connection: connection,
            message: message,
            into: mailbox
        )
        let uid = singleAppendUIDFromResponse(
            uidAppend: uidAppend,
            uidValidity: info.uidValidity,
            messageCount: messageCount
        )
        result.append(AppendedMessageInfo(messageID: message.messageID, uid: uid, id: message.id))
    }

    writeStatus("Did append \(result.count) message(s)")
    return result
}

/// Metadata about a message that was successfully appended via `APPEND`.
struct AppendedMessageInfo<ID: Sendable>: Sendable {
    /// The RFC 2822 `Message-ID` header value of the appended message.
    var messageID: MessageID
    /// The server-assigned `UID` from the `APPENDUID` response code, or `nil`
    /// if the server did not return one (e.g. no `UIDPLUS` support).
    var uid: UID?
    /// The caller-supplied identifier originally passed in via ``MessageToAppend/id``.
    var id: ID
}

/// Extracts the ``UID`` from the ``ResponseCodeAppend`` (`APPENDUID`, part of `UIDPLUS`).
///
/// This helper assumes a single-message `APPEND`, and returns `nil` if the
/// `APPENDUID` response code contains anything other than exactly one UID.
/// It is therefore not suitable for `MULTIAPPEND` (RFC 3502) responses.
private func singleAppendUIDFromResponse(
    uidAppend: ResponseCodeAppend?,
    uidValidity: UIDValidity,
    messageCount: Int
) -> UID? {
    guard
        let uidAppend
    else {
        writeStatus("[\(messageCount)] Server did not send APPENDUID for message")
        return nil
    }
    guard
        uidAppend.uidValidity == uidValidity
    else {
        writeStatus("[\(messageCount)] UIDVALIDITY in APPENDUID differs from mailbox UIDVALIDITY")
        return nil
    }
    guard
        uidAppend.uids.set.count == 1
    else {
        writeStatus("[\(messageCount)] APPENDUID has \(uidAppend.uids.set.count) UIDs, only expected 1")
        return nil
    }
    let uid = uidAppend.uids.min()
    writeStatus("[\(messageCount)] New message has UID \(uid)")
    return uid
}

/// Sends an `APPEND` for the given message.
func append<ID: Sendable>(
    connection: IMAPConnection,
    message: MessageToAppend<ID>,
    into mailbox: MailboxName
) async throws -> ResponseCodeAppend? {
    let options = AppendOptions(
        flagList: message.flags ?? [],
        internalDate: message.serverMessageDate
    )

    let tagged: TaggedResponse = try await connection.append(
        to: mailbox,
        writeClosure: { writer in
            try await writer.write(
                message: AppendMessage(
                    options: options,
                    data: AppendData(
                        byteCount: message.byteCount
                    )
                )
            ) { writer in
                for await bytes in message.data {
                    writeStatus("Sending \(bytes.readableBytes) message bytes")
                    try await writer.write(messageBytes: bytes)
                }
            }
        },
        readClosure: { tag, responses -> TaggedResponse in
            writeStatus("Appending message \(message.messageID) with tag \(tag)")
            return try await responses.waitForCompletion()
        }
    )
    guard
        case .ok(let text) = tagged.state
    else {
        writeStatus("error: failed to append (\(tagged.state))")
        throw FailedToAppendMessage(state: tagged.state)
    }
    guard
        case .uidAppend(let c) = text.code
    else { return nil }
    return c
}

struct FailedToAppendMessage: Equatable, Swift.Error {
    var state: TaggedResponse.State
}

extension AppendedMessageInfo where ID == FilePath {
    /// The file path the message was loaded from.
    var filePath: FilePath { id }
}

// MARK: MessageToAppend

/// A message to upload via `APPEND`, including its metadata and byte stream.
struct MessageToAppend<ID: Sendable>: Sendable {
    /// The total number of bytes in the message.
    var byteCount: Int
    /// A generic ID for this message, such as a file path or a counter.
    var id: ID
    /// The RFC 2822 `Message-ID` header value.
    var messageID: MessageID
    /// A sequence of bytes that make up the message. The total byte count must match `byteCount`.
    var data: AsyncStream<ByteBuffer>
    /// The flags to set on the message, or `nil` to use defaults.
    var flags: [Flag]?
    /// The internal date to assign to the message on the server.
    var serverMessageDate: ServerMessageDate?
    /// The subject of the message, for display purposes.
    var subject: String?
}

struct UnableToParseMessageID<ID: Sendable>: Swift.Error {
    var id: ID
}

extension MessageToAppend {
    /// Creates a message to append from an already-parsed email message.
    init(
        message other: EmailMessage,
        id: ID
    ) throws {
        guard
            let headers = other.headersOfInterest
        else { throw UnableToParseMessageID(id: id) }
        let dataStream = AsyncStream(
            ByteBuffer.self,
            { continuation in
                continuation.yield(with: .success(ByteBuffer(bytes: other.data)))
                continuation.finish()
            }
        )
        self.init(
            byteCount: other.data.count,
            id: id,
            messageID: headers.messageID,
            data: dataStream,
            flags: nil,
            serverMessageDate: ServerMessageDate(headers.date),
            subject: headers.subject
        )
    }
}

extension ServerMessageDate {
    init?(
        _ other: InternetMessageDate,
    ) {
        guard
            let date = other.parse()
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        let c = calendar.dateComponents(
            [
                .year,
                .month,
                .day,
                .hour,
                .minute,
                .second,
                .timeZone,
            ],
            from: date
        )
        guard
            let year = c.year,
            let month = c.month,
            let day = c.day,
            let hour = c.hour,
            let minute = c.minute,
            let second = c.second,
            let timeZone = c.timeZone,
            let cc = ServerMessageDate.Components(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second,
                timeZoneMinutes: timeZone.secondsFromGMT() / 60
            )
        else { return nil }
        self.init(cc)
    }
}

extension MessageToAppend: AsyncSequence {
    struct AsyncIterator: AsyncIteratorProtocol {
        typealias Element = NIOIMAP.AppendCommand

        var state: State

        enum State {
            case beginMessage(MessageToAppend)
            case messageBytes(AsyncStream<ByteBuffer>.Iterator)
            case endMessage
        }

        mutating func next() async throws -> NIOIMAP.AppendCommand? {
            switch state {
            case .beginMessage(let message):
                state = .messageBytes(message.data.makeAsyncIterator())
                return .beginMessage(message: AppendMessage(message))
            case .messageBytes(var data):
                guard
                    let bytes = await data.next()
                else {
                    state = .endMessage
                    return .endMessage
                }
                state = .messageBytes(data)
                return .messageBytes(bytes)
            case .endMessage:
                return nil
            }
        }

        init(
            message: MessageToAppend
        ) {
            self.state = .beginMessage(message)
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(message: self)
    }
}

extension AppendMessage {
    init<ID: Sendable>(_ message: MessageToAppend<ID>) {
        self.init(
            options: AppendOptions(
                flagList: message.flags ?? [],
                internalDate: message.serverMessageDate,
                extensions: [:]
            ),
            data: AppendData(byteCount: message.byteCount)
        )
    }
}
