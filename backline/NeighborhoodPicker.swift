//
//  NeighborhoodPicker.swift
//  backline
//
//  Created by Khadija Aslam on 5/21/26.
//

import SwiftUI

// MARK: - NYC Neighborhoods

enum NYCNeighborhoods {

    static let all: [(borough: String, neighborhoods: [String])] = [
        ("Manhattan", [
            "Alphabet City", "Battery Park City", "Chelsea", "Chinatown",
            "East Harlem", "East Village", "Financial District",
            "Flatiron District", "Gramercy Park", "Greenwich Village",
            "Hamilton Heights", "Harlem", "Hell's Kitchen",
            "Inwood", "Kips Bay", "Lenox Hill",
            "Little Italy", "Lower East Side", "Marble Hill",
            "Midtown East", "Midtown West", "Morningside Heights",
            "Murray Hill", "NoHo", "Nolita",
            "Roosevelt Island", "SoHo", "Stuyvesant Town",
            "Theater District", "Tribeca", "Two Bridges",
            "Upper East Side", "Upper West Side",
            "Washington Heights", "West Village", "Yorkville"
        ]),
        ("Brooklyn", [
            "Bay Ridge", "Bedford-Stuyvesant", "Bensonhurst",
            "Bergen Beach", "Boerum Hill", "Borough Park",
            "Brighton Beach", "Brooklyn Heights", "Brownsville",
            "Bushwick", "Canarsie", "Carroll Gardens",
            "Clinton Hill", "Cobble Hill", "Coney Island",
            "Crown Heights", "Cypress Hills", "DUMBO",
            "Ditmas Park", "Downtown Brooklyn", "Dyker Heights",
            "East Flatbush", "East New York", "East Williamsburg",
            "Flatbush", "Flatlands", "Fort Greene",
            "Fort Hamilton", "Gowanus", "Gravesend",
            "Greenpoint", "Greenwood Heights", "Kensington",
            "Marine Park", "Midwood", "Mill Basin",
            "Park Slope", "Prospect Heights", "Prospect Lefferts Gardens",
            "Prospect Park South", "Red Hook", "Sheepshead Bay",
            "South Slope", "Sunset Park", "Vinegar Hill",
            "Williamsburg", "Windsor Terrace"
        ]),
        ("Queens", [
            "Astoria", "Bayside", "Bellerose",
            "Briarwood", "College Point", "Corona",
            "Douglaston", "East Elmhurst", "Elmhurst",
            "Far Rockaway", "Flushing", "Forest Hills",
            "Fresh Meadows", "Glendale", "Howard Beach",
            "Jackson Heights", "Jamaica", "Kew Gardens",
            "Long Island City", "Maspeth", "Middle Village",
            "Ozone Park", "Rego Park", "Richmond Hill",
            "Ridgewood", "Rockaway Beach", "Rosedale",
            "South Ozone Park", "Sunnyside", "Whitestone",
            "Woodhaven", "Woodside"
        ]),
        ("Bronx", [
            "Belmont", "Castle Hill", "City Island",
            "Clason Point", "Co-op City", "Concourse Village",
            "Country Club", "Eastchester", "Fordham",
            "High Bridge", "Hunts Point", "Kingsbridge",
            "Melrose", "Morris Heights", "Morris Park",
            "Morrisania", "Mott Haven", "Norwood",
            "Parkchester", "Pelham Bay", "Pelham Parkway",
            "Port Morris", "Riverdale", "Soundview",
            "South Bronx", "Throgs Neck", "Tremont",
            "University Heights", "Van Nest", "Wakefield",
            "West Farms", "Williamsbridge", "Woodlawn"
        ]),
        ("Staten Island", [
            "Arden Heights", "Annadale", "Bulls Head",
            "Castleton Corners", "Dongan Hills", "Eltingville",
            "Graniteville", "Grant City", "Great Kills",
            "Grymes Hill", "Huguenot", "Mariners Harbor",
            "New Brighton", "New Dorp", "Oakwood",
            "Port Richmond", "Rosebank", "Rossville",
            "South Beach", "St. George", "Stapleton",
            "Todt Hill", "Tottenville", "Travis",
            "West Brighton", "Westerleigh"
        ]),
    ]

    /// Flat list of "Neighborhood, Borough" strings for searching.
    static let flatList: [String] = {
        all.flatMap { group in
            group.neighborhoods.map { "\($0), \(group.borough)" }
        }
    }()
}

// MARK: - Neighborhood Picker View

struct NeighborhoodPickerView: View {

    @Binding var selectedNeighborhood: String
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredNeighborhoods: [String] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return NYCNeighborhoods.flatList.filter { $0.lowercased().contains(query) }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColor.cyan)

                TextField("Search neighborhoods...", text: $searchText)
                    .font(.system(size: 13, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _, newValue in
                        // If user clears or types something that doesn't match selection, clear selection
                        if !NYCNeighborhoods.flatList.contains(newValue) && !newValue.isEmpty {
                            // Only clear if they're actively editing away from a prior selection
                            if selectedNeighborhood == newValue {
                                // still matches, do nothing
                            }
                        }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        selectedNeighborhood = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .overlay(
                Rectangle()
                    .stroke(
                        selectedNeighborhood.isEmpty ? .white.opacity(0.15) : ThemeColor.cyan.opacity(0.5),
                        lineWidth: 1
                    )
            )

            // Selected indicator
            if !selectedNeighborhood.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ThemeColor.green)
                    Text(selectedNeighborhood)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        selectedNeighborhood = ""
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(ThemeColor.green.opacity(0.1))
            }

            // Autocomplete results
            if !filteredNeighborhoods.isEmpty && selectedNeighborhood.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filteredNeighborhoods.prefix(8)), id: \.self) { neighborhood in
                            Button {
                                selectedNeighborhood = neighborhood
                                searchText = neighborhood
                                isSearchFocused = false
                            } label: {
                                HStack {
                                    Text(neighborhood)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if neighborhood != filteredNeighborhoods.prefix(8).last {
                                Divider()
                                    .background(.white.opacity(0.08))
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
                .background(Color.white.opacity(0.04))
                .overlay(
                    Rectangle()
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .onAppear {
            if !selectedNeighborhood.isEmpty {
                searchText = selectedNeighborhood
            }
        }
    }
}
