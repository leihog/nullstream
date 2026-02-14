import Foundation

/// Response from YouTube's oEmbed API
struct YouTubeOEmbedResponse: Decodable {
    let title: String?
    let type: String?
    let thumbnailUrl: String?
    let thumbnailHeight: Int?
    let thumbnailWidth: Int?

    enum CodingKeys: String, CodingKey {
        case title, type
        case thumbnailUrl = "thumbnail_url"
        case thumbnailHeight = "thumbnail_height"
        case thumbnailWidth = "thumbnail_width"
    }
}

/// Fetches video metadata from YouTube's oEmbed API.
/// - Parameter videoUrl: Full YouTube video URL (e.g. https://www.youtube.com/watch?v=...)
/// - Returns: oEmbed response with title, thumbnail, etc., or throws on network/decoding error.
func fetchOEmbed(videoUrl: String) async throws -> YouTubeOEmbedResponse {
    var components = URLComponents(string: "https://www.youtube.com/oembed")!
    components.queryItems = [
        URLQueryItem(name: "format", value: "json"),
        URLQueryItem(name: "url", value: videoUrl)
    ]
    guard let url = components.url else {
        throw OEmbedError.invalidURL
    }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        throw OEmbedError.badResponse
    }
    let decoder = JSONDecoder()
    return try decoder.decode(YouTubeOEmbedResponse.self, from: data)
}

enum OEmbedError: Error {
    case invalidURL
    case badResponse
}
