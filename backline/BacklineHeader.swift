//
//  BacklineHeader.swift
//  backline
//
//  Created by Khadija Aslam on 4/28/26.
//

import SwiftUI

// MARK: - Backline Wordmark Header

/// Broadcast-style header with "backline" wordmark and icon buttons.
struct BacklineHeader: View {

    var showMessages: Bool = false
    var unreadCount: Int = 0
    var profilePhotoURL: String? = nil

    var body: some View {
        HStack {
            // Brand: wordmark
            Text("backline")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .tracking(-0.2)

            Spacer()

            // Right side icons
            HStack(spacing: 8) {
                if showMessages {
                    NavigationLink {
                        ConversationsView()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 13))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Rectangle()
                                        .stroke(ThemeColor.subtleBorder, lineWidth: 1)
                                )

                            if unreadCount > 0 {
                                Circle()
                                    .fill(ThemeColor.red)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .accessibilityLabel(unreadCount > 0 ? "\(unreadCount) unread messages" : "Messages")
                }

                if let urlString = profilePhotoURL, let url = URL(string: urlString) {
                    NavigationLink(value: ProfileDestination(uid: "", username: "")) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray5))
                        }
                        .frame(width: 32, height: 32)
                        .clipped()
                        .overlay(
                            Rectangle()
                                .stroke(ThemeColor.subtleBorder, lineWidth: 1)
                        )
                    }
                    .disabled(true)
                    .opacity(0) // Hidden — profile is a tab
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ThemeColor.hairline)
                .frame(height: 1)
        }
    }
}

// MARK: - Section Header (Broadcast style)

struct BroadcastSectionHeader: View {
    let label: String
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.15)

            Spacer()

            if let trailing {
                if let action = trailingAction {
                    Button(action: action) {
                        Text("\(trailing) ›")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                            .tracking(0.4)
                    }
                } else {
                    Text("\(trailing) ›")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                        .tracking(0.4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}

// MARK: - Broadcast Filter Chip

struct BroadcastChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.4)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? .white : .clear)
                .foregroundStyle(isSelected ? Color(hex: 0x0A0A0A) : .white.opacity(0.7))
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? .white : .white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Monospace Metadata Text

extension View {
    func monoCaption(_ color: Color = .white.opacity(0.65)) -> some View {
        self
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
    }

    func monoLabel() -> some View {
        self
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.0)
    }
}
