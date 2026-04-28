//
//  ProfilePhotoCropView.swift
//  backline
//
//  Created by Khadija Aslam on 4/27/26.
//

import SwiftUI

/// A full-screen crop view that lets the user pan and zoom an image
/// behind a circular mask, then crops and returns the result.
struct ProfilePhotoCropView: View {

    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let circleSize = min(geo.size.width, geo.size.height) * 0.8

            ZStack {
                Color.black.ignoresSafeArea()

                // Movable / zoomable image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                },
                            MagnifyGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value.magnification
                                    scale = min(max(newScale, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                    )

                // Dark overlay with circular cutout
                CropOverlay(circleSize: circleSize)
                    .allowsHitTesting(false)

                // Circle border
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    .frame(width: circleSize, height: circleSize)
                    .allowsHitTesting(false)

                // Top bar
                VStack {
                    HStack {
                        Button("Cancel") {
                            onCancel()
                        }
                        .foregroundStyle(.white)

                        Spacer()

                        Button("Done") {
                            let cropped = cropImage(
                                viewSize: geo.size,
                                circleSize: circleSize
                            )
                            onCrop(cropped ?? image)
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Crop Logic

    private func cropImage(viewSize: CGSize, circleSize: CGFloat) -> UIImage? {
        let imageSize = image.size

        // How the image is displayed (scaledToFill)
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        var displayedWidth: CGFloat
        var displayedHeight: CGFloat

        if imageAspect > viewAspect {
            // Image wider than view
            displayedHeight = viewSize.height
            displayedWidth = displayedHeight * imageAspect
        } else {
            // Image taller than view
            displayedWidth = viewSize.width
            displayedHeight = displayedWidth / imageAspect
        }

        displayedWidth *= scale
        displayedHeight *= scale

        // Center of the circle in view coordinates
        let circleCenterX = viewSize.width / 2.0
        let circleCenterY = viewSize.height / 2.0

        // Center of the image in view coordinates
        let imageCenterX = viewSize.width / 2.0 + offset.width
        let imageCenterY = viewSize.height / 2.0 + offset.height

        // Circle top-left in image's displayed coordinates
        let circleOriginInImageX = circleCenterX - circleSize / 2.0 - (imageCenterX - displayedWidth / 2.0)
        let circleOriginInImageY = circleCenterY - circleSize / 2.0 - (imageCenterY - displayedHeight / 2.0)

        // Convert to actual image pixel coordinates
        let scaleX = imageSize.width / displayedWidth
        let scaleY = imageSize.height / displayedHeight

        let cropRect = CGRect(
            x: circleOriginInImageX * scaleX,
            y: circleOriginInImageY * scaleY,
            width: circleSize * scaleX,
            height: circleSize * scaleY
        )

        // Clamp to image bounds
        let clampedRect = cropRect.intersection(
            CGRect(origin: .zero, size: imageSize)
        )

        guard !clampedRect.isEmpty,
              let cgImage = image.cgImage?.cropping(to: clampedRect) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - Crop Overlay

/// Draws a dark overlay with a circular transparent hole.
private struct CropOverlay: View {
    let circleSize: CGFloat

    var body: some View {
        Canvas { context, size in
            // Full dark rectangle
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.55))
            )

            // Punch out the circle
            let circleRect = CGRect(
                x: (size.width - circleSize) / 2,
                y: (size.height - circleSize) / 2,
                width: circleSize,
                height: circleSize
            )
            context.blendMode = .destinationOut
            context.fill(
                Path(ellipseIn: circleRect),
                with: .color(.white)
            )
        }
        .compositingGroup()
    }
}
