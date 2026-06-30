import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: ContentViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.8), .indigo.opacity(0.8), .black.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        loginCard
                        searchCard
                        jobsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Encrypted IPA Fetcher")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Apple Account", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)

            TextField("Apple ID", text: $viewModel.appleID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            SecureField("Password", text: $viewModel.password)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            Button {
                viewModel.login()
            } label: {
                HStack {
                    Image(systemName: "lock.open")
                    Text(viewModel.isAuthenticating ? "Signing In..." : "Sign In")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.appleID.isEmpty || viewModel.password.isEmpty)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Find Apps", systemImage: "magnifyingglass")
                .font(.headline)

            HStack {
                TextField("Search App Store app", text: $viewModel.searchTerm)
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

                    Button("Get IPA") {
                        Task { await viewModel.requestDownload(for: app) }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var jobsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Download Queue", systemImage: "arrow.down.circle")
                .font(.headline)

            if viewModel.jobs.isEmpty {
                Text("No download requests yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.jobs) { job in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.appName).font(.subheadline.bold())
                        Text(job.bundleId).font(.caption).foregroundStyle(.secondary)
                        statusText(for: job.status)
                            .font(.caption)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusText(for status: DownloadJob.Status) -> Text {
        switch status {
        case .pending:
            return Text("Pending")
        case let .downloading(progress):
            return Text("Downloading \(Int(progress * 100))%")
        case let .completed(url):
            return Text("Completed: \(url.lastPathComponent)")
        case let .failed(message):
            return Text("Failed: \(message)")
        }
    }
}

#Preview {
    ContentView(viewModel: .init(service: IPAToolStyleService()))
}
