import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private struct SignedPDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    let data: Data

    init(data: Data) { self.data = data }

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
    @State private var isExportingSignedPDF = false
    @State private var isEmbeddingSignature = false
    @State private var sourcePDFData: Data?
    @State private var sourcePDFName = "document"
    @State private var sourcePDFPageCount = 0
    @State private var currentPDFPage = 0
    @State private var pdfPagePreview: UIImage?
    @State private var pdfPageSize = CGSize(width: 612, height: 792)
    @State private var signedPDFDocument: SignedPDFDocument?
    @State private var signedPDFFileName = "document-signed"

    @State private var normalizedCenter = CGPoint(x: 0.5, y: 0.5)
    @State private var dragStartCenter = CGPoint(x: 0.5, y: 0.5)
    @State private var signatureWidthFraction = 0.28
    @State private var rotationDegrees: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manage and place saved signatures.")
                    .vibeSyncStyle(.bodyMedium)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))

                Button {
                    isImportingPDF = true
                } label: {
                    Label(sourcePDFData == nil ? "Choose PDF to sign" : "Change PDF", systemImage: "doc.badge.plus")
                        .font(VibeSyncTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(VibeSyncColors.primary(for: colorScheme))
                .accessibilityIdentifier("signature_choose_pdf")

                if sourcePDFData != nil {
                    Text("PDF ready · page \(currentPDFPage + 1) of \(sourcePDFPageCount)")
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.successGreen)
                }

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

                if let selectedImage {
                    placementControls(for: selectedImage)
                }

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
        .fileImporter(
            isPresented: $isImportingPDF,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            importPDFForSigning(result)
        }
        .fileExporter(
            isPresented: $isExportingSignedPDF,
            document: signedPDFDocument,
            contentType: .pdf,
            defaultFilename: signedPDFFileName
        ) { result in
            switch result {
            case .success:
                statusMessage = "Signature embedded in the PDF and saved."
                errorMessage = nil
            case .failure(let error):
                statusMessage = nil
                errorMessage = "The signed PDF was not saved: \(error.localizedDescription)"
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

    private func placementControls(for image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Drag the signature into position on the selected PDF page. Adjust its size and rotation, then embed it.")
                .vibeSyncStyle(.bodyMedium)
                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))

            if let pdfPagePreview {
                GeometryReader { geometry in
                    let imageAspect = max(image.size.width / max(image.size.height, 1), 0.1)
                    ZStack {
                        Image(uiImage: pdfPagePreview)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: geometry.size.width * CGFloat(signatureWidthFraction),
                                height: geometry.size.width * CGFloat(signatureWidthFraction) / imageAspect
                            )
                            .rotationEffect(.degrees(rotationDegrees))
                            .position(
                                x: normalizedCenter.x * geometry.size.width,
                                y: normalizedCenter.y * geometry.size.height
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let nextX = dragStartCenter.x + value.translation.width / max(geometry.size.width, 1)
                                        let nextY = dragStartCenter.y + value.translation.height / max(geometry.size.height, 1)
                                        normalizedCenter = CGPoint(
                                            x: min(max(nextX, 0.04), 0.96),
                                            y: min(max(nextY, 0.04), 0.96)
                                        )
                                    }
                                    .onEnded { _ in
                                        dragStartCenter = normalizedCenter
                                    }
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    }
                }
                .aspectRatio(pdfPageSize.width / max(pdfPageSize.height, 1), contentMode: .fit)
                .accessibilityIdentifier("signature_placement_canvas")

                if sourcePDFPageCount > 1 {
                    Stepper(
                        "PDF page \(currentPDFPage + 1) of \(sourcePDFPageCount)",
                        value: $currentPDFPage,
                        in: 0...(sourcePDFPageCount - 1)
                    )
                    .onChange(of: currentPDFPage) { _ in
                        updateSigningPagePreview()
                    }
                }
            }

            Text("Signature size")
                .vibeSyncStyle(.labelLarge)
                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
            Slider(value: $signatureWidthFraction, in: 0.12...0.65)
                .tint(VibeSyncColors.primary(for: colorScheme))
                .accessibilityIdentifier("signature_size_slider")

            Text("Rotation: \(Int(rotationDegrees.rounded()))°")
                .vibeSyncStyle(.labelLarge)
                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
            Slider(value: $rotationDegrees, in: -180...180)
                .tint(VibeSyncColors.primary(for: colorScheme))
                .accessibilityIdentifier("signature_rotation_slider")

            Button {
                embedSignatureInPDF(image)
            } label: {
                HStack(spacing: 8) {
                    if isEmbeddingSignature {
                        ProgressView().tint(VibeSyncColors.white)
                    } else {
                        Image(systemName: "checkmark.seal")
                    }
                    Text(isEmbeddingSignature ? "Embedding…" : "Place signature in PDF")
                        .font(VibeSyncTypography.labelLarge)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VibeSyncColors.primary(for: colorScheme))
            .disabled(sourcePDFData == nil || pdfPagePreview == nil || isEmbeddingSignature)
            .accessibilityIdentifier("signature_place_button")
        }
    }

    private func importPDFForSigning(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasScope { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            guard let document = PDFDocument(data: data), document.pageCount > 0 else {
                throw SignaturePDFExporter.ExportError.unreadablePDF
            }
            guard !document.isLocked else {
                throw SignaturePDFExporter.ExportError.lockedPDF
            }

            sourcePDFData = data
            sourcePDFName = url.deletingPathExtension().lastPathComponent
            sourcePDFPageCount = document.pageCount
            currentPDFPage = 0
            normalizedCenter = CGPoint(x: 0.5, y: 0.5)
            dragStartCenter = normalizedCenter
            signatureWidthFraction = 0.28
            rotationDegrees = 0
            updateSigningPagePreview()
            statusMessage = "PDF loaded. Select a saved signature to place it on the page."
            errorMessage = nil
        } catch {
            sourcePDFData = nil
            sourcePDFPageCount = 0
            pdfPagePreview = nil
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func updateSigningPagePreview() {
        guard let sourcePDFData else { return }
        do {
            let preview = try SignaturePDFExporter.pagePreview(from: sourcePDFData, pageIndex: currentPDFPage)
            pdfPagePreview = preview.image
            pdfPageSize = preview.size
        } catch {
            pdfPagePreview = nil
            errorMessage = error.localizedDescription
        }
    }

    private func embedSignatureInPDF(_ image: UIImage) {
        guard let sourcePDFData else {
            errorMessage = "Choose a PDF before placing the signature."
            return
        }
        isEmbeddingSignature = true
        defer { isEmbeddingSignature = false }

        do {
            let signedData = try SignaturePDFExporter.addingSignature(
                to: sourcePDFData,
                signature: image,
                pageIndex: currentPDFPage,
                normalizedCenter: normalizedCenter,
                widthFraction: CGFloat(signatureWidthFraction),
                rotationDegrees: CGFloat(rotationDegrees)
            )
            signedPDFDocument = SignedPDFDocument(data: signedData)
            signedPDFFileName = "\(sourcePDFName)-signed"
            statusMessage = "Signature embedded into the PDF. Choose where to save the signed copy."
            errorMessage = nil
            isExportingSignedPDF = true
        } catch {
            statusMessage = nil
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
            normalizedCenter = CGPoint(x: 0.5, y: 0.5)
            dragStartCenter = normalizedCenter
            signatureWidthFraction = 0.28
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
            normalizedCenter = CGPoint(x: 0.5, y: 0.5)
            dragStartCenter = normalizedCenter
            signatureWidthFraction = 0.28
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
