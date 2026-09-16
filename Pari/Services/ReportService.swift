//
//  ReportService.swift
//  Pari
//
//  Submits user reports to the `reports` Supabase table.
//  Apple App Store Section 1.2 requirement for UGC apps.
//
//  Backend contract: 20260916000001_moderation_contract.sql.
//

import Foundation
import Supabase

enum ReportReason: String, CaseIterable, Identifiable {
    case spam = "spam"
    case inappropriate = "inappropriate"
    case harassment = "harassment"
    case misinformation = "misinformation"
    case underage = "underage"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .inappropriate: return "Inappropriate content"
        case .harassment: return "Harassment"
        case .misinformation: return "Misinformation"
        case .underage: return "Underage content"
        case .other: return "Other"
        }
    }
}

enum ReportContentType: String {
    case post = "post"
    case comment = "comment"
    case user = "user"
}

enum ReportService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// Submit a content report. Requires an authenticated session.
    static func submitReport(
        contentType: ReportContentType,
        contentId: UUID,
        reportedUserId: UUID,
        reason: ReportReason
    ) async throws {
        guard let reporterId = await AuthService.currentUserId() else { return }
        struct Insert: Encodable {
            let reporter_id: String
            let content_type: String
            let content_id: String
            let reported_user_id: String
            let reason: String
        }
        let payload = Insert(
            reporter_id: reporterId.uuidString,
            content_type: contentType.rawValue,
            content_id: contentId.uuidString,
            reported_user_id: reportedUserId.uuidString,
            reason: reason.rawValue
        )
        try await supabase
            .from("reports")
            .insert(payload)
            .execute()
    }
}
