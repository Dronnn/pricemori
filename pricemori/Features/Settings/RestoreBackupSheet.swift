import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RestoreBackupSheet: View {
    private enum Stage {
        case choose
        case review(MergePlan)
        case conflicts(MergePlan)
        case ready(MergePlan)
        case replace(MergePlan)
        case confirm(MergePlan, String)
        case complete(ImportResult)
        case error(String)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter

    @State private var stage: Stage = .choose
    @State private var showFileImporter = false
    @State private var choices: [UUID: ConflictChoice] = [:]
    @State private var showSafetyExporter = false
    @State private var safetyDocument: DataDocument?
    @State private var exportFailed = false

    var body: some View {
        ScreenScaffold(
            title: headerTitle,
            backLabel: backLabel,
            showsBackChevron: backLabel != "Cancel",
            backAction: goBack,
            footer: { footer }
        ) {
            content
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
            handleFile(result)
        }
        .fileExporter(
            isPresented: $showSafetyExporter,
            document: safetyDocument,
            contentType: .json,
            defaultFilename: ExportNaming.safetyBackup()
        ) { result in
            switch result {
            case .success(let url):
                if case .replace(let plan) = stage {
                    let name = url.lastPathComponent
                    UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "lastBackupExport")
                    stage = .confirm(plan, name)
                }
            case .failure:
                exportFailed = true
            }
        }
        .alert("Export failed", isPresented: $exportFailed) {
            Button("Try export again") { exportSafetyBackup() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("There may not be enough free space, or the chosen destination is unavailable. Your journal is safe on this device. Replacement stays blocked.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .choose:
            chooseContent
        case .review(let plan):
            reviewContent(plan)
        case .conflicts(let plan):
            conflictsContent(plan)
        case .ready(let plan):
            readyContent(plan)
        case .replace(let plan):
            replaceContent(plan)
        case .confirm(let plan, let name):
            confirmContent(plan, safetyName: name)
        case .complete(let result):
            completeContent(result)
        case .error(let message):
            errorContent(message)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch stage {
        case .choose:
            EmptyView()
        case .review(let plan):
            PrimaryButton(title: "Review final import") { stage = .ready(plan) }
        case .conflicts(let plan):
            PrimaryButton(title: "Review final import") { stage = .ready(plan) }
        case .ready(let plan):
            PrimaryButton(title: "Merge \(plan.newObservations) observations") { merge(plan) }
        case .replace:
            PrimaryButton(title: "Export safety backup") { exportSafetyBackup() }
        case .confirm(let plan, _):
            VStack(spacing: 0) {
                PrimaryButton(title: "Replace journal now") { replace(plan) }
                SecondaryButton(title: "Keep current journal") { dismiss() }
            }
        case .complete:
            EmptyView()
        case .error:
            EmptyView()
        }
    }

    private var headerTitle: String {
        switch stage {
        case .choose: "Choose backup"
        case .review: "Review backup"
        case .conflicts: "Resolve conflicts"
        case .ready: "Ready to merge"
        case .replace: "Replace journal"
        case .confirm: "Replace journal"
        case .complete: "Import complete"
        case .error: "Import error"
        }
    }

    private var backLabel: String? {
        switch stage {
        case .choose, .complete: "Cancel"
        case .error: "Cancel"
        default: "Back"
        }
    }

    private func goBack() {
        switch stage {
        case .choose, .complete:
            dismiss()
        case .review:
            stage = .choose
        case .conflicts(let plan), .ready(let plan), .replace(let plan):
            stage = .review(plan)
        case .confirm(let plan, _):
            stage = .replace(plan)
        case .error:
            stage = .choose
        }
    }

    private var chooseContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            InfoText(text: "Choose a full backup. CSV exports do not restore the complete journal.")
            PrimaryButton(title: "Choose a full backup") { showFileImporter = true }
            InfoText(text: "The file is validated before anything changes. Merge is the default; replacement needs a safety copy first.")
        }
    }

    private func reviewContent(_ plan: MergePlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Backup · \(Format.date(plan.backup.exportedAt)), \(Format.time(plan.backup.exportedAt))")
                .font(AppFont.inter(16, .medium))
                .foregroundStyle(Theme.primaryText)
            Text("\(plan.backup.products.count) products · \(plan.backup.stores.count) branches · \(plan.backup.observations.count) observations")
                .font(AppFont.inter(14))
                .foregroundStyle(Theme.secondaryText)

            VStack(alignment: .leading, spacing: 10) {
                Text("Merge · Recommended")
                    .font(AppFont.inter(17, .semibold))
                    .foregroundStyle(Theme.primaryText)
                Text("\(plan.newObservations) new observations")
                    .font(AppFont.inter(16))
                    .foregroundStyle(Theme.primaryText)
                Text("\(plan.identical) identical records already present")
                    .font(AppFont.inter(16))
                    .foregroundStyle(Theme.secondaryText)
                if !plan.conflicts.isEmpty {
                    Button {
                        stage = .conflicts(plan)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(plan.conflicts.count) conflicts need your choice")
                                    .font(AppFont.inter(16, .medium))
                                    .foregroundStyle(Theme.primaryText)
                                Text("Matching records contain different values")
                                    .font(AppFont.inter(14))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            InfoText(text: "\(plan.newObservations) + \(plan.identical) + \(plan.conflicts.count) = \(plan.totalObservations) records in this file. No changes are made before the final confirmation.")
                .padding(.top, 4)

            SecondaryButton(title: "Replace journal instead…") { stage = .replace(plan) }
                .padding(.top, 12)
        }
    }

    private func conflictsContent(_ plan: MergePlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose versions for \(plan.conflicts.count) \(plan.conflicts.count == 1 ? "record" : "records")")
                .font(AppFont.inter(16, .medium))
                .foregroundStyle(Theme.primaryText)

            ForEach(Array(plan.conflicts.enumerated()), id: \.element.id) { index, conflict in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(index + 1) · \(conflict.productName) · \(conflict.storeName)")
                        .font(AppFont.inter(15, .medium))
                        .foregroundStyle(Theme.primaryText)
                    Text("\(Format.timestamp(conflict.observedAt)) · \(conflict.current.packageQuantity ?? "") \(conflict.current.packageUnit ?? "")")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    WrappingHStack {
                        FilterChip(title: "Keep current", isSelected: (choices[conflict.id] ?? .current) == .current) {
                            choices[conflict.id] = .current
                        }
                        FilterChip(title: "Use backup", isSelected: (choices[conflict.id] ?? .current) == .backup) {
                            choices[conflict.id] = .backup
                        }
                    }
                    ForEach(conflictDifferences(conflict, plan: plan), id: \.label) { difference in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey(difference.label))
                                .font(AppFont.inter(14, .medium))
                            Text("Current: \(difference.current)")
                            Text("Backup: \(difference.backup)")
                        }
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                    }
                }
                .padding(.vertical, 10)
                SeparatorLine()
            }

            InfoText(text: "Both choices are reviewed before anything is imported.")
        }
    }

    private struct ConflictDifference {
        let label: String
        let current: String
        let backup: String
    }

    private func conflictDifferences(_ conflict: ImportConflict, plan: MergePlan) -> [ConflictDifference] {
        let current = conflict.current
        let backup = conflict.backup
        let dateFormatter = ISO8601DateFormatter()
        func date(_ value: Date?) -> String {
            value.map { dateFormatter.string(from: $0) } ?? "—"
        }
        var differences: [ConflictDifference] = []
        func add(_ label: String, _ current: String, _ backup: String) {
            guard current != backup else { return }
            differences.append(ConflictDifference(label: label, current: current.isEmpty ? "—" : current, backup: backup.isEmpty ? "—" : backup))
        }
        if current.productID != backup.productID {
            let product = plan.backup.products.first { $0.id == backup.productID }
            differences.append(ConflictDifference(label: "Different saved product", current: conflict.productName, backup: [product?.name, product?.brand, product?.variety].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")))
        }
        if current.storeID != backup.storeID {
            let store = plan.backup.stores.first { $0.id == backup.storeID }
            differences.append(ConflictDifference(label: "Different saved branch", current: conflict.storeName, backup: "\(store?.name ?? "") · \(store?.branch ?? "")"))
        }
        add("Price", current.price, backup.price)
        add("Currency", current.currencyCode, backup.currencyCode)
        add("Observed at", date(current.observedAt), date(backup.observedAt))
        add("Created at", date(current.createdAt), date(backup.createdAt))
        add("Updated at", date(current.updatedAt), date(backup.updatedAt))
        add("Package amount", current.packageQuantity ?? "", backup.packageQuantity ?? "")
        add("Package unit", current.packageUnit ?? "", backup.packageUnit ?? "")
        add("Package size known", L10n.string(current.sizeKnown ? "Yes" : "No"), L10n.string(backup.sizeKnown ? "Yes" : "No"))
        add("Loose goods", L10n.string(current.isLoose ? "Yes" : "No"), L10n.string(backup.isLoose ? "Yes" : "No"))
        add("Condition", ObservationCondition(rawValue: current.condition)?.title ?? current.condition, ObservationCondition(rawValue: backup.condition)?.title ?? backup.condition)
        add("Condition details", current.conditionLabel, backup.conditionLabel)
        add("Offer ends", date(current.conditionEndDate), date(backup.conditionEndDate))
        add("Minimum packages", String(current.multiBuyMinimum), String(backup.multiBuyMinimum))
        add("Source", ObservationSource(rawValue: current.source)?.title ?? current.source, ObservationSource(rawValue: backup.source)?.title ?? backup.source)
        add("Note", current.note, backup.note)
        return differences
    }

    private func readyContent(_ plan: MergePlan) -> some View {
        let backupKept = choices.values.filter { $0 == .backup }.count
        return VStack(alignment: .leading, spacing: 16) {
            Text("Review the final changes")
                .font(AppFont.inter(16, .medium))
                .foregroundStyle(Theme.primaryText)
            Text("\(plan.newObservations) observations will be added")
                .font(AppFont.inter(16))
                .foregroundStyle(Theme.primaryText)
            Text("\(plan.identical) identical observations will be skipped\n\(plan.conflicts.count) conflicts reviewed · \(backupKept) backup versions, \(plan.conflicts.count - backupKept) current versions")
                .font(AppFont.inter(14))
                .foregroundStyle(Theme.secondaryText)

            VStack(alignment: .leading, spacing: 6) {
                Text("Journal after merge")
                    .font(AppFont.inter(17, .semibold))
                    .foregroundStyle(Theme.primaryText)
                Text("\(plan.productsAfter) products · \(plan.storesAfter) locations\n\(plan.observationsAfter) observations")
                    .font(AppFont.inter(15))
                    .foregroundStyle(Theme.primaryText)
            }
            .padding(.top, 10)

            InfoText(text: "Existing data is kept. Original dates, units, branches and offer conditions are preserved.")
            InfoText(text: "Merge keeps existing product details, branch names and app preferences. Imported observations use those existing labels. Use replacement to restore all details and preferences from the backup.")
            SecondaryButton(title: "Review conflict choices") { stage = .conflicts(plan) }
        }
    }

    private func replaceContent(_ plan: MergePlan) -> some View {
        let current = currentCounts()
        return VStack(alignment: .leading, spacing: 16) {
            Text("Current journal will be replaced")
                .font(AppFont.inter(16, .medium))
                .foregroundStyle(Theme.primaryText)
            Text("\(current.products) products · \(current.stores) branches\n\(current.observations) observations")
                .font(AppFont.inter(15))
                .foregroundStyle(Theme.secondaryText)

            Text("Selected backup will become the journal")
                .font(AppFont.inter(16, .medium))
                .foregroundStyle(Theme.primaryText)
                .padding(.top, 8)
            Text("\(plan.backup.products.count) products · \(plan.backup.stores.count) branches\n\(plan.backup.observations.count) observations · \(Format.date(plan.backup.exportedAt)), \(Format.time(plan.backup.exportedAt))")
                .font(AppFont.inter(15))
                .foregroundStyle(Theme.secondaryText)

            InfoText(text: "Step 1: export a full safety backup.\nStep 2: review and confirm replacement.\nIf export fails, replacement stays blocked.")
                .padding(.top, 10)
        }
    }

    private func confirmContent(_ plan: MergePlan, safetyName: String) -> some View {
        let current = currentCounts()
        return VStack(alignment: .leading, spacing: 16) {
            Text("Safety backup exported")
                .font(AppFont.inter(16, .medium))
                .foregroundStyle(Theme.primaryText)
            Text("\(safetyName)\nSaved successfully to Files")
                .font(AppFont.inter(14))
                .foregroundStyle(Theme.secondaryText)

            Text("Replace this iPhone’s journal")
                .font(AppFont.inter(16, .medium))
                .foregroundStyle(Theme.primaryText)
                .padding(.top, 8)
            Text("Current: \(current.products) products / \(current.observations) observations\nBackup: \(plan.backup.products.count) products / \(plan.backup.observations.count) observations")
                .font(AppFont.inter(15))
                .foregroundStyle(Theme.secondaryText)

            InfoText(text: "The selected backup becomes the entire journal. Changes made after that backup will only remain in your safety copy.")
        }
    }

    private func completeContent(_ result: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.isReplacement ? "Backup restored in full" : "Your journal was merged")
                .font(AppFont.serif(32))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(result.summary)
                .font(AppFont.inter(16, .medium))
                .foregroundStyle(Theme.primaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(result.addedObservations) observations added")
                Text("\(result.skippedObservations) identical observations skipped")
                if result.keptCurrent > 0 {
                    Text("\(result.keptCurrent) current versions kept")
                }
            }
            .font(AppFont.inter(14))
            .foregroundStyle(Theme.secondaryText)

            Text("\(result.products) products · \(result.stores) branches\n\(result.observations) observations")
                .font(AppFont.inter(16, .medium))
                .foregroundStyle(Theme.primaryText)
                .padding(.top, 8)

            InfoText(text: result.isReplacement
                ? "The previous journal is preserved in your exported safety backup. Original record dates and units were kept."
                : "Existing records were kept. Imported observations retain their original dates, units and conditions.")

            PrimaryButton(title: result.isReplacement ? "Open restored Journal" : "Open Journal") {
                dismiss()
                router.reset()
            }
            SecondaryButton(title: "View statistics") {
                dismiss()
                router.reset()
                router.push(.statistics(nil, nil))
            }
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This backup is incomplete")
                .font(AppFont.serif(32))
                .foregroundStyle(Theme.primaryText)
            Text(L10n.string(message))
                .font(AppFont.inter(16))
                .foregroundStyle(Theme.primaryText)
            InfoText(text: "The file cannot be safely restored. No changes were made to your journal.")
            PrimaryButton(title: "Choose another file") { stage = .choose }
            SecondaryButton(title: "Back to backup options") { dismiss() }
        }
    }

    private func handleFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let backup = try BackupService.decode(data)
            let plan = try BackupService.plan(backup: backup, context: context)
            choices = Dictionary(uniqueKeysWithValues: plan.conflicts.map { ($0.id, ConflictChoice.current) })
            stage = .review(plan)
        } catch let error as BackupError {
            stage = .error(error.message)
        } catch {
            stage = .error("Some records are missing required fields, or the file is not a full backup.")
        }
    }

    private func merge(_ plan: MergePlan) {
        do {
            let result = try BackupService.applyMerge(plan: plan, choices: choices, context: context)
            stage = .complete(result)
        } catch let error as BackupError {
            stage = .error(error.message)
        } catch {
            stage = .error("The journal could not be merged. No changes were kept.")
        }
    }

    private func replace(_ plan: MergePlan) {
        do {
            let result = try BackupService.replace(with: plan.backup, context: context)
            stage = .complete(result)
        } catch let error as BackupError {
            stage = .error(error.message)
        } catch {
            stage = .error("The journal could not be replaced. No changes were kept.")
        }
    }

    private func exportSafetyBackup() {
        do {
            let backup = try BackupService.makeBackup(context: context)
            safetyDocument = DataDocument(data: try BackupService.encode(backup))
            showSafetyExporter = true
        } catch {
            exportFailed = true
        }
    }

    private func currentCounts() -> (products: Int, stores: Int, observations: Int) {
        (
            (try? context.fetchCount(FetchDescriptor<Product>())) ?? 0,
            (try? context.fetchCount(FetchDescriptor<StoreLocation>())) ?? 0,
            (try? context.fetchCount(FetchDescriptor<PriceObservation>())) ?? 0
        )
    }
}
