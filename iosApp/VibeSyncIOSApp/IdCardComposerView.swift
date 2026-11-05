import CoreGraphics
import Foundation
import ImageIO
import PhotosUI
import Shared
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum IDCardSide: String, Identifiable {
    case front
    case back

    var id: String { rawValue }
    var title: String { self == .front ? "Front" : "Back" }
    var pickLabel: String { self == .front ? "Pick front" : "Pick back" }
    var symbol: String { self == .front ? "person.text.rectangle" : "rectangle.on.rectangle" }
}

private struct IDCardPDFDocument: FileDocument {
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

/// Decodes gallery/camera data into a bounded raster before it is kept in view state.
/// 2480px is the Android 300-DPI A4 input ceiling used by the ID-card flow.
private enum IDCardImageDownsampler {
    static let MAX_INPUT_DIMENSION_300_DPI = 2480

    static func downsample(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: MAX_INPUT_DIMENSION_300_DPI
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return nil
        }

        return UIImage(cgImage: thumbnail, scale: 1, orientation: .up)
    }
}

/// A4 front/back layout matching Android IdCardComposer: 15 mm margins,
/// 10 mm between slots, centered images, and aspect-preserving fit.
private enum IDCardPDFComposer {
    private static let pageWidth: CGFloat = 595.2756
    private static let pageHeight: CGFloat = 841.8898
    private static let pointsPerMillimeter: CGFloat = 72 / 25.4
    private static let margin = 15 * pointsPerMillimeter
    private static let minimumGap = 10 * pointsPerMillimeter

    private struct Placement {
        let rect: CGRect
    }

    static func compose(front: UIImage, back: UIImage) throws -> Data {
        guard
            let frontCGImage = front.cgImage,
            let backCGImage = back.cgImage,
            frontCGImage.width > 0,
            frontCGImage.height > 0,
            backCGImage.width > 0,
            backCGImage.height > 0
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let slotHeight = (pageHeight - margin * 2 - minimumGap) / 2
        let topSlotBottom = margin + slotHeight + minimumGap
        let frontPlacement = placement(
            imageWidth: CGFloat(frontCGImage.width),
            imageHeight: CGFloat(frontCGImage.height),
            slotBottom: topSlotBottom,
            slotHeight: slotHeight
        )
        let backPlacement = placement(
            imageWidth: CGFloat(backCGImage.width),
            imageHeight: CGFloat(backCGImage.height),
            slotBottom: margin,
            slotHeight: slotHeight
        )

        let pageBounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let pdf = renderer.pdfData { context in
            context.beginPage()
            front.draw(in: frontPlacement.rect)
            back.draw(in: backPlacement.rect)
        }

        guard !pdf.isEmpty else {
            throw CocoaError(.fileWriteUnknown)
        }
        return pdf
    }

    private static func placement(
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        slotBottom: CGFloat,
        slotHeight: CGFloat
    ) -> Placement {
        let availableWidth = pageWidth - margin * 2
        let scale = min(availableWidth / imageWidth, slotHeight / imageHeight)
        let drawWidth = imageWidth * scale
        let drawHeight = imageHeight * scale
        let x = (pageWidth - drawWidth) / 2
        let yFromBottom = slotBottom + (slotHeight - drawHeight) / 2
        let yFromTop = pageHeight - (yFromBottom + drawHeight)

        return Placement(
            rect: CGRect(x: x, y: yFromTop, width: drawWidth, height: drawHeight)
        )
    }
}

