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

@testable import IMAPToolLib
import Testing
import Numerics

@Suite
private enum BinTests {
    @Test
    static func roundingBinSpan() {
        #expect(roundedBinSpan(0.7).isApproximatelyEqual(to: 0.7, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.6).isApproximatelyEqual(to: 0.6, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.9).isApproximatelyEqual(to: 0.9, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(1.0).isApproximatelyEqual(to: 1.0, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(1.1).isApproximatelyEqual(to: 1.2, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(1.2).isApproximatelyEqual(to: 1.2, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(1.3).isApproximatelyEqual(to: 1.4, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(1.4).isApproximatelyEqual(to: 1.4, absoluteTolerance: 0.000_1))

        #expect(roundedBinSpan(0.07).isApproximatelyEqual(to: 0.07, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.06).isApproximatelyEqual(to: 0.06, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.09).isApproximatelyEqual(to: 0.09, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.10).isApproximatelyEqual(to: 0.10, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.11).isApproximatelyEqual(to: 0.1, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.12).isApproximatelyEqual(to: 0.12, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.13).isApproximatelyEqual(to: 0.14, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.14).isApproximatelyEqual(to: 0.14, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.15).isApproximatelyEqual(to: 0.14, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.16).isApproximatelyEqual(to: 0.16, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.17).isApproximatelyEqual(to: 0.18, absoluteTolerance: 0.000_1))

        #expect(roundedBinSpan(0.070).isApproximatelyEqual(to: 0.070, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.071).isApproximatelyEqual(to: 0.072, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.072).isApproximatelyEqual(to: 0.072, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.073).isApproximatelyEqual(to: 0.074, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.074).isApproximatelyEqual(to: 0.074, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.075).isApproximatelyEqual(to: 0.076, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.076).isApproximatelyEqual(to: 0.076, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.077).isApproximatelyEqual(to: 0.078, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.078).isApproximatelyEqual(to: 0.078, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.079).isApproximatelyEqual(to: 0.080, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.080).isApproximatelyEqual(to: 0.080, absoluteTolerance: 0.000_1))

        #expect(roundedBinSpan(0.20562968179143173).isApproximatelyEqual(to: 0.200, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(0.21562968179143173).isApproximatelyEqual(to: 0.220, absoluteTolerance: 0.000_1))

        // Non-positive / non-finite inputs must not produce NaN.
        #expect(roundedBinSpan(0) == 0)
        #expect(roundedBinSpan(-1.3).isApproximatelyEqual(to: -1.4, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(-0.072).isApproximatelyEqual(to: -0.072, absoluteTolerance: 0.000_1))
        #expect(roundedBinSpan(.nan) == 0)
        #expect(roundedBinSpan(.infinity) == 0)
    }

    @Test
    static func binRangesFromData() throws {
        let bins: [Range<Int>] = try #require(binRanges(data: data)).map { r -> Range<Int> in
            let lower = Int((r.lowerBound * 1000).rounded(.toNearestOrAwayFromZero))
            let upper = Int((r.upperBound * 1000).rounded(.toNearestOrAwayFromZero))
            return lower..<upper
        }
        #expect(
            bins == [
                110..<140,
                140..<170,
                170..<200,
                200..<230,
                230..<260,
                260..<290,
            ]
        )
    }

    @Test
    static func createFromData() throws {
        let sut = try #require(Histogram(data: data))
        #expect(
            sut.bins.map(\.count) == [
                104,
                57,
                15,
                7,
                0,
                2,
            ]
        )
    }
}

private let data: [Double] = [
    0.122171192, 0.123395652, 0.123472153, 0.13781253, 0.144689425,
    0.158754769, 0.135024804, 0.212556388, 0.119193779, 0.134820369,
    0.127815519, 0.124780539, 0.150910074, 0.120827119, 0.150364741,
    0.146966822, 0.123306126, 0.140330586, 0.153496039, 0.129829528,
    0.274138931, 0.137818234, 0.119060215, 0.125635767, 0.118335712,
    0.12496699, 0.126019394, 0.133717599, 0.118377887, 0.123200242,
    0.120214432, 0.128805262, 0.141605264, 0.147688018, 0.13665841,
    0.118342992, 0.13340833, 0.164123679, 0.143677784, 0.138495189,
    0.171459794, 0.185034615, 0.163257631, 0.125976305, 0.135628424,
    0.132502991, 0.1505422, 0.160112694, 0.185119389, 0.138207083,
    0.126176955, 0.138213057, 0.134598795, 0.177951131, 0.128130949,
    0.172570313, 0.124905424, 0.141619087, 0.207915823, 0.131152969,
    0.123139228, 0.175255743, 0.15831435, 0.14910411, 0.159537588,
    0.193938038, 0.125374246, 0.139930923, 0.140384119, 0.129001231,
    0.126245557, 0.131497164, 0.137858935, 0.121978086, 0.138980462,
    0.154026367, 0.125193752, 0.176967353, 0.145071349, 0.13641629,
    0.131520032, 0.126133394, 0.126545686, 0.13611576, 0.122739261,
    0.134888492, 0.179227416, 0.147208528, 0.125008901, 0.12108777,
    0.137417394, 0.14340435, 0.167365776, 0.139132545, 0.165451138,
    0.166845733, 0.13760426, 0.139901412, 0.140568276, 0.163856659,
    0.145537728, 0.152495003, 0.147586944, 0.125992611, 0.119146645,
    0.14098255, 0.128252514, 0.12346929, 1.079886135, 0.122693624,
    0.122775901, 0.131289177, 0.127224351, 0.128993312, 0.124280839,
    0.128965948, 0.17204532, 0.20466414, 0.14229628, 0.131979797,
    0.145716555, 0.227100914, 0.143878482, 0.131024928, 0.142743257,
    0.155885018, 0.12318903, 0.144658231, 0.126166246, 0.163060934,
    0.171971104, 0.14729245, 0.125241788, 0.191618277, 0.12446891,
    0.129576867, 0.132809882, 0.147108319, 0.114849054, 0.206822199,
    0.1257895, 0.1365188, 0.140638183, 0.123274213, 0.12684512,
    0.166034035, 0.146449088, 0.126644715, 0.139560665, 0.138363492,
    0.174758821, 0.131317809, 0.123551418, 0.165621598, 0.167744131,
    0.11768365, 0.124945645, 0.119563897, 0.134626433, 0.166622316,
    0.275837005, 0.143031372, 0.155217997, 0.130167568, 0.136592654,
    0.144256404, 0.133093567, 0.193387005, 0.165363057, 0.14475142,
    0.162050933, 0.131305375, 0.125124742, 0.136353538, 0.138129362,
    0.132879413, 0.20659515, 0.229068123, 0.161760476, 0.128732902,
    0.164451069, 0.138786147, 0.164313424, 0.176923405, 0.118360439,
    0.163233585,
]
