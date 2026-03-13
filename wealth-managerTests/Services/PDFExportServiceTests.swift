import Testing
import Foundation

@testable import wealth_manager

// MARK: - PDFExportServiceTests

@Suite("PDFExportService")
struct PDFExportServiceTests {

    private let service = PDFExportService()

    // MARK: - Basic PDF Validity

    @Test("exportPDF: returns non-empty data")
    func exportPDF_returnsNonEmptyData() throws {
        let data = try service.exportBriefingPDF(
            title: "Financial Summary",
            sections: [("Income", "Total income: $120,000")]
        )
        #expect(data.count > 0)
    }

    @Test("exportPDF: data starts with PDF magic bytes")
    func exportPDF_startsWithPDFMagicBytes() throws {
        let data = try service.exportBriefingPDF(
            title: "Test Report",
            sections: [("Section 1", "Some content here")]
        )
        let magic = "%PDF"
        let prefix = String(data: data.prefix(4), encoding: .utf8) ?? ""
        #expect(prefix == magic)
    }

    @Test("exportPDF: empty sections still produces valid PDF")
    func exportPDF_emptyContent_stillValidPDF() throws {
        let data = try service.exportBriefingPDF(title: "Empty Report", sections: [])
        #expect(data.count > 0)
        let prefix = String(data: data.prefix(4), encoding: .utf8) ?? ""
        #expect(prefix == "%PDF")
    }
}
