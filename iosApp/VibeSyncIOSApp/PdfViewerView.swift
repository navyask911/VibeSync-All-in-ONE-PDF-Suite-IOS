import PDFKit
import SwiftUI
import UIKit

struct PdfViewerView: View {
    let pdfData: Data
    let fileName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var pdfDocument: PDFDocument?
    @State private var pdfView: PDFView?
    @State private var searchText = ""
    @State private var searchHits: [PDFViewerSearchHit] = []
    @State private var selectedMatchIndex = 0
    @State private var searchMessage = "Search embedded PDF text."
    @State private var loadError: String?
    @State private var ocrCache: [Int: [OcrTextObservation]] = [:]
    @State private var searchTask: Task<Void, Never>?
    @State private var temporaryOCRHighlights: [PDFViewerOCRHighlight] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            searchPanel

            if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.exclamationmark")
                        .font(.system(size: 38))
                        .foregroundStyle(VibeSyncColors.dangerRed)
                    Text("Unable to open PDF")
                        .vibeSyncStyle(.titleMedium)
                    Text(loadError)
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let pdfDocument {
                PDFKitReaderView(document: pdfDocument) { readyView in
                    if pdfView !== readyView {
                        pdfView = readyView
                    }
                }
                .accessibilityIdentifier("pdf_viewer_document")
                .background(Color(uiColor: .secondarySystemBackground))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Opening PDF…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(VibeSyncColors.background(for: colorScheme))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: loadPDF)
        .onDisappear {
            searchTask?.cancel()
            clearOCRHighlights()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("pdf_viewer_back")

            VStack(alignment: .leading, spacing: 2) {
                Text("View & Read")
                    .vibeSyncStyle(.titleMedium)
                    .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                Text(fileName)
                    .vibeSyncStyle(.bodyMedium)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                changeZoom(by: 1 / 1.25)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 34, height: 38)
            }
            .accessibilityLabel("Zoom out")
            .accessibilityIdentifier("pdf_viewer_zoom_out")

