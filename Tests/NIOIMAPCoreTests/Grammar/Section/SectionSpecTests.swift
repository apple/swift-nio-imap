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

import NIO
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

@Suite("SectionSpecifier")
private struct SectionSpecifierTests {
    @Test(arguments: [
        EncodeFixture.sectionSpecifier(nil, ""),
        EncodeFixture.sectionSpecifier(.init(kind: .header), "HEADER"),
        EncodeFixture.sectionSpecifier(.init(part: [1, 2, 3, 4], kind: .complete), "1.2.3.4"),
        EncodeFixture.sectionSpecifier(.init(part: [1, 2, 3, 4], kind: .header), "1.2.3.4.HEADER"),
    ])
    func encode(_ fixture: EncodeFixture<SectionSpecifier?>) {
        fixture.checkEncoding()
    }

    @Test("comparable SectionSpecifier", arguments: [
        ComparableFixture<SectionSpecifier>(lhs: .init(kind: .header), rhs: .init(kind: .text), expected: true),
        ComparableFixture<SectionSpecifier>(lhs: .init(kind: .text), rhs: .init(kind: .text), expected: false),
        ComparableFixture<SectionSpecifier>(
            lhs: .init(part: [1], kind: .complete),
            rhs: .init(part: [1], kind: .complete),
            expected: false
        ),
        ComparableFixture<SectionSpecifier>(
            lhs: .init(part: [1, 2], kind: .complete),
            rhs: .init(part: [1], kind: .complete),
            expected: false
        ),
        ComparableFixture<SectionSpecifier>(
            lhs: .init(part: [1, 2], kind: .complete),
            rhs: .init(part: [1, 2, 3], kind: .complete),
            expected: true
        ),
        ComparableFixture<SectionSpecifier>(
            lhs: .init(part: [1, 2, 3], kind: .complete),
            rhs: .init(part: [1, 2, 3], kind: .text),
            expected: true
        ),
        ComparableFixture<SectionSpecifier>(
            lhs: .init(part: [1, 2], kind: .text),
            rhs: .init(part: [1, 2, 3], kind: .header),
            expected: true
        ),
    ])
    func comparableSectionSpecifier(_ fixture: ComparableFixture<SectionSpecifier>) {
        #expect((fixture.lhs < fixture.rhs) == fixture.expected)
    }

