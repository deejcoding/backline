//
//  HomeView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct HomeView: View {
    
    //TODO: show listings and services nearby and based on previous searches
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("For You")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Your personalized feed is coming soon.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("Home")
        }
    }
}
