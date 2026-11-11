import SwiftData

extension ModelContext {
    /// A failed mutation must never be presented as a successful saved record.
    @MainActor
    func saveReportingError(_ failed: inout Bool) -> Bool {
        do {
            try save()
            return true
        } catch {
            rollback()
            failed = true
            return false
        }
    }
}
