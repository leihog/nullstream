import Foundation

/// Maximum length for displayed video titles (avoids overflow in UI).
private let maxDisplayTitleLength = 60

struct Video: Identifiable, Codable, Equatable {
    let id: String
    var url: String
    var title: String?
    var thumbnailURL: String?

    init(url: String, title: String? = nil, thumbnailURL: String? = nil) {
        self.url = url
        self.id = url
        self.title = title
        self.thumbnailURL = thumbnailURL
    }

    /// Display name: title (capped) if set, otherwise the extracted video ID from the URL.
    var displayName: String {
        if let t = title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count <= maxDisplayTitleLength { return trimmed }
            return String(trimmed.prefix(maxDisplayTitleLength)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return Video.extractVideoId(from: url) ?? url
    }

    static func extractVideoId(from url: String) -> String? {
        let patterns = [
            "(?:youtube\\.com\\/watch\\?v=|youtu\\.be\\/|youtube\\.com\\/embed\\/)([^&?\\/]+)",
            "youtube\\.com\\/shorts\\/([^&?\\/]+)"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        return nil
    }
}

final class VideoStore: ObservableObject {
    @Published var videos: [Video] = []

    private let key = "savedVideos"

    init() {
        load()
    }

    /// URLs of videos that have no title yet (e.g. after migration). Used to trigger oEmbed fetch.
    func urlsNeedingMetadata() -> [String] {
        videos.filter { $0.title == nil }.map(\.url)
    }

    func add(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !videos.contains(where: { $0.url == trimmed }) else { return }
        videos.append(Video(url: trimmed))
        save()
    }

    func updateMetadata(url: String, title: String?, thumbnailURL: String?) {
        guard let index = videos.firstIndex(where: { $0.url == url }) else { return }
        videos[index].title = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        videos[index].thumbnailURL = thumbnailURL
        save()
    }

    func remove(at indexSet: IndexSet) {
        videos.remove(atOffsets: indexSet)
        save()
    }

    func remove(_ url: String) {
        videos.removeAll { $0.url == url }
        save()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Video].self, from: data) {
            videos = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(videos) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
