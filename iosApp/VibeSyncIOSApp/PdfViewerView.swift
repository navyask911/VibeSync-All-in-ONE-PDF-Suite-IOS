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
    @State private var matches: [PDFSelection] = []
    @State private var selectedMatchIndex = 0
    @State private var searchMessage = "Search embedded PDF text. OCR is not included yet."
    @State private var loadError: String?

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
                .disabled(matches.isEmpty)

                Button {
                    moveToMatch(direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 34, height: 30)
                }
                .accessibilityLabel("Next search result")
                .accessibilityIdentifier("pdf_viewer_next_match")
                .disabled(matches.isEmpty)
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
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )

        guard let pdfDocument, let pdfView else {
            searchMessage = "PDF is still loading."
            return
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            clearSearch()
            return
        }

        // PDFKit searches embedded text, including Unicode scripts when the PDF has
        // a selectable text layer. Image-only scans require OCR, which is a later phase.
        let found = pdfDocument.findString(query, withOptions: [.caseInsensitive])
        found.forEach { $0.color = UIColor.systemYellow.withAlphaComponent(0.55) }
        matches = found
        selectedMatchIndex = 0

        guard !found.isEmpty else {
            pdfView.highlightedSelections = nil
            pdfView.setCurrentSelection(nil, animate: false)
            searchMessage = "No text matches (scanned PDFs need OCR)."
            return
        }

        pdfView.highlightedSelections = found
        focusMatch(at: selectedMatchIndex)
        searchMessage = "1 of \(found.count) matches"
    }

    private func clearSearch() {
        matches = []
        selectedMatchIndex = 0
        searchMessage = "Search embedded PDF text. OCR is not included yet."
        pdfView?.highlightedSelections = nil
        pdfView?.setCurrentSelection(nil, animate: false)
    }

    private func moveToMatch(direction: Int) {
        guard !matches.isEmpty else { return }
        selectedMatchIndex = (selectedMatchIndex + direction + matches.count) % matches.count
        focusMatch(at: selectedMatchIndex)
        searchMessage = "\(selectedMatchIndex + 1) of \(matches.count) matches"
    }

    private func focusMatch(at index: Int) {
        guard matches.indices.contains(index), let pdfView else { return }
        let selection = matches[index]
        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.go(to: selection)
    }

    private func changeZoom(by multiplier: CGFloat) {
        guard let pdfView else { return }
        let fitScale = max(pdfView.minScaleFactor, 0.01)
        let maximum = max(fitScale, fitScale * 4)
        pdfView.scaleFactor = min(maximum, max(fitScale, pdfView.scaleFactor * multiplier))
    }
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
