import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

/// Renders PDF documents from structured content using platform-appropriate APIs.
struct PDFExportService: DataExportServiceProtocol {

    // MARK: - DataExportServiceProtocol

    func exportAccountsCSV(accounts: [Account]) throws -> Data {
        try CSVExportService().exportAccountsCSV(accounts: accounts)
    }

    func exportTransactionsCSV(transactions: [Transaction]) throws -> Data {
        try CSVExportService().exportTransactionsCSV(transactions: transactions)
    }

    func exportNetWorthHistoryCSV(snapshots: [NetWorthSnapshot]) throws -> Data {
        try CSVExportService().exportNetWorthHistoryCSV(snapshots: snapshots)
    }

    /// Renders a PDF with a title heading and one section per `(heading, body)` tuple.
    func exportBriefingPDF(title: String, sections: [(String, String)]) throws -> Data {
        #if os(iOS) || os(visionOS)
        return renderPDFiOS(title: title, sections: sections)
        #else
        return renderPDFmacOS(title: title, sections: sections)
        #endif
    }

    // MARK: - macOS Rendering

    #if os(macOS)
    private func renderPDFmacOS(title: String, sections: [(String, String)]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = NSMutableData()

        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { return Data() }

        var mediaBox = pageRect
        context.beginPDFPage(nil)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        var yOffset: CGFloat = pageRect.height - 60

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 20),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle,
        ]
        drawText(title, in: context, rect: CGRect(x: 40, y: yOffset, width: 532, height: 30), attributes: titleAttrs)
        yOffset -= 40

        // Sections
        let headingAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: NSColor.black,
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black,
        ]

        for (heading, body) in sections {
            guard yOffset > 80 else { break }
            drawText(heading, in: context, rect: CGRect(x: 40, y: yOffset, width: 532, height: 20), attributes: headingAttrs)
            yOffset -= 24
            drawText(body, in: context, rect: CGRect(x: 40, y: yOffset, width: 532, height: 60), attributes: bodyAttrs)
            yOffset -= 70
        }

        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    private func drawText(
        _ text: String,
        in context: CGContext,
        rect: CGRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    }
    #endif

    // MARK: - iOS / visionOS Rendering

    #if os(iOS) || os(visionOS)
    private func renderPDFiOS(title: String, sections: [(String, String)]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()

            var yOffset: CGFloat = 40

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black,
            ]
            let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
            titleStr.draw(in: CGRect(x: 40, y: yOffset, width: 532, height: 30))
            yOffset += 40

            // Sections
            let headingAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black,
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black,
            ]

            for (heading, body) in sections {
                guard yOffset < pageRect.height - 80 else { break }
                let headingStr = NSAttributedString(string: heading, attributes: headingAttrs)
                headingStr.draw(in: CGRect(x: 40, y: yOffset, width: 532, height: 20))
                yOffset += 24
                let bodyStr = NSAttributedString(string: body, attributes: bodyAttrs)
                bodyStr.draw(in: CGRect(x: 40, y: yOffset, width: 532, height: 60))
                yOffset += 70
            }
        }
    }
    #endif
}
