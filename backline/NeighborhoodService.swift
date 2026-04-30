//
//  NeighborhoodService.swift
//  backline
//
//  Created by Khadija Aslam on 4/30/26.
//

import Foundation

/// Queries the NYC Neighborhood Tabulation Areas ArcGIS API to detect
/// which neighborhood a coordinate falls within.
enum NeighborhoodService {

    enum NeighborhoodError: LocalizedError {
        case invalidURL
        case notInNYC
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid request URL."
            case .notInNYC: return "Location is outside NYC."
            case .networkError(let err): return err.localizedDescription
            }
        }
    }

    /// Returns `"NeighborhoodName, Borough"` (e.g. `"Williamsburg, Brooklyn"`)
    /// for the given WGS84 coordinate, or throws if the point is outside NYC.
    static func detectNeighborhood(lat: Double, lng: Double) async throws -> String {
        let base = "https://services5.arcgis.com/GfwWNkhOj9bNBqoJ/arcgis/rest/services/NYC_Neighborhood_Tabulation_Areas_2020/FeatureServer/0/query"

        var components = URLComponents(string: base)
        components?.queryItems = [
            URLQueryItem(name: "geometry", value: "\(lng),\(lat)"),
            URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
            URLQueryItem(name: "inSR", value: "4326"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "NTAName,BoroName"),
            URLQueryItem(name: "returnGeometry", value: "false"),
            URLQueryItem(name: "f", value: "json"),
        ]

        guard let url = components?.url else {
            throw NeighborhoodError.invalidURL
        }

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            throw NeighborhoodError.networkError(error)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let features = json?["features"] as? [[String: Any]],
              let first = features.first,
              let attrs = first["attributes"] as? [String: Any],
              let ntaName = attrs["NTAName"] as? String,
              let boroName = attrs["BoroName"] as? String else {
            throw NeighborhoodError.notInNYC
        }

        return "\(ntaName), \(boroName)"
    }
}
