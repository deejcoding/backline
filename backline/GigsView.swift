//
//  GigsView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct GigsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "music.mic")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Gigs")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Find bandmates, session musicians, and services.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("Gigs")
        }
    }
}
