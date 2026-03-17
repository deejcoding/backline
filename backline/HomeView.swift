//
//  HomeView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "house.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("For You")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Your personalized feed is coming soon.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("Home")
        }
    }
}