    @Test("comparable SectionSpecifier Kind", arguments: [
        ComparableFixture<SectionSpecifier.Kind>(lhs: .complete, rhs: .complete, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .complete, rhs: .header, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .complete, rhs: .headerFields([]), expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .complete, rhs: .headerFieldsNot([]), expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .complete, rhs: .MIMEHeader, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .complete, rhs: .text, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .header, rhs: .complete, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .header, rhs: .header, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .header, rhs: .headerFields([]), expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .header, rhs: .headerFieldsNot([]), expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .header, rhs: .MIMEHeader, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .header, rhs: .text, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFields([]), rhs: .complete, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFields([]), rhs: .header, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFields([]), rhs: .headerFields([]), expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFields([]), rhs: .headerFieldsNot([]), expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFields([]), rhs: .MIMEHeader, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFields([]), rhs: .text, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFieldsNot([]), rhs: .complete, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFieldsNot([]), rhs: .header, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFieldsNot([]), rhs: .headerFields([]), expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFieldsNot([]), rhs: .headerFieldsNot([]), expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFieldsNot([]), rhs: .MIMEHeader, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .headerFieldsNot([]), rhs: .text, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .MIMEHeader, rhs: .complete, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .MIMEHeader, rhs: .header, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .MIMEHeader, rhs: .headerFields([]), expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .MIMEHeader, rhs: .headerFieldsNot([]), expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .MIMEHeader, rhs: .MIMEHeader, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .MIMEHeader, rhs: .text, expected: true),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .text, rhs: .complete, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .text, rhs: .header, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .text, rhs: .headerFields([]), expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .text, rhs: .headerFieldsNot([]), expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .text, rhs: .MIMEHeader, expected: false),
        ComparableFixture<SectionSpecifier.Kind>(lhs: .text, rhs: .text, expected: false),
    ])
    func comparableSectionSpecifierKind(_ fixture: ComparableFixture<SectionSpecifier.Kind>) {
        #expect((fixture.lhs < fixture.rhs) == fixture.expected)
    }

    @Test("comparable SectionSpecifier Part", arguments: [
        ComparableFixture<SectionSpecifier.Part>(lhs: [1], rhs: [1], expected: false),
        ComparableFixture<SectionSpecifier.Part>(lhs: [1], rhs: [1, 2], expected: true),
        ComparableFixture<SectionSpecifier.Part>(lhs: [1, 2], rhs: [1], expected: false),
        ComparableFixture<SectionSpecifier.Part>(lhs: [1, 2, 3, 4], rhs: [1, 2, 3, 4], expected: false),
        ComparableFixture<SectionSpecifier.Part>(lhs: [1, 2, 3, 4], rhs: [1, 2, 3, 4, 5, 6], expected: true),
        ComparableFixture<SectionSpecifier.Part>(lhs: [1, 2, 3, 4, 5, 6], rhs: [1, 2, 3], expected: false),
    ])
    func comparableSectionSpecifierPart(_ fixture: ComparableFixture<SectionSpecifier.Part>) {
        #expect((fixture.lhs < fixture.rhs) == fixture.expected)
    }

    @Test("Part dropFirst", arguments: [
        PartHelperFixture(part: [], expected: []),
        PartHelperFixture(part: [5], expected: []),
        PartHelperFixture(part: [5, 3], expected: [3]),
        PartHelperFixture(part: [5, 3, 8], expected: [3, 8]),
    ])
    func partDropFirst(_ fixture: PartHelperFixture) {
        #expect(fixture.part.dropFirst() == fixture.expected)
    }

    @Test("Part dropLast", arguments: [
        PartHelperFixture(part: [], expected: []),
        PartHelperFixture(part: [5], expected: []),
        PartHelperFixture(part: [5, 3], expected: [5]),
        PartHelperFixture(part: [5, 3, 8], expected: [5, 3]),
    ])
    func partDropLast(_ fixture: PartHelperFixture) {
        #expect(fixture.part.dropLast() == fixture.expected)
    }

    @Test("Part appending", arguments: [
        PartAppendingFixture(part: [], new: 1, expected: [1]),
        PartAppendingFixture(part: [5, 3, 8], new: 4, expected: [5, 3, 8, 4]),
    ])
    func partAppending(_ fixture: PartAppendingFixture) {
        #expect(fixture.part.appending(fixture.new) == fixture.expected)
    }

    @Test("Part relation", arguments: [
        PartRelationFixture(part: [], other: [], expected: false, relation: .isSubPart),
        PartRelationFixture(part: [2, 3], other: [2, 3], expected: false, relation: .isSubPart),
        PartRelationFixture(part: [2, 3, 1], other: [2, 3], expected: true, relation: .isSubPart),
        PartRelationFixture(part: [2, 3], other: [2, 3, 1], expected: false, relation: .isSubPart),
        PartRelationFixture(part: [2, 3, 1, 7], other: [2, 3], expected: true, relation: .isSubPart),
        PartRelationFixture(part: [2, 3, 1, 7], other: [2, 3, 1], expected: true, relation: .isSubPart),
        PartRelationFixture(part: [2, 4, 1, 7], other: [2, 3], expected: false, relation: .isSubPart),
        PartRelationFixture(part: [5, 3, 1, 7], other: [2, 3], expected: false, relation: .isSubPart),
        PartRelationFixture(part: [], other: [], expected: false, relation: .isChildPart),
        PartRelationFixture(part: [], other: [1], expected: false, relation: .isChildPart),
        PartRelationFixture(part: [], other: [8], expected: false, relation: .isChildPart),
        PartRelationFixture(part: [1], other: [], expected: true, relation: .isChildPart),
        PartRelationFixture(part: [8], other: [], expected: true, relation: .isChildPart),
        PartRelationFixture(part: [2, 3], other: [2, 3], expected: false, relation: .isChildPart),
        PartRelationFixture(part: [2, 3, 1], other: [2, 3], expected: true, relation: .isChildPart),
        PartRelationFixture(part: [2, 3, 1], other: [4, 3], expected: false, relation: .isChildPart),
        PartRelationFixture(part: [2, 3, 1], other: [2, 7], expected: false, relation: .isChildPart),
        PartRelationFixture(part: [2, 3, 1, 4], other: [2, 3], expected: false, relation: .isChildPart),
        PartRelationFixture(part: [2, 3], other: [2, 3, 1], expected: false, relation: .isChildPart),
        PartRelationFixture(part: [2, 3, 1, 7], other: [2, 3], expected: false, relation: .isChildPart),
        PartRelationFixture(part: [2, 3, 1, 7], other: [2, 3, 1], expected: true, relation: .isChildPart),
        PartRelationFixture(part: [2, 4, 1, 7], other: [2, 3], expected: false, relation: .isChildPart),
        PartRelationFixture(part: [5, 3, 1, 7], other: [2, 3], expected: false, relation: .isChildPart),
    ])
    func partRelation(_ fixture: PartRelationFixture) {
        switch fixture.relation {
        case .isSubPart:
            #expect(fixture.part.isSubPart(of: fixture.other) == fixture.expected)
        case .isChildPart:
            #expect(fixture.part.isChildPart(of: fixture.other) == fixture.expected)
        }
    }

    @Test("Part custom debug string", arguments: [
        DebugStringFixture(sut: SectionSpecifier.Part([]), expected: ""),
        DebugStringFixture(sut: SectionSpecifier.Part([1]), expected: "1"),
        DebugStringFixture(sut: SectionSpecifier.Part([1, 2]), expected: "1.2"),
        DebugStringFixture(sut: SectionSpecifier.Part([1, 2, 3, 4]), expected: "1.2.3.4"),
    ])
    func partCustomDebugString(_ fixture: DebugStringFixture<SectionSpecifier.Part>) {
        fixture.check()
    }

    @Test("parse section", arguments: [
        ParseFixture.section("[]", expected: .success(.complete)),
        ParseFixture.section("[HEADER]", expected: .success(SectionSpecifier(kind: .header))),
        ParseFixture.section("[", " ", expected: .failure),
        ParseFixture.section("[HEADER", " ", expected: .failure),
        ParseFixture.section("[", "", expected: .incompleteMessage),
        ParseFixture.section("[HEADER", "", expected: .incompleteMessage),
    ])
    func parseSection(_ fixture: ParseFixture<SectionSpecifier>) {
        fixture.checkParsing()
    }

    @Test("parse section specifier", arguments: [
        ParseFixture.sectionSpecifier("HEADER", expected: .success(.init(kind: .header))),
        ParseFixture.sectionSpecifier("1.2.3", expected: .success(.init(part: [1, 2, 3], kind: .complete))),
        ParseFixture.sectionSpecifier("1.2.3.HEADER", expected: .success(.init(part: [1, 2, 3], kind: .header))),
        ParseFixture.sectionSpecifier("MIME", expected: .failure),
        ParseFixture.sectionSpecifier("", "", expected: .incompleteMessage),
        ParseFixture.sectionSpecifier("1", "", expected: .incompleteMessage),
        ParseFixture.sectionSpecifier("1.", "", expected: .incompleteMessage),
    ])
    func parseSectionSpecifier(_ fixture: ParseFixture<SectionSpecifier>) {
        fixture.checkParsing()
    }

    @Test("parse section specifier kind", arguments: [
        ParseFixture.sectionSpecifierKind("MIME", expected: .success(.MIMEHeader)),
        ParseFixture.sectionSpecifierKind("HEADER", expected: .success(.header)),
        ParseFixture.sectionSpecifierKind("TEXT", expected: .success(.text)),
        ParseFixture.sectionSpecifierKind("HEADER.FIELDS (f1)", expected: .success(.headerFields(["f1"]))),
        ParseFixture.sectionSpecifierKind(
            "HEADER.FIELDS (f1 f2 f3)",
            expected: .success(.headerFields(["f1", "f2", "f3"]))
        ),
        ParseFixture.sectionSpecifierKind("HEADER.FIELDS.NOT (f1)", expected: .success(.headerFieldsNot(["f1"]))),
        ParseFixture.sectionSpecifierKind(
            "HEADER.FIELDS.NOT (f1 f2 f3)",
            expected: .success(.headerFieldsNot(["f1", "f2", "f3"]))
        ),
        ParseFixture.sectionSpecifierKind("", expected: .success(.complete)),
        ParseFixture.sectionSpecifierKind("HEADER.FIELDS ", "", expected: .incompleteMessage),
        ParseFixture.sectionSpecifierKind("HEADER.FIELDS (f1 f2 f3 ", "", expected: .incompleteMessage),
    ])
    func parseSectionSpecifierKind(_ fixture: ParseFixture<SectionSpecifier.Kind>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<SectionSpecifier?> {
    fileprivate static func sectionSpecifier(
        _ input: SectionSpecifier?,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSectionSpecifier($1) }
        )
    }
}

