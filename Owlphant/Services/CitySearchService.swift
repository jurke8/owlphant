import Foundation

struct CitySuggestion: Decodable, Hashable, Identifiable {
    let name: String
    let admin1: String?
    let country: String?

    var label: String {
        [name, admin1, country]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    var id: String { label }
}

private struct CitySearchResponse: Decodable {
    let results: [CitySuggestion]?
}

enum CitySearchService {
    static func search(query: String) async -> [CitySuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=6&language=en&format=json") else {
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return [] }
            let payload = try JSONDecoder().decode(CitySearchResponse.self, from: data)
            return payload.results ?? []
        } catch {
            return []
        }
    }
}
