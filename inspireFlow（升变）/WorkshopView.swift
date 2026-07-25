import SwiftUI

struct WorkshopView: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var session: AppSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var workshop: WorkshopPublicDTO?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showEditSheet = false
    @State private var showAddContactSheet = false
    @State private var showAddSocialSheet = false
    @State private var isPublishing = false

    var body: some View {
        NavigationStack {
            ShengbianBackground {
                if isLoading {
                    loadingView
                } else if let workshop {
                    workshopContent(workshop)
                } else if let errorMessage {
                    errorView(errorMessage)
                }
            }
            .navigationTitle("创作主页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if workshop != nil {
                        HStack(spacing: 12) {
                            if workshop?.publishedAt == nil {
                                publishButton
                            } else {
                                Button("撤回") { Task { await withdraw() } }
                                    .font(ShengbianTypography.caption)
                                    .foregroundStyle(ShengbianColors.warning)
                            }
                            Button("编辑") { showEditSheet = true }
                                .font(ShengbianTypography.caption)
                                .foregroundStyle(ShengbianColors.primaryAction)
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                WorkshopEditSheet(workshop: workshop) { updated in
                    workshop = updated
                }
            }
            .task { await loadWorkshop() }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("加载创作主页...")
                .font(ShengbianTypography.body)
                .foregroundStyle(ShengbianColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(ShengbianColors.warning)
            Text(message)
                .font(ShengbianTypography.body)
                .foregroundStyle(ShengbianColors.secondaryText)
            Button("重试") { Task { await loadWorkshop() } }
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.primaryAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var publishButton: some View {
        Button {
            Task { await publish() }
        } label: {
            if isPublishing {
                ProgressView()
            } else {
                Label("发布", systemImage: "paperplane.fill")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.inverseText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ShengbianColors.success, in: Capsule())
            }
        }
        .disabled(isPublishing)
    }

    private func workshopContent(_ w: WorkshopPublicDTO) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header section
                headerSection(w)
                // Status badge
                statusSection(w)
                // Bio section
                if let bio = w.bio, !bio.isEmpty {
                    bioSection(bio)
                }
                // Content focus
                if let focus = w.contentFocus, !focus.isEmpty {
                    contentFocusSection(focus)
                }
                // Social accounts
                socialAccountsSection(w.socialAccounts)
                // Contact methods
                contactsSection(w.contacts)
                // Published projects
                projectsSection(w.projects)
            }
            .padding(.horizontal, ShengbianMetrics.pageMargin)
            .padding(.bottom, 40)
        }
    }

    private func headerSection(_ w: WorkshopPublicDTO) -> some View {
        HStack(spacing: 16) {
            // Avatar placeholder
            ZStack {
                Circle()
                    .fill(ShengbianColors.glassTintStrong)
                    .frame(width: 64, height: 64)
                Text(String(w.nickname.prefix(1)))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ShengbianColors.primaryAction)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(w.nickname)
                    .font(ShengbianTypography.title2)
                    .foregroundStyle(ShengbianColors.primaryText)
                if let title = w.title {
                    Text(title)
                        .font(ShengbianTypography.headline)
                        .foregroundStyle(ShengbianColors.secondaryText)
                }
                if let identity = w.creatorIdentity {
                    Text(identity)
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.listening)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ShengbianColors.listening.opacity(0.1), in: Capsule())
                }
            }
            Spacer()
        }
    }

    private func statusSection(_ w: WorkshopPublicDTO) -> some View {
        HStack(spacing: 8) {
            Image(systemName: w.publishedAt != nil ? "globe.asia.australia.fill" : "lock.fill")
                .foregroundStyle(w.publishedAt != nil ? ShengbianColors.success : ShengbianColors.secondaryText)
            Text(w.publishedAt != nil ? "已公开发布" : "草稿（仅自己可见）")
                .font(ShengbianTypography.caption)
                .foregroundStyle(w.publishedAt != nil ? ShengbianColors.success : ShengbianColors.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            (w.publishedAt != nil ? ShengbianColors.success : ShengbianColors.secondaryText).opacity(0.1),
            in: Capsule()
        )
    }

    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("个人简介")
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.primaryText)
            Text(bio)
                .font(ShengbianTypography.body)
                .foregroundStyle(ShengbianColors.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShengbianColors.glassTintStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func contentFocusSection(_ focus: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("内容方向")
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.primaryText)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                ForEach(focus, id: \.self) { tag in
                    Text(tag)
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.listening)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(ShengbianColors.listening.opacity(0.1), in: Capsule())
                }
            }
        }
    }

    private func socialAccountsSection(_ accounts: [WorkshopSocialAccountPublicDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("社交账号")
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.primaryText)
                Spacer()
                Button {
                    showAddSocialSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ShengbianColors.primaryAction)
                }
            }
            if accounts.isEmpty {
                Text("添加社交账号，让品牌方更了解你")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
            } else {
                ForEach(accounts) { account in
                    socialAccountRow(account)
                }
            }
        }
        .sheet(isPresented: $showAddSocialSheet) {
            AddSocialAccountSheet { await loadWorkshop() }
        }
    }

    private func socialAccountRow(_ account: WorkshopSocialAccountPublicDTO) -> some View {
        HStack(spacing: 10) {
            Image(systemName: account.platform.symbol)
                .foregroundStyle(ShengbianColors.primaryAction)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.platform.title)
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.primaryText)
                if let handle = account.handle {
                    Text("@\(handle)")
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.secondaryText)
                }
            }
            Spacer()
            if let followers = account.followerCount {
                Text("\(followers) 粉丝")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
            }
            Button {
                Task {
                    try? await WorkshopAPI.removeSocialAccount(account.id, accessToken: session.accessToken ?? "")
                    await loadWorkshop()
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(ShengbianColors.warning.opacity(0.6))
            }
        }
        .padding(12)
        .background(ShengbianColors.glassTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func contactsSection(_ contacts: [WorkshopContactPublicDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("联系方式")
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.primaryText)
                Spacer()
                Button {
                    showAddContactSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ShengbianColors.primaryAction)
                }
            }
            if contacts.isEmpty {
                Text("添加联系方式（默认不公开，需授权后品牌方才能看到）")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
            } else {
                ForEach(contacts) { contact in
                    contactRow(contact)
                }
            }
        }
        .sheet(isPresented: $showAddContactSheet) {
            AddContactSheet { await loadWorkshop() }
        }
    }

    private func contactRow(_ contact: WorkshopContactPublicDTO) -> some View {
        HStack(spacing: 10) {
            Image(systemName: contact.type.symbol)
                .foregroundStyle(ShengbianColors.secondaryText)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.label ?? contact.type.title)
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.primaryText)
                Text(contact.value)
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
            }
            Spacer()
            let isPrivate = contact.visibility == .private || contact.visibility == nil
            Text(isPrivate ? "仅授权品牌" : "公开")
                .font(ShengbianTypography.caption)
                .foregroundStyle(isPrivate ? ShengbianColors.secondaryText : ShengbianColors.listening)
        }
        .padding(12)
        .background(ShengbianColors.glassTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func projectsSection(_ projects: [WorkshopProjectCardPublicDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("展示项目")
                .font(ShengbianTypography.headline)
                .foregroundStyle(ShengbianColors.primaryText)
            if projects.isEmpty {
                Text("选择要展示的项目，让品牌方了解你的创作")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
            } else {
                ForEach(projects) { project in
                    projectCard(project)
                }
            }
        }
    }

    private func projectCard(_ project: WorkshopProjectCardPublicDTO) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ShengbianColors.glassTintStrong)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(ShengbianColors.secondaryText)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.primaryText)
                if let type = project.type {
                    Text(type)
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.secondaryText)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(ShengbianColors.glassTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions

    private func loadWorkshop() async {
        guard let token = session.accessToken else {
            errorMessage = "未登录"
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            workshop = try await WorkshopAPI.myWorkshop(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func publish() async {
        guard let token = session.accessToken else { return }
        isPublishing = true
        do {
            try await WorkshopAPI.publish(accessToken: token)
            Haptics.success()
            await loadWorkshop()
        } catch {
            Haptics.error()
        }
        isPublishing = false
    }

    private func withdraw() async {
        guard let token = session.accessToken else { return }
        do {
            try await WorkshopAPI.withdraw(accessToken: token)
            Haptics.impact(.light)
            await loadWorkshop()
        } catch {
            Haptics.error()
        }
    }
}

// MARK: - Edit Sheet

private struct WorkshopEditSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let current: WorkshopPublicDTO?
    let onSave: (WorkshopPublicDTO) -> Void

    @State private var nickname = ""
    @State private var title = ""
    @State private var bio = ""
    @State private var creatorIdentity = ""
    @State private var contentFocus: String = ""
    @State private var collaborationPreferences = ""
    @State private var isLoading = false

    init(workshop: WorkshopPublicDTO?, onSave: @escaping (WorkshopPublicDTO) -> Void) {
        self.current = workshop
        self.onSave = onSave
        _nickname = State(initialValue: workshop?.nickname ?? "")
        _title = State(initialValue: workshop?.title ?? "")
        _bio = State(initialValue: workshop?.bio ?? "")
        _creatorIdentity = State(initialValue: workshop?.creatorIdentity ?? "")
        _contentFocus = State(initialValue: workshop?.contentFocus?.joined(separator: "，") ?? "")
        _collaborationPreferences = State(initialValue: workshop?.collaborationPreferences ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("昵称", text: $nickname)
                    TextField("头衔（如：B站UP主、导演）", text: $title)
                    TextField("身份（如：视频创作者、00后创作者）", text: $creatorIdentity)
                }
                Section("个人简介") {
                    TextField("介绍一下自己...", text: $bio, axis: .vertical)
                        .lineLimit(6)
                }
                Section("内容方向") {
                    TextField("用逗号分隔，如：科技,生活,游戏", text: $contentFocus)
                }
                Section("合作偏好") {
                    TextField("你希望和什么样的品牌合作？", text: $collaborationPreferences, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("编辑创作主页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("保存") { Task { await save() } }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() async {
        guard let token = session.accessToken else { return }
        isLoading = true
        let focusItems = contentFocus
            .split(separator: "，").map { $0.trimmingCharacters(in: .whitespaces) }
            + contentFocus.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        do {
            let updated = try await WorkshopAPI.update(
                accessToken: token,
                nickname: nickname.isEmpty ? nil : nickname,
                title: title.isEmpty ? nil : title,
                bio: bio.isEmpty ? nil : bio,
                creatorIdentity: creatorIdentity.isEmpty ? nil : creatorIdentity,
                contentFocus: focusItems.isEmpty ? nil : Array(Set(focusItems.filter { !$0.isEmpty })),
                collaborationPreferences: collaborationPreferences.isEmpty ? nil : collaborationPreferences
            )
            Haptics.success()
            await MainActor.run {
                onSave(updated)
                dismiss()
            }
        } catch {
            Haptics.error()
        }
        isLoading = false
    }
}

// MARK: - Add Contact Sheet

private struct AddContactSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var type: ContactType = .email
    @State private var label = ""
    @State private var value = ""

    let onAdded: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("联系方式") {
                    Picker("类型", selection: $type) {
                        ForEach(ContactType.allCases, id: \.self) { t in
                            Label(t.title, systemImage: t.symbol).tag(t)
                        }
                    }
                    TextField("标签（可选）", text: $label)
                    TextField("内容（邮箱/微信/手机号等）", text: $value)
                }
            }
            .navigationTitle("添加联系方式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { Task { await add() } }
                        .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func add() async {
        guard let token = session.accessToken else { return }
        do {
            _ = try await WorkshopAPI.createContact(
                type: type,
                label: label.isEmpty ? nil : label,
                value: value,
                accessToken: token
            )
            Haptics.success()
            await MainActor.run { dismiss() }
            await onAdded()
        } catch {
            Haptics.error()
        }
    }
}

// MARK: - Add Social Account Sheet

private struct AddSocialAccountSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var platform: SocialPlatform = .bilibili
    @State private var handle = ""

    let onAdded: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("社交账号") {
                    Picker("平台", selection: $platform) {
                        ForEach(SocialPlatform.allCases, id: \.self) { p in
                            Label(p.title, systemImage: p.symbol).tag(p)
                        }
                    }
                    TextField("用户名（如：inspireFlow）", text: $handle)
                }
            }
            .navigationTitle("添加社交账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { Task { await add() } }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func add() async {
        guard let token = session.accessToken else { return }
        do {
            _ = try await WorkshopAPI.createSocialAccount(
                platform: platform,
                handle: handle.isEmpty ? nil : handle,
                accessToken: token
            )
            Haptics.success()
            await MainActor.run { dismiss() }
            await onAdded()
        } catch {
            Haptics.error()
        }
    }
}
