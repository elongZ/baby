import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Form {
            Section("运行方式") {
                Text("App 会在启动时自动拉起本地 Python FastAPI 服务，并轮询 /health。")
                Text("如需从 Finder 或独立目录运行，请设置环境变量 BABY_APP_PROJECT_ROOT 指向仓库根目录。")
            }
            Section("当前配置") {
                LabeledContent("项目目录", value: viewModel.projectRootPath.isEmpty ? "-" : viewModel.projectRootPath)
                LabeledContent("服务状态", value: viewModel.serviceState.message)
                LabeledContent("Web 状态", value: viewModel.webState.message)
                LabeledContent("Web 地址", value: viewModel.webURLLabel)
            }
        }
        .formStyle(.grouped)
        .padding(18)
    }
}
