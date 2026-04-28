//
//  ReportView.swift
//  backline
//
//  Created by Khadija Aslam on 4/20/26.
//

import SwiftUI

struct ReportView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(\.dismiss) private var dismiss

    let contentType: String   // "user", "listing", "isoPost", "service"
    let contentId: String
    let reportedUID: String

    private static let reasons = [
        "Spam",
        "Inappropriate content",
        "Harassment",
        "Scam or fraud",
        "Other"
    ]

    @State private var selectedReason = ""
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if didSubmit {
                    // Confirmation
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Report Submitted")
                        .font(.headline)
                    Text("Thanks for helping keep Backline safe. We'll review this report.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ThemeColor.blue)
                        .foregroundStyle(.white)
                        .clipShape(Rectangle())
                        .padding(.horizontal)
                } else {
                    // Report form
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Why are you reporting this?")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(Self.reasons, id: \.self) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                HStack {
                                    Text(reason)
                                        .font(.subheadline)
                                    Spacer()
                                    if selectedReason == reason {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundStyle(ThemeColor.blue)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                                .background(
                                    selectedReason == reason
                                        ? ThemeColor.blue.opacity(0.1)
                                        : Color(.systemGray6)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .foregroundStyle(.primary)
                        }

                        TextField("Additional details (optional)", text: $details, axis: .vertical)
                            .lineLimit(3...6)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button {
                        Task { await submitReport() }
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Submit Report")
                            }
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedReason.isEmpty ? Color.gray : ThemeColor.blue)
                        .foregroundStyle(.white)
                        .clipShape(Rectangle())
                    }
                    .disabled(selectedReason.isEmpty || isSubmitting)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submitReport() async {
        guard let uid = authManager.currentUser?.uid else { return }
        isSubmitting = true
        await listingManager.submitReport(
            reporterUID: uid,
            reportedUID: reportedUID,
            contentType: contentType,
            contentId: contentId,
            reason: selectedReason,
            details: details.trimmingCharacters(in: .whitespaces)
        )
        isSubmitting = false
        didSubmit = true
    }
}
