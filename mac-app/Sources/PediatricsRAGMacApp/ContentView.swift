import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 280, max: 280)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspace")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(AppSection.allCases) { section in
                        Button {
                            viewModel.selectedSection = section
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: section.systemImage)
                                    .frame(width: 18)
                                Text(section.title)
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(viewModel.selectedSection == section ? Color.accentColor.opacity(0.16) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Runtime")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LabeledContent("API", value: viewModel.serviceState.message)
                    LabeledContent("Web", value: viewModel.webState.message)
                    LabeledContent("Project Root", value: viewModel.projectRootPath.isEmpty ? "-" : viewModel.projectRootPath)
                    if !viewModel.logFilePath.isEmpty {
                        LabeledContent("Log File", value: viewModel.logFilePath)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Chat Parameters")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    CompactSliderCard(
                        title: "Top-K",
                        subtitle: "final context count",
                        valueText: String(format: "%.0f", viewModel.topK),
                        tint: Color(red: 0.22, green: 0.51, blue: 0.95),
                        value: $viewModel.topK,
                        range: 1...10,
                        step: 1
                    )

                    CompactSliderCard(
                        title: "Retrieve-K",
                        subtitle: "candidate recall count",
                        valueText: String(format: "%.0f", viewModel.retrieveK),
                        tint: Color(red: 0.12, green: 0.70, blue: 0.56),
                        value: $viewModel.retrieveK,
                        range: 1...30,
                        step: 1
                    )

                    CompactSliderCard(
                        title: "Relevance Threshold",
                        subtitle: "evidence gate",
                        valueText: String(format: "%.2f", viewModel.relevanceThreshold),
                        tint: Color(red: 0.96, green: 0.58, blue: 0.24),
                        value: $viewModel.relevanceThreshold,
                        range: 0...1,
                        step: 0.01
                    )
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch viewModel.selectedSection ?? .chat {
        case .chat:
            chatDetail
        case .knowledgeBase:
            knowledgeBaseDetail
        case .trainingData:
            trainingDetail
        }
    }

    private var chatDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            topComposer
            metricsRow
            contentPanels
            logsPanel
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var knowledgeBaseDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                knowledgeBaseHeader
                if !viewModel.knowledgeBaseErrorMessage.isEmpty {
                    warningBanner(viewModel.knowledgeBaseErrorMessage)
                }
                indexMetrics
                HStack(alignment: .top, spacing: 16) {
                    indexStatusPanel
                    manifestDiffPanel
                }
                sourcesPanel
                logsPanel
            }
            .padding(22)
        }
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var trainingDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                trainingHeader
                trainingMetrics
                if !viewModel.trainingErrorMessage.isEmpty {
                    warningBanner(viewModel.trainingErrorMessage)
                }
                if let autosaveMessage = viewModel.trainingAutosaveState.message {
                    autosaveBanner(message: autosaveMessage, state: viewModel.trainingAutosaveState)
                }
                if !viewModel.trainingInfoMessage.isEmpty {
                    infoBanner(viewModel.trainingInfoMessage)
                }
                trainingPanels
            }
            .padding(22)
        }
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var trainingHeader: some View {
        glassPanel(title: "Training Data", systemImage: "square.and.pencil", minHeight: 150) {
            VStack(alignment: .leading, spacing: 14) {
                Text("SQLite is the source of truth for LoRA annotation. Edit samples locally, refresh retrieved contexts, export snapshots, and build `sft_train.jsonl` when the batch is ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        viewModel.createTrainingSample()
                    } label: {
                        Label("New Sample", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewModel.duplicateSelectedTrainingSample()
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.selectedTrainingSampleID == nil)

                    Button {
                        viewModel.saveTrainingSample()
                    } label: {
                        if viewModel.isSavingTrainingSample {
                            ProgressView().frame(width: 72)
                        } else {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.trainingDraft == nil)

                    Button {
                        viewModel.markSelectedTrainingSampleDone()
                    } label: {
                        Label("Mark Done", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.trainingDraft == nil || !viewModel.canMarkTrainingSampleDone)

                    Button {
                        viewModel.refreshSelectedTrainingContexts()
                    } label: {
                        if viewModel.isRefreshingTrainingContexts {
                            ProgressView().frame(width: 124)
                        } else {
                            Label("Refresh Contexts", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.selectedTrainingSampleID == nil)

                    Button {
                        viewModel.exportTrainingSnapshot()
                    } label: {
                        if viewModel.isExportingTrainingSnapshot {
                            ProgressView().frame(width: 126)
                        } else {
                            Label("Export Snapshot", systemImage: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.buildTrainingDataset()
                    } label: {
                        if viewModel.isBuildingTrainingDataset {
                            ProgressView().frame(width: 118)
                        } else {
                            Label("Build Dataset", systemImage: "hammer")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        viewModel.deleteSelectedTrainingSample()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.selectedTrainingSampleID == nil)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("DB: \(viewModel.trainingDatabasePath.isEmpty ? "-" : viewModel.trainingDatabasePath)")
                    Text("Snapshot: \(viewModel.trainingSnapshotPath.isEmpty ? "-" : viewModel.trainingSnapshotPath)")
                    Text("Dataset: \(viewModel.trainingDatasetPath.isEmpty ? "-" : viewModel.trainingDatasetPath)")
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }
        }
    }

    private var trainingMetrics: some View {
        let draftCount = viewModel.trainingSamples.filter { $0.status == .draft }.count
        let doneCount = viewModel.trainingSamples.filter { $0.status == .done }.count
        let archivedCount = viewModel.trainingSamples.filter { $0.status == .archived }.count

        return HStack(spacing: 14) {
            MetricTile(title: "All Samples", value: "\(viewModel.trainingSamples.count)")
            MetricTile(title: "Draft", value: "\(draftCount)")
            MetricTile(title: "Done", value: "\(doneCount)")
            MetricTile(title: "Archived", value: "\(archivedCount)")
            MetricTile(title: "Unsaved", value: viewModel.hasUnsavedTrainingChanges ? "true" : "false")
            MetricTile(title: "Complete", value: viewModel.canMarkTrainingSampleDone ? "true" : "false")
        }
    }

    private var trainingPanels: some View {
        HStack(alignment: .top, spacing: 16) {
            glassPanel(title: "Samples", systemImage: "list.bullet.rectangle", minHeight: 540) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Search sample id or question", text: $viewModel.trainingSearchText)
                        .textFieldStyle(.roundedBorder)

                    Picker("Status", selection: $viewModel.trainingStatusFilter) {
                        ForEach(TrainingSampleFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.isLoadingTrainingSamples {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else if viewModel.filteredTrainingSamples.isEmpty {
                        Text("No samples match the current filter.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(viewModel.filteredTrainingSamples) { sample in
                                    Button {
                                        viewModel.selectTrainingSample(sample.sampleID)
                                    } label: {
                                        TrainingSampleRow(
                                            sample: sample,
                                            isSelected: viewModel.selectedTrainingSampleID == sample.sampleID
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .frame(width: 300)

            glassPanel(title: "Editor", systemImage: "slider.horizontal.3", minHeight: 540) {
                if viewModel.trainingDraft != nil {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            trainingMetadataStrip

                            if !viewModel.trainingCompletionIssues.isEmpty {
                                validationCard(viewModel.trainingCompletionIssues)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Question")
                                    .font(.subheadline.weight(.semibold))
                                TextField(
                                    "Ask a pediatric question grounded in retrieved context",
                                    text: viewModel.binding(for: \.question, default: ""),
                                    axis: .vertical
                                )
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(4...8)
                                .controlSize(.large)
                            }

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Mode")
                                        .font(.subheadline.weight(.semibold))
                                    Picker("", selection: viewModel.binding(for: \.mode, default: .groundedAnswer)) {
                                        ForEach(TrainingSampleMode.allCases) { mode in
                                            Text(mode.title).tag(mode)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Status")
                                        .font(.subheadline.weight(.semibold))
                                    Picker("", selection: viewModel.trainingStatusBinding) {
                                        ForEach(TrainingSampleStatus.allCases) { status in
                                            Text(status.title).tag(status)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                }
                            }

                            TrainingTextEditorCard(
                                title: "Annotation Guideline",
                                text: viewModel.binding(for: \.annotationGuideline, default: ""),
                                minHeight: 150
                            )

                            TrainingTextEditorCard(
                                title: "Answer",
                                text: viewModel.binding(for: \.answer, default: ""),
                                accessory: {
                                    Button {
                                        viewModel.insertAnswerTemplate()
                                    } label: {
                                        Label("Insert Template", systemImage: "text.badge.plus")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                },
                                minHeight: 320
                            )

                            TrainingTextEditorCard(
                                title: "Annotation Notes",
                                text: viewModel.binding(for: \.annotationNotes, default: ""),
                                minHeight: 160
                            )
                        }
                    }
                } else {
                    Text("Create a sample or choose one from the list.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(minWidth: 380, maxWidth: .infinity)

            glassPanel(title: "Contexts", systemImage: "doc.text.magnifyingglass", minHeight: 540) {
                if let draft = viewModel.trainingDraft {
                    if draft.contexts.isEmpty {
                        Text("No retrieved contexts yet. Use `Refresh Contexts` after writing the question.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(draft.contexts) { context in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(context.ref)
                                                .font(.headline)
                                            Spacer()
                                            TrainingStatusBadge(
                                                title: context.chunkID ?? "-",
                                                tint: Color(red: 0.24, green: 0.53, blue: 0.94)
                                            )
                                        }

                                        Text("source \(context.source ?? "-")   page \(context.page.map(String.init) ?? "-")")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)

                                        Divider()

                                        Text(context.text)
                                            .font(.system(size: 14))
                                            .textSelection(.enabled)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.black.opacity(0.035))
                                    )
                                }
                            }
                        }
                    }
                } else {
                    Text("Context preview is empty.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(minWidth: 320, maxWidth: .infinity)
        }
    }

    private var knowledgeBaseHeader: some View {
        glassPanel(title: "Knowledge Base Admin", systemImage: "externaldrive.badge.checkmark", minHeight: 110) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Manage the local source set, inspect vector index health, and rebuild the FAISS materialization.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        viewModel.importDocument()
                    } label: {
                        if viewModel.isImportingDocument {
                            ProgressView()
                                .frame(width: 110)
                        } else {
                            Label("Import Source", systemImage: "plus")
                                .frame(width: 110)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isImportingDocument || viewModel.isRebuildingIndex)

                    Button {
                        viewModel.rebuildIndex()
                    } label: {
                        if viewModel.isRebuildingIndex {
                            ProgressView()
                                .frame(width: 110)
                        } else {
                            Label("Rebuild Index", systemImage: "arrow.triangle.2.circlepath")
                                .frame(width: 110)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isImportingDocument || viewModel.isRebuildingIndex)

                    Button("Refresh State") {
                        viewModel.refreshKnowledgeBase()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isRefreshingKnowledgeBase || viewModel.isRebuildingIndex)
                }
            }
        }
    }

    private var indexMetrics: some View {
        let status = viewModel.vectorIndexStatus
        return HStack(spacing: 14) {
            MetricTile(title: "Build Status", value: status?.buildStatus ?? "-")
            MetricTile(title: "Dirty", value: boolLabel(status?.dirty))
            MetricTile(title: "Documents", value: "\(status?.documentCount ?? 0)")
            MetricTile(title: "Indexed Docs", value: "\(status?.indexedDocumentCount ?? 0)")
            MetricTile(title: "Total Chunks", value: "\(status?.totalChunks ?? 0)")
        }
    }

    private var indexStatusPanel: some View {
        glassPanel(title: "Index Status", systemImage: "cpu", minHeight: 260) {
            VStack(alignment: .leading, spacing: 10) {
                keyValueRow("Embedding Model", viewModel.vectorIndexStatus?.embeddingModel ?? "-")
                keyValueRow("FAISS Path", viewModel.vectorIndexStatus?.faissIndexPath ?? "-")
                keyValueRow("Chunks Path", viewModel.vectorIndexStatus?.chunksPath ?? "-")
                keyValueRow("Manifest Path", viewModel.vectorIndexStatus?.manifestPath ?? "-")
                keyValueRow("Index Exists", boolLabel(viewModel.vectorIndexStatus?.indexExists))
                keyValueRow("Chunks Exists", boolLabel(viewModel.vectorIndexStatus?.chunksExists))
                keyValueRow("Manifest Exists", boolLabel(viewModel.vectorIndexStatus?.manifestExists))
                keyValueRow("Index MTime", viewModel.formattedTimestamp(viewModel.vectorIndexStatus?.indexModifiedAt))
                keyValueRow("Chunks MTime", viewModel.formattedTimestamp(viewModel.vectorIndexStatus?.chunksModifiedAt))
                keyValueRow("Manifest MTime", viewModel.formattedTimestamp(viewModel.vectorIndexStatus?.manifestModifiedAt))
                keyValueRow("Last Build", viewModel.formattedTimestamp(viewModel.vectorIndexStatus?.lastBuildAt))
                if let lastError = viewModel.vectorIndexStatus?.lastError, !lastError.isEmpty {
                    Divider()
                    Text(lastError)
                        .font(.caption.monospaced())
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var manifestDiffPanel: some View {
        glassPanel(title: "Manifest Diff", systemImage: "arrow.left.arrow.right.square", minHeight: 260) {
            VStack(alignment: .leading, spacing: 14) {
                diffBlock(title: "Added", items: viewModel.vectorIndexStatus?.diff.added ?? [])
                diffBlock(title: "Modified", items: viewModel.vectorIndexStatus?.diff.modified ?? [])
                diffBlock(title: "Deleted", items: viewModel.vectorIndexStatus?.diff.deleted ?? [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var sourcesPanel: some View {
        glassPanel(title: "Sources", systemImage: "doc.on.doc", minHeight: 320) {
            VStack(spacing: 0) {
                HStack {
                    sourceHeader("Path", width: 240, alignment: .leading)
                    sourceHeader("Status", width: 96, alignment: .leading)
                    sourceHeader("Chunks", width: 64, alignment: .trailing)
                    sourceHeader("Manifest", width: 64, alignment: .center)
                    sourceHeader("Size", width: 82, alignment: .trailing)
                    sourceHeader("Modified At", width: 196, alignment: .leading)
                    Spacer()
                    sourceHeader("Actions", width: 160, alignment: .center)
                }
                .padding(.bottom, 10)

                Divider()

                if viewModel.documents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No source documents.")
                            .font(.headline)
                        Text("Import PDF/TXT/MD files into `kb_sources/uploads` through the admin action above.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.documents) { document in
                            SourceRow(document: document, viewModel: viewModel)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var topComposer: some View {
        glassPanel(title: "Prompt", systemImage: "bubble.left.and.text.bubble.right", minHeight: 130) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Question")
                            .font(.headline)
                        TextField("例如：宝宝几个月可以吃辅食？", text: $viewModel.question, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .lineLimit(3...6)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                            )
                    }

                    VStack(spacing: 10) {
                        Button {
                            viewModel.ask()
                        } label: {
                            if viewModel.isAsking {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 80)
                            } else {
                                Text("Ask")
                                    .frame(width: 80)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!viewModel.canAsk)

                        Button("Clear") {
                            viewModel.clear()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.top, 30)
                }

                if !viewModel.errorMessage.isEmpty {
                    warningBanner(viewModel.errorMessage)
                }
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 14) {
            MetricTile(title: "Generation Mode", value: viewModel.generationModeLabel)
            MetricTile(title: "Best Relevance", value: viewModel.bestRelevanceLabel)
            MetricTile(title: "Threshold", value: viewModel.thresholdLabel)
            MetricTile(title: "Evidence", value: viewModel.evidencePassedLabel)
        }
    }

    private var contentPanels: some View {
        HStack(alignment: .top, spacing: 16) {
            glassPanel(title: "Answer", systemImage: "text.alignleft", minHeight: 420) {
                answerContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)

            glassPanel(title: "Retrieved Contexts", systemImage: "doc.text.magnifyingglass", minHeight: 420) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.response?.contexts ?? []) { chunk in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(chunk.chunkID)
                                        .font(.headline)
                                    Spacer()
                                    Text(chunk.retrievalMethod ?? "-")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                Text("source \(chunk.source ?? "-")   page \(chunk.page ?? -1)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)

                                Text(
                                    String(
                                        format: "dense %.4f   keyword %.4f   relevance %.4f",
                                        chunk.denseScore ?? 0,
                                        chunk.keywordScore ?? 0,
                                        chunk.relevanceScore ?? 0
                                    )
                                )
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)

                                Divider()

                                Text(chunk.text)
                                    .font(.system(size: 14))
                                    .textSelection(.enabled)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.black.opacity(0.035))
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var answerContent: some View {
        let structured = viewModel.response?.structuredAnswer

        return ScrollView {
            if let structured, structured.hasStructuredSections {
                VStack(alignment: .leading, spacing: 14) {
                    if let conclusion = structured.conclusion, !conclusion.isEmpty {
                        AnswerSectionCard(
                            title: "结论",
                            systemImage: "checkmark.seal.fill",
                            tint: Color(red: 0.23, green: 0.55, blue: 0.96),
                            text: conclusion
                        )
                    }

                    if let evidence = structured.evidence, !evidence.isEmpty {
                        AnswerSectionCard(
                            title: "依据",
                            systemImage: "text.quote",
                            tint: Color(red: 0.13, green: 0.68, blue: 0.54),
                            text: evidence
                        )
                    }

                    if let citations = structured.citations, !citations.isEmpty {
                        AnswerSectionCard(
                            title: "引用",
                            systemImage: "link.circle.fill",
                            tint: Color(red: 0.95, green: 0.63, blue: 0.22),
                            text: citations
                        )
                    }

                    if let reminder = structured.reminder, !reminder.isEmpty {
                        AnswerSectionCard(
                            title: "提醒",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: Color(red: 0.94, green: 0.43, blue: 0.33),
                            text: reminder
                        )
                    }

                    DisclosureGroup("原始回答") {
                        Text(structured.rawText)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.top, 8)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.03))
                    )
                }
            } else {
                Text(viewModel.response?.answer ?? "等待提问。")
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.top, 4)
            }
        }
    }

    private var logsPanel: some View {
        glassPanel(title: "Backend Logs", systemImage: "terminal", minHeight: 150) {
            VStack(alignment: .leading, spacing: 10) {
                if !viewModel.logFilePath.isEmpty {
                    Text(viewModel.logFilePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                ScrollView {
                    Text(viewModel.logs.isEmpty ? "暂无日志输出。" : viewModel.logs)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func warningBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private func infoBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text(message)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.blue.opacity(0.1))
        )
    }

    private func autosaveBanner(message: String, state: TrainingAutosaveState) -> some View {
        let tint: Color = switch state {
        case .idle, .pending:
            .orange
        case .saving:
            .blue
        case .saved:
            .green
        case .failed:
            .red
        }

        return HStack(spacing: 8) {
            Image(systemName: autosaveSymbol(for: state))
                .foregroundStyle(tint)
            Text(message)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.1))
        )
    }

    private func validationCard(_ issues: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Completion Check", systemImage: "checklist")
                .font(.subheadline.weight(.semibold))
            ForEach(issues, id: \.self) { issue in
                Text("• \(issue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("只有完整样本才能标记为 done。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
    }

    private func diffBlock(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if items.isEmpty {
                Text("[]")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func keyValueRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func sourceHeader(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
    }

    private func glassPanel<Content: View>(
        title: String,
        systemImage: String,
        minHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
    }

    private func boolLabel(_ value: Bool?) -> String {
        guard let value else { return "-" }
        return value ? "true" : "false"
    }

    private var trainingMetadataStrip: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sample ID")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedTrainingSampleID ?? "-")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }

            Spacer()

            if let draft = viewModel.trainingDraft {
                TrainingStatusBadge(title: draft.status.title, tint: statusTint(draft.status))
                TrainingStatusBadge(title: draft.mode.title, tint: Color(red: 0.24, green: 0.53, blue: 0.94))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.05))
        )
    }

    private func statusTint(_ status: TrainingSampleStatus) -> Color {
        switch status {
        case .draft:
            return Color(red: 0.96, green: 0.58, blue: 0.24)
        case .done:
            return Color(red: 0.13, green: 0.68, blue: 0.54)
        case .archived:
            return .secondary
        }
    }

    private func autosaveSymbol(for state: TrainingAutosaveState) -> String {
        switch state {
        case .idle:
            return "circle"
        case .pending:
            return "clock"
        case .saving:
            return "arrow.triangle.2.circlepath"
        case .saved:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }
}

private struct SourceRow: View {
    let document: DocumentRecord
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.relativePath)
                    .font(.subheadline.monospaced())
                    .lineLimit(2)
                    .textSelection(.enabled)
                Text(document.absolutePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .frame(width: 240, alignment: .leading)

            Text(document.indexStatus)
                .font(.caption.monospaced())
                .frame(width: 96, alignment: .leading)

            Text("\(document.chunkCount)")
                .font(.caption.monospaced())
                .frame(width: 64, alignment: .trailing)

            Image(systemName: document.inManifest ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(document.inManifest ? .green : .secondary)
                .frame(width: 64)

            Text(viewModel.formattedFileSize(document.size))
                .font(.caption.monospaced())
                .frame(width: 82, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formattedTimestamp(document.modifiedAt))
                    .font(.caption.monospaced())
                Text("indexed \(viewModel.formattedTimestamp(document.lastIndexedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 196, alignment: .leading)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    viewModel.replaceDocument(document)
                } label: {
                    if viewModel.isReplacingDocument(id: document.id) {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 76)
                    } else {
                        Text("Replace")
                            .frame(width: 76)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isRebuildingIndex || viewModel.isImportingDocument || viewModel.isDeletingDocument(id: document.id))

                Button(role: .destructive) {
                    viewModel.deleteDocument(id: document.id)
                } label: {
                    if viewModel.isDeletingDocument(id: document.id) {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 68)
                    } else {
                        Text("Delete")
                            .frame(width: 68)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isRebuildingIndex || viewModel.isImportingDocument || viewModel.isReplacingDocument(id: document.id))
            }
            .frame(width: 160, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

private struct TrainingSampleRow: View {
    let sample: TrainingSample
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(sample.sampleID)
                    .font(.subheadline.monospaced().weight(.semibold))
                Spacer()
                TrainingStatusBadge(title: sample.status.title, tint: tint)
            }

            Text(sample.question.isEmpty ? "Untitled sample" : sample.question)
                .font(.subheadline)
                .lineLimit(2)

            HStack {
                TrainingStatusBadge(title: sample.mode.title, tint: Color(red: 0.24, green: 0.53, blue: 0.94))
                Spacer()
                Text(sample.updatedAt)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.black.opacity(0.035))
        )
    }

    private var tint: Color {
        switch sample.status {
        case .draft:
            return Color(red: 0.96, green: 0.58, blue: 0.24)
        case .done:
            return Color(red: 0.13, green: 0.68, blue: 0.54)
        case .archived:
            return .secondary
        }
    }
}

private struct TrainingStatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .foregroundStyle(tint)
    }
}

private struct TrainingTextEditorCard: View {
    let title: String
    var text: Binding<String>
    var isReadOnly = false
    var accessory: AnyView?
    var minHeight: CGFloat

    init<Accessory: View>(
        title: String,
        text: Binding<String>,
        isReadOnly: Bool = false,
        @ViewBuilder accessory: () -> Accessory,
        minHeight: CGFloat
    ) {
        self.title = title
        self.text = text
        self.isReadOnly = isReadOnly
        self.accessory = AnyView(accessory())
        self.minHeight = minHeight
    }

    init(title: String, text: Binding<String>, isReadOnly: Bool = false, minHeight: CGFloat) {
        self.title = title
        self.text = text
        self.isReadOnly = isReadOnly
        self.accessory = nil
        self.minHeight = minHeight
    }

    init(title: String, text: String, isReadOnly: Bool = true, minHeight: CGFloat) {
        self.title = title
        self.text = .constant(text)
        self.isReadOnly = isReadOnly
        self.accessory = nil
        self.minHeight = minHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                accessory
            }

            TextEditor(text: text)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .disabled(isReadOnly)
                .frame(minHeight: minHeight)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

private struct CompactSliderCard: View {
    let title: String
    let subtitle: String
    let valueText: String
    let tint: Color
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(valueText)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range, step: step)
                .tint(tint)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct AnswerSectionCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            Text(text)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}
