//
//  MomentStorageService.swift
//  Pari
//
//  Upload "wine night" photo for feed. Path: moment_images/{userId}/{uuid}.jpg
//

import Foundation
import Supabase

enum MomentStorageService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    private static let bucket = "moment_images"
    private static let contentType = "image/jpeg"

    /// Store an object reference. Reading it always requires current authorization.
    static func uploadMoment(userId: UUID, jpegData: Data) async throws -> String {
        let name = "\(userId.uuidString)/\(UUID().uuidString).jpg"
        _ = try await supabase.storage
            .from(bucket)
            .upload(
                name,
                data: jpegData,
                options: FileOptions(contentType: contentType, upsert: false)
            )
        return name
    }

    static func objectPath(from reference: String) -> String? {
        let marker = "/storage/v1/object/public/\(bucket)/"
        let path: String
        if let range = reference.range(of: marker) {
            path = String(reference[range.upperBound...])
        } else {
            path = reference
        }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, UUID(uuidString: String(parts[0])) != nil,
              !parts[1].isEmpty, !path.contains(".."),
              !path.contains("?"), !path.contains("#"), !path.contains("%") else { return nil }
        return path
    }

    static func downloadMoment(reference: String) async throws -> Data {
        guard let path = objectPath(from: reference) else { throw URLError(.badURL) }
        return try await supabase.storage.from(bucket).download(path: path)
    }
}
