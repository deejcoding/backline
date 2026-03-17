//
//  MarketplaceView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct MarketplaceView: View {
    var body: some View {
        NavigationStack {
            VStack {
                /* TODO: create a feed of boxes of listed items with the photo of listing and title of listing and location. */
                /* TODO: add search bar to search keywords. */
                /* TODO: add a filters menu to filter through categories like guitars, amps, miscellaneous, synthesizers, stringed instruments, etc. */
                Spacer()
                Image(systemName: "guitars")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Marketplace")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Browse gear and instruments near you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("Marketplace")
        }
    }
}
