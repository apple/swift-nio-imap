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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
let badOS = { fatalError("unsupported OS") }()
#endif

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView
import struct OrderedCollections.OrderedDictionary

extension GrammarParser {
    // body            = "(" (body-type-1part / body-type-mpart) ")"
    static func parseBody(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure {
        func parseBody_singlePart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let part = try self.parseBodyKindSinglePart(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .singlepart(part)
        }

        func parseBody_multiPart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let part = try self.parseBodyKindMultipart(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .multipart(part)
        }

        return try PL.parseOneOf(
            parseBody_singlePart,
            parseBody_multiPart,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // body-extension  = nstring / number /
    //                    "(" body-extension *(SP body-extension) ")"
    static func parseBodyExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [BodyExtension] {
        func parseBodyExtensionKind_string(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyExtension {
            .string(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionKind_number(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyExtension {
            .number(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionKind(buffer: inout ParseBuffer, tracker: StackTracker, into array: inout [BodyExtension]) throws {
            let element = try PL.parseOneOf(
                parseBodyExtensionKind_string,
                parseBodyExtensionKind_number,
                buffer: &buffer,
                tracker: tracker
            )
            array.append(element)
        }

        func parseBodyExtension_array(buffer: inout ParseBuffer, tracker: StackTracker, into array: inout [BodyExtension]) throws {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
            var save = buffer
            do {
                while true {
                    save = buffer
                    try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                    try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
                }
            } catch is ParserError {
                buffer = save
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
        }

        func parseBodyExtension_arrayOrStatic(buffer: inout ParseBuffer, tracker: StackTracker, into array: inout [BodyExtension]) throws {
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
    static func parseBodyExtSinglePart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart.Extension {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Singlepart.Extension in
            let md5 = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { (buffer: ByteBuffer) -> String in
                return try ParserLibrary.parseBufferAsUTF8(buffer)
            }
            let dsp = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.DispositionAndLanguage in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Singlepart.Extension(digest: md5, dispositionAndLanguage: dsp)
        }
    }

    // body-ext-mpart  = body-fld-param [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    static func parseBodyExtMpart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Multipart.Extension {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Multipart.Extension in
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            let dsp = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.DispositionAndLanguage in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Multipart.Extension(parameters: param, dispositionAndLanguage: dsp)
        }
    }

    // body-fields     = body-fld-param SP body-fld-id SP body-fld-desc SP
    //                   body-fld-enc SP body-fld-octets
    static func parseBodyFields(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Fields {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Fields in
            let fieldParam = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let fieldID = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { (buffer: ByteBuffer) -> String in
                try ParserLibrary.parseBufferAsUTF8(buffer)
            }
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let fieldDescription = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { (buffer: ByteBuffer) -> String in
                try ParserLibrary.parseBufferAsUTF8(buffer)
            }
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let Encoding = try self.parseBodyEncoding(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let fieldOctets = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return BodyStructure.Fields(
                parameters: fieldParam,
                id: fieldID,
                contentDescription: fieldDescription,
                encoding: Encoding,
                octetCount: fieldOctets
            )
        }
    }

    // body-fld-dsp    = "(" string SP body-fld-param ")" / nil
    static func parseBodyFieldDsp(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Disposition? {
        func parseBodyFieldDsp_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Disposition? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseBodyFieldDsp_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Disposition? {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
            let string = try ParserLibrary.parseBufferAsUTF8(parsed)
            let dispositionKind = BodyStructure.DispositionKind(rawValue: string)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return BodyStructure.Disposition(kind: dispositionKind, parameters: param)
        }

        return try PL.parseOneOf(
            parseBodyFieldDsp_nil,
            parseBodyFieldDsp_some,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // body-fld-enc    = (DQUOTE ("7BIT" / "8BIT" / "BINARY" / "BASE64"/
    //                   "QUOTED-PRINTABLE") DQUOTE) / string
    static func parseBodyEncoding(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
        func parseBodyEncoding_string(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
            return .init(try ParserLibrary.parseBufferAsUTF8(parsed))
        }

        func parseBodyEncoding_option(_ option: String, result: BodyStructure.Encoding, buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try PL.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(option, buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return result
        }

        func parseBodyEncoding_7bit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("7BIT", result: .sevenBit, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_8bit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("8BIT", result: .eightBit, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_binary(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("BINARY", result: .binary, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_base64(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("BASE64", result: .base64, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_quotePrintable(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("QUOTED-PRINTABLE", result: .quotedPrintable, buffer: &buffer, tracker: tracker)
        }

        return try PL.parseOneOf([
            parseBodyEncoding_7bit,
            parseBodyEncoding_8bit,
            parseBodyEncoding_binary,
            parseBodyEncoding_base64,
            parseBodyEncoding_quotePrintable,
            parseBodyEncoding_string,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-lang   = nstring / "(" string *(SP string) ")"
    static func parseBodyFieldLanguage(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [String] {
        func parseBodyFieldLanguage_single(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [String] {
            guard let parsed = try self.parseNString(buffer: &buffer, tracker: tracker) else {
                return []
            }
            return [try ParserLibrary.parseBufferAsUTF8(parsed)]
        }

        func parseBodyFieldLanguage_multiple(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [String] {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)

            let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
            var array = [try ParserLibrary.parseBufferAsUTF8(parsed)]

            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> String in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)

                let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
                return try ParserLibrary.parseBufferAsUTF8(parsed)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try PL.parseOneOf(
            parseBodyFieldLanguage_multiple,
            parseBodyFieldLanguage_single,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // body-fld-param  = "(" string SP string *(SP string SP string) ")" / nil
    static func parseBodyFieldParam(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<String, String> {
        func parseBodyFieldParam_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<String, String> {
            try parseNil(buffer: &buffer, tracker: tracker)
            return [:]
        }

        func parseBodyFieldParam_singlePair(buffer: inout ParseBuffer, tracker: StackTracker) throws -> (String, String) {
            let parsedField = try parseString(buffer: &buffer, tracker: tracker)
            let field = try ParserLibrary.parseBufferAsUTF8(parsedField)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let parsedValue = try parseString(buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseBufferAsUTF8(parsedValue)
            return (field, value)
        }

        func parseBodyFieldParam_pairs(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<String, String> {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var kvs = OrderedDictionary<String, String>()
            let keyValue = try parseBodyFieldParam_singlePair(buffer: &buffer, tracker: tracker)
            kvs[keyValue.0] = keyValue.1
            try PL.parseZeroOrMore(buffer: &buffer, into: &kvs, tracker: tracker) { (buffer, tracker) -> (String, String) in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try parseBodyFieldParam_singlePair(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return kvs
        }

        return try PL.parseOneOf(
            parseBodyFieldParam_pairs,
            parseBodyFieldParam_nil,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // body-type-1part = (body-type-basic / body-type-msg / body-type-text)
    //                   [SP body-ext-1part]
    static func parseBodyKindSinglePart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
        func parseBodyKindSinglePart_extension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart.Extension? {
            try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseBodyExtSinglePart(buffer: &buffer, tracker: tracker)
            }
        }

        func parseBodyKindSinglePart_basic(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let media = try self.parseMediaBasic(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(kind: .basic(media), fields: fields, extension: ext)
        }

        func parseBodyKindSinglePart_message(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let mediaMessage = try self.parseMediaMessage(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let envelope = try self.parseEnvelope(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let fieldLines = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let message = BodyStructure.Singlepart.Message(message: mediaMessage, envelope: envelope, body: body, lineCount: fieldLines)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(kind: .message(message), fields: fields, extension: ext)
        }

        func parseBodyKindSinglePart_text(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let media = try self.parseMediaText(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let fieldLines = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let text = BodyStructure.Singlepart.Text(mediaText: media, lineCount: fieldLines)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(kind: .text(text), fields: fields, extension: ext)
        }

        return try PL.parseOneOf(
            parseBodyKindSinglePart_message,
            parseBodyKindSinglePart_text,
            parseBodyKindSinglePart_basic,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // body-type-mpart = 1*body SP media-subtype
    //                   [SP body-ext-mpart]
    static func parseBodyKindMultipart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.Multipart {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Multipart in
            let parts = try PL.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure in
                try? PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseBody(buffer: &buffer, tracker: tracker)
            }
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let media = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            let ext = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.Multipart.Extension in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseBodyExtMpart(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Multipart(parts: parts, mediaSubtype: media, extension: ext)
        }
    }

    static func parseBodyLocationExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.LocationAndExtensions {
        let fieldLocation = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { (buffer: ByteBuffer) -> String in
            return try ParserLibrary.parseBufferAsUTF8(buffer)
        }
        let extensions = try PL.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [BodyExtension] in
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return try self.parseBodyExtension(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.LocationAndExtensions(location: fieldLocation, extensions: extensions.reduce([], +))
    }

    static func parseBodyLanguageLocation(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.LanguageLocation {
        let fieldLanguage = try self.parseBodyFieldLanguage(buffer: &buffer, tracker: tracker)
        let locationExtension = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.LocationAndExtensions in
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return try parseBodyLocationExtension(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.LanguageLocation(languages: fieldLanguage, location: locationExtension)
    }

    static func parseBodyDescriptionLanguage(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.DispositionAndLanguage {
        let description = try self.parseBodyFieldDsp(buffer: &buffer, tracker: tracker)
        let language = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.LanguageLocation in
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return try parseBodyLanguageLocation(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.DispositionAndLanguage(disposition: description, language: language)
    }
}
