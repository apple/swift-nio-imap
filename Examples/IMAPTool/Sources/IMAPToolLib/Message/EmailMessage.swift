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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOIMAP
import SystemPackage

/// An RFC 5322 email message stored as raw data.
public struct EmailMessage: Hashable, Sendable {
    var data: Data
}

extension EmailMessage {
    init(filePath: FilePath) async throws {
        let input = try await Data(
            asyncContentsOf: filePath
        )
        // This is not entirely clean, but we want to avoid uploading
        // messages with Unix file endings to an IMAP server.
        guard
            EmailMessage.headerIsCRLFClean(input)
        else {
            self = EmailMessage.convertingLineEndings(input)
            return
        }
        self.init(data: input)
    }
}

extension EmailMessage {
    /// Checks whether the message header uses CRLF line endings.
    static func headerIsCRLFClean(_ input: Data) -> Bool {
        let bytes = input.span
        // Only the first four line breaks are inspected, and only near the start.
        let limit = min(bytes.count, 10_000)
        var position = 0
        var lineBreakCount = 0
        while lineBreakCount < 4, position < limit {
            guard let index = bytes.firstIndexOfLineBreak(in: position..<limit) else { break }
            // Every line break in the header has to be a CRLF pair.
            guard
                bytes[index] == 0x0D,
                index + 1 < limit,
                bytes[index + 1] == 0x0A
            else { return false }
            lineBreakCount += 1
            position = index + 2
        }
        return true
    }

    /// Creates an email message by converting all line endings to CRLF.
    static func convertingLineEndings(_ input: Data) -> EmailMessage {
        // Convert to CRLF:
        var output = Data(capacity: input.count)
        let bytes = input.span
        var position = 0
        while let ending = bytes.locateLineEnding(from: position) {
            output.append(bytes.extracting(position..<ending.lowerBound))
            output.append(contentsOf: [0xD, 0xA])
            position = ending.upperBound
        }
        if position < bytes.count {
            output.append(bytes.extracting(position..<bytes.count))
        }
        return EmailMessage(data: output)
    }
}

extension EmailMessage {
    public struct HeadersOfInterest: Hashable, Sendable {
        public var messageID: MessageID
        public var date: InternetMessageDate
        /// The message subject, for display purposes. Not populated by the
        /// default ``MiniMIMEHeaderParser``.
        public var subject: String?

        public init(messageID: MessageID, date: InternetMessageDate, subject: String? = nil) {
            self.messageID = messageID
            self.date = date
            self.subject = subject
        }
    }

    var headersOfInterest: HeadersOfInterest? {
        MessageHeaderParser.current.headersOfInterest(data)
    }
}

// MARK: -

extension Span<UInt8> {
    /// Returns the index of the first CR or LF within `range`, or `nil` if there is none.
    func firstIndexOfLineBreak(in range: Range<Int>) -> Int? {
        for index in range where self[index] == 0x0D || self[index] == 0x0A {
            return index
        }
        return nil
    }

    /// Locates the next line ending at or after `start`, returning the range it
    /// occupies. A CRLF pair is reported as a single two-byte ending.
    func locateLineEnding(from start: Int) -> Range<Int>? {
        guard let lf = firstIndexOfLineEnding(from: start) else { return nil }
        // Include a preceding CR, so that CRLF is treated as one ending.
        if start < lf, self[lf - 1] == 0x0D {
            return (lf - 1)..<(lf + 1)
        }
        return lf..<(lf + 1)
    }

    private func firstIndexOfLineEnding(from start: Int) -> Int? {
        for index in start..<count where self[index] == 0x0A {
            return index
        }
        return nil
    }
}

extension Data {
    /// Appends the bytes of `span`.
    fileprivate mutating func append(_ span: Span<UInt8>) {
        span.withUnsafeBufferPointer { append(contentsOf: $0) }
    }
}