struct IdCardComposerView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var sourceChooserSide: IDCardSide?
    @State private var activeCameraSide: IDCardSide?
    @State private var activeGallerySide: IDCardSide?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isGalleryPickerPresented = false
    @State private var isLoadingImage = false
    @State private var isSaving = false
    @State private var isExportingPDF = false
    @State private var exportDocument: IDCardPDFDocument?
    @State private var exportFileName = "ID_Card"
    @State private var stagedExportURL: URL?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick the front and back of one card. Both sides are fitted onto one A4 PDF page without stretching.")
                    .vibeSyncStyle(.bodyMedium)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))

                HStack(alignment: .top, spacing: 10) {
                    imageSlot(for: .front)
                    imageSlot(for: .back)
                }

                VStack(spacing: 14) {
                    previewImage(frontImage, accessibilityLabel: "Front")
                    previewImage(backImage, accessibilityLabel: "Back")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .aspectRatio(595.2756 / 841.8898, contentMode: .fit)
                .background(VibeSyncColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }
                .accessibilityIdentifier("id_card_layout_preview")

                Text(
                    frontImage == nil || backImage == nil
                    ? "Choose exactly two images: one front and one back."
                    : "Both sides are ready. Preview the layout, then save the PDF."
                )
                .vibeSyncStyle(.bodyMedium)
                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                .accessibilityIdentifier("id_card_guidance")

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

                Button(action: saveA4PDF) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(VibeSyncColors.white)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isSaving ? "Preparing PDF…" : "Save A4 PDF")
                            .font(VibeSyncTypography.labelLarge)
                            .lineSpacing(6)
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(VibeSyncColors.primary(for: colorScheme))
                .disabled(frontImage == nil || backImage == nil || isSaving || isLoadingImage)
                .accessibilityIdentifier("id_card_save")
            }
            .padding(16)
        }
        .background(VibeSyncColors.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle("ID Card Composer")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            sourceChooserSide.map { "Choose \($0.title.lowercased()) image source" } ?? "Choose image source",
            isPresented: Binding(
                get: { sourceChooserSide != nil },
                set: { if !$0 { sourceChooserSide = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Camera") {
                guard let side = sourceChooserSide else { return }
                sourceChooserSide = nil
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    errorMessage = "Camera is unavailable on this device. Choose Gallery instead."
                    return
                }
                activeCameraSide = side
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            Button("Gallery") {
                activeGallerySide = sourceChooserSide
                sourceChooserSide = nil
                isGalleryPickerPresented = true
            }

            Button("Cancel", role: .cancel) {
                sourceChooserSide = nil
            }
        }
        .photosPicker(
            isPresented: $isGalleryPickerPresented,
            selection: $photoPickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: photoPickerItem) { item in
            guard let item, let side = activeGallerySide else { return }
            Task {
                await loadGalleryImage(item, for: side)
            }
        }
        .sheet(item: $activeCameraSide) { side in
            CameraCaptureView(
                onImageCaptured: { image in
                    activeCameraSide = nil
                    loadCameraImage(image, for: side)
                },
                onCancel: {
                    activeCameraSide = nil
                }
            )
            .ignoresSafeArea()
        }
        .fileExporter(
            isPresented: $isExportingPDF,
            document: exportDocument,
            contentType: .pdf,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                statusMessage = "ID card PDF saved."
                errorMessage = nil
            case .failure(let error):
                statusMessage = nil
                errorMessage = "Could not save the ID card PDF: \(error.localizedDescription)"
            }
            if let stagedExportURL {
                try? FileManager.default.removeItem(at: stagedExportURL)
                self.stagedExportURL = nil
            }
        }
        .tint(VibeSyncColors.primary(for: colorScheme))
    }

    private func imageSlot(for side: IDCardSide) -> some View {
        let image = side == .front ? frontImage : backImage

        return VStack(spacing: 10) {
            Text(side.title)
                .vibeSyncStyle(.titleMedium)
                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(VibeSyncColors.white)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: side.symbol)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(VibeSyncColors.secondary(for: colorScheme).opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)

            Button {
                sourceChooserSide = side
            } label: {
                Label(side.pickLabel, systemImage: "photo.badge.plus")
                    .font(VibeSyncTypography.labelLarge)
                            .lineSpacing(6)
                            .tracking(0.5)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(VibeSyncColors.primary(for: colorScheme))
            .disabled(isLoadingImage)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(VibeSyncColors.surfaceVariant(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func previewImage(_ image: UIImage?, accessibilityLabel: String) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(accessibilityLabel)
        } else {
            Spacer(minLength: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @MainActor
    private func loadGalleryImage(_ item: PhotosPickerItem, for side: IDCardSide) async {
        isLoadingImage = true
        defer {
            isLoadingImage = false
            photoPickerItem = nil
            activeGallerySide = nil
        }

        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = IDCardImageDownsampler.downsample(data)
            else {
                throw CocoaError(.fileReadCorruptFile)
            }
            setImage(image, for: side)
        } catch {
            errorMessage = "Could not load the selected image: \(error.localizedDescription)"
        }
    }

    private func loadCameraImage(_ image: UIImage, for side: IDCardSide) {
        guard
            let data = image.jpegData(compressionQuality: 0.94),
            let downsampled = IDCardImageDownsampler.downsample(data)
        else {
            errorMessage = "Could not process the captured image."
            return
        }
        setImage(downsampled, for: side)
    }

    private func setImage(_ image: UIImage, for side: IDCardSide) {
        if side == .front {
            frontImage = image
        } else {
            backImage = image
        }
        errorMessage = nil
        statusMessage = nil
    }

    private func saveA4PDF() {
        guard let frontImage, let backImage else { return }
        isSaving = true
        errorMessage = nil
        statusMessage = nil

        do {
            let pdfData = try IDCardPDFComposer.compose(front: frontImage, back: backImage)
            guard
                let stagedURI = IosPlatformProviders.shared.stageExportCopy(
                    data: pdfData,
                    suggestedFileName: "ID_Card.pdf"
                ),
                let stagedURL = URL(string: stagedURI)
            else {
                throw CocoaError(.fileWriteUnknown)
            }

            let stagedData = try Data(contentsOf: stagedURL)
            stagedExportURL = stagedURL
            exportDocument = IDCardPDFDocument(data: stagedData)
            exportFileName = "ID_Card"
            isSaving = false
            isExportingPDF = true
        } catch {
            isSaving = false
            errorMessage = "Could not create the ID card PDF: \(error.localizedDescription)"
        }
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImageCaptured: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onImageCaptured: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImageCaptured = onImageCaptured
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
