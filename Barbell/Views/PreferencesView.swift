import SwiftUI
import LaunchAtLogin

struct PreferencesView: View {
    
    enum FocusedField: Hashable {
        case twitterUsernames, subredditsNames
    }
    
    @FocusState private var focusedField: FocusedField?
    @ObservedObject private var viewModel: FeedListViewModel
    
    @State private var twitterUsernames: String = UserDefaults.getSavedTwitterUsers().joined(separator: ", ")
    @State private var subredditNames: String = UserDefaults.getSavedSubredditNames().joined(separator: ", ")
    @State private var isHackerNewsSelected: Bool = UserDefaults.getIsHackerNewsSelected()
    @State private var isRedditSelected: Bool = UserDefaults.getIsRedditSelected()
    @State private var feedRefreshInterval: Double = UserDefaults.getFeedRefreshInterval()
    
    init(viewModel: FeedListViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a Public Twitter User (Separate users by comma)")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                TextField("Twitter, NBA", text: $twitterUsernames)
                    .focused($focusedField, equals: .twitterUsernames)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a Subreddit (Separate by comma)")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                TextField("worldnews, wholesomememes", text: $subredditNames)
                    .focused($focusedField, equals: .subredditsNames)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $isHackerNewsSelected) {
                    Text("Hacker News")
                }
                .toggleStyle(.checkbox)
                
                Toggle(isOn: $isRedditSelected) {
                    Text("Reddit")
                }
                .toggleStyle(.checkbox)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Number of characters in feed. This will adjust the length of the menu bar app")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                TextField("Max characters", value: $viewModel.menuBarMaxCharactersSubject, format: .number)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Refresh interval (in seconds)")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                TextField("120 seconds", value: $feedRefreshInterval, format: .number)
                    .textFieldStyle(.roundedBorder)
            }
            
            Text("Showing new post every \(Int(feedRefreshInterval)) seconds. Only showing the newest tweet, not every tweet.")
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            LaunchAtLogin.Toggle()
            
            HStack {
                Button("Cancel") {
                    NSApplication.shared.keyWindow?.close()
                }
                
                Spacer()
                Button("Save") {
                    Task {
                        NSApplication.shared.keyWindow?.close()
                        await viewModel.onSaveButtonTapped(
                            newTwitterUsernames: twitterUsernames,
                            newSubredditNames: subredditNames,
                            isHNSelected: isHackerNewsSelected,
                            isRedditSelected: isRedditSelected,
                            feedRefreshInterval: feedRefreshInterval
                        )
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.focusedField = nil
                }
            }
        }
        .padding()
    }
}

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView(viewModel: FeedListViewModel())
            .frame(width: Constants.preferencesMenuWidth, height: Constants.preferencesMenuHeight)
    }
}
