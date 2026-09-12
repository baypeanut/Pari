import Foundation

/// Feed content can become private after it was downloaded. Do not persist it.
/// Remove caches written by earlier app versions without touching other files.
enum FeedCache {
    static func clearLegacyFiles(directory: URL? = FileManager.default.urls(
        for: .cachesDirectory, in: .userDomainMask).first) {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let name = file.lastPathComponent
            if name.hasSuffix(".json") &&
                (name.hasPrefix("pari_feed_global_") || name.hasPrefix("pari_feed_following_")) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
