import AppKit
import SwiftUI

@main
struct DITPrinterApp: App {
    @StateObject private var store = PrinterJobStore()
    @StateObject private var templateStore = LabelTemplateStore()

    var body: some Scene {
        WindowGroup("DIT Printer") {
            DITPrinterMainView(store: store, templateStore: templateStore)
                .frame(minWidth: 920, minHeight: 580)
        }
        .defaultSize(width: 980, height: 650)
        .windowStyle(.hiddenTitleBar)
    }
}

@MainActor
final class PrinterJobStore: ObservableObject {
    @Published private(set) var jobs: [DITPrinterJob] = []
    @Published var selectedJobID: UUID?
    @Published var printerQueues: [String] = []
    @Published var selectedQueue: String {
        didSet { UserDefaults.standard.set(selectedQueue, forKey: Self.queueDefaultsKey) }
    }
    @Published var isSubmitting = false

    private static let queueDefaultsKey = "ditPrinter.selectedQueue"
    private var pollTimer: Timer?

    init() {
        selectedQueue = UserDefaults.standard.string(forKey: Self.queueDefaultsKey) ?? ""
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshJobs() }
        }
    }

    deinit { pollTimer?.invalidate() }

    var pendingJobs: [DITPrinterJob] {
        jobs.filter { $0.status == .pending || $0.status == .failed }
    }

    var selectedJob: DITPrinterJob? {
        jobs.first { $0.id == selectedJobID }
    }

    func refresh() {
        refreshJobs()
        refreshQueues()
    }

    func refreshJobs() {
        do {
            let directory = try DITPrinterJob.jobsDirectory()
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            jobs = urls
                .filter { $0.pathExtension.lowercased() == "json" }
                .compactMap { try? DITPrinterDateCodec.decoder.decode(DITPrinterJob.self, from: Data(contentsOf: $0)) }
                .sorted { $0.receivedAt > $1.receivedAt }
            if selectedJobID == nil || !jobs.contains(where: { $0.id == selectedJobID }) {
                selectedJobID = pendingJobs.first?.id ?? jobs.first?.id
            }
        } catch {
            jobs = []
        }
    }

    func refreshQueues() {
        printerQueues = CUPSPrinter.availableQueues()
        if !selectedQueue.isEmpty && !printerQueues.contains(selectedQueue) {
            printerQueues.insert(selectedQueue, at: 0)
        }
        if selectedQueue.isEmpty, let firstQueue = printerQueues.first {
            selectedQueue = firstQueue
        }
    }

    func updateSelectedJob(binName: String, lastAssetName: String, reuseCount: Int?) {
        guard let index = jobs.firstIndex(where: { $0.id == selectedJobID }) else { return }
        jobs[index].binName = binName.trimmingCharacters(in: .whitespacesAndNewlines)
        jobs[index].lastAssetName = lastAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
        jobs[index].reuseCount = reuseCount
        persist(jobs[index])
    }

    func submitSelectedJob(template: LabelTemplate) {
        guard let index = jobs.firstIndex(where: { $0.id == selectedJobID }) else { return }
        guard !selectedQueue.isEmpty else {
            markFailed(at: index, error: "No CUPS printer queue selected.")
            return
        }
        guard let reuseCount = jobs[index].reuseCount, reuseCount >= 0 else {
            markFailed(at: index, error: "Enter the card reuse count before printing.")
            return
        }

        isSubmitting = true
        jobs[index].labelTemplate = template
        jobs[index].status = .printing
        jobs[index].lastError = nil
        persist(jobs[index])
        let job = jobs[index]
        let queue = selectedQueue

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let reference = try CUPSPrinter.submit(job: job, queueName: queue, template: job.labelTemplate ?? template)
                DispatchQueue.main.async {
                    guard let self, let updatedIndex = self.jobs.firstIndex(where: { $0.id == job.id }) else { return }
                    self.jobs[updatedIndex].status = .printed
                    self.jobs[updatedIndex].printedAt = Date()
                    self.jobs[updatedIndex].queueName = queue
                    self.jobs[updatedIndex].cupsJobReference = reference
                    self.jobs[updatedIndex].lastError = nil
                    self.isSubmitting = false
                    self.persist(self.jobs[updatedIndex])
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self, let updatedIndex = self.jobs.firstIndex(where: { $0.id == job.id }) else { return }
                    self.markFailed(at: updatedIndex, error: error.localizedDescription)
                    self.isSubmitting = false
                }
            }
        }
    }

    func retrySelectedJob() {
        guard let index = jobs.firstIndex(where: { $0.id == selectedJobID }) else { return }
        jobs[index].status = .pending
        jobs[index].lastError = nil
        persist(jobs[index])
    }

    private func markFailed(at index: Int, error: String) {
        jobs[index].status = .failed
        jobs[index].lastError = error
        persist(jobs[index])
    }

    private func persist(_ job: DITPrinterJob) {
        do {
            let url = try job.fileURL()
            try DITPrinterDateCodec.encoder.encode(job).write(to: url, options: .atomic)
        } catch {
            // The app must keep the in-memory task visible even if its ledger cannot be updated.
        }
    }
}

