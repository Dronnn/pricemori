import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportSummary: Identifiable {
    enum Kind: Equatable {
        case fullBackup
        case csv
    }

    let id = UUID()
    let kind: Kind
    let fileName: String
    let lines: [String]
    let info: String
}

struct BackupExportView: View {
    @EnvironmentObject private var router: AppRouter
    @AppStorage("lastBackupExport") private var lastBackupExport: Double = 0

    @State private var showExport = false
    @State private var showRestore = false

    private var lastExportText: String {
        guard lastBackupExport > 0 else { return "Last full backup exported: never" }
        return "Last full backup exported: \(Format.date(Date(timeIntervalSince1970: lastBackupExport)))"
    }

    var body: some View {
        ScreenScaffold(title: "Backup & export", backLabel: "Back", topPadding: 8) {
            VStack(alignment: .leading, spacing: 0) {
                InfoText(text: "Your journal is stored on this iPhone. Keep a full backup somewhere you can access later.")

                OpenRow(
                    title: "Export your journal",
                    subtitle: "Full backup for restoration\nCSV for a spreadsheet"
                ) {
                    showExport = true
                }
                .padding(.top, 18)

                SeparatorLine()

                OpenRow(
                    title: "Restore a full backup",
                    subtitle: "Choose a file, validate it and review changes\nMerge is the default"
                ) {
                    showRestore = true
                }

                SeparatorLine()

                InfoText(text: "\(lastExportText)\nThe app cannot check whether that copy still exists.")
                    .padding(.top, 18)
            }
        }
        .fullScreenCover(isPresented: $showExport) {
            ExportJournalView()
        }
        .fullScreenCover(isPresented: $showRestore) {
            RestoreBackupSheet()
        }
    }
}

struct ExportJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter

    @State private var showExporter = false
    @State private var document: DataDocument?
    @State private var exporterType: UTType = .json
    @State private var fileName = ""
    @State private var pendingKind: ExportSummary.Kind = .fullBackup
    @State private var summary: ExportSummary?
    @State private var exportFailure = false
    @State private var csvRows = 0

    var body: some View {
        ScreenScaffold(
            title: exportFailure ? "Export failed" : (summary == nil ? "Export journal" : (summary?.kind == .fullBackup ? "Backup exported" : "CSV exported")),
            backLabel: summary == nil ? "Cancel" : "Done",
            showsBackChevron: false,
            backAction: { dismiss() }
        ) {
            if exportFailure {
                failureContent
            } else if let summary {
                completionContent(summary)
            } else {
                optionsContent
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: document,
            contentType: exporterType,
            defaultFilename: fileName
        ) { result in
            switch result {
            case .success:
                if pendingKind == .fullBackup {
                    UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "lastBackupExport")
                    summary = ExportSummary(
                        kind: .fullBackup,
                        fileName: fileName,
                        lines: summaryLinesForFullBackup(),
                        info: "Keep the exported file safe. The app cannot check whether you move or delete it later."
                    )
                } else {
                    summary = ExportSummary(
                        kind: .csv,
                        fileName: fileName,
                        lines: ["\(csvRows) observation rows", "Includes branch, date, amount, units and conditions"],
                        info: "This CSV is for spreadsheets. Use a full backup to restore products, branches and settings together."
                    )
                }
            case .failure:
                exportFailure = true
            }
        }
    }

    private var failureContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The file was not saved")
                .font(AppFont.serif(32))
                .foregroundStyle(Theme.primaryText)
            InfoText(text: "There may not be enough free space, or the chosen destination is unavailable.")
            InfoText(text: "Your journal is safe on this device. No observations were removed.")
            PrimaryButton(title: "Try export again") {
                exportFailure = false
                if pendingKind == .fullBackup {
                    exportFullBackup()
                } else {
                    exportCSV()
                }
            }
            SecondaryButton(title: "Back to backup options") {
                exportFailure = false
            }
        }
    }

    private var optionsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Full backup · Restorable")
                    .font(AppFont.inter(17, .semibold))
                    .foregroundStyle(Theme.primaryText)
                Text("Products, branches, observations and settings\nIncludes archived data")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                PrimaryButton(title: "Export full backup") { exportFullBackup() }
                    .padding(.top, 8)
            }

            SeparatorLine()
                .padding(.vertical, 22)

            VStack(alignment: .leading, spacing: 8) {
                Text("CSV · For a spreadsheet")
                    .font(AppFont.inter(17, .semibold))
                    .foregroundStyle(Theme.primaryText)
                Text("Dated observations, units and conditions\nDoes not restore a complete journal")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                SecondaryButton(title: "Export CSV") { exportCSV() }
                    .padding(.top, 5)
            }

            InfoText(text: "Choose a format, then save or share the file using your iPhone.")
                .padding(.top, 28)
        }
    }

    private func completionContent(_ summary: ExportSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summary.kind == .fullBackup ? "Full backup exported" : "Observation table exported")
                .font(AppFont.serif(32))
                .foregroundStyle(Theme.primaryText)

            Text(summary.fileName)
                .font(AppFont.inter(15))
                .foregroundStyle(Theme.secondaryText)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(summary.lines, id: \.self) { line in
                    Text(line)
                }
            }
            .font(AppFont.inter(16))
            .foregroundStyle(Theme.primaryText)

            InfoText(text: summary.info)

            if summary.kind == .fullBackup {
                PrimaryButton(title: "Back to backup options") { self.summary = nil }
            } else {
                PrimaryButton(title: "Export a full backup") { exportFullBackup() }
            }
            SecondaryButton(title: "Open Journal") {
                dismiss()
                router.reset()
            }
        }
    }

    private func exportFullBackup() {
        do {
            let backup = try BackupService.makeBackup(context: context)
            document = DataDocument(data: try BackupService.encode(backup))
            exporterType = .json
            fileName = ExportNaming.backup()
            pendingKind = .fullBackup
            showExporter = true
        } catch {
            exportFailure = true
        }
    }

    private func exportCSV() {
        do {
            let csv = try CSVExport.makeData(context: context)
            csvRows = csv.rows
            document = DataDocument(data: csv.data)
            exporterType = .commaSeparatedText
            fileName = ExportNaming.csv()
            pendingKind = .csv
            showExporter = true
        } catch {
            exportFailure = true
        }
    }

    private func summaryLinesForFullBackup() -> [String] {
        let products = (try? context.fetchCount(FetchDescriptor<Product>())) ?? 0
        let stores = (try? context.fetchCount(FetchDescriptor<StoreLocation>())) ?? 0
        let observations = (try? context.fetchCount(FetchDescriptor<PriceObservation>())) ?? 0
        return [
            "\(products) products · \(stores) branches",
            "\(observations) observations · Archived data included"
        ]
    }
}
