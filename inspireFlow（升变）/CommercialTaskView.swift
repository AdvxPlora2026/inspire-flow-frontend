import SwiftUI
import CryptoKit
import UIKit
import UniformTypeIdentifiers

struct CommercialTaskView: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var session: AppSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let projectID: UUID
    let projectName: String
    let existingTaskID: UUID?

    @State private var task: CommercialTaskPublicDTO?
    @State private var proof: CommercialTaskProofDTO?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Create-task form state
    @State private var showCreateForm = false
    @State private var taskTitle = ""
    @State private var taskAmount = ""
    @State private var taskDenom = "INJ"
    @State private var taskDeadline = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var isCreating = false

    // Submit-work form state
    @State private var showSubmitForm = false
    @State private var deliveryURL = ""
    @State private var selectedFileURL: URL? = nil
    @State private var showDocumentPicker = false
    @State private var isSubmitting = false
    @State private var submitErrorMessage: String?

    private var resolvedTaskID: UUID? {
        existingTaskID ?? task?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader

            if existingTaskID == nil && task == nil && !isLoading {
                noTaskView
            } else if isLoading {
                loadingState
            } else if let errorMessage {
                errorState(errorMessage)
            } else if let task {
                taskStatusCard(task)
                if let proof {
                    submissionsSection(proof.submissions)
                    chainTransactionsSection(proof.transactions)
                }
            }
        }
        .task {
            if existingTaskID != nil {
                await loadTask()
            } else {
                isLoading = false
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Label("Injective 链上履约", systemImage: "bitcoinsign.circle.fill")
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.primaryText)
            Spacer()
            if task != nil {
                Button("刷新") { Task { await loadTask() } }
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("正在获取链上任务状态...")
                .font(ShengbianTypography.body)
                .foregroundStyle(ShengbianColors.secondaryText)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.icloud")
                .font(.title2)
                .foregroundStyle(ShengbianColors.warning)
            Text(message)
                .font(ShengbianTypography.body)
                .foregroundStyle(ShengbianColors.secondaryText)
                .multilineTextAlignment(.center)
            Button("重试") { Task { await loadTask() } }
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.primaryAction)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    private func taskStatusCard(_ task: CommercialTaskPublicDTO) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(ShengbianTypography.title3)
                        .foregroundStyle(ShengbianColors.primaryText)
                    Text("预算：\(task.budget.amount) \(task.budget.denom)")
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.secondaryText)
                }
                Spacer()
                statusBadge(task.status)
            }

            Divider().background(ShengbianColors.glassBorder)

            // Status timeline
            statusTimeline(task.status)

            // Action button
            actionButton(for: task)
        }
        .padding(16)
        .background(
            ShengbianColors.glassTintStrong,
            in: RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous)
        )
    }

    private func statusBadge(_ status: CommercialTaskStatus) -> some View {
        Text(status.title)
            .font(ShengbianTypography.caption)
            .foregroundStyle(badgeColor(for: status))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                badgeColor(for: status).opacity(0.15),
                in: Capsule(style: .continuous)
            )
    }

    private func badgeColor(for status: CommercialTaskStatus) -> Color {
        switch status {
        case .created: ShengbianColors.secondaryText
        case .escrowFunded: ShengbianColors.warning
        case .submissionRecorded: ShengbianColors.listening
        case .authorizationActivated: ShengbianColors.primaryAction
        case .settlementReleased: ShengbianColors.success
        }
    }

    private func statusTimeline(_ current: CommercialTaskStatus) -> some View {
        let stages: [(CommercialTaskStatus, String, String)] = [
            (.created, "1.circle.fill", "创建任务"),
            (.escrowFunded, "2.circle.fill", "资金托管"),
            (.submissionRecorded, "3.circle.fill", "作品提交"),
            (.authorizationActivated, "4.circle.fill", "授权激活"),
            (.settlementReleased, "checkmark.circle.fill", "结算释放")
        ]
        return VStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                let isReached = stageOrder(stage.0) <= stageOrder(current)
                HStack(spacing: 10) {
                    Image(systemName: isReached ? stage.1 : "circle")
                        .foregroundStyle(isReached ? badgeColor(for: stage.0) : ShengbianColors.glassBorder)
                        .font(.caption)
                    Text(stage.2)
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(isReached ? ShengbianColors.primaryText : ShengbianColors.secondaryText)
                    Spacer()
                }
                if index < stages.count - 1 {
                    Rectangle()
                        .fill(isReached && stageOrder(stages[index + 1].0) <= stageOrder(current)
                            ? badgeColor(for: stages[index + 1].0)
                            : ShengbianColors.glassBorder)
                        .frame(width: 1.5, height: 18)
                        .padding(.leading, 6)
                }
            }
        }
    }

    private func stageOrder(_ status: CommercialTaskStatus) -> Int {
        switch status {
        case .created: 0
        case .escrowFunded: 1
        case .submissionRecorded: 2
        case .authorizationActivated: 3
        case .settlementReleased: 4
        }
    }

    @ViewBuilder
    private func actionButton(for task: CommercialTaskPublicDTO) -> some View {
        if session.role == .creator {
            switch task.status {
            case .escrowFunded:
                submitWorkButton(task)
            case .authorizationActivated:
                settleButton(task)
            default:
                EmptyView()
            }
        } else {
            switch task.status {
            case .submissionRecorded:
                authorizeButton(task)
            default:
                EmptyView()
            }
        }
    }

    private func submitWorkButton(_ task: CommercialTaskPublicDTO) -> some View {
        VStack(spacing: 10) {
            if showSubmitForm {
                submitWorkForm(task)
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showSubmitForm = true }
                } label: {
                    Label("提交作品", systemImage: "square.and.arrow.up.fill")
                        .font(ShengbianTypography.headline)
                        .foregroundStyle(ShengbianColors.inverseText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            ShengbianColors.primaryAction,
                            in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                        )
                }
                .shengbianPressable(reduceMotion: reduceMotion)
            }
        }
    }

    private func submitWorkForm(_ task: CommercialTaskPublicDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let submitErrorMessage {
                Text(submitErrorMessage)
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.warning)
            }

            TextField("作品交付链接（URL）", text: $deliveryURL)
                .font(ShengbianTypography.body)
                .foregroundStyle(ShengbianColors.primaryText)
                .keyboardType(.URL)
                .padding(10)
                .background(ShengbianColors.glassTint, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Button {
                    // Present document picker
                    showDocumentPicker = true
                } label: {
                    Label("选择文件", systemImage: "doc")
                        .font(ShengbianTypography.caption)
                }
                .sheet(isPresented: $showDocumentPicker) {
                    DocumentPicker { url in
                        selectedFileURL = url
                        if let url = url {
                            deliveryURL = url.absoluteString
                        }
                        showDocumentPicker = false
                    }
                }

                if let file = selectedFileURL {
                    Text(file.lastPathComponent)
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.secondaryText)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 10) {
                Button("取消") {
                    withAnimation(.easeOut(duration: 0.2)) { showSubmitForm = false }
                }
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.secondaryText)

                Button {
                    Task { await doSubmit(task) }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(ShengbianColors.inverseText)
                    } else {
                        Text("确认提交")
                            .font(ShengbianTypography.headline)
                    }
                }
                .foregroundStyle(ShengbianColors.inverseText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    deliveryURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting
                        ? ShengbianColors.glassTint
                        : ShengbianColors.primaryAction,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .disabled(deliveryURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
    }

    private func doSubmit(_ task: CommercialTaskPublicDTO) async {
        let url = deliveryURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token = session.accessToken, !url.isEmpty else { return }
        isSubmitting = true
        submitErrorMessage = nil
        do {
            // Generate artifact ID and SHA-256 from the delivery URL
            let artifactID = UUID()
            let sha256: String
            if let fileURL = selectedFileURL {
                // Prefer file content hash when user selected a file
                let data = try Data(contentsOf: fileURL)
                sha256 = data.sha256()
            } else {
                // Fallback: hash the URL string (weaker proof)
                sha256 = url.sha256()
            }
            _ = try await CommercialTaskAPI.submit(
                taskID: task.id,
                artifactID: artifactID,
                artifactSHA256: sha256,
                deliveryURL: url,
                accessToken: token
            )
            Haptics.success()
            showSubmitForm = false
            deliveryURL = ""
            selectedFileURL = nil
            await loadTask()
        } catch {
            submitErrorMessage = friendlyError(error)
            Haptics.error()
        }
        isSubmitting = false
    }

    private func authorizeButton(_ task: CommercialTaskPublicDTO) -> some View {
        Button {
            Task { await doAuthorize(task.id) }
        } label: {
            Label("授权结算", systemImage: "checkmark.seal.fill")
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.inverseText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ShengbianColors.primaryAction,
                    in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                )
        }
        .shengbianPressable(reduceMotion: reduceMotion)
    }

    private func settleButton(_ task: CommercialTaskPublicDTO) -> some View {
        Button {
            Task { await doSettle(task.id) }
        } label: {
            Label("释放结算", systemImage: "dollarsign.circle.fill")
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.inverseText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ShengbianColors.success,
                    in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                )
        }
        .shengbianPressable(reduceMotion: reduceMotion)
    }

    private func submissionsSection(_ submissions: [CommercialSubmissionPublicDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已提交作品")
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.primaryText)
            ForEach(submissions, id: \.id) { sub in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "doc.badge.clock.fill")
                            .foregroundStyle(ShengbianColors.secondaryText)
                        Text("SHA-256: \(String(sub.artifactSHA256.prefix(16)))...")
                            .font(ShengbianTypography.caption)
                            .foregroundStyle(ShengbianColors.secondaryText)
                            .lineLimit(1)
                    }
                    Text(sub.deliveryURL)
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.listening)
                        .lineLimit(1)
                }
                .padding(10)
                .background(ShengbianColors.glassTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func chainTransactionsSection(_ txs: [ChainTransactionPublicDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("链上交易记录")
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.primaryText)
            if let failed = txs.first(where: { $0.status == .failed }) {
                transactionFailureNotice(failed)
            }
            if txs.isEmpty {
                Text("暂无链上记录")
                    .font(ShengbianTypography.body)
                    .foregroundStyle(ShengbianColors.secondaryText)
            } else {
                ForEach(txs, id: \.id) { tx in
                    chainTransactionRow(tx)
                }
            }
        }
    }

    private func transactionFailureNotice(_ tx: ChainTransactionPublicDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("链上动作尚未确认", systemImage: "exclamationmark.triangle.fill")
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.warning)
            Text("任务状态与单笔交易状态分别计算。当前任务仍显示为任务流程状态，不能据此判断资金已完成上链。")
                .font(ShengbianTypography.caption)
                .foregroundStyle(ShengbianColors.secondaryText)
            if let reason = tx.failureReason, !reason.isEmpty {
                Text(reason)
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.warning)
            }
            if tx.retryable == true {
                Text("读取 proof 时后端会自动重试可重试的交易，请稍后刷新。")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
            } else if tx.retryable == false {
                Text("该交易不可自动重试，请根据交易哈希和浏览器记录排查。")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
            }
            Button {
                Task { await loadTask() }
            } label: {
                Label("刷新链上确认（触发自动重试）", systemImage: "arrow.clockwise")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.primaryAction)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShengbianColors.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func chainTransactionRow(_ tx: ChainTransactionPublicDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: transactionIcon(for: tx.status))
                    .foregroundStyle(transactionColor(for: tx.status))
                Text(transactionTitle(for: tx.action))
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.primaryText)
                Spacer()
                Text(transactionStatusTitle(tx.status))
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(transactionColor(for: tx.status))
            }

            if let hash = tx.transactionHash {
                Text("Tx: \(String(hash.prefix(20)))...")
                    .font(ShengbianTypography.technical)
                    .foregroundStyle(ShengbianColors.listening)
                    .lineLimit(1)
            }

            if let amount = tx.amount, let denom = tx.denom {
                Text("金额：\(amount) \(denom)")
                    .font(ShengbianTypography.technical)
                    .foregroundStyle(ShengbianColors.secondaryText)
            }

            HStack(spacing: 4) {
                Text(tx.network)
                    .font(ShengbianTypography.technical)
                    .foregroundStyle(ShengbianColors.secondaryText)
                if let cid = tx.chainID {
                    Text("(\(cid))")
                        .font(ShengbianTypography.technical)
                        .foregroundStyle(ShengbianColors.secondaryText)
                }
            }

            if let submitted = tx.submittedAt {
                Text("提交：\(Self.dateFormatter.string(from: submitted))")
                    .font(ShengbianTypography.technical)
                    .foregroundStyle(ShengbianColors.secondaryText)
            }
            if let confirmed = tx.confirmedAt {
                Text("确认：\(Self.dateFormatter.string(from: confirmed))")
                    .font(ShengbianTypography.technical)
                    .foregroundStyle(ShengbianColors.success)
            }
            if let failureReason = tx.failureReason, !failureReason.isEmpty {
                Text(failureReason)
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.warning)
            }

            if tx.status == .failed && tx.retryable == true {
                Button {
                    Task { await loadTask() }
                } label: {
                    Label("手动重试广播", systemImage: "arrow.clockwise")
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.primaryAction)
                }
            }

            if let urlStr = tx.explorerURL, let validURL = URL(string: urlStr) {
                Link("在浏览器查看", destination: validURL)
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.primaryAction)
            }
        }
        .padding(10)
        .background(ShengbianColors.glassTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func transactionTitle(for action: ChainTransactionAction) -> String {
        switch action {
        case .escrowFunded: "资金托管"
        case .submissionRecorded: "提交存证"
        case .authorizationActivated: "授权激活"
        case .settlementReleased: "结算释放"
        }
    }

    private func transactionStatusTitle(_ status: ChainTransactionStatus) -> String {
        switch status {
        case .prepared: "待广播"
        case .broadcast: "广播中"
        case .confirmed: "已确认"
        case .failed: "失败"
        }
    }

    private func transactionIcon(for status: ChainTransactionStatus) -> String {
        switch status {
        case .prepared: "clock"
        case .broadcast: "arrow.up.circle"
        case .confirmed: "checkmark.shield.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private func transactionColor(for status: ChainTransactionStatus) -> Color {
        switch status {
        case .confirmed: ShengbianColors.success
        case .failed: ShengbianColors.warning
        case .prepared, .broadcast: ShengbianColors.secondaryText
        }
    }

    // MARK: - Actions

    private var noTaskView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bitcoinsign.circle")
                .font(.system(size: 36))
                .foregroundStyle(ShengbianColors.secondaryText.opacity(0.5))

            if session.role == .client {
                // Brand side: create task button
                Text("尚未创建链上任务")
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.primaryText)
                Text("创建 Injective 链上任务后，可以追踪资金托管、作品提交和结算状态")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
                    .multilineTextAlignment(.center)

                if showCreateForm {
                    createTaskForm
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { showCreateForm = true }
                    } label: {
                        Label("创建链上任务", systemImage: "plus.circle.fill")
                            .font(ShengbianTypography.headline)
                            .foregroundStyle(ShengbianColors.inverseText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                ShengbianColors.primaryAction,
                                in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                            )
                    }
                    .shengbianPressable(reduceMotion: reduceMotion)
                }
            } else {
                // Creator side: waiting for brand
                Text("等待品牌方创建链上任务")
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.primaryText)
                Text("品牌方创建 Injective 链上任务后，你可以在这里提交作品和释放结算")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
                    .multilineTextAlignment(.center)

                Label("当前角色：创作者", systemImage: "person.fill")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.listening)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ShengbianColors.listening.opacity(0.1), in: Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            ShengbianColors.glassTintStrong,
            in: RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous)
        )
    }

    private var createTaskForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("任务标题", text: $taskTitle)
                .font(ShengbianTypography.body)
                .foregroundStyle(ShengbianColors.primaryText)
                .padding(10)
                .background(ShengbianColors.glassTint, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                TextField("金额", text: $taskAmount)
                    .keyboardType(.decimalPad)
                TextField("币种", text: $taskDenom)
                    .disabled(true)
                    .foregroundStyle(ShengbianColors.secondaryText)
            }
            .font(ShengbianTypography.body)
            .foregroundStyle(ShengbianColors.primaryText)
            .padding(10)
            .background(ShengbianColors.glassTint, in: RoundedRectangle(cornerRadius: 8))

            DatePicker("截止日期", selection: $taskDeadline, displayedComponents: .date)
                .font(ShengbianTypography.body)
                .foregroundStyle(ShengbianColors.primaryText)
                .colorScheme(.dark)

            HStack(spacing: 10) {
                Button("取消") {
                    withAnimation(.easeOut(duration: 0.2)) { showCreateForm = false }
                }
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.secondaryText)

                Button {
                    Task { await doCreate() }
                } label: {
                    if isCreating {
                        ProgressView().tint(ShengbianColors.inverseText)
                    } else {
                        Text("确认创建")
                            .font(ShengbianTypography.headline)
                    }
                }
                .foregroundStyle(ShengbianColors.inverseText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || taskAmount.isEmpty
                        ? ShengbianColors.glassTint
                        : ShengbianColors.primaryAction,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || taskAmount.isEmpty || isCreating)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    private func friendlyError(_ error: Error) -> String {
        guard let apiError = error as? APIClientError else { return error.localizedDescription }
        switch apiError {
        case .server(_, let code, let message, _):
            switch code {
            case "injective_unavailable":
                return "Injective 链尚未配置或不可用，请确认后端已设置 APP_INJECTIVE_PRIVATE_KEY 环境变量。"
            case "sequence_conflict":
                return "操作顺序冲突：该任务当前状态不允许此操作，请刷新后重试。"
            case "commercial_task_not_found":
                return "链上任务不存在或不属于当前用户。"
            case "project_not_found":
                return "关联项目不存在或不属于当前用户。"
            default:
                return message
            }
        case .unauthorized:
            return "登录状态已失效，请重新登录。"
        default:
            return apiError.localizedDescription
        }
    }

    private func loadTask() async {
        guard let taskID = resolvedTaskID else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        guard let token = session.accessToken else {
            errorMessage = "未登录"
            isLoading = false
            return
        }
        do {
            let result = try await CommercialTaskAPI.proof(taskID: taskID, accessToken: token)
            task = result.task
            proof = result
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    private func doCreate() async {
        guard let token = session.accessToken, !taskAmount.isEmpty else { return }
        let amountTrimmed = taskAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        // Basic validation: must be positive decimal with ≤18 decimal places
        if let dotIndex = amountTrimmed.firstIndex(of: ".") {
            let decimals = amountTrimmed[amountTrimmed.index(after: dotIndex)...]
            if decimals.count > 18 {
                errorMessage = "金额小数位数不能超过 18 位。"
                Haptics.error()
                return
            }
        }
        guard let _ = Decimal(string: amountTrimmed), amountTrimmed != "0" else {
            errorMessage = "金额必须为正数。"
            Haptics.error()
            return
        }
        isCreating = true
        do {
            let newTask = try await CommercialTaskAPI.create(
                projectID: projectID,
                title: taskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                budget: BudgetDTO(amount: amountTrimmed, denom: "inj"),
                deadline: taskDeadline,
                splits: [CommercialTaskSplitDTO(partyID: "creator", bps: 10000)],
                accessToken: token
            )
            // Store task ID back to the project
            appStore.setCommercialTaskID(for: projectID, taskID: newTask.id)
            task = newTask
            showCreateForm = false
            taskDenom = "INJ"
            Haptics.success()
            // Now load proof with the correct task ID
            await loadTask()
        } catch {
            errorMessage = friendlyError(error)
            Haptics.error()
        }
        isCreating = false
    }

    private func doAuthorize(_ taskID: UUID) async {
        guard let token = session.accessToken else {
            errorMessage = "请先登录"
            return
        }
        do {
            _ = try await CommercialTaskAPI.authorize(taskID: taskID, accessToken: token)
            errorMessage = nil
            Haptics.success()
            await loadTask()
        } catch {
            errorMessage = friendlyError(error)
            Haptics.error()
        }
    }

    private func doSettle(_ taskID: UUID) async {
        guard let token = session.accessToken else {
            errorMessage = "请先登录"
            return
        }
        do {
            _ = try await CommercialTaskAPI.settle(taskID: taskID, accessToken: token)
            errorMessage = nil
            Haptics.success()
            await loadTask()
        } catch {
            errorMessage = friendlyError(error)
            Haptics.error()
        }
    }
}

// MARK: - Helpers

import UniformTypeIdentifiers

private struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data, UTType.item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        init(onPick: @escaping (URL?) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}

private extension Data {
    func sha256() -> String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}



private extension String {
    func sha256() -> String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
