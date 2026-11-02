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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#elseif canImport(Android)
import Android
#else
let badOS = { fatalError("unsupported OS") }()
#endif

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView
import struct OrderedCollections.OrderedDictionary

extension GrammarParser {
    func parseMessageAttributeBody(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> MessageAttribute.BodyStructure {
        func parseValid(buffer: inout ParseInput, tracker: StackTracker) throws -> MessageAttribute.BodyStructure {
            try .valid(self.parseBody(buffer: &buffer, tracker: tracker))
        }

        do {
            return try .valid(self.parseBody(buffer: &buffer, tracker: tracker))
        } catch {
            // Re-try parsing as an invalid body response.
            // This may throw either IncompleteMessage or a “real” parse error.
            return try parseInvalidBody(buffer: &buffer, tracker: tracker)
        }
    }

    // body            = "(" (body-type-1part / body-type-mpart) ")"
    func parseBody(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure {
        func parseBody_singlePart(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure {
            try buffer.matchFixed("(")
            let part = try self.parseBodyKindSinglePart(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return .singlepart(part)
        }

        func parseBody_multiPart(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure {
            try buffer.matchFixed("(")
            let part = try self.parseBodyKindMultipart(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return .multipart(part)
        }

        return try buffer.parseOneOf(
            { try parseBody_singlePart(buffer: &$0, tracker: $1) },
            { try parseBody_multiPart(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    /// Effectively _skips_ the `body` data.
    func parseInvalidBody(buffer: inout ParseInput, tracker: StackTracker) throws -> MessageAttribute.BodyStructure {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            // We’re basically just counting `(` vs. `)`, but we need to skip
            // * quoted strings
            // * literals

            try buffer.matchFixed("(")
            var parenthesisCount = 1

            var byteCount = 0
            let maximumByteCount = 200_000

            enum State {
                case normal
                case quoted
            }
            var state = State.normal

            while true {
                guard
                    byteCount < maximumByteCount
                else { throw ParserError(hint: "Run-away body structure") }
                switch state {
                case .normal:
                    // Skip anything except for
                    // 7b `{` -> literal
                    // 28 `(` / 29 `)` -> count
                    // 22 `"` -> quoted string
                    byteCount +=
                        try buffer.parseZeroOrMoreCharacters(
                            where: {
                                $0 != 0x7B && $0 != 0x28 && $0 != 0x29 && $0 != 0x22
                            }
                        ).count + 1
                    let byte = try buffer.readByte()
                    switch byte {
                    case 0x7B:
                        let literalCount: Int
                        do {
                            literalCount = try parseLiteralLength(
                                buffer: &buffer,
                                tracker: tracker,
                                maxLength: max(0, maximumByteCount - byteCount)
                            )
                        } catch let error as IncompleteMessage {
                            // The length may simply not have arrived yet, e.g. a read ending in `{1`.
                            throw error
                        } catch {
                            throw ParserError(hint: "Run-away literal in body structure")
                        }
                        try buffer.matchFixed("}")
                        try buffer.matchNewline()
                        _ = try buffer.extractBytes(length: literalCount)
                    case 0x28:
                        parenthesisCount += 1
                    case 0x29:
                        parenthesisCount -= 1
                        guard
                            parenthesisCount > 0
                        else { return .invalid }
                    case 0x22:
                        state = .quoted
                    default:
                        throw ParserError(hint: "Unexpected byte \(byte) in body structure")
                    }
                case .quoted:
                    // Skip anything except for
                    // 5c `\` -> escaped
                    // 22 `"` -> quoted string
                    byteCount +=
                        try buffer.parseZeroOrMoreCharacters(
                            where: {
                                $0 != 0x5C && $0 != 0x22
                            }
                        ).count + 1
                    let byte = try buffer.readByte()
                    switch byte {
                    case 0x5C:
                        _ = try buffer.readByte()
                        byteCount += 1
                    case 0x22:
                        state = .normal
                    default:
                        throw ParserError(hint: "Unexpected byte \(byte) inside quoted in body structure")
                    }
                }
            }
        }
    }

    // body-extension  = nstring / number /
    //                    "(" body-extension *(SP body-extension) ")"
    func parseBodyExtension(buffer: inout ParseInput, tracker: StackTracker) throws -> [BodyExtension] {
        func parseBodyExtensionKind_string(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyExtension {
            try .string(self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionKind_number(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyExtension {
            try .number(self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionKind(
            buffer: inout ParseInput,
            tracker: StackTracker,
            into array: inout [BodyExtension]
        ) throws {
            let element = try buffer.parseOneOf(
                { try parseBodyExtensionKind_string(buffer: &$0, tracker: $1) },
                { try parseBodyExtensionKind_number(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
            array.append(element)
        }

        func parseBodyExtension_array(
            buffer: inout ParseInput,
            tracker: StackTracker,
            into array: inout [BodyExtension]
        ) throws {
            try buffer.matchFixed("(")
            try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
            var save = buffer
            do {
                while true {
                    save = buffer
                    try buffer.parseSpaces()
                    try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
                }
            } catch is ParserError {
                buffer = save
            }
            try buffer.matchFixed(")")
        }

        func parseBodyExtension_arrayOrStatic(
            buffer: inout ParseInput,
            tracker: StackTracker,
            into array: inout [BodyExtension]
        ) throws {
            let save = buffer
            do {
                try parseBodyExtensionKind(buffer: &buffer, tracker: tracker, into: &array)
            } catch is ParserError {
                buffer = save
                try parseBodyExtension_array(buffer: &buffer, tracker: tracker, into: &array)
            }
        }

        var array = [BodyExtension]()
        try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
        return array
    }

    // body-ext-1part  = body-fld-md5 [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    func parseBodyExtSinglePart(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> BodyStructure.Singlepart.Extension {
        try buffer.composite(tracker: tracker) { buffer, tracker -> BodyStructure.Singlepart.Extension in
            let md5 = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap {
                (buffer: [UInt8]) -> String in
                try decodeUTF8(buffer)
            }
            let dsp = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) -> BodyStructure.DispositionAndLanguage in
                try buffer.parseSpaces()
                return try self.parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Singlepart.Extension(digest: md5, dispositionAndLanguage: dsp)
        }
    }

    // body-ext-mpart  = body-fld-param [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    func parseBodyExtMpart(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure.Multipart.Extension
    {
        try buffer.composite(tracker: tracker) { buffer, tracker -> BodyStructure.Multipart.Extension in
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            let dsp = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) -> BodyStructure.DispositionAndLanguage in
                try buffer.parseSpaces()
                return try self.parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Multipart.Extension(parameters: param, dispositionAndLanguage: dsp)
        }
    }

    // body-fields     = body-fld-param SP body-fld-id SP body-fld-desc SP
    //                   body-fld-enc SP body-fld-octets
    func parseBodyFields(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure.Fields {
        try buffer.composite(tracker: tracker) { buffer, tracker -> BodyStructure.Fields in
            let fieldParam = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let fieldID = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap {
                (buffer: [UInt8]) -> String in
                try decodeUTF8(buffer)
            }
            try buffer.parseSpaces()
            let fieldDescription = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap {
                (buffer: [UInt8]) -> String in
                try decodeUTF8(buffer)
            }
            try buffer.parseSpaces()
            let encoding = try self.parseBodyEncoding(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let fieldOctets = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return BodyStructure.Fields(
                parameters: fieldParam,
                id: fieldID,
                contentDescription: fieldDescription,
                encoding: encoding,
                octetCount: fieldOctets
            )
        }
    }

    // body-fld-dsp    = "(" string SP body-fld-param ")" / nil
    func parseBodyFieldDsp(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure.Disposition? {
        func parseBodyFieldDsp_nil(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Disposition? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseBodyFieldDsp_some(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Disposition? {
            try buffer.matchFixed("(")
            let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
            let string = try decodeUTF8(parsed)
            let dispositionKind = BodyStructure.DispositionKind(rawValue: string)
            try buffer.parseSpaces()
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return BodyStructure.Disposition(kind: dispositionKind, parameters: param)
        }

        return try buffer.parseOneOf(
            { try parseBodyFieldDsp_nil(buffer: &$0, tracker: $1) },
            { try parseBodyFieldDsp_some(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // body-fld-enc    = (DQUOTE ("7BIT" / "8BIT" / "BINARY" / "BASE64"/
    //                   "QUOTED-PRINTABLE") DQUOTE) / string (or NIL because of some implementations)
    func parseBodyEncoding(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure.Encoding? {
        func parseBodyEncoding_string(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Encoding? {
            let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
            return try .init(decodeUTF8(parsed))
        }

        func parseBodyEncoding_option(
            _ option: String,
            result: BodyStructure.Encoding,
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Encoding? {
            try buffer.matchFixed("\"")
            try buffer.matchFixed(option)
            try buffer.matchFixed("\"")
            return result
        }

        func parseBodyEncoding_7bit(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure.Encoding? {
            try parseBodyEncoding_option("7BIT", result: .sevenBit, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_8bit(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure.Encoding? {
            try parseBodyEncoding_option("8BIT", result: .eightBit, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_binary(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Encoding? {
            try parseBodyEncoding_option("BINARY", result: .binary, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_base64(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Encoding? {
            try parseBodyEncoding_option("BASE64", result: .base64, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_quotePrintable(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Encoding? {
            try parseBodyEncoding_option(
                "QUOTED-PRINTABLE",
                result: .quotedPrintable,
                buffer: &buffer,
                tracker: tracker
            )
        }

        func parseBodyEncoding_nil(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure.Encoding? {
            try parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try buffer.parseOneOf(
            [
                { try parseBodyEncoding_7bit(buffer: &$0, tracker: $1) },
                { try parseBodyEncoding_8bit(buffer: &$0, tracker: $1) },
                { try parseBodyEncoding_binary(buffer: &$0, tracker: $1) },
                { try parseBodyEncoding_base64(buffer: &$0, tracker: $1) },
                { try parseBodyEncoding_quotePrintable(buffer: &$0, tracker: $1) },
                { try parseBodyEncoding_string(buffer: &$0, tracker: $1) },
                { try parseBodyEncoding_nil(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // body-fld-lang   = nstring / "(" string *(SP string) ")"
    func parseBodyFieldLanguage(buffer: inout ParseInput, tracker: StackTracker) throws -> [String] {
        func parseBodyFieldLanguage_single(buffer: inout ParseInput, tracker: StackTracker) throws -> [String] {
            guard let parsed = try self.parseNString(buffer: &buffer, tracker: tracker) else {
                return []
            }
            return try [decodeUTF8(parsed)]
        }

        func parseBodyFieldLanguage_multiple(buffer: inout ParseInput, tracker: StackTracker) throws -> [String] {
            try buffer.matchFixed("(")

            let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
            var array = try [decodeUTF8(parsed)]

            try buffer.parseZeroOrMore(into: &array, tracker: tracker) { (buffer, tracker) -> String in
                try buffer.parseSpaces()

                let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
                return try decodeUTF8(parsed)
            }
            try buffer.matchFixed(")")
            return array
        }

        return try buffer.parseOneOf(
            { try parseBodyFieldLanguage_multiple(buffer: &$0, tracker: $1) },
            { try parseBodyFieldLanguage_single(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // body-fld-param  = "(" string SP string *(SP string SP string) ")" / nil
    func parseBodyFieldParam(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> OrderedDictionary<String, String> {
        func parseBodyFieldParam_nil(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> OrderedDictionary<String, String> {
            try parseNil(buffer: &buffer, tracker: tracker)
            return [:]
        }

        func parseBodyFieldParam_singlePair(buffer: inout ParseInput, tracker: StackTracker) throws -> (String, String)
        {
            let parsedField = try parseString(buffer: &buffer, tracker: tracker)
            let field = try decodeUTF8(parsedField)
            try buffer.parseSpaces()
            let parsedValue = try parseStringAllowingNonASCII(buffer: &buffer, tracker: tracker)
            let value = String(bestEffortDecodingUTF8Bytes: parsedValue)
            return (field, value)
        }

        func parseBodyFieldParam_pairs(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> OrderedDictionary<String, String> {
            try buffer.matchFixed("(")
            var kvs = OrderedDictionary<String, String>()
            let keyValue = try parseBodyFieldParam_singlePair(buffer: &buffer, tracker: tracker)
            kvs[keyValue.0] = keyValue.1
            try buffer.parseZeroOrMore(into: &kvs, tracker: tracker) {
                (buffer, tracker) -> (String, String) in
                try buffer.parseSpaces()
                return try parseBodyFieldParam_singlePair(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return kvs
        }

        return try buffer.parseOneOf(
            { try parseBodyFieldParam_pairs(buffer: &$0, tracker: $1) },
            { try parseBodyFieldParam_nil(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // body-type-1part = (body-type-basic / body-type-msg / body-type-text)
    //                   [SP body-ext-1part]
    func parseBodyKindSinglePart(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure.Singlepart {
        func parseBodyKindSinglePart_extension(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Singlepart.Extension? {
            try buffer.parseOptional(tracker: tracker) { (buffer, tracker) in
                try buffer.parseSpaces()
                return try self.parseBodyExtSinglePart(buffer: &buffer, tracker: tracker)
            }
        }

        func parseBodyKindSinglePart_basic(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Singlepart {
            let media = try self.parseMediaType(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(kind: .basic(media), fields: fields, extension: ext)
        }

        func parseBodyKindSinglePart_message(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Singlepart {
            let mediaMessage = try self.parseMediaMessage(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let envelope = try self.parseEnvelope(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let fieldLines = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let message = BodyStructure.Singlepart.Message(
                message: mediaMessage,
                envelope: envelope,
                body: body,
                lineCount: fieldLines
            )
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(kind: .message(message), fields: fields, extension: ext)
        }

        func parseBodyKindSinglePart_text(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> BodyStructure.Singlepart {
            let media = try self.parseMediaText(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let fieldLines = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let text = BodyStructure.Singlepart.Text(mediaSubtype: media, lineCount: fieldLines)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(kind: .text(text), fields: fields, extension: ext)
        }

        return try buffer.parseOneOf(
            { try parseBodyKindSinglePart_message(buffer: &$0, tracker: $1) },
            { try parseBodyKindSinglePart_text(buffer: &$0, tracker: $1) },
            { try parseBodyKindSinglePart_basic(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // body-type-mpart = 1*body SP media-subtype
    //                   [SP body-ext-mpart]
    func parseBodyKindMultipart(buffer: inout ParseInput, tracker: StackTracker) throws -> BodyStructure.Multipart {
        try buffer.composite(tracker: tracker) { buffer, tracker -> BodyStructure.Multipart in
            let parts = try buffer.parseOneOrMore(tracker: tracker) { (buffer, tracker) -> BodyStructure in
                try? buffer.parseSpaces()
                return try self.parseBody(buffer: &buffer, tracker: tracker)
            }
            try buffer.parseSpaces()
            let media = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            let ext = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) -> BodyStructure.Multipart.Extension in
                try buffer.parseSpaces()
                return try self.parseBodyExtMpart(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Multipart(parts: parts, mediaSubtype: media, extension: ext)
        }
    }

    func parseBodyLocationExtension(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> BodyStructure.LocationAndExtensions {
        let fieldLocation = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap {
            (buffer: [UInt8]) -> String in
            try decodeUTF8(buffer)
        }
        let extensions = try buffer.parseZeroOrMore(tracker: tracker) {
            (buffer, tracker) -> [BodyExtension] in
            try buffer.parseSpaces()
            return try self.parseBodyExtension(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.LocationAndExtensions(location: fieldLocation, extensions: extensions.reduce([], +))
    }

    func parseBodyLanguageLocation(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> BodyStructure.LanguageLocation {
        let fieldLanguage = try self.parseBodyFieldLanguage(buffer: &buffer, tracker: tracker)
        let locationExtension = try buffer.parseOptional(tracker: tracker) {
            (buffer, tracker) -> BodyStructure.LocationAndExtensions in
            try buffer.parseSpaces()
            return try self.parseBodyLocationExtension(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.LanguageLocation(languages: fieldLanguage, location: locationExtension)
    }

    func parseBodyDescriptionLanguage(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> BodyStructure.DispositionAndLanguage {
        let description = try self.parseBodyFieldDsp(buffer: &buffer, tracker: tracker)
        let language = try buffer.parseOptional(tracker: tracker) {
            (buffer, tracker) -> BodyStructure.LanguageLocation in
            try buffer.parseSpaces()
            return try self.parseBodyLanguageLocation(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.DispositionAndLanguage(disposition: description, language: language)
    }
}
