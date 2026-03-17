//
//  CreateListingView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct CreateListingView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                Text("Create Listing")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Post gear for sale or offer your services.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("New Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