extension ParseFixture<SectionSpecifier> {
    fileprivate static func section(
        _ input: String,
        _ terminator: String = "",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSection
        )
    }

    fileprivate static func sectionSpecifier(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSectionSpecifier
        )
    }
}

extension ParseFixture<SectionSpecifier.Kind> {
    fileprivate static func sectionSpecifierKind(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSectionSpecifierKind
        )
    }
}

private struct ComparableFixture<T>: Sendable, CustomTestStringConvertible where T: Comparable, T: Sendable {
    let lhs: T
    let rhs: T
    let expected: Bool

    var testDescription: String { "\(lhs) < \(rhs)" }
}

private struct PartHelperFixture: Sendable, CustomTestStringConvertible {
    let part: SectionSpecifier.Part
    let expected: SectionSpecifier.Part

    var testDescription: String { "'\(part)'" }
}

private struct PartAppendingFixture: Sendable, CustomTestStringConvertible {
    let part: SectionSpecifier.Part
    let new: Int
    let expected: SectionSpecifier.Part

    var testDescription: String { "'\(part)' + \(new)" }
}

private struct PartRelationFixture: Sendable, CustomTestStringConvertible {
    let part: SectionSpecifier.Part
    let other: SectionSpecifier.Part
    let expected: Bool
    let relation: Relation

    enum Relation: Sendable {
        case isSubPart
        case isChildPart
    }

    var testDescription: String { "'\(part)' \(relation) of '\(other)'" }
}