struct DITPrinterMainView: View {
    @ObservedObject var store: PrinterJobStore
    @ObservedObject var templateStore: LabelTemplateStore
    @State private var showTemplateLibrary = false

    var body: some View {
        NavigationSplitView {
            List(store.jobs, selection: $store.selectedJobID) { job in
                JobRow(job: job)
                    .tag(job.id)
            }
            .navigationTitle("DIT Printer")
            .toolbar {
                Button(action: store.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh pending print jobs")
                Button { showTemplateLibrary = true } label: {
                    Image(systemName: "tag")
                }
                .help("Manage label stock templates")
            }
        } detail: {
            if let job = store.selectedJob {
                JobEditor(job: job, store: store, templateStore: templateStore)
            } else {
                ContentUnavailableView("No print jobs", systemImage: "printer")
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showTemplateLibrary) {
            LabelTemplateLibrary(store: templateStore)
        }
    }
}

private struct JobRow: View {
    let job: DITPrinterJob

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(job.binName.isEmpty ? "Unnamed Bin" : job.binName)
                .lineLimit(1)
            Text(job.lastAssetName.isEmpty ? "No final asset received" : job.lastAssetName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(statusLabel)
                .font(.caption2)
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 3)
    }

    private var statusLabel: String {
        switch job.status {
        case .pending: return "Awaiting reuse count"
        case .printing: return "Submitting to printer"
        case .printed: return "Submitted \(job.printedAt?.formatted(date: .omitted, time: .shortened) ?? "")"
        case .failed: return "Needs attention"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .pending: return .yellow
        case .printing: return .blue
        case .printed: return .green
        case .failed: return .red
        }
    }
}

private struct JobEditor: View {
    let job: DITPrinterJob
    @ObservedObject var store: PrinterJobStore
    @ObservedObject var templateStore: LabelTemplateStore
    @State private var binName = ""
    @State private var lastAssetName = ""
    @State private var reuseText = ""
    @State private var showPreview = false

