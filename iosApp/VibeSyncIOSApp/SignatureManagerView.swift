import Foundation
import SwiftUI
import UIKit
import PDFKit
import Shared
import UniformTypeIdentifiers

struct SignatureManagerView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let vault = SignatureVault()

    @State private var signatures: [SignatureVault.SavedSignature] = []
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var selectedSignature: SignatureVault.SavedSignature?
    @State private var selectedImage: UIImage?
    @State private var isDrawing = false
    @State private var renameTarget: SignatureVault.SavedSignature?
    @State private var renameValue = ""
    @State private var deleteTarget: SignatureVault.SavedSignature?
    @State private var showDeleteConfirmation = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    @State private var isImportingPDF = false
    @State private var pdfDocument: PDFDocument?
    @State private var pdfFileName = "document"
    @State private var pdfPageIndex = 0
    @State private var placement: PDFSignaturePlacement?
    @State private var sizeScale: Double = 1
    @State private var rotationDegrees: Double = 0
    @State private var isExportingPDF = false
    @State private var exportDocument: SignaturePDFExportDocument?
    @State private var exportFileName = "signed-document"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manage and place saved signatures.")
                    .vibeSyncStyle(.bodyMedium)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))

                if signatures.isEmpty {
                    emptyState
                } else {
                    HStack {
                        Text("Saved signatures")
                            .vibeSyncStyle(.titleMedium)
                            .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                        Spacer()
                        Button {
                            isDrawing = true
                        } label: {
                            Label("Draw new", systemImage: "pencil.tip.crop.circle")
                                .font(VibeSyncTypography.labelLarge)
                        }
                        .buttonStyle(.bordered)
                        .tint(VibeSyncColors.primary(for: colorScheme))
                    }

                    VStack(spacing: 8) {
                        ForEach(signatures) { signature in
                            signatureRow(signature)
                        }
                    }
                }

                pdfSigningSection

                if let statusMessage {
                    Text(statusMessage)
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.successGreen)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.dangerRed)
                }
            }
            .padding(16)
        }
        .background(VibeSyncColors.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Signature Manager")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshSignatures)
        .fileImporter(
            isPresented: $isImportingPDF,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            importPDF(result)
        }
        .fileExporter(
            isPresented: $isExportingPDF,
            document: exportDocument,
            contentType: .pdf,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                statusMessage = "Signed PDF saved successfully."
                errorMessage = nil
            case .failure(let error):
                statusMessage = "The signed PDF was not saved."
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $isDrawing) {
            SignatureDrawingSheet { image in
                saveNewSignature(image)
            }
        }
        .alert("Rename signature", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Signature name", text: $renameValue)
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
            Button("Rename") {
                renameSelectedSignature()
            }
        } message: {
            Text("Enter a unique, non-empty signature name.")
        }
        .confirmationDialog(
            "Delete selected signature?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSelectedSignature()
            }
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
        }
        .tint(VibeSyncColors.primary(for: colorScheme))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "signature")
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(VibeSyncColors.primary(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.top, 28)

            Text("No saved signatures yet.")
                .vibeSyncStyle(.bodyMedium)
                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                .accessibilityIdentifier("signature_manager_empty")

            Button {
                isDrawing = true
            } label: {
                Label("Draw your signature", systemImage: "pencil.tip.crop.circle")
                    .font(VibeSyncTypography.labelLarge)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VibeSyncColors.primary(for: colorScheme))
            .accessibilityIdentifier("signature_draw_button")
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(VibeSyncColors.surfaceVariant(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func signatureRow(_ signature: SignatureVault.SavedSignature) -> some View {
        HStack(spacing: 8) {
            Button {
                selectSignature(signature)
            } label: {
                HStack(spacing: 10) {
                    Group {
                        if let image = thumbnails[signature.id] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "signature")
                                .font(.system(size: 22))
                                .foregroundStyle(VibeSyncColors.secondary(for: colorScheme))
                        }
                    }
                    .frame(width: 76, height: 42)
                    .background(VibeSyncColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text(signature.id)
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Image(systemName: selectedSignature?.id == signature.id ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(VibeSyncColors.primary(for: colorScheme))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("signature_select_\(signature.id)")

            Button {
                renameTarget = signature
                renameValue = signature.id
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(VibeSyncColors.primary(for: colorScheme))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Rename \(signature.id)")
            .accessibilityIdentifier("signature_rename_\(signature.id)")

            Button {
                deleteTarget = signature
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(VibeSyncColors.dangerRed)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(signature.id)")
            .accessibilityIdentifier("signature_delete_\(signature.id)")
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(VibeSyncColors.surfaceVariant(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("signature_item_\(signature.id)")
    }

    private var pdfSigningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sign a PDF")
                .vibeSyncStyle(.titleMedium)
                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))

            Text("Choose a PDF, select one of your saved signatures, then tap on the page to place it.")
                .vibeSyncStyle(.bodyMedium)
                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))

            Button {
                isImportingPDF = true
            } label: {
                Label("Choose PDF", systemImage: "doc.badge.plus")
                    .font(VibeSyncTypography.labelLarge)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VibeSyncColors.primary(for: colorScheme))
            .accessibilityIdentifier("signature_pdf_import_button")

            if let pdfDocument {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pdfFileName)
                            .vibeSyncStyle(.bodyMedium)
                            .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                            .lineLimit(1)
                        Text("\(pdfDocument.pageCount) pages")
                            .vibeSyncStyle(.bodyMedium)
                            .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                    }
                    Spacer()
                    Button("Change") {
                        isImportingPDF = true
                    }
                    .font(VibeSyncTypography.labelLarge)
                }

                HStack {
                    Button {
                        pdfPageIndex = max(0, pdfPageIndex - 1)
                    } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .disabled(pdfPageIndex == 0)

                    Spacer()
                    Text("Page \(pdfPageIndex + 1) of \(pdfDocument.pageCount)")
                        .vibeSyncStyle(.labelLarge)
                        .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                    Spacer()

                    Button {
                        pdfPageIndex = min(pdfDocument.pageCount - 1, pdfPageIndex + 1)
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(pdfPageIndex >= pdfDocument.pageCount - 1)
                }

                SignaturePDFPreview(
                    document: pdfDocument,
                    pageIndex: pdfPageIndex,
                    signatureImage: selectedImage,
                    placement: placement,
                    sizeScale: CGFloat(sizeScale),
                    rotationDegrees: CGFloat(rotationDegrees)
                ) { tappedPageIndex, page, point in
                    pdfPageIndex = tappedPageIndex
                    guard selectedImage != nil else {
                        errorMessage = "Select a saved signature above before tapping the PDF."
                        return
                    }
                    let pageBounds = page.bounds(for: .cropBox)
                    let baseWidth = pageBounds.width * 0.15
                    placement = PDFSignaturePlacement(
                        pageIndex: tappedPageIndex,
                        center: point,
                        baseWidth: baseWidth,
                        baseHeight: baseWidth * 0.5
                    )
                    statusMessage = "Signature placed. Adjust its size or rotation, then export."
                    errorMessage = nil
                }
                .frame(height: 440)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(VibeSyncColors.secondary(for: colorScheme).opacity(0.25), lineWidth: 1)
                }
                .accessibilityIdentifier("signature_pdf_preview")

                if selectedImage == nil {
                    Text("Select a saved signature above to enable placement.")
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                } else {
                    Text(placement == nil
                         ? "Tap the visible PDF page to place your signature."
                         : "The signature is shown on the page preview.")
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))

                    Text("Signature size")
                        .vibeSyncStyle(.labelLarge)
                        .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                    Slider(value: $sizeScale, in: 0.5...2)
                        .tint(VibeSyncColors.primary(for: colorScheme))
                        .accessibilityIdentifier("signature_pdf_size_slider")

                    Text("Rotation: \(Int(rotationDegrees.rounded()))°")
                        .vibeSyncStyle(.labelLarge)
                        .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                    Slider(value: $rotationDegrees, in: -180...180)
                        .tint(VibeSyncColors.primary(for: colorScheme))
                        .accessibilityIdentifier("signature_pdf_rotation_slider")

                    Button {
                        prepareSignedPDFExport()
                    } label: {
                        Label("Export flattened PDF", systemImage: "checkmark.seal")
                            .font(VibeSyncTypography.labelLarge)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VibeSyncColors.primary(for: colorScheme))
                    .disabled(placement == nil || exportDocument != nil && isExportingPDF)
                    .accessibilityIdentifier("signature_pdf_export_button")
                }
            } else {
                Text("No PDF selected.")
                    .vibeSyncStyle(.bodyMedium)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(VibeSyncColors.surfaceVariant(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(VibeSyncColors.surfaceVariant(for: colorScheme).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func importPDF(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            guard let document = PDFDocument(data: data), document.pageCount > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            guard !document.isLocked else {
                throw NSError(
                    domain: "VibeSyncSignaturePDF",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Unlock this password-protected PDF before adding a signature."]
                )
            }

            pdfDocument = document
            pdfFileName = url.deletingPathExtension().lastPathComponent
            pdfPageIndex = 0
            placement = nil
            sizeScale = 1
            rotationDegrees = 0
            exportDocument = nil
            statusMessage = "PDF loaded. Select a saved signature, then tap the page to place it."
            errorMessage = nil
        } catch {
            pdfDocument = nil
            placement = nil
            statusMessage = "The selected PDF could not be opened."
            errorMessage = error.localizedDescription
        }
    }

    private func prepareSignedPDFExport() {
        guard let pdfDocument, placement != nil, selectedImage != nil else {
            errorMessage = "Choose a PDF, select a saved signature, and tap the page before exporting."
            return
        }

        let options: [PDFDocumentWriteOption: Any] = [
            PDFDocumentWriteOption.burnInAnnotationsOption: true
        ]
        guard
            let flattenedData = pdfDocument.dataRepresentation(options: options),
            !flattenedData.isEmpty,
            let verifiedDocument = PDFDocument(data: flattenedData),
            verifiedDocument.pageCount == pdfDocument.pageCount
        else {
            errorMessage = "The signature could not be embedded into the PDF."
            return
        }

        let suggestedName = "\(pdfFileName)-signed.pdf"
        guard
            let stagedURI = IosPlatformProviders.shared.stageExportCopy(
                data: flattenedData as NSData,
                suggestedFileName: suggestedName
            ),
            let stagedURL = URL(string: stagedURI)
        else {
            errorMessage = "The signed PDF could not be staged for export."
            return
        }

        do {
            let stagedData = try Data(contentsOf: stagedURL)
            exportDocument = SignaturePDFExportDocument(data: stagedData)
            exportFileName = (suggestedName as NSString).deletingPathExtension
            errorMessage = nil
            isExportingPDF = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectSignature(_ signature: SignatureVault.SavedSignature) {
        do {
            guard let image = try vault.loadSignature(named: signature.id) else {
                throw SignatureVault.VaultError.imageEncodingFailed
            }
            selectedSignature = signature
            selectedImage = image
            placement = nil
            sizeScale = 1
            rotationDegrees = 0
            statusMessage = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSignatures() {
        do {
            signatures = try vault.listSignatures()
            thumbnails = [:]
            for signature in signatures {
                thumbnails[signature.id] = try vault.loadSignature(named: signature.id)
            }
            if let selectedSignature, !signatures.contains(selectedSignature) {
                self.selectedSignature = nil
                selectedImage = nil
                placement = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveNewSignature(_ image: UIImage) {
        let nextNumber = (1...max(1, signatures.count + 1)).first { number in
            !signatures.contains(where: { $0.id == "Signature \(number)" })
        } ?? signatures.count + 1
        let identifier = "Signature \(nextNumber)"
        do {
            try vault.saveSignature(image, named: identifier)
            refreshSignatures()
            let saved = SignatureVault.SavedSignature(id: identifier)
            selectedSignature = saved
            selectedImage = image
            placement = nil
            sizeScale = 1
            rotationDegrees = 0
            statusMessage = "Signature saved securely."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renameSelectedSignature() {
        guard let target = renameTarget else { return }
        do {
            if try vault.renameSignature(from: target.id, to: renameValue) {
                renameTarget = nil
                refreshSignatures()
                if let renamed = signatures.first(where: {
                    $0.id == renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }) {
                    selectSignature(renamed)
                }
            } else {
                errorMessage = "Enter a unique, non-empty signature name."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSelectedSignature() {
        guard let target = deleteTarget else { return }
        do {
            _ = try vault.deleteSignature(named: target.id)
            if selectedSignature?.id == target.id {
                selectedSignature = nil
                selectedImage = nil
                placement = nil
            }
            deleteTarget = nil
            refreshSignatures()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SignatureDrawingSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (UIImage) -> Void

    @State private var strokes: [[CGPoint]] = []
    @State private var activeStroke: [CGPoint] = []
    @State private var canvasSize = CGSize(width: 360, height: 220)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Draw your signature")
                    .vibeSyncStyle(.titleMedium)
                    .foregroundStyle(VibeSyncColors.textPrimary(for: .light))

                GeometryReader { geometry in
                    Canvas { context, _ in
                        for stroke in strokes + (activeStroke.isEmpty ? [] : [activeStroke]) {
                            guard let first = stroke.first else { continue }
                            var path = Path()
                            path.move(to: first)
                            for point in stroke.dropFirst() {
                                path.addLine(to: point)
                            }
                            context.stroke(
                                path,
                                with: .color(.black),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if activeStroke.isEmpty {
                                    activeStroke = [value.startLocation]
                                }
                                activeStroke.append(value.location)
                            }
                            .onEnded { _ in
                                if activeStroke.count >= 2 {
                                    strokes.append(activeStroke)
                                }
                                activeStroke = []
                            }
                    )
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    }
                    .accessibilityIdentifier("signature_drawing_canvas")
                    .onAppear {
                        canvasSize = geometry.size
                    }
                    .onChange(of: geometry.size) { newSize in
                        canvasSize = newSize
                    }
                }
                .frame(height: 220)

                Button("Clear") {
                    strokes = []
                    activeStroke = []
                }
                .buttonStyle(.bordered)
                .tint(VibeSyncColors.primary(for: .light))
                .accessibilityIdentifier("signature_clear_button")

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(VibeSyncColors.background(for: .light).ignoresSafeArea())
            .navigationTitle("Draw your signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Signature") {
                        let image = renderSignatureImage()
                        onSave(image)
                        dismiss()
                    }
                    .disabled(strokes.isEmpty)
                    .accessibilityIdentifier("signature_use_button")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func renderSignatureImage() -> UIImage {
        let size = canvasSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.clear(CGRect(origin: .zero, size: size))
            context.setStrokeColor(UIColor.black.cgColor)
            context.setLineWidth(4)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            for stroke in strokes {
                guard let first = stroke.first else { continue }
                context.beginPath()
                context.move(to: first)
                for point in stroke.dropFirst() {
                    context.addLine(to: point)
                }
                context.strokePath()
            }
        }
    }
}


private struct PDFSignaturePlacement {
    let pageIndex: Int
    let center: CGPoint
    let baseWidth: CGFloat
    let baseHeight: CGFloat

    func annotationBounds(
        pageBounds: CGRect,
        sizeScale: CGFloat,
        rotationDegrees: CGFloat
    ) -> (bounds: CGRect, imageSize: CGSize) {
        let imageWidth = max(1, baseWidth * sizeScale)
        let imageHeight = max(1, baseHeight * sizeScale)
        let radians = rotationDegrees * .pi / 180
        let envelopeWidth = abs(cos(radians)) * imageWidth + abs(sin(radians)) * imageHeight
        let envelopeHeight = abs(sin(radians)) * imageWidth + abs(cos(radians)) * imageHeight
        let halfWidth = envelopeWidth / 2
        let halfHeight = envelopeHeight / 2
        let safeCenter = CGPoint(
            x: min(max(center.x, pageBounds.minX + halfWidth), pageBounds.maxX - halfWidth),
            y: min(max(center.y, pageBounds.minY + halfHeight), pageBounds.maxY - halfHeight)
        )
        return (
            CGRect(
                x: safeCenter.x - halfWidth,
                y: safeCenter.y - halfHeight,
                width: envelopeWidth,
                height: envelopeHeight
            ),
            CGSize(width: imageWidth, height: imageHeight)
        )
    }
}

private struct SignaturePDFPreview: UIViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int
    let signatureImage: UIImage?
    let placement: PDFSignaturePlacement?
    let sizeScale: CGFloat
    let rotationDegrees: CGFloat
    let onTap: (Int, PDFPage, CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.displayBox = .cropBox
        pdfView.backgroundColor = .secondarySystemBackground
        pdfView.pageShadowsEnabled = true
        pdfView.document = document

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        pdfView.addGestureRecognizer(tap)
        context.coordinator.pdfView = pdfView
        context.coordinator.document = document
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
            pdfView.autoScales = true
        }
        context.coordinator.pdfView = pdfView
        context.coordinator.document = document
        context.coordinator.onTap = onTap

        if let page = document.page(at: min(max(0, pageIndex), document.pageCount - 1)),
           pdfView.currentPage !== page {
            pdfView.go(to: page)
        }

        context.coordinator.updatePreviewAnnotation(
            image: signatureImage,
            placement: placement,
            sizeScale: sizeScale,
            rotationDegrees: rotationDegrees
        )
    }

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        coordinator.removePreviewAnnotation()
        uiView.document = nil
    }

    final class Coordinator: NSObject {
        weak var pdfView: PDFView?
        weak var document: PDFDocument?
        var onTap: (Int, PDFPage, CGPoint) -> Void

        private weak var annotationPage: PDFPage?
        private var previewAnnotation: SignatureImageAnnotation?

        init(onTap: @escaping (Int, PDFPage, CGPoint) -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard
                let pdfView,
                let document,
                recognizer.state == .ended
            else { return }

            let viewPoint = recognizer.location(in: pdfView)
            guard
                let page = pdfView.page(for: viewPoint, nearest: true),
                document.index(for: page) != NSNotFound
            else { return }

            let pagePoint = pdfView.convert(viewPoint, to: page)
            onTap(document.index(for: page), page, pagePoint)
        }

        func updatePreviewAnnotation(
            image: UIImage?,
            placement: PDFSignaturePlacement?,
            sizeScale: CGFloat,
            rotationDegrees: CGFloat
        ) {
            guard
                let pdfView,
                let document,
                let image,
                let placement,
                let page = document.page(at: placement.pageIndex)
            else {
                removePreviewAnnotation()
                return
            }

            let pageBounds = page.bounds(for: .cropBox)
            let geometry = placement.annotationBounds(
                pageBounds: pageBounds,
                sizeScale: sizeScale,
                rotationDegrees: rotationDegrees
            )

            if let previewAnnotation, annotationPage === page {
                previewAnnotation.bounds = geometry.bounds
                previewAnnotation.imageSize = geometry.imageSize
                previewAnnotation.rotationDegrees = rotationDegrees
                previewAnnotation.signatureImage = image
            } else {
                removePreviewAnnotation()
                let annotation = SignatureImageAnnotation(
                    bounds: geometry.bounds,
                    signatureImage: image,
                    imageSize: geometry.imageSize,
                    rotationDegrees: rotationDegrees
                )
                page.addAnnotation(annotation)
                annotationPage = page
                previewAnnotation = annotation
            }
            pdfView.setNeedsDisplay()
        }

        func removePreviewAnnotation() {
            if let previewAnnotation, let annotationPage {
                annotationPage.removeAnnotation(previewAnnotation)
            }
            previewAnnotation = nil
            annotationPage = nil
            pdfView?.setNeedsDisplay()
        }
    }
}

private final class SignatureImageAnnotation: PDFAnnotation {
    var signatureImage: UIImage
    var imageSize: CGSize
    var rotationDegrees: CGFloat

    init(
        bounds: CGRect,
        signatureImage: UIImage,
        imageSize: CGSize,
        rotationDegrees: CGFloat
    ) {
        self.signatureImage = signatureImage
        self.imageSize = imageSize
        self.rotationDegrees = rotationDegrees
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
        shouldDisplay = true
        shouldPrint = true
    }

    required init?(coder: NSCoder) {
        signatureImage = UIImage()
        imageSize = .zero
        rotationDegrees = 0
        super.init(coder: coder)
    }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let cgImage = signatureImage.cgImage else { return }

        context.saveGState()
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.rotate(by: -rotationDegrees * .pi / 180)
        context.scaleBy(x: 1, y: -1)
        context.draw(
            cgImage,
            in: CGRect(
                x: -imageSize.width / 2,
                y: -imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            )
        )
        context.restoreGState()
    }
}

private struct SignaturePDFExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
