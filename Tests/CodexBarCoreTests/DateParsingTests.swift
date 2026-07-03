import Foundation
import Testing
@testable import CodexBarCore

@Suite
struct DateParsingTests {
    @Test
    func parsesFractionalISO8601Date() {
        #expect(DateParsing.parseISO8601("2026-06-24T20:00:00.123Z") == Date(timeIntervalSince1970: 1_782_331_200.123))
    }

    @Test
    func parsesPlainISO8601Date() {
        #expect(DateParsing.parseISO8601("2026-06-24T20:00:00Z") == Date(timeIntervalSince1970: 1_782_331_200))
    }

    @Test
    func returnsNilForMissingOrInvalidDate() {
        #expect(DateParsing.parseISO8601(nil) == nil)
        #expect(DateParsing.parseISO8601("not-a-date") == nil)
    }
}
