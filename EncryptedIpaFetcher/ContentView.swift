import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: ContentViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.75), .indigo.opacity(0.78), .black.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView {
                initiatorTab
                    .tabItem {
                        Label(L10n.text("tab.initiator"), systemImage: "paperplane.fill")
                    }

                queueTab
                    .tabItem {
                        Label(L10n.text("tab.queue"), systemImage: "list.bullet.rectangle.portrait.fill")
                    }

                historyTab
                    .tabItem {
                        Label(L10n.text("tab.history"), systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }
            }
        }
        .alert(L10n.text("alert.errorTitle"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L10n.text("button.ok"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? L10n.text("alert.unknownError"))
        }
    }

    private var initiatorTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let infoMessage = viewModel.infoMessage, !infoMessage.isEmpty {
                        Text(infoMessage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.white)
                            .padding(12)
                            .liquidGlassCard()
                    }

                    loginCard
                    searchCard
                }
                .padding()
            }
            .navigationTitle(L10n.text("navigation.initiator"))
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var queueTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.activeJobs.isEmpty {
                        Text(L10n.text("queue.empty"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .liquidGlassCard()
                    } else {
                        ForEach(viewModel.activeJobs) { job in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(job.appName).font(.headline)
                                Text(job.bundleId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(viewModel.statusLabel(for: job.status))
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .liquidGlassCard()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.text("navigation.queue"))
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var historyTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.historyJobs.isEmpty {
                        Text(L10n.text("history.empty"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .liquidGlassCard()
                    } else {
                        ForEach(viewModel.historyJobs) { job in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(job.appName).font(.headline)
                                    Spacer()
                                    if let finishedAt = job.finishedAt {
                                        Text(finishedAt, style: .time)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(job.bundleId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(viewModel.statusLabel(for: job.status))
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .liquidGlassCard()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.text("navigation.history"))
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.text("login.title"), systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)

            TextField(L10n.text("login.appleIdPlaceholder"), text: $viewModel.appleID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            SecureField(L10n.text("login.passwordPlaceholder"), text: $viewModel.password)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            if viewModel.requiresTwoFactorCode {
                TextField(L10n.text("login.twoFactorPlaceholder"), text: $viewModel.twoFactorCode)
                    .keyboardType(.numberPad)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }

            Button {
                Task { await viewModel.login() }
            } label: {
                HStack {
                    Image(systemName: "lock.open")
                    Text(viewModel.isAuthenticating ? L10n.text("login.signingIn") : L10n.text("login.signIn"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.appleID.isEmpty || viewModel.password.isEmpty || viewModel.isAuthenticating)
        }
        .padding()
        .liquidGlassCard()
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.text("search.title"), systemImage: "magnifyingglass")
                .font(.headline)

            HStack {
                TextField(L10n.text("search.placeholder"), text: $viewModel.searchTerm)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                Button {
                    Task { await viewModel.search() }
                } label: {
                    if viewModel.isSearching {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(viewModel.results.prefix(8)) { app in
                HStack(spacing: 12) {
                    AsyncImage(url: app.artworkUrl100) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.2))
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading) {
                        Text(app.trackName)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(app.bundleId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(L10n.text("search.getIpaButton")) {
                        Task { await viewModel.requestDownload(for: app) }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(10)
                .liquidGlassCard()
            }
        }
        .padding()
        .liquidGlassCard()
    }
}

private struct LiquidGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 12, y: 8)
    }
}

private extension View {
    func liquidGlassCard() -> some View {
        modifier(LiquidGlassCardModifier())
    }
}

#Preview {
    ContentView(viewModel: .init(service: IPAToolStyleService()))
}