            Button {
                changeZoom(by: 1.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 34, height: 38)
            }
            .accessibilityLabel("Zoom in")
            .accessibilityIdentifier("pdf_viewer_zoom_in")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(VibeSyncColors.surface(for: colorScheme))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var searchPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))

                TextField("Search text in this PDF", text: $searchText)
                    .font(VibeSyncTypography.bodyLarge)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityIdentifier("pdf_viewer_search_field")
                    .onSubmit { performSearch() }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                    }
                    .accessibilityLabel("Clear search")
                    .accessibilityIdentifier("pdf_viewer_search_clear")
                }

                Button(action: performSearch) {
                    Text("Search")
                        .font(VibeSyncTypography.labelLarge)
                        .foregroundStyle(VibeSyncColors.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(VibeSyncColors.crimsonPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pdf_viewer_search_submit")
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pdfView == nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VibeSyncColors.surfaceVariant(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Text(searchMessage)
                    .font(VibeSyncTypography.bodyMedium)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
                    .accessibilityIdentifier("pdf_viewer_search_count")

                Spacer(minLength: 4)

                Button {
                    moveToMatch(direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 34, height: 30)
                }
                .accessibilityLabel("Previous search result")
                .accessibilityIdentifier("pdf_viewer_previous_match")
                .disabled(searchHits.isEmpty)

                Button {
                    moveToMatch(direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 34, height: 30)
                }
                .accessibilityLabel("Next search result")
                .accessibilityIdentifier("pdf_viewer_next_match")
                .disabled(searchHits.isEmpty)
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(VibeSyncColors.surface(for: colorScheme))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func loadPDF() {
        guard pdfDocument == nil, loadError == nil else { return }
        guard let document = PDFDocument(data: pdfData), document.pageCount > 0 else {
            loadError = "The selected file is not a readable PDF."
            return
        }
        pdfDocument = document
    }

    private func performSearch() {
        searchTask?.cancel()
        clearOCRHighlights()

        guard let pdfDocument, let pdfView else {
            searchMessage = "PDF is still loading."
            return
        }

        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            clearSearch()
            return
        }

        // Search embedded text first. PDFKit returns real text selections very quickly.
        let digitalSelections = pdfDocument.findString(query, withOptions: [.caseInsensitive])
        digitalSelections.forEach { $0.color = UIColor.systemYellow.withAlphaComponent(0.55) }
        let digitalHits = digitalSelections.compactMap { selection -> PDFViewerSearchHit? in
            guard let page = selection.pages.first else { return nil }
            let pageIndex = pdfDocument.index(for: page)
            guard pageIndex != NSNotFound else { return nil }
            return PDFViewerSearchHit(pageIndex: pageIndex, selection: selection, ocrBounds: nil)
        }

        // OCR is only required for pages whose PDF text layer is absent or empty.
        let scannedPageIndices = (0..<pdfDocument.pageCount).filter { pageIndex in
            guard let page = pdfDocument.page(at: pageIndex) else { return false }
            return (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !scannedPageIndices.isEmpty else {
            publishSearchResults(digitalHits, digitalSelections: digitalSelections)
            return
        }

        searchMessage = "Searching \(scannedPageIndices.count) scanned pages…"
        searchTask = Task { @MainActor in
            var recognitionFailures = 0
            for pageIndex in scannedPageIndices {
                guard !Task.isCancelled, let page = pdfDocument.page(at: pageIndex) else { return }
                if ocrCache[pageIndex] != nil { continue }
                do {
                    ocrCache[pageIndex] = try await OcrEngine.recognize(page: page)
                } catch {
                    recognitionFailures += 1
                }
            }

            guard !Task.isCancelled else { return }
            let ocrHits = matchingOCRHits(query: query, document: pdfDocument)
            let allHits = sortHits(digitalHits + ocrHits, document: pdfDocument)
            publishSearchResults(
                allHits,
                digitalSelections: digitalSelections,
                recognitionFailures: recognitionFailures
            )
        }
    }

    private func matchingOCRHits(query: String, document: PDFDocument) -> [PDFViewerSearchHit] {
        var results: [PDFViewerSearchHit] = []
        for (pageIndex, observations) in ocrCache {
            guard let page = document.page(at: pageIndex) else { continue }
            let pageBounds = page.bounds(for: .cropBox)
            for observation in observations where observation.text.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil {
                let normalized = observation.normalizedBounds
                let rect = CGRect(
                    x: pageBounds.minX + normalized.minX * pageBounds.width,
                    y: pageBounds.minY + normalized.minY * pageBounds.height,
                    width: normalized.width * pageBounds.width,
                    height: normalized.height * pageBounds.height
                ).intersection(pageBounds)
                guard !rect.isNull, !rect.isEmpty else { continue }
                results.append(
                    PDFViewerSearchHit(pageIndex: pageIndex, selection: nil, ocrBounds: rect)
                )
            }
        }
        return results
    }

    private func sortHits(
        _ hits: [PDFViewerSearchHit],
        document: PDFDocument
    ) -> [PDFViewerSearchHit] {
        hits.sorted { first, second in
            if first.pageIndex != second.pageIndex {
                return first.pageIndex < second.pageIndex
            }
            let firstY = first.ocrBounds?.midY ?? document.page(at: first.pageIndex)
                .map { first.selection?.bounds(for: $0).midY ?? 0 } ?? 0
            let secondY = second.ocrBounds?.midY ?? document.page(at: second.pageIndex)
                .map { second.selection?.bounds(for: $0).midY ?? 0 } ?? 0
            return firstY > secondY
        }
    }

    private func publishSearchResults(
        _ hits: [PDFViewerSearchHit],
        digitalSelections: [PDFSelection],
        recognitionFailures: Int = 0
    ) {
        searchHits = hits
        selectedMatchIndex = 0
        pdfView?.highlightedSelections = digitalSelections

        for hit in hits {
            guard let bounds = hit.ocrBounds,
                  let page = pdfDocument?.page(at: hit.pageIndex) else { continue }
            let annotation = PDFAnnotation(bounds: bounds, forType: .square, withProperties: nil)
            annotation.color = UIColor.systemYellow.withAlphaComponent(0.65)
            annotation.interiorColor = UIColor.systemYellow.withAlphaComponent(0.36)
            let border = PDFBorder()
            border.lineWidth = 0
            annotation.border = border
            page.addAnnotation(annotation)
            temporaryOCRHighlights.append(PDFViewerOCRHighlight(page: page, annotation: annotation))
        }

        guard !hits.isEmpty else {
            pdfView?.setCurrentSelection(nil, animate: false)
            searchMessage = recognitionFailures > 0
                ? "Some scanned pages could not be recognized."
                : "No text matches."
            return
        }

        focusMatch(at: 0)
        searchMessage = "1 of \(hits.count) matches"
    }

    private func clearOCRHighlights() {
        for highlight in temporaryOCRHighlights {
            highlight.page.removeAnnotation(highlight.annotation)
        }
        temporaryOCRHighlights.removeAll()
        pdfView?.setNeedsDisplay()
    }

    private func clearSearch() {
        searchTask?.cancel()
        searchHits = []
        selectedMatchIndex = 0
        searchMessage = "Search embedded PDF text."
        pdfView?.highlightedSelections = nil
        pdfView?.setCurrentSelection(nil, animate: false)
        clearOCRHighlights()
    }

    private func moveToMatch(direction: Int) {
        guard !searchHits.isEmpty else { return }
        selectedMatchIndex = (selectedMatchIndex + direction + searchHits.count) % searchHits.count
        focusMatch(at: selectedMatchIndex)
        searchMessage = "\(selectedMatchIndex + 1) of \(searchHits.count) matches"
    }

    private func focusMatch(at index: Int) {
        guard searchHits.indices.contains(index), let pdfView,
              let document = pdfDocument else { return }
        let hit = searchHits[index]
        if let selection = hit.selection {
            pdfView.setCurrentSelection(selection, animate: true)
            pdfView.go(to: selection)
        } else if let bounds = hit.ocrBounds, let page = document.page(at: hit.pageIndex) {
            pdfView.setCurrentSelection(nil, animate: false)
            pdfView.go(to: bounds, on: page)
        }
    }

    private func changeZoom(by multiplier: CGFloat) {
        guard let pdfView else { return }
        let fitScale = max(pdfView.minScaleFactor, 0.01)
        let maximum = max(fitScale, fitScale * 4)
        pdfView.scaleFactor = min(maximum, max(fitScale, pdfView.scaleFactor * multiplier))
    }
}

private struct PDFViewerSearchHit {
    let pageIndex: Int
    let selection: PDFSelection?
    let ocrBounds: CGRect?
}

private struct PDFViewerOCRHighlight {
    let page: PDFPage
    let annotation: PDFAnnotation
}

private struct PDFKitReaderView: UIViewRepresentable {
    let document: PDFDocument
    let onReady: (PDFView) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.backgroundColor = UIColor.secondarySystemBackground
        pdfView.document = document
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displayBox = .cropBox
        pdfView.usePageViewController(false, withViewOptions: nil)
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        pdfView.autoScales = true
        pdfView.maxScaleFactor = max(0.01, pdfView.minScaleFactor) * 4
        DispatchQueue.main.async {
            onReady(pdfView)
        }
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
            pdfView.autoScales = true
            pdfView.maxScaleFactor = max(0.01, pdfView.minScaleFactor) * 4
        }
    }
}
