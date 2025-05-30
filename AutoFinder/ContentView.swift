import SwiftUI
import Combine

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var networkManager = NetworkManager.shared
    @State private var selectedTab: TabSelection = .home
    @State private var showingNetworkAlert = false
    
    var body: some View {
        Group {
            switch authManager.loadingState {
            case .loading:
                LoadingView()
            case .authenticated:
                MainTabView(selectedTab: $selectedTab)
            case .unauthenticated:
                LoginView()
            }
        }
        .onReceive(networkManager.$isConnected) { isConnected in
            showingNetworkAlert = !isConnected
        }
        .alert("네트워크 연결 없음", isPresented: $showingNetworkAlert) {
            Button("확인") {
                showingNetworkAlert = false
            }
        } message: {
            Text("인터넷 연결을 확인하고 다시 시도해주세요.")
        }
    }
}

// MARK: - Authentication State
private extension AuthManager {
    enum LoadingState {
        case loading, authenticated, unauthenticated
    }
    
    var loadingState: LoadingState {
        if isLoading { return .loading }
        return isAuthenticated ? .authenticated : .unauthenticated
    }
}

// MARK: - MainTabView
struct MainTabView: View {
    @Binding var selectedTab: TabSelection
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(TabSelection.allCases, id: \.self) { tab in
                NavigationView {
                    tab.destinationView
                }
                .tabItem {
                    Image(systemName: tab.iconName)
                    Text(tab.title)
                }
                .tag(tab)
            }
        }
        .accentColor(Color(UIConstants.Colors.primaryBlue))
    }
}

// MARK: - TabSelection
enum TabSelection: String, CaseIterable {
    case home, search, recommendation, favorite, profile
    
    var title: String {
        switch self {
        case .home: return "홈"
        case .search: return "검색"
        case .recommendation: return "AI 추천"
        case .favorite: return "즐겨찾기"
        case .profile: return "프로필"
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .recommendation: return "brain.head.profile"
        case .favorite: return "heart.fill"
        case .profile: return "person.fill"
        }
    }
    
    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .home: HomeView()
        case .search: SearchView()
        case .recommendation: RecommendationView()
        case .favorite: FavoriteView()
        case .profile: ProfileView()
        }
    }
}

// MARK: - LoadingView
struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color(UIConstants.Colors.backgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: UIConstants.Spacing.lg) {
                AppLogoView(isAnimating: $isAnimating)
                AppInfoView()
                LoadingIndicator()
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Loading Components
private struct AppLogoView: View {
    @Binding var isAnimating: Bool
    
    var body: some View {
        Image(systemName: "car.fill")
            .font(.system(size: 60))
            .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
    }
}

private struct AppInfoView: View {
    var body: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            Text(AppConstants.appName)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            Text("차량 정보를 불러오는 중...")
                .font(.subheadline)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
        }
    }
}

private struct LoadingIndicator: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: Color(UIConstants.Colors.primaryBlue)))
            .scaleEffect(1.2)
    }
}

// MARK: - Button Styles
struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                Color(UIConstants.Colors.primaryBlue)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .cornerRadius(UIConstants.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(Color(UIConstants.Colors.primaryBlue), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
