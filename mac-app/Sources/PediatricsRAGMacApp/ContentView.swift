import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
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