    var body: some View {
        Form {
            Section("Copy Event") {
                TextField("Silverstack Bin name", text: $binName)
                TextField("Last copied asset filename", text: $lastAssetName)
                LabeledContent("Copy completed") {
                    Text(job.copyCompletedAt.formatted(date: .abbreviated, time: .standard))
                }
                LabeledContent("Received by DIT Printer") {
                    Text(job.receivedAt.formatted(date: .abbreviated, time: .standard))
                }
            }

            if let audit = job.renamerAudit {
                Section("Renamer Audit (Read-Only)") {
                    LabeledContent("Renamed volume", value: audit.actualName)
                    LabeledContent("Camera/media", value: audit.deviceType)
                    if let lastClipName = audit.lastClipName {
                        LabeledContent("Last recorded clip", value: lastClipName)
                    }
                    if let volumeUUID = audit.volumeUUID {
                        LabeledContent("Volume UUID", value: volumeUUID)
                    }
                    LabeledContent("Renamed at") {
                        Text(audit.renamedAt.formatted(date: .abbreviated, time: .standard))
                    }
                }
            }

            Section("Card Reuse") {
                TextField("Reuse count", text: $reuseText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                Text("Enter the number of times this physical card has been reused.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Printer") {
                Picker("CUPS raw queue", selection: $store.selectedQueue) {
                    if store.printerQueues.isEmpty {
                        Text("No queues found").tag("")
                    } else {
                        ForEach(store.printerQueues, id: \.self) { Text($0).tag($0) }
                    }
                }
                Button("Refresh printer queues", action: store.refreshQueues)
                if let queue = job.queueName {
                    LabeledContent("Last submitted queue", value: queue)
                }
                if let reference = job.cupsJobReference {
                    LabeledContent("CUPS response", value: reference)
                }
            }

            Section("Label Stock") {
                Picker("Saved template", selection: $templateStore.selectedTemplateID) {
                    ForEach(templateStore.templates) { template in
                        Text(template.name).tag(template.id)
                    }
                }
                LabeledContent("Size") {
                    Text("\(templateStore.selectedTemplate.widthMm, specifier: "%.1f") x \(templateStore.selectedTemplate.heightMm, specifier: "%.1f") mm")
                }
            }

            if let error = job.lastError {
                Section {
                    Text(error).foregroundStyle(.red)
                    if job.status == .failed {
                        Button("Clear error", action: store.retrySelectedJob)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button { showPreview = true } label: {
                        Image(systemName: "eye")
                    }
                    .help("Preview label")
                    Button {
                        save()
                        store.submitSelectedJob(template: templateStore.selectedTemplate)
                    } label: {
                        Label(store.isSubmitting ? "Submitting" : "Print label", systemImage: "printer.fill")
                    }
                    .disabled(store.isSubmitting || job.status == .printing)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .navigationTitle(job.binName.isEmpty ? "Incoming label" : job.binName)
        .onAppear(perform: load)
        .onChange(of: job.id) { _, _ in load() }
        .sheet(isPresented: $showPreview) {
            LabelPreviewSheet(job: previewJob, template: templateStore.selectedTemplate)
        }
    }

    private func load() {
        binName = job.binName
        lastAssetName = job.lastAssetName
        reuseText = job.reuseCount.map(String.init) ?? ""
    }

    private func save() {
        let reuseCount = Int(reuseText.trimmingCharacters(in: .whitespacesAndNewlines))
        store.updateSelectedJob(binName: binName, lastAssetName: lastAssetName, reuseCount: reuseCount)
    }

    private var previewJob: DITPrinterJob {
        var draft = job
        draft.binName = binName.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.lastAssetName = lastAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.reuseCount = Int(reuseText.trimmingCharacters(in: .whitespacesAndNewlines))
        return draft
    }
}

private struct LabelTemplateLibrary: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LabelTemplateStore
    @State private var name = ""
    @State private var width = ""
    @State private var height = ""
    @State private var gap = ""
    @State private var validationError: String?

    var body: some View {
        Form {
            Section("Label Templates") {
                Picker("Template", selection: $store.selectedTemplateID) {
                    ForEach(store.templates) { template in
                        Text(template.name).tag(template.id)
                    }
                }
            }
            Section("Dimensions (mm)") {
                TextField("Name", text: $name)
                HStack {
                    TextField("Width", text: $width)
                    TextField("Height", text: $height)
                    TextField("Gap", text: $gap)
                }
            }
            if let validationError {
                Section { Text(validationError).foregroundStyle(.red) }
            }
            Section {
                Button {
                    validationError = store.save(
                        name: name,
                        widthMm: Double(width),
                        heightMm: Double(height),
                        gapMm: Double(gap)
                    )
                    loadSelectedTemplate()
                } label: {
                    Label("Save template", systemImage: "square.and.arrow.down")
                }
                Button(role: .destructive) {
                    store.deleteSelectedCustomTemplate()
                    loadSelectedTemplate()
                } label: {
                    Label("Delete custom template", systemImage: "trash")
                }
                .disabled(store.selectedTemplate.isBuiltIn)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 440, height: 410)
        .onAppear(perform: loadSelectedTemplate)
        .onChange(of: store.selectedTemplateID) { _, _ in loadSelectedTemplate() }
        .toolbar {
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .help("Close")
        }
    }

    private func loadSelectedTemplate() {
        let template = store.selectedTemplate
        name = template.name
        width = String(template.widthMm)
        height = String(template.heightMm)
        gap = String(template.gapMm)
        validationError = nil
    }
}

private struct LabelPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let template: LabelTemplate
    private let image: NSImage?

    init(job: DITPrinterJob, template: LabelTemplate) {
        self.template = template
        image = try? TSPLLabelRenderer.previewImage(job: job, template: template)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Print Preview").font(.headline)
                    Text(template.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .help("Close")
            }
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 700, maxHeight: 460)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(.secondary.opacity(0.5)))
            } else {
                ContentUnavailableView("Preview unavailable", systemImage: "exclamationmark.triangle")
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 400)
    }
}
