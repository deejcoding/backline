//
//  PhotoFullscreenView.swift
//  backline
//

import SwiftUI

struct PhotoFullscreenView: View {

    @Environment(\.dismiss) private var dismiss

    let photoURLs: [String]
    let startIndex: Int

    @State private var currentIndex: Int = 0
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, urlString in
                    if let url = URL(string: urlString) {
                        ZoomablePhoto(url: url)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photoURLs.count > 1 ? .automatic : .never))
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        if abs(value.translation.height) > 100 {
                            dismiss()
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = 0
                            }
                        }
                    }
            )

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }

            // Page indicator
            if photoURLs.count > 1 {
                VStack {
                    Spacer()
                    Text("\(currentIndex + 1) / \(photoURLs.count)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            currentIndex = startIndex
        }
        .statusBarHidden()
    }
}

// MARK: - Zoomable Photo

private struct ZoomablePhoto: View {

    let url: URL

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = lastScale * value.magnification
                        }
                        .onEnded { _ in
                            if scale < 1 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    scale = 1
                                    offset = .zero
                                }
                                lastScale = 1
                                lastOffset = .zero
                            } else if scale > 4 {
                                scale = 4
                                lastScale = 4
                            } else {
                                lastScale = scale
                            }
                        }
                )
                .simultaneousGesture(
                    scale > 1 ?
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                    : nil
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            lastScale = 1
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }
        } placeholder: {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
