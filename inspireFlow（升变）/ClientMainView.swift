import SwiftUI

struct ClientMainView: View {
    @State private var selectedTab: ClientTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { ClientHomeView() }
                .tabItem { Label("工作台", systemImage: "rectangle.grid.2x2.fill") }
                .tag(ClientTab.home)

            NavigationStack { ClientBriefsView() }
                .tabItem { Label("委托", systemImage: "briefcase.fill") }
                .tag(ClientTab.briefs)

            NavigationStack { ClientMessagesView() }
                .tabItem { Label("需求助手", systemImage: "sparkles") }
                .tag(ClientTab.messages)

            NavigationStack { BrandDiscoveryView() }
                .tabItem { Label("发现", systemImage: "binoculars.fill") }
                .tag(ClientTab.discovery)

            NavigationStack { AccountView() }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(ClientTab.account)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private enum ClientTab: Hashable {
        case home, briefs, messages, discovery, account
    }
}