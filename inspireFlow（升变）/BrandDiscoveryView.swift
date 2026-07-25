import SwiftUI

struct BrandDiscoveryView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var brands: [BrandPublicDTO] = []
    @State private var selectedBrand: BrandPublicDTO?
    @State private var creators: [CreatorDiscoveryItemDTO] = []
    @State private var isLoadingBrands = true
    @State private var isLoadingCreators = false
    @State private var errorMessage: String?
    @State private var searchQuery = ""
    @State private var showNewBrandSheet = false

    var body: some View {
        NavigationStack {
            ShengbianBackground {
                if isLoadingBrands {
                    loadingView
                } else if brands.isEmpty {
                    emptyBrandView
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            brandSelector
                            if let selectedBrand {
                                creatorDiscoverySection
                            }
                        }
                        .padding(.horizontal, ShengbianMetrics.pageMargin)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("品牌发现")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showNewBrandSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(ShengbianColors.primaryText)
                    }
                }
            }
            .sheet(isPresented: $showNewBrandSheet) {
                NewBrandSheet { await loadBrands() }
            }
            .task { await loadBrands() }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("加载品牌...")
                .font(ShengbianTypography.body)
                .foregroundStyle(ShengbianColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyBrandView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(ShengbianColors.secondaryText.opacity(0.5))
            Text("还没有品牌")
                .font(ShengbianTypography.title3)
                .foregroundStyle(ShengbianColors.primaryText)
            Text("创建一个品牌，开始发现创作者")
                .font(ShengbianTypography.body)
                .foregroundStyle(ShengbianColors.secondaryText)
            Button(action: { showNewBrandSheet = true }) {
                Label("创建品牌", systemImage: "plus")
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.inverseText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        ShengbianColors.primaryAction,
                        in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                    )
            }
            .shengbianPressable(reduceMotion: reduceMotion)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var brandSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(brands, id: \.id) { brand in
                    brandChip(brand)
                }
            }
        }
    }

    private func brandChip(_ brand: BrandPublicDTO) -> some View {
        let isSelected = selectedBrand?.id == brand.id
        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                selectedBrand = brand
                Task { await loadCreators(for: brand) }
            }
        } label: {
            HStack(spacing: 6) {
                if let logo = brand.logoURL {
                    AsyncImage(url: URL(string: logo)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "building.fill")
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                }
                Text(brand.name)
                    .font(ShengbianTypography.headline)
            }
            .foregroundStyle(isSelected ? ShengbianColors.inverseText : ShengbianColors.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? ShengbianColors.primaryAction
                    : ShengbianColors.glassTintStrong,
                in: Capsule(style: .continuous)
            )
        }
        .shengbianPressable(reduceMotion: reduceMotion)
    }

    private var creatorDiscoverySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("发现创作者")
                    .font(ShengbianTypography.title3)
                    .foregroundStyle(ShengbianColors.primaryText)
                Spacer()
                if isLoadingCreators { ProgressView() }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ShengbianColors.secondaryText)
                TextField("搜索创作者...", text: $searchQuery)
                    .font(ShengbianTypography.body)
                    .foregroundStyle(ShengbianColors.primaryText)
                    .onSubmit {
                        if let brand = selectedBrand {
                            Task { await loadCreators(for: brand) }
                        }
                    }
            }
            .padding(12)
            .background(ShengbianColors.glassTintStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if creators.isEmpty && !isLoadingCreators {
                Text("暂无匹配的创作者")
                    .font(ShengbianTypography.body)
                    .foregroundStyle(ShengbianColors.secondaryText)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(creators, id: \.creatorID) { creator in
                        creatorCard(creator)
                    }
                }
            }
        }
    }

    private func creatorCard(_ creator: CreatorDiscoveryItemDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(creator.nickname)
                        .font(ShengbianTypography.headline)
                        .foregroundStyle(ShengbianColors.primaryText)
                    if let title = creator.title {
                        Text(title)
                            .font(ShengbianTypography.caption)
                            .foregroundStyle(ShengbianColors.secondaryText)
                    }
                }
                Spacer()
                if creator.isFollowed {
                    Text("已关注")
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ShengbianColors.success.opacity(0.15), in: Capsule())
                }
            }

            if let bio = creator.bio {
                Text(bio)
                    .font(ShengbianTypography.body)
                    .foregroundStyle(ShengbianColors.secondaryText)
                    .lineLimit(3)
            }

            if let focus = creator.contentFocus, !focus.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(focus, id: \.self) { tag in
                            Text(tag)
                                .font(ShengbianTypography.caption)
                                .foregroundStyle(ShengbianColors.listening)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ShengbianColors.listening.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }

            HStack {
                Label("\(creator.publishedProjectCount) 个作品", systemImage: "folder.fill")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
                Spacer()

                if !creator.isFollowed {
                    Button {
                        Task { await followCreator(creator.creatorID) }
                    } label: {
                        Label("关注", systemImage: "person.badge.plus")
                            .font(ShengbianTypography.headline)
                            .foregroundStyle(ShengbianColors.primaryAction)
                    }
                }

                Button {
                    Task { await showInterest(creator.creatorID) }
                } label: {
                    Label("表达合作意向", systemImage: "hand.raised.fill")
                        .font(ShengbianTypography.headline)
                        .foregroundStyle(ShengbianColors.inverseText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            ShengbianColors.primaryAction,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .shengbianPressable(reduceMotion: reduceMotion)
            }
        }
        .padding(14)
        .background(ShengbianColors.glassTintStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions

    private func loadBrands() async {
        guard let token = session.accessToken else { return }
        isLoadingBrands = true
        do {
            let page = try await BrandEngagementAPI.list(accessToken: token)
            brands = page.items
            if selectedBrand == nil, let first = brands.first {
                selectedBrand = first
                await loadCreators(for: first)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingBrands = false
    }

    private func loadCreators(for brand: BrandPublicDTO) async {
        guard let token = session.accessToken else { return }
        isLoadingCreators = true
        do {
            let page = try await BrandEngagementAPI.discoverCreators(
                brand.id,
                accessToken: token,
                query: searchQuery.isEmpty ? nil : searchQuery
            )
            creators = page.items
        } catch {
            // Silently fail for discovery errors
        }
        isLoadingCreators = false
    }

    private func followCreator(_ creatorID: UUID) async {
        guard let token = session.accessToken, let brand = selectedBrand else { return }
        do {
            try await BrandEngagementAPI.follow(brand.id, creatorID: creatorID, accessToken: token)
            Haptics.impact(.medium)
            await loadCreators(for: brand)
        } catch {
            Haptics.error()
        }
    }

    private func showInterest(_ creatorID: UUID) async {
        guard let token = session.accessToken, let brand = selectedBrand else { return }
        do {
            _ = try await BrandEngagementAPI.createInterest(
                brand.id,
                creatorID: creatorID,
                message: "我们对您的创作风格非常感兴趣，希望进一步沟通合作机会。",
                accessToken: token
            )
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }
}

// MARK: - New Brand Sheet

private struct NewBrandSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var websiteURL = ""
    @State private var isLoading = false

    let onCreated: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("品牌信息") {
                    TextField("品牌名称", text: $name)
                    TextField("简介（可选）", text: $description, axis: .vertical)
                        .lineLimit(3)
                    TextField("官网链接（可选）", text: $websiteURL)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("创建品牌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("创建") { Task { await create() } }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func create() async {
        guard let token = session.accessToken else { return }
        isLoading = true
        do {
            _ = try await BrandEngagementAPI.create(
                name: name,
                description: description.isEmpty ? nil : description,
                websiteURL: websiteURL.isEmpty ? nil : websiteURL,
                accessToken: token
            )
            await MainActor.run {
                dismiss()
                Task { await onCreated() }
            }
        } catch {
            Haptics.error()
        }
        isLoading = false
    }
}
