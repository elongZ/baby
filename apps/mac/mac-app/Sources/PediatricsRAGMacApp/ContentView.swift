// 应用主界面的布局入口。
// 本文件负责侧边栏导航和各业务页面的视图组合，不负责状态持有和后端调用。

import AppKit
import SwiftUI

/// 应用主界面的根视图。
struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var roboticsDemoStageIndex = -1
    @State private var roboticsDemoElapsed = 0.0
    @State private var roboticsDemoIsComplete = false
    @State private var roboticsTimelineTask: Task<Void, Never>?
    @State private var roboticsDebugStageIndex: Int?
    @State private var roboticsDebugStageProgress = 0.5
    private let groupedSections = Dictionary(grouping: AppSection.allCases, by: \.groupTitle)
    private let titleBarInset: CGFloat = 28
    private let sidebarTrafficLightsClearance: CGFloat = 44
    private let detailTopPadding: CGFloat = 14

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

                    ForEach(["RAG", "Vision", "Detection", "Robotics"], id: \.self) { groupTitle in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(groupTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, groupTitle == "RAG" ? 2 : 10)

                            ForEach(groupedSections[groupTitle] ?? []) { section in
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
                                    .padding(.leading, 24)
                                    .padding(.trailing, 12)
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

            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 16 + titleBarInset + sidebarTrafficLightsClearance)
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
        case .visionPlayground:
            visionPlaygroundDetail
        case .visionDataset:
            visionDatasetDetail
        case .visionTraining:
            visionTrainingDetail
        case .visionEvaluation:
            visionEvaluationDetail
        case .detectionPlayground:
            detectionPlaygroundDetail
        case .detectionDataset:
            detectionDatasetDetail
        case .detectionTraining:
            detectionTrainingDetail
        case .detectionEvaluation:
            detectionEvaluationDetail
        case .roboticsPlayground:
            roboticsPlaygroundDetail
        case .roboticsWorkflow:
            roboticsWorkflowDetail
        }
    }

    private var chatDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            chatParametersPanel
            topComposer
            metricsRow
            contentPanels
            logsPanel
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .padding(.top, detailTopPadding)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var chatParametersPanel: some View {
        glassPanel(title: "Chat Parameters", systemImage: "slider.horizontal.3", minHeight: 186) {
            HStack(alignment: .top, spacing: 14) {
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
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
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
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .padding(.top, detailTopPadding)
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
                Text("SQLite is the source of truth for LoRA annotation. Edit samples locally, refresh retrieved contexts, and build `sft_train.jsonl` when the batch is ready.")
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
                    Text("Dataset: \(viewModel.trainingDatasetPath.isEmpty ? "-" : viewModel.trainingDatasetPath)")
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }
        }
    }

    private var visionPlaygroundDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                visionHeroPanel(
                    title: "Vision Playground",
                    systemImage: "photo.on.rectangle.angled",
                    description: "Upload a product image, run local inference, and inspect why the model predicts `diaper`, `stroller`, or `other`."
                )
                if !viewModel.visionErrorMessage.isEmpty {
                    warningBanner(viewModel.visionErrorMessage)
                }
                if !viewModel.visionInfoMessage.isEmpty {
                    infoBanner(viewModel.visionInfoMessage)
                }
                visionPlaygroundToolbar
                visionMetrics
                HStack(alignment: .top, spacing: 16) {
                    visionImagePanel
                    visionPredictionPanel
                }
                HStack(alignment: .top, spacing: 16) {
                    visionTopPredictionsPanel
                    visionWhyPanel
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
        }
        .background(detailBackground)
    }

    private var visionDatasetDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                visionHeroPanel(
                    title: "Vision Dataset",
                    systemImage: "square.stack.3d.up",
                    description: "Browse how the vision project is structured: raw images, train/val/test splits, and examples that are useful for manual inspection."
                )
                if !viewModel.visionDatasetErrorMessage.isEmpty {
                    warningBanner(viewModel.visionDatasetErrorMessage)
                }
                visionDatasetToolbar
                visionDatasetMetrics
                HStack(alignment: .top, spacing: 16) {
                    visionDatasetListPanel
                    visionDatasetPreviewPanel
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
        }
        .background(detailBackground)
    }

    private var visionTrainingDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                visionHeroPanel(
                    title: "Vision Training",
                    systemImage: "brain",
                    description: "Expose the training recipe directly in the app so you can understand what the classifier learned and which knobs matter."
                )
                if !viewModel.visionTrainingErrorMessage.isEmpty {
                    warningBanner(viewModel.visionTrainingErrorMessage)
                }
                visionTrainingToolbar
                visionTrainingMetrics
                HStack(alignment: .top, spacing: 16) {
                    visionTrainingConfigPanel
                    visionTrainingGuidePanel
                }
                visionTrainingHistoryPanel
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
        }
        .background(detailBackground)
    }

    private var visionEvaluationDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                visionHeroPanel(
                    title: "Vision Evaluation",
                    systemImage: "chart.bar.xaxis",
                    description: "Turn metrics into something explorable: confusion matrix, per-class scores, and the actual mistakes behind the numbers."
                )
                if !viewModel.visionEvaluationErrorMessage.isEmpty {
                    warningBanner(viewModel.visionEvaluationErrorMessage)
                }
                visionEvaluationToolbar
                visionEvaluationMetrics
                HStack(alignment: .top, spacing: 16) {
                    visionClassMetricsPanel
                    visionEvaluationGuidePanel
                }
                visionConfusionMatrixPanel
                HStack(alignment: .top, spacing: 16) {
                    visionEvaluationSamplesPanel
                    visionEvaluationSamplePreviewPanel
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
        }
        .background(detailBackground)
    }

    private var detectionPlaygroundDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !viewModel.detectionErrorMessage.isEmpty {
                    warningBanner(viewModel.detectionErrorMessage)
                }
                if !viewModel.detectionCameraDemoErrorMessage.isEmpty {
                    warningBanner(viewModel.detectionCameraDemoErrorMessage)
                }
                detectionPlaygroundToolbar
                detectionMetrics
                HStack(alignment: .top, spacing: 16) {
                    detectionImagePanel
                    detectionWhyPanel
                }
                detectionBoxesPanel
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
        }
        .background(detailBackground)
    }

    private var detectionDatasetDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !viewModel.detectionDatasetErrorMessage.isEmpty {
                    warningBanner(viewModel.detectionDatasetErrorMessage)
                }
                detectionDatasetToolbar
                detectionDatasetMetrics
                HStack(alignment: .top, spacing: 16) {
                    detectionDatasetListPanel
                    detectionDatasetPreviewPanel
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
        }
        .background(detailBackground)
    }

    private var detectionTrainingDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !viewModel.detectionTrainingErrorMessage.isEmpty {
                    warningBanner(viewModel.detectionTrainingErrorMessage)
                }
                detectionTrainingToolbar
                detectionTrainingMetrics
                HStack(alignment: .top, spacing: 16) {
                    detectionTrainingConfigPanel
                    detectionTrainingGuidePanel
                }
                detectionTrainingHistoryPanel
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
        }
        .background(detailBackground)
    }

    private var detectionEvaluationDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !viewModel.detectionEvaluationErrorMessage.isEmpty {
                    warningBanner(viewModel.detectionEvaluationErrorMessage)
                }
                detectionEvaluationToolbar
                detectionEvaluationMetrics
                HStack(alignment: .top, spacing: 16) {
                    detectionEvaluationSummaryPanel
                    detectionEvaluationMetricGuidePanel
                }
                HStack(alignment: .top, spacing: 16) {
                    detectionResultsPanel
                    detectionConfusionMatrixPanel
                }
                detectionValidationPreviewsPanel
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
        }
        .background(detailBackground)
    }

    private var roboticsPlaygroundDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !viewModel.detectionErrorMessage.isEmpty {
                    warningBanner(viewModel.detectionErrorMessage)
                }
                if !viewModel.detectionCameraDemoErrorMessage.isEmpty {
                    warningBanner(viewModel.detectionCameraDemoErrorMessage)
                }

                glassPanel(title: "Robotics Console", systemImage: "dot.scope.and.hand.point.up.left.fill", minHeight: 156) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("视觉引导机械臂演示")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                Text("把 Detection 结果直接映射成机械臂任务时间线、抓取点和分拣动作，用一页完成从场景识别到执行演示。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 10) {
                                    TrainingStatusBadge(title: viewModel.roboticsConfig.mode, tint: Color(red: 0.25, green: 0.50, blue: 0.95))
                                    TrainingStatusBadge(title: viewModel.roboticsConfig.scenario, tint: Color(red: 0.10, green: 0.69, blue: 0.56))
                                    TrainingStatusBadge(title: roboticsStatusLabel, tint: Color(red: 0.96, green: 0.58, blue: 0.24))
                                    if roboticsIsDebugMode {
                                        TrainingStatusBadge(title: "Manual Debug", tint: Color(red: 0.47, green: 0.56, blue: 0.98))
                                    }
                                }
                            }

                            Spacer(minLength: 12)

                            VStack(alignment: .trailing, spacing: 10) {
                                HStack(spacing: 10) {
                                    Button {
                                        viewModel.launchDetectionCameraDemo()
                                    } label: {
                                        HStack(spacing: 8) {
                                            if viewModel.isLaunchingDetectionCameraDemo {
                                                ProgressView()
                                                    .controlSize(.small)
                                            } else {
                                                Image(systemName: "video.badge.waveform")
                                            }
                                            Text(viewModel.isDetectionCameraDemoRunning ? "Camera Running" : "Start Camera Demo")
                                        }
                                        .frame(minWidth: 150)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(viewModel.isLaunchingDetectionCameraDemo || viewModel.isDetectionCameraDemoRunning)

                                    Button {
                                        viewModel.stopDetectionCameraDemo()
                                    } label: {
                                        Label("Stop Camera", systemImage: "stop.circle")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(!viewModel.isDetectionCameraDemoRunning)

                                    Button {
                                        let previousPath = viewModel.selectedDetectionImagePath
                                        viewModel.selectDetectionImage()
                                        if !viewModel.selectedDetectionImagePath.isEmpty, viewModel.selectedDetectionImagePath != previousPath {
                                            startRoboticsTimeline()
                                        }
                                    } label: {
                                        if viewModel.isPickingDetectionImage {
                                            ProgressView().frame(width: 96)
                                        } else {
                                            Label("Choose Image", systemImage: "photo")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)

                                    Button {
                                        startRoboticsTimeline()
                                        viewModel.runRoboticsSampleDemo()
                                    } label: {
                                        Label("Load Sample Image", systemImage: "sparkles.rectangle.stack")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(viewModel.isRunningDetectionPrediction)

                                    Button {
                                        startRoboticsTimeline()
                                        viewModel.runDetectionPrediction()
                                    } label: {
                                        HStack(spacing: 8) {
                                            if viewModel.isRunningDetectionPrediction {
                                                ProgressView()
                                                    .controlSize(.small)
                                            } else {
                                                Image(systemName: "bolt.circle")
                                            }
                                            Text(viewModel.isRunningDetectionPrediction ? "Running..." : (roboticsIsDebugMode ? "Run Auto Timeline" : "Run Current Image"))
                                        }
                                        .frame(minWidth: 144)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(viewModel.selectedDetectionImagePath.isEmpty || viewModel.isRunningDetectionPrediction)

                                    Button {
                                        viewModel.refreshDetectionStatus()
                                    } label: {
                                        Label("Refresh", systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Text(viewModel.selectedDetectionImagePath.isEmpty ? "No image selected." : viewModel.selectedDetectionImagePath)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 520, alignment: .trailing)
                                    .textSelection(.enabled)
                            }
                        }

                        HStack(spacing: 14) {
                            MetricTile(title: "Task", value: roboticsTaskLabel)
                            MetricTile(title: "Target", value: roboticsTargetLabel)
                            MetricTile(title: "Planner", value: roboticsPlannerLabel)
                            MetricTile(title: "Route", value: roboticsDestinationBinLabel)
                            MetricTile(title: "Camera", value: detectionCameraStatusLabel)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    glassPanel(title: "Execution Stage", systemImage: "move.3d", minHeight: 560) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Detection Scene", systemImage: "photo")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    if viewModel.isDetectionCameraDemoRunning, let session = viewModel.liveCameraSession {
                                        ZStack {
                                            CameraPreviewView(session: session)
                                            DetectionOverlayView(
                                                detections: viewModel.detectionPrediction?.detections ?? [],
                                                frameSize: viewModel.liveCameraFrameSize
                                            )
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 450)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    } else if let image = detectionRenderedPreviewImage ?? detectionOriginalPreviewImage {
                                        Image(nsImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 450)
                                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0.16, green: 0.21, blue: 0.31),
                                                        Color(red: 0.08, green: 0.11, blue: 0.18)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(minHeight: 360)
                                            .overlay {
                                                VStack(spacing: 12) {
                                                    Image(systemName: "viewfinder.circle.fill")
                                                        .font(.system(size: 46))
                                                        .foregroundStyle(.white.opacity(0.9))
                                                    Text(viewModel.roboticsConfig.emptyStateTitle)
                                                        .font(.headline)
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Robot Motion", systemImage: "move.3d")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    RobotArmSimulationView(state: roboticsSimulationState)
                                        .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 450)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        }
                                }
                                .frame(width: 430)
                            }

                            HStack(spacing: 12) {
                                DetectionOverviewTile(title: "Target Class", value: roboticsTargetLabel, tint: Color(red: 0.22, green: 0.51, blue: 0.95))
                                DetectionOverviewTile(title: "Confidence", value: roboticsTargetConfidenceLabel, tint: Color(red: 0.12, green: 0.70, blue: 0.56))
                                DetectionOverviewTile(title: "Pick Point", value: roboticsPickPointLabel, tint: Color(red: 0.96, green: 0.58, blue: 0.24))
                                DetectionOverviewTile(title: "Preprocess", value: detectionPreprocessSummaryLabel, tint: Color(red: 0.55, green: 0.48, blue: 0.94))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        glassPanel(title: roboticsBilingualLabel("mission_timer", fallback: "任务计时 Mission Timer"), systemImage: "timer", minHeight: 160) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(roboticsElapsedTimeLabel)
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                HStack(spacing: 12) {
                                    MetricTile(title: roboticsStageMetricTitle, value: roboticsCurrentStage)
                                    MetricTile(title: roboticsNextActionMetricTitle, value: roboticsNextAction)
                                }
                            }
                        }

                        glassPanel(title: "Stage Debugger", systemImage: "timeline.selection", minHeight: 420) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Button {
                                        setRoboticsDebugStage(max(roboticsEffectiveStageIndex - 1, 0))
                                    } label: {
                                        Label("Previous", systemImage: "chevron.left")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(viewModel.roboticsConfig.stages.isEmpty || roboticsEffectiveStageIndex <= 0)

                                    Button {
                                        if roboticsIsDebugMode {
                                            clearRoboticsDebugStage()
                                        } else {
                                            setRoboticsDebugStage(max(roboticsEffectiveStageIndex, 0))
                                        }
                                    } label: {
                                        Label(roboticsIsDebugMode ? "Exit Debug" : "Debug Current", systemImage: roboticsIsDebugMode ? "play.fill" : "cursorarrow.click")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(viewModel.roboticsConfig.stages.isEmpty)

                                    Button {
                                        setRoboticsDebugStage(min(roboticsEffectiveStageIndex + 1, viewModel.roboticsConfig.stages.count - 1))
                                    } label: {
                                        Label("Next", systemImage: "chevron.right")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(viewModel.roboticsConfig.stages.isEmpty || roboticsEffectiveStageIndex >= viewModel.roboticsConfig.stages.count - 1)
                                }

                                Text(roboticsDebugHint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if roboticsIsDebugMode {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("Stage Progress")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text("\(Int(roboticsDebugStageProgress * 100))%")
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }

                                        Slider(value: $roboticsDebugStageProgress, in: 0...1)

                                        let options = roboticsDebugPhaseOptions(for: roboticsStageID)
                                        if !options.isEmpty {
                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                                                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                                                    Button(option.label) {
                                                        roboticsDebugStageProgress = option.progress
                                                    }
                                                    .buttonStyle(.bordered)
                                                }
                                            }
                                        }
                                    }
                                }

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    ForEach(Array(viewModel.roboticsConfig.stages.enumerated()), id: \.element.id) { index, stage in
                                        Button {
                                            setRoboticsDebugStage(index)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(stage.title)
                                                        .font(.subheadline.weight(.semibold))
                                                        .multilineTextAlignment(.leading)
                                                    Text(stage.detail)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(2)
                                                }
                                                Spacer(minLength: 8)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(index == roboticsEffectiveStageIndex ? roboticsStageTint(index).opacity(0.18) : Color.white.opacity(0.04))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke((index == roboticsEffectiveStageIndex ? roboticsStageTint(index) : Color.white.opacity(0.08)), lineWidth: 1)
                                        }
                                    }
                                }
                            }
                        }

                        glassPanel(title: roboticsBilingualLabel("task_stages", fallback: "任务阶段 Task Stages"), systemImage: "list.bullet.clipboard", minHeight: 560) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(viewModel.roboticsConfig.stages.enumerated()), id: \.element.id) { index, stage in
                                    RoboticsStageRow(title: stage.title, status: roboticsStageStatus(index), tint: roboticsStageTint(index), detail: stage.detail)
                                }
                            }
                        }
                    }
                    .frame(width: 360)
                }

                HStack(alignment: .top, spacing: 16) {
                    glassPanel(title: "Decision and Reasoning", systemImage: "brain.head.profile", minHeight: 260) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Target Lock")
                                    .font(.headline)
                                RoboticsKeyValueRow(label: roboticsReasoningLabel("selection", fallback: "Selection"), value: roboticsSelectionReasonLabel)
                                RoboticsKeyValueRow(label: roboticsReasoningLabel("center", fallback: "Center"), value: roboticsPickPointLabel)
                                RoboticsKeyValueRow(label: roboticsReasoningLabel("box", fallback: "Box"), value: roboticsBoundingBoxLabel)
                                RoboticsKeyValueRow(label: roboticsReasoningLabel("confidence", fallback: "Confidence"), value: roboticsTargetConfidenceLongLabel)
                                Divider()
                                Text(roboticsTargetLockNarrative)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Routing Logic")
                                    .font(.headline)
                                RoboticsKeyValueRow(label: roboticsReasoningLabel("input_class", fallback: "Input Class"), value: roboticsTargetLabel)
                                RoboticsKeyValueRow(label: roboticsReasoningLabel("rule", fallback: "Rule"), value: roboticsRoutingRuleLabel)
                                RoboticsKeyValueRow(label: roboticsReasoningLabel("output_bin", fallback: "Output Bin"), value: roboticsDestinationBinLabel)
                                RoboticsKeyValueRow(label: roboticsReasoningLabel("planner", fallback: "Planner"), value: roboticsPlannerLabel)
                                Divider()
                                Text(roboticsDecisionNarrative)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        glassPanel(title: "Action Summary", systemImage: "checkmark.seal", minHeight: 178) {
                            VStack(alignment: .leading, spacing: 10) {
                                RoboticsKeyValueRow(label: roboticsSummaryLabel("decision", fallback: "Decision"), value: roboticsDecisionLabel)
                                RoboticsKeyValueRow(label: roboticsSummaryLabel("execution", fallback: "Execution"), value: viewModel.roboticsConfig.actionExecutionLabel)
                                RoboticsKeyValueRow(label: roboticsSummaryLabel("result", fallback: "Result"), value: roboticsStatusLabel)
                                RoboticsKeyValueRow(label: roboticsSummaryLabel("runtime", fallback: "Runtime"), value: "\(viewModel.detectionStatus?.device ?? "-") | conf \(detectionConfidenceLabel) | IoU \(detectionIoULabel)")
                            }
                        }

                        glassPanel(title: "Technology Stack", systemImage: "cpu", minHeight: 240) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(viewModel.roboticsConfig.technologyCards) { card in
                                    AnswerSectionCard(
                                        title: card.title,
                                        systemImage: card.systemImage,
                                        tint: colorFromHex(card.tintHex),
                                        text: card.body
                                    )
                                }
                            }
                        }
                    }
                    .frame(width: 360)
                }

                glassPanel(title: "Runtime Snapshot", systemImage: "waveform.path.ecg", minHeight: 132) {
                    HStack(spacing: 14) {
                        MetricTile(title: "Model", value: roboticsModelLabel)
                        MetricTile(title: "Device", value: roboticsDeviceLabel)
                        MetricTile(title: "Rendered", value: roboticsRenderedImageName)
                        MetricTile(title: "Image", value: roboticsSelectedImageName)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
        }
        .onChange(of: viewModel.selectedDetectionImagePath) { _, _ in
            resetRoboticsTimeline()
        }
        .background(detailBackground)
    }

    private var roboticsWorkflowDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                glassPanel(title: "Workflow", systemImage: "point.3.connected.trianglepath.dotted", minHeight: 120) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.roboticsConfig.workflowTitle)
                            .font(.title3.weight(.semibold))
                        Text(viewModel.roboticsConfig.workflowSubtitle)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 14) {
                    MetricTile(title: "Step 1", value: "Input")
                    MetricTile(title: "Step 2", value: "OpenCV")
                    MetricTile(title: "Step 3", value: "PyTorch")
                    MetricTile(title: "Step 4", value: "Decision")
                    MetricTile(title: "Step 5", value: "Robot Action")
                }

                HStack(spacing: 14) {
                    MetricTile(title: "Model", value: roboticsModelLabel)
                    MetricTile(title: "Device", value: roboticsDeviceLabel)
                    MetricTile(title: "Conf", value: detectionConfidenceLabel)
                    MetricTile(title: "IoU", value: detectionIoULabel)
                    MetricTile(title: "Target", value: roboticsTargetLabel)
                    MetricTile(title: "Preprocess", value: detectionPreprocessSummaryLabel)
                }

                glassPanel(title: "Pipeline Overview", systemImage: "arrow.right.circle", minHeight: 180) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(viewModel.roboticsConfig.pipelineOverviewTitle)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                        Text(roboticsWorkflowOverviewText)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    ForEach(viewModel.roboticsConfig.workflowSteps.prefix(3)) { step in
                        AnswerSectionCard(
                            title: step.title,
                            systemImage: step.systemImage,
                            tint: colorFromHex(step.tintHex),
                            text: roboticsWorkflowCardText(for: step)
                        )
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    ForEach(viewModel.roboticsConfig.workflowSteps.dropFirst(3)) { step in
                        AnswerSectionCard(
                            title: step.title,
                            systemImage: step.systemImage,
                            tint: colorFromHex(step.tintHex),
                            text: roboticsWorkflowCardText(for: step)
                        )
                    }
                }

                glassPanel(title: "Runtime Snapshot", systemImage: "waveform.path.ecg", minHeight: 220) {
                    VStack(alignment: .leading, spacing: 12) {
                        RoboticsKeyValueRow(label: roboticsRuntimeLabel("image", fallback: "Image"), value: roboticsSelectedImageName)
                        RoboticsKeyValueRow(label: roboticsRuntimeLabel("rendered", fallback: "Rendered"), value: roboticsRenderedImageName)
                        RoboticsKeyValueRow(label: roboticsRuntimeLabel("target", fallback: "Target"), value: roboticsTargetLabel)
                        RoboticsKeyValueRow(label: roboticsRuntimeLabel("pick_point", fallback: "Pick Point"), value: roboticsPickPointLabel)
                        RoboticsKeyValueRow(label: roboticsRuntimeLabel("decision", fallback: "Decision"), value: roboticsDecisionLabel)
                        RoboticsKeyValueRow(label: "Camera", value: detectionCameraStatusLabel)
                        RoboticsKeyValueRow(label: "Preprocess", value: detectionPreprocessStepsLabel)
                        RoboticsKeyValueRow(label: roboticsRuntimeLabel("stage", fallback: "Stage"), value: roboticsCurrentStage)
                        RoboticsKeyValueRow(label: roboticsRuntimeLabel("next", fallback: "Next"), value: roboticsNextAction)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, detailTopPadding)
        }
        .background(detailBackground)
    }

    private var detailBackground: some View {
        LinearGradient(
            colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var visionPlaygroundToolbar: some View {
        glassPanel(title: "Playground Controls", systemImage: "slider.horizontal.3", minHeight: 120) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        viewModel.selectVisionImage()
                    } label: {
                        if viewModel.isPickingVisionImage {
                            ProgressView().frame(width: 96)
                        } else {
                            Label("Choose Image", systemImage: "photo")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewModel.refreshVisionStatus()
                    } label: {
                        Label("Refresh Status", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                Text(viewModel.selectedVisionImagePath.isEmpty ? "No image selected." : viewModel.selectedVisionImagePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var detectionPlaygroundToolbar: some View {
        glassPanel(title: "Detection Controls", systemImage: "slider.horizontal.3", minHeight: 120) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        viewModel.launchDetectionCameraDemo()
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isLaunchingDetectionCameraDemo {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "video.badge.waveform")
                            }
                            Text(viewModel.isDetectionCameraDemoRunning ? "Camera Running" : "Start Camera")
                        }
                        .frame(minWidth: 144)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLaunchingDetectionCameraDemo || viewModel.isDetectionCameraDemoRunning)

                    Button {
                        viewModel.stopDetectionCameraDemo()
                    } label: {
                        Label("Stop Camera", systemImage: "stop.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isDetectionCameraDemoRunning)

                    Button {
                        viewModel.selectDetectionImage()
                    } label: {
                        if viewModel.isPickingDetectionImage {
                            ProgressView().frame(width: 96)
                        } else {
                            Label("Choose Image", systemImage: "photo")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewModel.refreshDetectionStatus()
                    } label: {
                        Label("Refresh Status", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.runDetectionPrediction()
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isRunningDetectionPrediction {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "scope")
                            }
                            Text(viewModel.isRunningDetectionPrediction ? "Running..." : "Run Detection")
                        }
                        .frame(minWidth: 158)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.selectedDetectionImagePath.isEmpty || viewModel.isRunningDetectionPrediction)
                }

                Text(viewModel.selectedDetectionImagePath.isEmpty ? "No image selected." : viewModel.selectedDetectionImagePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 14) {
                    MetricTile(title: "Camera", value: detectionCameraStatusLabel)
                    MetricTile(title: "Preprocess", value: detectionPreprocessSummaryLabel)
                    MetricTile(title: "Pick Point", value: roboticsPickPointLabel)
                    MetricTile(title: "Decision", value: roboticsDecisionLabel)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Confidence Threshold")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f", viewModel.detectionConfidenceThreshold))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $viewModel.detectionConfidenceThreshold, in: 0.05...0.95, step: 0.05)

                    HStack(spacing: 8) {
                        detectionThresholdPresetButton(0.50)
                        detectionThresholdPresetButton(0.70)
                        detectionThresholdPresetButton(0.85)
                    }
                }
            }
        }
    }

    private var visionMetrics: some View {
        HStack(spacing: 14) {
            MetricTile(title: "Mode", value: viewModel.visionStatus?.rejectionMode.capitalized ?? "-")
            MetricTile(title: "Threshold", value: visionThresholdLabel)
            MetricTile(title: "Final Label", value: viewModel.visionPrediction?.finalLabel ?? "-")
            MetricTile(title: "Accepted", value: boolLabel(viewModel.visionPrediction?.accepted))
            MetricTile(title: "Image Size", value: viewModel.visionStatus?.imageSize.map(String.init) ?? "-")
        }
    }

    private var detectionMetrics: some View {
        HStack(spacing: 14) {
            MetricTile(title: "Model", value: viewModel.detectionStatus?.modelName ?? "-")
            MetricTile(title: "Image Size", value: viewModel.detectionStatus.map { "\($0.imageSize)" } ?? "-")
            MetricTile(title: "Conf", value: detectionConfidenceLabel)
            MetricTile(title: "IoU", value: detectionIoULabel)
            MetricTile(title: "Boxes", value: viewModel.detectionPrediction.map { "\($0.detectionCount)" } ?? "-")
            MetricTile(title: "Target", value: roboticsTargetLabel)
            MetricTile(title: "Route", value: roboticsDestinationBinLabel)
        }
    }

    private var detectionDatasetToolbar: some View {
        glassPanel(title: "Dataset Controls", systemImage: "slider.horizontal.3", minHeight: 120) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Picker("Split", selection: viewModel.detectionDatasetBucketBinding) {
                        ForEach(DetectionDatasetBucket.allCases) { bucket in
                            Text(bucket.title).tag(bucket)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)

                    Picker("Class", selection: viewModel.detectionDatasetClassFilterBinding) {
                        ForEach(DetectionDatasetClassFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)

                    Button {
                        viewModel.refreshDetectionDataset()
                    } label: {
                        Label("Refresh Dataset", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.openDetectionAnnotationTool()
                    } label: {
                        Label("启动标注", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedDetectionDatasetBucket == .rejected)
                }

                Text("This page reads `images/` and matching YOLO `labels/`. Use it to study how normalized txt annotations become actual bounding boxes on top of each image.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detectionDatasetMetrics: some View {
        HStack(spacing: 14) {
            MetricTile(title: "Pending", value: "\(viewModel.detectionDatasetCount(bucket: .pending))")
            MetricTile(title: "Train", value: "\(viewModel.detectionDatasetCount(bucket: .train))")
            MetricTile(title: "Val", value: "\(viewModel.detectionDatasetCount(bucket: .val))")
            MetricTile(title: "Test", value: "\(viewModel.detectionDatasetCount(bucket: .test))")
            MetricTile(title: "Rejected", value: "\(viewModel.detectionDatasetCount(bucket: .rejected))")
            MetricTile(title: "Current View", value: "\(viewModel.filteredDetectionDatasetSamples.count)")
        }
    }

    private var currentDetectionDatasetClassLabel: String {
        switch viewModel.selectedDetectionDatasetClassFilter {
        case .all:
            return "All"
        case .diaper:
            return "diaper"
        case .stroller:
            return "stroller"
        case .phone:
            return "phone"
        case .unlabeled:
            return "Unlabeled"
        }
    }

    private var detectionDatasetListPanel: some View {
        glassPanel(title: "Samples", systemImage: "photo.stack", minHeight: 520) {
            if viewModel.filteredDetectionDatasetSamples.isEmpty {
                Text("No detection samples match the current filters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.filteredDetectionDatasetSamples) { sample in
                            Button {
                                viewModel.selectDetectionDatasetSample(sample.id)
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sample.fileName)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        Text("\(sample.primaryClassLabel) • \(sample.boxes.count) box")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(viewModel.selectedDetectionDatasetSampleID == sample.id ? Color.accentColor.opacity(0.16) : Color.black.opacity(0.04))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(width: 360)
    }

    private var detectionDatasetPreviewPanel: some View {
        glassPanel(title: "Preview", systemImage: "viewfinder.rectangular", minHeight: 520) {
            VStack(alignment: .leading, spacing: 14) {
                if let sample = viewModel.selectedDetectionDatasetSample {
                    if let image = NSImage(contentsOfFile: sample.imagePath) {
                        DetectionAnnotatedImage(image: image, boxes: sample.boxes)
                            .frame(maxWidth: .infinity, maxHeight: 360)
                    }

                    HStack(spacing: 10) {
                        Button {
                            viewModel.reopenSelectedDetectionSampleForAnnotation()
                        } label: {
                            Label("重新标注当前图片", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(sample.bucket == .rejected)

                        Button(role: .destructive) {
                            viewModel.clearSelectedDetectionAnnotation()
                        } label: {
                            Label("清空当前标注", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(sample.labelPath == nil)

                        Button(role: .destructive) {
                            viewModel.moveSelectedDetectionSampleToRejected()
                        } label: {
                            Label("移到 Rejected", systemImage: "tray.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .disabled(sample.bucket == .rejected)
                    }

                    keyValueRow("Filename", sample.fileName)
                    keyValueRow("Split", sample.bucket.title)
                    keyValueRow("Label File", sample.labelPath ?? "-")
                    keyValueRow("Classes", sample.classNames.isEmpty ? "unlabeled" : sample.classNames.joined(separator: ", "))

                    AnswerSectionCard(
                        title: "How To Read This",
                        systemImage: "eye",
                        tint: .blue,
                        text: "YOLO 标签存的是归一化中心点和宽高。看这页时要同时关注：框是否贴近目标、同类框风格是否一致、以及是否有漏标。"
                    )
                } else {
                    Text("Select a detection sample to preview it here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
                }
            }
        }
    }

    private var detectionEvaluationToolbar: some View {
        glassPanel(title: "评测控制", systemImage: "slider.horizontal.3", minHeight: 108) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        viewModel.refreshDetectionEvaluation()
                    } label: {
                        Label("刷新评测结果", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                Text("这个页面会读取检测模型的评测结果文件，方便你把指标、曲线图和验证集可视化结果放在一起看。")
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detectionTrainingToolbar: some View {
        glassPanel(title: "训练控制", systemImage: "slider.horizontal.3", minHeight: 108) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        viewModel.refreshDetectionTraining()
                    } label: {
                        Label("刷新训练结果", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    trainingStepperCard(
                        title: "Epochs",
                        value: viewModel.detectionTrainingEpochsInput,
                        range: 1...500,
                        binding: $viewModel.detectionTrainingEpochsInput
                    )

                    trainingStepperCard(
                        title: "Batch Size",
                        value: viewModel.detectionTrainingBatchSizeInput,
                        range: 1...128,
                        binding: $viewModel.detectionTrainingBatchSizeInput
                    )

                    Button {
                        viewModel.runDetectionTraining()
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isRunningDetectionTraining {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text(viewModel.isRunningDetectionTraining ? "训练中..." : "重新训练")
                        }
                        .frame(minWidth: 132)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRunningDetectionTraining)
                }

                Text("这个页面会读取检测器配置、YOLO 参数和 `results.csv`，方便你把训练曲线和实际训练设置对应起来。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func trainingStepperCard(
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        binding: Binding<Int>
    ) -> some View {
        Stepper(value: binding, in: range) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
            }
            .frame(minWidth: 112, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
    }

    private var detectionTrainingMetrics: some View {
        let latest = viewModel.detectionTrainingHistory.last
        return HStack(spacing: 14) {
            MetricTile(title: "Model", value: viewModel.detectionTrainingConfig["train.model_name"] ?? viewModel.detectionTrainingArgs["model"] ?? "-")
            MetricTile(title: "Epochs", value: viewModel.detectionTrainingArgs["epochs"] ?? "\(viewModel.detectionTrainingHistory.count)")
            MetricTile(title: "Batch Size", value: viewModel.detectionTrainingConfig["train.batch_size"] ?? viewModel.detectionTrainingArgs["batch"] ?? "-")
            MetricTile(title: "Image Size", value: viewModel.detectionTrainingConfig["train.image_size"] ?? viewModel.detectionTrainingArgs["imgsz"] ?? "-")
            MetricTile(title: "Latest mAP50", value: evaluationPercentLabel(latest?.map50))
            MetricTile(title: "Latest Recall", value: evaluationPercentLabel(latest?.recall))
        }
    }

    private var detectionTrainingConfigPanel: some View {
        glassPanel(title: "Training Recipe", systemImage: "list.bullet.rectangle", minHeight: 320) {
            VStack(alignment: .leading, spacing: 10) {
                keyValueRow("Run Dir", viewModel.detectionTrainingRunDir.isEmpty ? "-" : viewModel.detectionTrainingRunDir)
                keyValueRow("Weights", viewModel.detectionBestWeightsPath.isEmpty ? "-" : viewModel.detectionBestWeightsPath)
                keyValueRow("Model", viewModel.detectionTrainingConfig["train.model_name"] ?? viewModel.detectionTrainingArgs["model"] ?? "-")
                keyValueRow("Device", viewModel.detectionTrainingConfig["train.device"] ?? viewModel.detectionTrainingArgs["device"] ?? "-")
                keyValueRow("Image Size", viewModel.detectionTrainingConfig["train.image_size"] ?? viewModel.detectionTrainingArgs["imgsz"] ?? "-")
                keyValueRow("Batch Size", viewModel.detectionTrainingConfig["train.batch_size"] ?? viewModel.detectionTrainingArgs["batch"] ?? "-")
                keyValueRow("Epochs", viewModel.detectionTrainingConfig["train.epochs"] ?? viewModel.detectionTrainingArgs["epochs"] ?? "-")
                keyValueRow("Patience", viewModel.detectionTrainingConfig["train.patience"] ?? viewModel.detectionTrainingArgs["patience"] ?? "-")
            }
        }
    }

    private var detectionTrainingGuidePanel: some View {
        glassPanel(title: "这里看什么", systemImage: "graduationcap", minHeight: 320) {
            VStack(alignment: .leading, spacing: 14) {
                AnswerSectionCard(
                    title: "定位损失，对应下方 Epoch History 里的 Box",
                    systemImage: "scope",
                    tint: .orange,
                    text: "这里对应的是下方训练历史表里的 `Box`。这个值长时间偏高，通常说明模型在目标定位上还不稳定，框容易偏移、过大或过小。"
                )

                AnswerSectionCard(
                    title: "训练中的 mAP，对应上方 Latest mAP50",
                    systemImage: "chart.xyaxis.line",
                    tint: .blue,
                    text: "这里主要对应上方的 `Latest mAP50`，下方训练历史表里也能看到每个 epoch 的 `mAP50` 和 `mAP95`。这个指标既看类别对不对，也看预测框和标注框的重合程度。"
                )

                AnswerSectionCard(
                    title: "小数据风险，主要看 Epoch History 的波动",
                    systemImage: "exclamationmark.triangle",
                    tint: .green,
                    text: "这不是单独对应上方某一个按钮，而是主要看下方 `Epoch History` 里 `Recall`、`mAP50`、`mAP95` 这些列在不同 epoch 之间是否波动很大。数据少时，更应该看趋势，不要只看某一轮。"
                )
            }
        }
    }

    private var detectionTrainingHistoryPanel: some View {
        glassPanel(title: "Epoch History", systemImage: "chart.bar.doc.horizontal", minHeight: 360) {
            VStack(alignment: .leading, spacing: 10) {
                if !viewModel.detectionTrainingHistory.isEmpty {
                    HStack(spacing: 10) {
                        historyHeader("Epoch", width: 52)
                        historyHeader("Box", width: 76)
                        historyHeader("Cls", width: 76)
                        historyHeader("DFL", width: 76)
                        historyHeader("Prec", width: 76)
                        historyHeader("Recall", width: 76)
                        historyHeader("mAP50", width: 76)
                        historyHeader("mAP95", width: 76)
                    }

                    Divider()

                    ForEach(viewModel.detectionTrainingHistory) { epoch in
                        HStack(spacing: 10) {
                            historyValue("\(epoch.epoch)", width: 52)
                            historyValue(String(format: "%.3f", epoch.trainBoxLoss), width: 76)
                            historyValue(String(format: "%.3f", epoch.trainClsLoss), width: 76)
                            historyValue(String(format: "%.3f", epoch.trainDflLoss), width: 76)
                            historyValue(evaluationPercentLabel(epoch.precision), width: 76)
                            historyValue(evaluationPercentLabel(epoch.recall), width: 76)
                            historyValue(evaluationPercentLabel(epoch.map50), width: 76)
                            historyValue(evaluationPercentLabel(epoch.map50_95), width: 76)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("Detection training history not loaded.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var detectionEvaluationMetrics: some View {
        HStack(spacing: 14) {
            MetricTile(title: "mAP50", value: evaluationPercentLabel(viewModel.detectionEvaluationSummary?.map50))
            MetricTile(title: "mAP50-95", value: evaluationPercentLabel(viewModel.detectionEvaluationSummary?.map50_95))
            MetricTile(title: "Precision", value: evaluationPercentLabel(viewModel.detectionEvaluationSummary?.mp))
            MetricTile(title: "Recall", value: evaluationPercentLabel(viewModel.detectionEvaluationSummary?.mr))
            MetricTile(title: "Split", value: viewModel.detectionEvaluationSummary?.split.capitalized ?? "-")
        }
    }

    private var detectionEvaluationSummaryPanel: some View {
        glassPanel(title: "Evaluation Summary", systemImage: "list.bullet.rectangle", minHeight: 280) {
            VStack(alignment: .leading, spacing: 10) {
                keyValueRow("Run Dir", viewModel.detectionEvaluationRunDir.isEmpty ? "-" : viewModel.detectionEvaluationRunDir)
                keyValueRow("Weights", viewModel.detectionEvaluationSummary?.weights ?? "-")
                keyValueRow("Split", viewModel.detectionEvaluationSummary?.split ?? "-")
                keyValueRow("mAP50", evaluationPercentLabel(viewModel.detectionEvaluationSummary?.map50))
                keyValueRow("mAP50-95", evaluationPercentLabel(viewModel.detectionEvaluationSummary?.map50_95))
                keyValueRow("Precision", evaluationPercentLabel(viewModel.detectionEvaluationSummary?.mp))
                keyValueRow("Recall", evaluationPercentLabel(viewModel.detectionEvaluationSummary?.mr))
            }
        }
    }

    private var detectionEvaluationMetricGuidePanel: some View {
        glassPanel(title: "指标说明", systemImage: "text.book.closed", minHeight: 280) {
            VStack(alignment: .leading, spacing: 14) {
                AnswerSectionCard(
                    title: "mAP50",
                    systemImage: "chart.bar",
                    tint: .blue,
                    text: "表示在 IoU = 0.50 这个条件下，模型整体检测效果有多好。这个值越高，通常说明类别判断和框的位置都更接近真实标注。"
                )

                AnswerSectionCard(
                    title: "mAP50-95",
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: .orange,
                    text: "这是更严格的综合指标，会同时考察 IoU 从 0.50 到 0.95 的表现。它通常比 mAP50 更低，也更能反映框是否真的贴合目标。"
                )

                AnswerSectionCard(
                    title: "Precision / Recall / Split",
                    systemImage: "scope",
                    tint: .green,
                    text: "Precision 看误检多不多，越高说明多余框越少；Recall 看漏检多不多，越高说明漏掉的目标越少；Split 表示这些指标是在哪个数据划分上算出来的，这里是 test。"
                )
            }
        }
    }

    private var detectionResultsPanel: some View {
        glassPanel(title: "训练曲线快照", systemImage: "chart.xyaxis.line", minHeight: 360) {
            VStack(alignment: .leading, spacing: 12) {
                Text("这张图展示训练和验证阶段的损失、Precision、Recall、mAP50、mAP50-95 随 epoch 的变化。主要看曲线是持续变好、已经进入平台期，还是波动明显。")
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)

                if let image = detectionResultsImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Text("未找到训练曲线图。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 240, alignment: .center)
                }
            }
        }
    }

    private var detectionConfusionMatrixPanel: some View {
        glassPanel(title: "混淆矩阵 / PR 曲线", systemImage: "square.grid.3x3", minHeight: 360) {
            VStack(alignment: .leading, spacing: 14) {
                Text("上半部分混淆矩阵看类别之间有没有混淆；下半部分 PR 曲线看 Precision 和 Recall 在不同阈值下的取舍。这个面板适合判断模型是更容易误检，还是更容易漏检。")
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)

                if let image = detectionConfusionMatrixImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                if let image = detectionPrecisionRecallCurveImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                if detectionConfusionMatrixImage == nil && detectionPrecisionRecallCurveImage == nil {
                    Text("未找到混淆矩阵或 PR 曲线。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 240, alignment: .center)
                }
            }
        }
    }

    private var detectionValidationPreviewsPanel: some View {
        glassPanel(title: "验证批次预览", systemImage: "photo.stack", minHeight: 320) {
            if viewModel.detectionValidationPreviewPaths.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("这里会同时展示验证集的预测图和标注图，方便直接对比有没有漏框、多框或框偏移。看这块通常比只看数字更容易发现具体错误模式。")
                        .font(.system(size: 16, weight: .medium))
                        .lineSpacing(3)
                        .foregroundStyle(.secondary)

                    Text("未找到验证集预览图。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("这里会同时展示验证集的预测图和标注图，方便直接对比有没有漏框、多框或框偏移。看这块通常比只看数字更容易发现具体错误模式。")
                        .font(.system(size: 16, weight: .medium))
                        .lineSpacing(3)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(viewModel.detectionValidationPreviewPaths, id: \.self) { path in
                                VStack(alignment: .leading, spacing: 8) {
                                    if let image = NSImage(contentsOfFile: path) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    Text((path as NSString).lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var detectionImagePanel: some View {
        glassPanel(title: "Rendered Detection", systemImage: "photo", minHeight: 360) {
            if viewModel.isDetectionCameraDemoRunning, let session = viewModel.liveCameraSession {
                ZStack {
                    CameraPreviewView(session: session)
                    DetectionOverlayView(
                        detections: viewModel.detectionPrediction?.detections ?? [],
                        frameSize: viewModel.liveCameraFrameSize
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if let image = detectionRenderedPreviewImage ?? detectionOriginalPreviewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                Text("Choose an image to preview it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 300, alignment: .center)
            }
        }
    }

    private var detectionBoxesPanel: some View {
        glassPanel(title: "Detections", systemImage: "square.dashed", minHeight: 280) {
            VStack(alignment: .leading, spacing: 10) {
                if let prediction = viewModel.detectionPrediction {
                    HStack(spacing: 12) {
                        DetectionOverviewTile(
                            title: "Boxes",
                            value: "\(prediction.detectionCount)",
                            tint: Color(red: 0.96, green: 0.58, blue: 0.24)
                        )
                        DetectionOverviewTile(
                            title: "Top Class",
                            value: detectionTopClassLabel,
                            tint: Color(red: 0.21, green: 0.60, blue: 0.86)
                        )
                        DetectionOverviewTile(
                            title: "Avg Conf",
                            value: detectionAverageConfidenceLabel,
                            tint: Color(red: 0.16, green: 0.68, blue: 0.53)
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        keyValueRow("Runtime", "\(viewModel.detectionStatus?.device ?? "-") | conf \(detectionConfidenceLabel) | IoU \(detectionIoULabel)")
                        keyValueRow("Classes", (viewModel.detectionStatus?.classNames ?? []).joined(separator: ", ").isEmpty ? "-" : (viewModel.detectionStatus?.classNames ?? []).joined(separator: ", "))
                        keyValueRow("Weights", (viewModel.detectionPrediction?.weightsPath as NSString?)?.lastPathComponent ?? (viewModel.detectionStatus?.weightsPath as NSString?)?.lastPathComponent ?? "-")
                        keyValueRow("Center Pick", roboticsPickPointLabel)
                        keyValueRow("Decision", roboticsDecisionLabel)
                    }
                    .padding(.bottom, 6)
                }

                if let prediction = viewModel.detectionPrediction, !prediction.detections.isEmpty {
                    ForEach(prediction.detections) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.label)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(String(format: "%.4f", item.confidence))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.box.map { String(format: "%.1f", $0) }.joined(separator: ", "))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.04))
                        )
                    }
                } else {
                    Text("Run detection to inspect box-level predictions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var detectionWhyPanel: some View {
        glassPanel(title: "Why This Result", systemImage: "lightbulb", minHeight: 280) {
            VStack(alignment: .leading, spacing: 14) {
                AnswerSectionCard(
                    title: "Explanation",
                    systemImage: "text.bubble",
                    tint: .orange,
                    text: viewModel.detectionPrediction?.explanation ?? "Detection explanation will appear here after you run the model."
                )

                AnswerSectionCard(
                    title: "What to Check",
                    systemImage: "scope",
                    tint: .blue,
                    text: viewModel.detectionPrediction?.concept ?? "Run detection first, then this area will point to the parts of the result that deserve manual review."
                )
            }
        }
    }

    private var visionDatasetToolbar: some View {
        glassPanel(title: "Dataset Controls", systemImage: "slider.horizontal.3", minHeight: 120) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Picker("Split", selection: viewModel.visionDatasetBucketBinding) {
                        ForEach(VisionDatasetBucket.allCases) { bucket in
                            Text(bucket.title).tag(bucket)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)

                    Picker("Class", selection: viewModel.visionDatasetClassFilterBinding) {
                        ForEach(VisionDatasetClassFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)

                    Button {
                        viewModel.refreshVisionDataset()
                    } label: {
                        Label("Refresh Dataset", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                Text("Use this page to inspect the actual images behind each split. Start with `Raw` to understand data coverage, then switch to `Train / Val / Test` to verify the split quality.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var visionDatasetMetrics: some View {
        HStack(spacing: 14) {
            MetricTile(title: "Raw", value: "\(viewModel.visionDatasetCount(bucket: .raw))")
            MetricTile(title: "Train", value: "\(viewModel.visionDatasetCount(bucket: .train))")
            MetricTile(title: "Val", value: "\(viewModel.visionDatasetCount(bucket: .val))")
            MetricTile(title: "Test", value: "\(viewModel.visionDatasetCount(bucket: .test))")
            MetricTile(title: "Current View", value: "\(viewModel.filteredVisionDatasetSamples.count)")
            MetricTile(
                title: "Class Mix",
                value: "\(viewModel.visionDatasetCount(bucket: viewModel.selectedVisionDatasetBucket, className: "diaper")) / \(viewModel.visionDatasetCount(bucket: viewModel.selectedVisionDatasetBucket, className: "stroller"))"
            )
        }
    }

    private var visionDatasetListPanel: some View {
        glassPanel(title: "Samples", systemImage: "photo.stack", minHeight: 520) {
            if viewModel.filteredVisionDatasetSamples.isEmpty {
                Text("No samples match the current filters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.filteredVisionDatasetSamples) { sample in
                            Button {
                                viewModel.selectVisionDatasetSample(sample.id)
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sample.name)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        Text("\(sample.className) • \(sample.bucket.title)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(viewModel.selectedVisionDatasetSampleID == sample.id ? Color.accentColor.opacity(0.16) : Color.black.opacity(0.04))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(width: 360)
    }

    private var visionDatasetPreviewPanel: some View {
        glassPanel(title: "Preview", systemImage: "photo.fill.on.rectangle.fill", minHeight: 520) {
            VStack(alignment: .leading, spacing: 14) {
                if let sample = viewModel.selectedVisionDatasetSample {
                    if let image = NSImage(contentsOfFile: sample.absolutePath) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    keyValueRow("Filename", sample.name)
                    keyValueRow("Class", sample.className)
                    keyValueRow("Split", sample.bucket.title)
                    keyValueRow("Path", sample.absolutePath)

                    AnswerSectionCard(
                        title: "How To Read This",
                        systemImage: "eye",
                        tint: .blue,
                        text: "先看类内是否风格一致，再看背景、角度、裁切是否过于单一。数据分布越单调，测试集指标越容易高估真实效果。"
                    )
                } else {
                    Text("Select a sample from the list to preview it here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
                }
            }
        }
    }

    private var visionEvaluationToolbar: some View {
        glassPanel(title: "Evaluation Controls", systemImage: "slider.horizontal.3", minHeight: 108) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        viewModel.refreshVisionEvaluation()
                    } label: {
                        Label("Refresh Evaluation", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.toggleVisionEvaluationShowErrorsOnly()
                    } label: {
                        Label(
                            viewModel.visionEvaluationShowErrorsOnly ? "Show All Samples" : "Show Errors Only",
                            systemImage: viewModel.visionEvaluationShowErrorsOnly ? "line.3.horizontal.decrease.circle" : "exclamationmark.triangle"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                Text("This page reads the local evaluation artifacts generated under `vision/outputs/classification_run` and keeps them visible inside the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var visionTrainingToolbar: some View {
        glassPanel(title: "Training Controls", systemImage: "slider.horizontal.3", minHeight: 108) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        viewModel.refreshVisionTraining()
                    } label: {
                        Label("Refresh Training", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                Text("This page reads the local training summary and the current YAML config so you can connect model behavior back to the training recipe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var visionTrainingMetrics: some View {
        let latestEpoch = viewModel.visionTrainingSummary?.history.last
        return HStack(spacing: 14) {
            MetricTile(title: "Best Val Acc", value: evaluationPercentLabel(viewModel.visionTrainingSummary?.bestValAcc))
            MetricTile(title: "Epochs", value: viewModel.visionTrainingSummary.map { "\($0.history.count)" } ?? (viewModel.visionTrainingConfig["train.epochs"] ?? "-"))
            MetricTile(title: "Batch Size", value: viewModel.visionTrainingConfig["train.batch_size"] ?? "-")
            MetricTile(title: "Learning Rate", value: viewModel.visionTrainingConfig["train.learning_rate"] ?? "-")
            MetricTile(title: "Latest Train Acc", value: evaluationPercentLabel(latestEpoch?.trainAcc))
            MetricTile(title: "Latest Val Acc", value: evaluationPercentLabel(latestEpoch?.valAcc))
        }
    }

    private var visionTrainingConfigPanel: some View {
        glassPanel(title: "Training Recipe", systemImage: "list.bullet.rectangle", minHeight: 320) {
            VStack(alignment: .leading, spacing: 10) {
                keyValueRow("Model", viewModel.visionTrainingConfig["train.model_name"] ?? "-")
                keyValueRow("Pretrained", viewModel.visionTrainingConfig["train.pretrained"] ?? "-")
                keyValueRow("Device", viewModel.visionTrainingConfig["train.device"] ?? "-")
                keyValueRow("Image Size", viewModel.visionTrainingConfig["data.image_size"] ?? "-")
                keyValueRow("Epochs", viewModel.visionTrainingConfig["train.epochs"] ?? "-")
                keyValueRow("Batch Size", viewModel.visionTrainingConfig["train.batch_size"] ?? "-")
                keyValueRow("Learning Rate", viewModel.visionTrainingConfig["train.learning_rate"] ?? "-")
                keyValueRow("Weight Decay", viewModel.visionTrainingConfig["train.weight_decay"] ?? "-")
                keyValueRow("Checkpoint", viewModel.visionCheckpointPath.isEmpty ? "-" : viewModel.visionCheckpointPath)
            }
        }
    }

    private var visionTrainingGuidePanel: some View {
        glassPanel(title: "What To Learn Here", systemImage: "graduationcap", minHeight: 320) {
            VStack(alignment: .leading, spacing: 14) {
                AnswerSectionCard(
                    title: "Overfitting Signal",
                    systemImage: "waveform.path.ecg",
                    tint: .orange,
                    text: "Watch the gap between train accuracy and validation accuracy. If train keeps climbing while validation stalls or drops, the model is memorizing the training set."
                )

                AnswerSectionCard(
                    title: "Why Augmentation Matters",
                    systemImage: "wand.and.stars",
                    tint: .blue,
                    text: "Augmentation adds controlled variation such as flips, rotation, and color shifts. It helps the model rely less on narrow visual shortcuts."
                )

                AnswerSectionCard(
                    title: "Checkpointing",
                    systemImage: "externaldrive.fill.badge.checkmark",
                    tint: .green,
                    text: "The best checkpoint should reflect the best validation behavior, not simply the last epoch. That keeps deployment tied to generalization rather than training momentum."
                )
            }
        }
    }

    private var visionTrainingHistoryPanel: some View {
        glassPanel(title: "Epoch History", systemImage: "chart.xyaxis.line", minHeight: 360) {
            VStack(alignment: .leading, spacing: 10) {
                if let history = viewModel.visionTrainingSummary?.history, !history.isEmpty {
                    HStack(spacing: 10) {
                        historyHeader("Epoch", width: 56)
                        historyHeader("Train Loss", width: 96)
                        historyHeader("Train Acc", width: 96)
                        historyHeader("Val Loss", width: 96)
                        historyHeader("Val Acc", width: 96)
                    }

                    Divider()

                    ForEach(history) { epoch in
                        HStack(spacing: 10) {
                            historyValue("\(epoch.epoch)", width: 56)
                            historyValue(String(format: "%.4f", epoch.trainLoss), width: 96)
                            historyValue(evaluationPercentLabel(epoch.trainAcc), width: 96)
                            historyValue(String(format: "%.4f", epoch.valLoss), width: 96)
                            historyValue(evaluationPercentLabel(epoch.valAcc), width: 96)
                        }
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(epoch.valAcc == viewModel.visionTrainingSummary?.bestValAcc ? Color.green.opacity(0.08) : Color.clear)
                        )
                    }
                } else {
                    Text("Training summary not loaded.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var visionEvaluationMetrics: some View {
        HStack(spacing: 14) {
            MetricTile(title: "Accuracy", value: evaluationPercentLabel(viewModel.visionEvaluationReport?.accuracy))
            MetricTile(title: "Macro F1", value: evaluationPercentLabel(viewModel.visionEvaluationReport?.macroAvg.f1Score))
            MetricTile(title: "Weighted F1", value: evaluationPercentLabel(viewModel.visionEvaluationReport?.weightedAvg.f1Score))
            MetricTile(title: "Macro Recall", value: evaluationPercentLabel(viewModel.visionEvaluationReport?.macroAvg.recall))
            MetricTile(title: "Support", value: viewModel.visionEvaluationReport.map { String(format: "%.0f", $0.macroAvg.support) } ?? "-")
        }
    }

    private var visionClassMetricsPanel: some View {
        glassPanel(title: "Per-Class Metrics", systemImage: "list.bullet.rectangle", minHeight: 320) {
            VStack(alignment: .leading, spacing: 14) {
                if let report = viewModel.visionEvaluationReport {
                    ForEach(report.classMetrics, id: \.0) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.0.capitalized)
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 10) {
                                metricPill("Precision", item.1.precision)
                                metricPill("Recall", item.1.recall)
                                metricPill("F1", item.1.f1Score)
                                metricPill("Support", item.1.support, isPercent: false)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.04))
                        )
                    }
                } else {
                    Text("Evaluation report not loaded.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var visionEvaluationGuidePanel: some View {
        glassPanel(title: "How To Read It", systemImage: "graduationcap", minHeight: 320) {
            VStack(alignment: .leading, spacing: 14) {
                AnswerSectionCard(
                    title: "Accuracy vs F1",
                    systemImage: "chart.bar",
                    tint: .blue,
                    text: "Accuracy tells you overall hit rate. Macro F1 is more useful when you want each class to matter equally, even if class counts drift."
                )

                AnswerSectionCard(
                    title: "Confusion Matrix",
                    systemImage: "square.grid.2x2",
                    tint: .orange,
                    text: "Look for off-diagonal cells. Those are the concrete places where the model confuses one class for another."
                )

                AnswerSectionCard(
                    title: "Learning Takeaway",
                    systemImage: "lightbulb",
                    tint: .green,
                    text: "A clean test score can still hide weak robustness. If the dataset is visually narrow, the next improvement usually comes from adding harder examples, not only retuning the model."
                )
            }
        }
    }

    private var visionConfusionMatrixPanel: some View {
        glassPanel(title: "Confusion Matrix", systemImage: "square.grid.3x3", minHeight: 420) {
            VStack(alignment: .leading, spacing: 14) {
                if let image = visionConfusionMatrixImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Text("No confusion matrix image found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
                }

                if !viewModel.visionConfusionMatrixPath.isEmpty {
                    keyValueRow("Path", viewModel.visionConfusionMatrixPath)
                }
            }
        }
    }

    private var visionEvaluationSamplesPanel: some View {
        glassPanel(title: "Sample Outcomes", systemImage: "list.bullet.rectangle.portrait", minHeight: 420) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    MetricTile(title: "Loaded", value: "\(viewModel.visionEvaluationSamples.count)")
                    MetricTile(title: "Visible", value: "\(viewModel.filteredVisionEvaluationSamples.count)")
                    MetricTile(title: "Errors", value: "\(viewModel.visionEvaluationSamples.filter(\.isError).count)")
                }

                if viewModel.filteredVisionEvaluationSamples.isEmpty {
                    Text("No evaluation samples match the current view.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.filteredVisionEvaluationSamples) { sample in
                                Button {
                                    viewModel.selectVisionEvaluationSample(sample.id)
                                } label: {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(sample.fileName)
                                                .font(.subheadline.weight(.semibold))
                                                .lineLimit(1)
                                            Text("true: \(sample.trueLabel)  pred: \(sample.finalLabel)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        TrainingStatusBadge(
                                            title: sample.isError ? "Error" : "Correct",
                                            tint: sample.isError ? .orange : .green
                                        )
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(viewModel.selectedVisionEvaluationSampleID == sample.id ? Color.accentColor.opacity(0.16) : Color.black.opacity(0.04))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 420)
    }

    private var visionEvaluationSamplePreviewPanel: some View {
        glassPanel(title: "Selected Outcome", systemImage: "photo.badge.magnifyingglass", minHeight: 420) {
            if let sample = viewModel.selectedVisionEvaluationSample {
                VStack(alignment: .leading, spacing: 14) {
                    if let image = NSImage(contentsOfFile: sample.imagePath) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    keyValueRow("File", sample.fileName)
                    keyValueRow("True", sample.trueLabel)
                    keyValueRow("Predicted", sample.predictedLabel)
                    keyValueRow("Final", sample.finalLabel)
                    keyValueRow("Accepted", boolLabel(sample.accepted))
                    keyValueRow("Max Prob", String(format: "%.4f", sample.maxProbability))
                    keyValueRow("Similarity", sample.bestSimilarity.map { String(format: "%.4f", $0) } ?? "-")

                    AnswerSectionCard(
                        title: sample.isError ? "Why This Is Useful" : "Why This Matters",
                        systemImage: sample.isError ? "exclamationmark.triangle" : "checkmark.circle",
                        tint: sample.isError ? .orange : .green,
                        text: sample.isError
                            ? "误判样本是最值得学习的地方。先看它与真实类别的关键差异，再看背景、角度或裁切是否诱导了模型。"
                            : "正确样本也值得看。它能帮助你理解模型目前依赖了哪些稳定线索。"
                    )

                    Text(sample.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select an evaluation sample to inspect it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
            }
        }
    }

    private var visionImagePanel: some View {
        glassPanel(title: "Selected Image", systemImage: "photo", minHeight: 360) {
            if let image = visionPreviewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                Text("Choose an image to preview it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 300, alignment: .center)
            }
        }
    }

    private var visionPredictionPanel: some View {
        glassPanel(title: "Prediction", systemImage: "sparkles.rectangle.stack", minHeight: 360) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(viewModel.visionPrediction?.finalLabel ?? "-")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    if let prediction = viewModel.visionPrediction {
                        TrainingStatusBadge(
                            title: prediction.accepted ? "Accepted" : "Rejected",
                            tint: prediction.accepted ? .green : .orange
                        )
                    }
                }

                keyValueRow("Raw prediction", viewModel.visionPrediction?.predictedLabel ?? "-")
                keyValueRow("Mode", viewModel.visionPrediction?.rejectionMode ?? viewModel.visionStatus?.rejectionMode ?? "-")
                keyValueRow("Threshold", visionThresholdLabel)
                keyValueRow("Max probability", visionMaxProbabilityLabel)
                keyValueRow("Best similarity", visionSimilarityLabel)
                keyValueRow("Known classes", (viewModel.visionStatus?.classNames ?? []).joined(separator: ", ").isEmpty ? "-" : (viewModel.visionStatus?.classNames ?? []).joined(separator: ", "))
            }
        }
    }

    private var visionTopPredictionsPanel: some View {
        glassPanel(title: "Top Predictions", systemImage: "list.number", minHeight: 280) {
            VStack(alignment: .leading, spacing: 10) {
                if let prediction = viewModel.visionPrediction, !prediction.topPredictions.isEmpty {
                    ForEach(prediction.topPredictions) { item in
                        scoreRow(title: item.label, score: item.score)
                    }
                } else {
                    Text("Run inference to inspect class probabilities.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var visionWhyPanel: some View {
        glassPanel(title: "Why This Result", systemImage: "lightbulb", minHeight: 280) {
            VStack(alignment: .leading, spacing: 14) {
                AnswerSectionCard(
                    title: "Explanation",
                    systemImage: "text.bubble",
                    tint: .orange,
                    text: viewModel.visionPrediction?.explanation ?? "Inference explanation will appear here after you run the model."
                )

                AnswerSectionCard(
                    title: "Concept",
                    systemImage: "graduationcap",
                    tint: .blue,
                    text: viewModel.visionPrediction?.concept ?? "Use this area to connect the prediction back to a vision concept such as confidence, rejection, or prototype similarity."
                )

                if let prediction = viewModel.visionPrediction, !prediction.prototypeScores.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prototype Similarity")
                            .font(.subheadline.weight(.semibold))
                        ForEach(prediction.prototypeScores) { item in
                            scoreRow(title: item.label, score: item.score)
                        }
                    }
                }
            }
        }
    }

    private var visionPreviewImage: NSImage? {
        guard !viewModel.selectedVisionImagePath.isEmpty else { return nil }
        return NSImage(contentsOfFile: viewModel.selectedVisionImagePath)
    }

    private var detectionOriginalPreviewImage: NSImage? {
        guard !viewModel.selectedDetectionImagePath.isEmpty else { return nil }
        return NSImage(contentsOfFile: viewModel.selectedDetectionImagePath)
    }

    private var detectionRenderedPreviewImage: NSImage? {
        guard let path = viewModel.detectionPrediction?.renderedImagePath, !path.isEmpty else { return nil }
        return NSImage(contentsOfFile: path)
    }

    private var detectionResultsImage: NSImage? {
        guard !viewModel.detectionResultsImagePath.isEmpty else { return nil }
        return NSImage(contentsOfFile: viewModel.detectionResultsImagePath)
    }

    private var detectionConfusionMatrixImage: NSImage? {
        guard !viewModel.detectionConfusionMatrixPath.isEmpty else { return nil }
        return NSImage(contentsOfFile: viewModel.detectionConfusionMatrixPath)
    }

    private var detectionPrecisionRecallCurveImage: NSImage? {
        guard !viewModel.detectionPrecisionRecallCurvePath.isEmpty else { return nil }
        return NSImage(contentsOfFile: viewModel.detectionPrecisionRecallCurvePath)
    }

    private var visionConfusionMatrixImage: NSImage? {
        guard !viewModel.visionConfusionMatrixPath.isEmpty else { return nil }
        return NSImage(contentsOfFile: viewModel.visionConfusionMatrixPath)
    }

    private var visionThresholdLabel: String {
        if let value = viewModel.visionPrediction?.threshold {
            return String(format: "%.2f", value)
        }
        if let value = viewModel.visionStatus?.currentThreshold {
            return String(format: "%.2f", value)
        }
        return "-"
    }

    private var visionMaxProbabilityLabel: String {
        guard let value = viewModel.visionPrediction?.maxProbability else { return "-" }
        return String(format: "%.4f", value)
    }

    private var visionSimilarityLabel: String {
        guard let value = viewModel.visionPrediction?.bestSimilarity else { return "-" }
        return String(format: "%.4f", value)
    }

    private var detectionConfidenceLabel: String {
        String(format: "%.2f", viewModel.detectionConfidenceThreshold)
    }

    private var detectionIoULabel: String {
        String(format: "%.2f", viewModel.detectionIoUThreshold)
    }

    private var detectionTopClassLabel: String {
        guard let topDetection = viewModel.detectionPrediction?.detections.max(by: { $0.confidence < $1.confidence }) else {
            return "-"
        }
        return topDetection.label
    }

    private var detectionAverageConfidenceLabel: String {
        guard let detections = viewModel.detectionPrediction?.detections, !detections.isEmpty else {
            return "-"
        }
        let average = detections.reduce(0.0) { partial, item in
            partial + item.confidence
        } / Double(detections.count)
        return String(format: "%.2f", average)
    }

    private var roboticsTopDetection: DetectionBox? {
        viewModel.detectionPrediction?.robotics?.target
        ?? viewModel.detectionPrediction?.detections.max(by: { $0.confidence < $1.confidence })
    }

    private var roboticsHasPrediction: Bool {
        !(viewModel.detectionPrediction?.detections.isEmpty ?? true)
    }

    private var roboticsTaskLabel: String {
        guard roboticsHasPrediction else { return viewModel.roboticsConfig.idleTask }
        return viewModel.roboticsConfig.taskTemplate.replacingOccurrences(of: "{label}", with: roboticsTargetLabel)
    }

    private var roboticsStatusLabel: String {
        if roboticsIsDebugMode {
            return "Debug"
        }
        if viewModel.isRunningDetectionPrediction {
            return "Running"
        }
        if roboticsDemoIsComplete {
            return "Complete"
        }
        if roboticsHasPrediction {
            return "Ready"
        }
        if !viewModel.selectedDetectionImagePath.isEmpty {
            return "Image Loaded"
        }
        return "Idle"
    }

    private var roboticsTargetLabel: String {
        roboticsTopDetection?.label ?? "-"
    }

    private var roboticsTargetConfidenceLabel: String {
        guard let confidence = roboticsTopDetection?.confidence else { return "-" }
        return String(format: "%.2f", confidence)
    }

    private var roboticsTargetConfidenceLongLabel: String {
        guard let confidence = roboticsTopDetection?.confidence else { return "-" }
        return String(format: "%.4f", confidence)
    }

    private var roboticsPickPointLabel: String {
        if let pickPoint = viewModel.detectionPrediction?.robotics?.pickPoint {
            return "(\(Int(pickPoint.x)), \(Int(pickPoint.y)))"
        }
        guard let box = roboticsTopDetection?.box, box.count >= 4 else { return "-" }
        let x = (box[0] + box[2]) / 2
        let y = (box[1] + box[3]) / 2
        return "(\(Int(x)), \(Int(y)))"
    }

    private var roboticsBoundingBoxLabel: String {
        guard let box = roboticsTopDetection?.box, box.count >= 4 else { return "-" }
        return box.map { String(Int($0)) }.joined(separator: ", ")
    }

    private var roboticsElapsedTimeLabel: String {
        if roboticsIsDebugMode {
            return "Manual"
        }
        return String(format: "%.1fs", roboticsDemoElapsed)
    }

    private var roboticsStageMetricTitle: String {
        if roboticsIsDebugMode {
            return "Debug Stage"
        }
        return roboticsBilingualLabel("current_stage", fallback: "当前阶段 Current Stage")
    }

    private var roboticsNextActionMetricTitle: String {
        if roboticsIsDebugMode {
            return "Auto Timeline"
        }
        return roboticsBilingualLabel("next_action", fallback: "下一步 Next Action")
    }

    private var roboticsCurrentStage: String {
        guard roboticsEffectiveStageIndex >= 0, roboticsEffectiveStageIndex < viewModel.roboticsConfig.stages.count else {
            return !viewModel.selectedDetectionImagePath.isEmpty ? "Ready" : "Idle"
        }
        return viewModel.roboticsConfig.stages[roboticsEffectiveStageIndex].title
    }

    private var roboticsStageID: String {
        if roboticsIsDebugMode,
           roboticsEffectiveStageIndex >= 0,
           roboticsEffectiveStageIndex < viewModel.roboticsConfig.stages.count {
            return viewModel.roboticsConfig.stages[roboticsEffectiveStageIndex].id
        }
        if roboticsDemoIsComplete {
            return "complete"
        }
        guard roboticsDemoStageIndex >= 0, roboticsDemoStageIndex < viewModel.roboticsConfig.stages.count else {
            return !viewModel.selectedDetectionImagePath.isEmpty ? "ready" : "idle"
        }
        return viewModel.roboticsConfig.stages[roboticsDemoStageIndex].id
    }

    private var roboticsNextAction: String {
        if roboticsIsDebugMode {
            let nextIndex = roboticsEffectiveStageIndex + 1
            if nextIndex >= 0, nextIndex < viewModel.roboticsConfig.stages.count {
                return "Paused at \(viewModel.roboticsConfig.stages[roboticsEffectiveStageIndex].title)"
            }
            return "Paused in Debug"
        }
        if roboticsDemoIsComplete {
            return "Demo Complete"
        }
        let nextIndex = roboticsDemoStageIndex + 1
        if nextIndex >= 0, nextIndex < viewModel.roboticsConfig.stages.count {
            return viewModel.roboticsConfig.stages[nextIndex].title
        }
        return !viewModel.selectedDetectionImagePath.isEmpty ? "Run Detection" : "Choose Image"
    }

    private var roboticsDecisionLabel: String {
        guard roboticsHasPrediction else { return "Awaiting detection result" }
        return "Send \(roboticsTargetLabel) to \(roboticsDestinationBinLabel)"
    }

    private var roboticsDestinationBinLabel: String {
        guard roboticsHasPrediction else { return "-" }
        if let destinationBin = viewModel.detectionPrediction?.robotics?.destinationBin, !destinationBin.isEmpty {
            return destinationBin
        }
        return viewModel.roboticsConfig.routes.first(where: { $0.className == roboticsTargetLabel })?.destinationBin
            ?? viewModel.roboticsConfig.defaultDestinationBin
    }

    private var roboticsRoutingRuleLabel: String {
        guard roboticsHasPrediction else { return "\(viewModel.roboticsConfig.routeRuleDescription) is idle until a target is detected." }
        if let routeRule = viewModel.detectionPrediction?.robotics?.routeRule, !routeRule.isEmpty {
            return routeRule
        }
        return "\(roboticsTargetLabel) -> \(roboticsDestinationBinLabel)"
    }

    private var roboticsSelectionReasonLabel: String {
        guard roboticsHasPrediction else { return "No target locked yet" }
        if let selectionReason = viewModel.detectionPrediction?.robotics?.selectionReason, !selectionReason.isEmpty {
            return selectionReason
        }
        return "Highest-confidence detection selected as the active target."
    }

    private var roboticsPlannerLabel: String {
        guard roboticsHasPrediction else { return "Waiting for detection output" }
        if let planner = viewModel.detectionPrediction?.robotics?.planner, !planner.isEmpty {
            return planner
        }
        return viewModel.roboticsConfig.planner
    }

    private var roboticsTargetPointNormalized: RobotArmSimulationState.Point? {
        guard
            let imageSize = detectionOriginalPreviewImage?.size,
            imageSize.width > 0,
            imageSize.height > 0
        else {
            return nil
        }

        let centerX: Double
        let centerY: Double
        if let pickPoint = viewModel.detectionPrediction?.robotics?.pickPoint {
            centerX = pickPoint.x
            centerY = pickPoint.y
        } else if
            let box = roboticsTopDetection?.box,
            box.count >= 4
        {
            centerX = (box[0] + box[2]) / 2
            centerY = (box[1] + box[3]) / 2
        } else {
            return nil
        }

        return RobotArmSimulationState.Point(
            x: min(max(centerX / imageSize.width, 0.05), 0.95),
            y: min(max(centerY / imageSize.height, 0.05), 0.95)
        )
    }

    private var roboticsSimulationState: RobotArmSimulationState {
        RobotArmSimulationState(
            status: roboticsIsDebugMode ? "Debug" : roboticsStatusLabel,
            stageTitle: roboticsCurrentStage,
            stageID: roboticsStageID,
            targetClass: roboticsTargetLabel,
            destinationBin: roboticsDestinationBinLabel,
            elapsedSeconds: roboticsIsDebugMode ? 0 : roboticsDemoElapsed,
            stageProgress: roboticsStageProgress,
            confidence: roboticsTopDetection?.confidence,
            targetPoint: roboticsTargetPointNormalized,
            hasTarget: roboticsHasPrediction
        )
    }

    private var roboticsStageProgress: Double {
        if roboticsIsDebugMode {
            return roboticsDebugStageProgress
        }
        guard
            roboticsDemoStageIndex >= 0,
            roboticsDemoStageIndex < viewModel.roboticsConfig.stages.count
        else {
            return roboticsDemoIsComplete ? 1.0 : 0.0
        }

        let currentStage = viewModel.roboticsConfig.stages[roboticsDemoStageIndex]
        let elapsedBeforeCurrentStage = viewModel.roboticsConfig.stages
            .prefix(roboticsDemoStageIndex)
            .reduce(0.0) { partial, stage in
                partial + stage.durationSeconds
            }

        let progress = (roboticsDemoElapsed - elapsedBeforeCurrentStage) / max(currentStage.durationSeconds, 0.001)
        return min(max(progress, 0.0), 1.0)
    }

    private var roboticsEffectiveStageIndex: Int {
        if let debugIndex = roboticsDebugStageIndex {
            return debugIndex
        }
        return roboticsDemoStageIndex
    }

    private var roboticsIsDebugMode: Bool {
        roboticsDebugStageIndex != nil
    }

    private var roboticsDebugHint: String {
        if roboticsIsDebugMode {
            return "Manual debug is active. The automatic timeline is paused, and every stage panel on this page now follows the debug selection. Previous / Next jumps to each stage's representative debug frame."
        }
        return "Click any stage to freeze the arm on that step. Use Previous / Next to walk the motion chain."
    }

    private func roboticsDebugPhaseOptions(for stageID: String) -> [(label: String, progress: Double)] {
        switch stageID {
        case "pick":
            return [
                ("Above Target", 0.22),
                ("Grip Close", 0.62),
                ("Attached", 0.76),
                ("Lift", 0.90)
            ]
        case "transfer":
            return [
                ("Leave Target", 0.18),
                ("Transport", 0.50),
                ("Above Bin", 0.82)
            ]
        case "place":
            return [
                ("Above Bin", 0.18),
                ("Lower", 0.58),
                ("At Bin", 0.94)
            ]
        case "release":
            return [
                ("Hold", 0.18),
                ("Drop", 0.58),
                ("Settled", 0.94)
            ]
        case "target_lock":
            return [
                ("Approach", 0.35),
                ("Align", 0.78)
            ]
        default:
            return []
        }
    }

    private var roboticsTargetLockNarrative: String {
        guard roboticsHasPrediction else {
            return viewModel.roboticsConfig.targetLockNarrativeEmpty
        }
        if let selectionReason = viewModel.detectionPrediction?.robotics?.selectionReason, !selectionReason.isEmpty {
            return "\(selectionReason) \(viewModel.roboticsConfig.targetLockNarrativeBody)"
        }
        return viewModel.roboticsConfig.targetLockNarrativeBody
    }

    private var roboticsDecisionNarrative: String {
        guard roboticsHasPrediction else {
            return viewModel.roboticsConfig.decisionNarrativeEmpty
        }
        if let routeRule = viewModel.detectionPrediction?.robotics?.routeRule, !routeRule.isEmpty {
            return "\(routeRule)。\(viewModel.roboticsConfig.decisionNarrativeBody)"
        }
        return viewModel.roboticsConfig.decisionNarrativeBody
    }

    private var roboticsModelLabel: String {
        viewModel.detectionStatus?.modelName ?? "-"
    }

    private var roboticsDeviceLabel: String {
        viewModel.detectionStatus?.device ?? "-"
    }

    private var roboticsSelectedImageName: String {
        guard !viewModel.selectedDetectionImagePath.isEmpty else { return "-" }
        return (viewModel.selectedDetectionImagePath as NSString).lastPathComponent
    }

    private var roboticsRenderedImageName: String {
        guard let path = viewModel.detectionPrediction?.renderedImagePath, !path.isEmpty else { return "-" }
        return (path as NSString).lastPathComponent
    }

    private var roboticsWorkflowOverviewText: String {
        if roboticsHasPrediction {
            return "当前工作流已经读取检测结果，并把目标 \(roboticsTargetLabel) 转成 \(roboticsDestinationBinLabel) 的分拣任务。页面结构保持不变，后续只需要替换成更真实的任务规划或硬件回传。"
        }
        return viewModel.roboticsConfig.pipelineOverviewBody
    }

    private func roboticsWorkflowCardText(for step: RoboticsInfoCardConfig) -> String {
        switch step.id {
        case "input":
            if !viewModel.selectedDetectionImagePath.isEmpty {
                return "当前输入来自 \(roboticsSelectedImageName)，作为整条视觉分析链的原始场景。"
            }
        case "opencv":
            if roboticsHasPrediction {
                return "当前已基于输入图像完成结果叠加与点位表达，抓取点使用 \(roboticsPickPointLabel) 作为模拟执行坐标；预处理链路状态为 \(detectionPreprocessStepsLabel)。"
            }
        case "pytorch":
            if roboticsHasPrediction {
                return "当前模型输出目标类别 \(roboticsTargetLabel)，最高置信度为 \(roboticsTargetConfidenceLongLabel)，模型运行设备为 \(roboticsDeviceLabel)。"
            }
        case "decision":
            if roboticsHasPrediction {
                return "当前工业视觉逻辑已根据类别路由规则生成决策：\(roboticsRoutingRuleLabel)，并输出 \(roboticsDecisionLabel)。"
            }
        case "action":
            if roboticsHasPrediction || viewModel.isRunningDetectionPrediction {
                return "当前机械臂演示状态为 \(roboticsStatusLabel)，任务阶段位于 \(roboticsCurrentStage)，下一步为 \(roboticsNextAction)。"
            }
        default:
            break
        }
        return step.body
    }

    private var detectionCameraStatusLabel: String {
        if viewModel.isDetectionCameraDemoRunning {
            return "Live"
        }
        if viewModel.isLaunchingDetectionCameraDemo {
            return "Booting"
        }
        return "Idle"
    }

    private var detectionPreprocessStepsLabel: String {
        let isEnabled = (viewModel.detectionPreprocessConfig["enabled"] ?? "").lowercased() == "true"
        guard isEnabled else { return "Disabled" }

        let activeKeys = [
            ("resize.enabled", "resize"),
            ("brightness.enabled", "brightness"),
            ("contrast.enabled", "contrast"),
            ("gaussian_blur.enabled", "blur"),
            ("roi.enabled", "roi"),
        ].compactMap { key, label -> String? in
            (viewModel.detectionPreprocessConfig[key] ?? "").lowercased() == "true" ? label : nil
        }

        return activeKeys.isEmpty ? "Enabled" : activeKeys.joined(separator: ", ")
    }

    private var detectionPreprocessSummaryLabel: String {
        detectionPreprocessStepsLabel == "Disabled" ? "Off" : "On"
    }

    private func roboticsStageStatus(_ index: Int) -> String {
        if roboticsIsDebugMode {
            if index < roboticsEffectiveStageIndex { return roboticsBilingualLabel("done", fallback: "已完成 Done") }
            if index == roboticsEffectiveStageIndex { return roboticsBilingualLabel("active", fallback: "进行中 Active") }
            return roboticsBilingualLabel("pending", fallback: "待执行 Pending")
        }
        if roboticsDemoIsComplete && index < viewModel.roboticsConfig.stages.count { return roboticsBilingualLabel("done", fallback: "已完成 Done") }
        if index < roboticsDemoStageIndex { return roboticsBilingualLabel("done", fallback: "已完成 Done") }
        if index == roboticsDemoStageIndex { return roboticsBilingualLabel("active", fallback: "进行中 Active") }
        return roboticsBilingualLabel("pending", fallback: "待执行 Pending")
    }

    private func roboticsStageTint(_ index: Int) -> Color {
        switch roboticsStageStatus(index) {
        case "Done":
            return Color(red: 0.12, green: 0.70, blue: 0.56)
        case "Active":
            return Color(red: 0.96, green: 0.58, blue: 0.24)
        default:
            return Color(red: 0.52, green: 0.57, blue: 0.67)
        }
    }

    private func colorFromHex(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
            return .accentColor
        }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    private func roboticsSummaryLabel(_ key: String, fallback: String) -> String {
        viewModel.roboticsConfig.summaryLabels[key] ?? fallback
    }

    private func roboticsRuntimeLabel(_ key: String, fallback: String) -> String {
        viewModel.roboticsConfig.runtimeSnapshotLabels[key] ?? fallback
    }

    private func roboticsReasoningLabel(_ key: String, fallback: String) -> String {
        viewModel.roboticsConfig.reasoningLabels[key] ?? fallback
    }

    private func roboticsBilingualLabel(_ key: String, fallback: String) -> String {
        viewModel.roboticsConfig.bilingualLabels[key] ?? fallback
    }

    private func resetRoboticsTimeline() {
        roboticsTimelineTask?.cancel()
        roboticsTimelineTask = nil
        roboticsDemoStageIndex = -1
        roboticsDemoElapsed = 0.0
        roboticsDemoIsComplete = false
        roboticsDebugStageIndex = nil
        roboticsDebugStageProgress = 0.5
    }

    private func startRoboticsTimeline() {
        roboticsTimelineTask?.cancel()
        roboticsDebugStageIndex = nil
        roboticsDebugStageProgress = 0.5
        roboticsDemoStageIndex = 0
        roboticsDemoElapsed = 0.0
        roboticsDemoIsComplete = false

        roboticsTimelineTask = Task { @MainActor in
            var elapsed = 0.0
            let stages = viewModel.roboticsConfig.stages
            guard !stages.isEmpty else { return }

            while viewModel.isRunningDetectionPrediction {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                elapsed += 0.12
                roboticsDemoElapsed = elapsed
            }

            guard viewModel.detectionPrediction != nil else {
                return
            }

            for index in 1..<stages.count {
                roboticsDemoStageIndex = index
                let duration = stages[index].durationSeconds
                let step = 0.05
                var stageElapsed = 0.0

                while stageElapsed < duration {
                    let slice = min(step, duration - stageElapsed)
                    try? await Task.sleep(nanoseconds: UInt64(slice * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    stageElapsed += slice
                    roboticsDemoElapsed = elapsed + stageElapsed
                }

                elapsed += duration
                roboticsDemoElapsed = elapsed
            }

            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            roboticsDemoElapsed = elapsed + 0.4
            roboticsDemoIsComplete = true
        }
    }

    private func setRoboticsDebugStage(_ index: Int) {
        guard index >= 0, index < viewModel.roboticsConfig.stages.count else { return }
        roboticsTimelineTask?.cancel()
        roboticsTimelineTask = nil
        roboticsDemoIsComplete = false
        roboticsDebugStageIndex = index
        roboticsDebugStageProgress = defaultDebugProgress(for: viewModel.roboticsConfig.stages[index].id)
    }

    private func clearRoboticsDebugStage() {
        roboticsDebugStageIndex = nil
        roboticsDebugStageProgress = 0.5
    }

    private func defaultDebugProgress(for stageID: String) -> Double {
        switch stageID {
        case "detect":
            return 0.65
        case "target_lock":
            return 0.75
        case "path_plan":
            return 0.75
        case "pick":
            return 0.76
        case "transfer":
            return 0.82
        case "place":
            return 0.58
        case "release":
            return 0.18
        case "complete":
            return 0.35
        default:
            return 0.5
        }
    }

    private func detectionThresholdPresetButton(_ value: Double) -> some View {
        Button {
            viewModel.detectionConfidenceThreshold = value
        } label: {
            Text(String(format: "%.2f", value))
                .font(.caption.monospaced())
        }
        .buttonStyle(.bordered)
    }

    private func visionHeroPanel(title: String, systemImage: String, description: String) -> some View {
        glassPanel(title: title, systemImage: systemImage, minHeight: 148) {
            VStack(alignment: .leading, spacing: 12) {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("V1 keeps these pages intentionally simple: each page owns its own controls and learning context, instead of mixing everything into the sidebar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scoreRow(title: String, score: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.4f", score))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: max(8, geometry.size.width * min(max(score, 0), 1)))
                }
            }
            .frame(height: 8)
        }
    }

    private func metricPill(_ title: String, _ value: Double, isPercent: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(isPercent ? evaluationPercentLabel(value) : String(format: "%.0f", value))
                .font(.system(.caption, design: .monospaced).weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func historyHeader(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
    }

    private func historyValue(_ value: String, width: CGFloat) -> some View {
        Text(value)
            .font(.caption.monospaced())
            .frame(width: width, alignment: .leading)
    }

    private func evaluationPercentLabel(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f%%", value * 100)
    }

    private func visionParameterPanel(title: String, items: [(String, String)]) -> some View {
        glassPanel(title: title, systemImage: "list.bullet.rectangle", minHeight: 260) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(items, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0)
                            .font(.subheadline.weight(.semibold))
                        Text(item.1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                    )
                }
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
                    TextField("Search sample id or question", text: viewModel.trainingSearchBinding)
                        .textFieldStyle(.roundedBorder)

                    Picker("Status", selection: viewModel.trainingStatusFilterBinding) {
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
                                ForEach(viewModel.pagedTrainingSamples) { sample in
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

                        HStack {
                            Button {
                                viewModel.goToPreviousTrainingPage()
                            } label: {
                                Label("Prev", systemImage: "chevron.left")
                            }
                            .buttonStyle(.bordered)
                            .disabled(!viewModel.canGoToPreviousTrainingPage)

                            Spacer()

                            Text("Page \(viewModel.trainingPaginationLabel)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                viewModel.goToNextTrainingPage()
                            } label: {
                                Label("Next", systemImage: "chevron.right")
                            }
                            .buttonStyle(.bordered)
                            .disabled(!viewModel.canGoToNextTrainingPage)
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
                    .frame(maxHeight: .infinity, alignment: .top)
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
                        .frame(maxHeight: .infinity, alignment: .top)
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
                keyValueRow("Answer Model", viewModel.vectorIndexStatus?.answerModel ?? "-")
                keyValueRow("LoRA Adapter", viewModel.vectorIndexStatus?.loraAdapterName ?? "-")
                keyValueRow("Generation Mode", viewModel.vectorIndexStatus?.generationMode ?? "-")
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
                if let adapterPath = viewModel.vectorIndexStatus?.loraAdapterPath, !adapterPath.isEmpty {
                    keyValueRow("LoRA Path", adapterPath)
                }
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
                        Text("Import supported source files into `workspace/kb_sources/uploads` through the admin action above.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Supported formats: PDF, DOCX, images, TXT/MD, PPTX, XLS/XLSX, HTML, CSV, JSON, XML, and EPUB.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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
            Text("只有填写问题和答案的样本才能标记为 done。")
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

private struct RoboticsStageRow: View {
    let title: String
    let status: String
    let tint: Color
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(tint.opacity(0.14))
                        )
                        .foregroundStyle(tint)
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct RoboticsKeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
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

private struct DetectionOverviewTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct DetectionAnnotatedImage: View {
    let image: NSImage
    let boxes: [DetectionDatasetBox]

    var body: some View {
        GeometryReader { geometry in
            let size = fittedSize(container: geometry.size, imageSize: image.size)
            let origin = CGPoint(
                x: (geometry.size.width - size.width) / 2,
                y: (geometry.size.height - size.height) / 2
            )

            ZStack(alignment: .topLeading) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                ForEach(boxes) { box in
                    let rect = rectForBox(box, canvasSize: size, origin: origin)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(boxColor(for: box.className), lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .overlay(alignment: .topLeading) {
                            Text(box.className)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(boxColor(for: box.className))
                                .foregroundStyle(.white)
                                .clipShape(Capsule(style: .continuous))
                                .offset(x: rect.minX - rect.midX, y: rect.minY - rect.midY - 16)
                        }
                }
            }
        }
        .frame(minHeight: 280)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func fittedSize(container: CGSize, imageSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return container }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func rectForBox(_ box: DetectionDatasetBox, canvasSize: CGSize, origin: CGPoint) -> CGRect {
        let width = canvasSize.width * box.width
        let height = canvasSize.height * box.height
        let centerX = origin.x + canvasSize.width * box.xCenter
        let centerY = origin.y + canvasSize.height * box.yCenter
        return CGRect(
            x: centerX - width / 2,
            y: centerY - height / 2,
            width: width,
            height: height
        )
    }

    private func boxColor(for className: String) -> Color {
        switch className {
        case "diaper":
            return .orange
        case "stroller":
            return .blue
        case "phone":
            return .purple
        default:
            return .green
        }
    }
}
