//
//  FeedListViewModel.swift
//  MenuBarFeed
//
//  Created by Fred Murakawa on 26/09/22.
//
//
import Combine
import Foundation
import OrderedCollections

final class FeedListViewModel: ObservableObject {
    
    private let webService = WebService()
    
    private var cleanHistoryTimer = Timer.publish(
        every: Constants.hackerNewsFetchPeriod,
        tolerance: 0.5,
        on: .main,
        in: .common
    ).autoconnect()
    private var hackerNewsTimer = Timer.publish(
        every: Constants.hackerNewsFetchPeriod,
        tolerance: 0.5,
        on: .main,
        in: .common
    ).autoconnect()
    private var redditTimer = Timer.publish(
        every: Constants.hackerNewsFetchPeriod,
        tolerance: 0.5,
        on: .main,
        in: .common
    ).autoconnect()
    private var twitterTimer = Timer.publish(
        every: Constants.twitterFetchPeriod,
        tolerance: 0.5,
        on: .main,
        in: .common
    ).autoconnect()
    private var feedTimer: Publishers.Autoconnect<Timer.TimerPublisher>?
    
    private var cleanHistoryTimerCancellable: AnyCancellable?
    private var hackerNewsTimerCancellable: AnyCancellable?
    private var redditTimerCancellable: AnyCancellable?
    private var twitterTimerCancellable: AnyCancellable?
    private var feedTimerCancellable: AnyCancellable?
    
    private var twitterUsers: [String] = UserDefaults.getSavedTwitterUsers()
    private var subredditNames: [String] = UserDefaults.getSavedSubredditNames()
    private var isHackerNewsSelected: Bool = UserDefaults.getIsHackerNewsSelected()
    private var isRedditSelected: Bool = UserDefaults.getIsRedditSelected()
    private var feedRefreshInterval: Double = UserDefaults.getFeedRefreshInterval()
    
    var isFeedSilenced: Bool = false
    
    @Published var menuBarMaxCharactersSubject: Int = {
        if UserDefaults.standard.object(forKey: Constants.menuBarMaxCharactersKey) == nil {
            UserDefaults.standard.set(Constants.defaultMenuBarCharacters, forKey: Constants.menuBarMaxCharactersKey)
        }
        return UserDefaults.standard.integer(forKey: Constants.menuBarMaxCharactersKey)
    }()
    
    private(set) var history: OrderedSet<FeedItem> = []
    private var lastUpdatedDate: Date?
    
    private var tweets: [FeedItem] = []
    private var hackerNews: [FeedItem] = []
    
    private var redditPosts: [FeedItem] = []
    private var redditPostsDict: [String: [FeedItem]] = [:]
    
    private var feedItems: [FeedItem] = []
    
    @Published var currentFeedItemTitle: String?
    private(set) var currentFeedItem: FeedItem? {
        didSet {
            currentFeedItemTitle = croppedTitle(currentFeedItem?.authorAndTitle ?? "")
        }
    }
    
    init() {
        resetHackerNewsTimer()
        resetTwitterTimer()
        resetRedditTimer()
        resetCleanHistoryTimer()
    }
    
    // MARK: - Fetch items
    
    func fetchAll() async {
        async let newTweets = fetchHackerNews()
        async let hnStories = fetchTweets()
        async let newRedditPosts = fetchReddit()
        
        let (_, _, _) = await (newTweets, hnStories, newRedditPosts)
        
        prioritizeFeedItems()
        
        await updateCurrentItem()
    }
    
    private func fetchHackerNews() async {
        guard !isFeedSilenced else {
            resetHackerNewsTimer()
            hackerNews = []
            return
        }
        
        if isHackerNewsSelected {
            hackerNews = await webService.getHackerNewsStories().filter { !history.contains($0) }.reversed() // Reverse ok
            resetHackerNewsTimer()
        } else {
            hackerNews = []
        }
    }
    
    private func fetchTweets() async {
        guard !isFeedSilenced else {
            tweets = []
            resetTwitterTimer()
            return
        }
        
        tweets = await webService.getTweets(from: twitterUsers).filter { !history.contains($0) }
        resetTwitterTimer()
    }
    
    private func fetchReddit() async {
        guard !isFeedSilenced else {
            redditPosts = []
            resetRedditTimer()
            return
        }
        
        if isRedditSelected {
            redditPostsDict = await webService.getReddits(for: subredditNames)
            sortRedditPosts()
            resetRedditTimer()
        } else {
            redditPosts = []
        }
    }
    
    // MARK: - Sort Feed Items
    
    private func sortRedditPosts() {
        var subredditsPosts: [[FeedItem]] = []
        
        for subreddit in subredditNames {
            if let posts = redditPostsDict[subreddit] {
                subredditsPosts.append(posts)
            }
        }
        
        let totalPosts: Int = subredditsPosts.reduce(0, { $0 + $1.count })
        
        while redditPosts.count < totalPosts {
            for i in 0 ..< subredditsPosts.count {
                if !subredditsPosts[i].isEmpty {
                    redditPosts.append(subredditsPosts[i].removeLast())
                }
            }
        }
        
        redditPosts = Array(redditPosts.filter { !history.contains($0) }.prefix(Constants.maxItemsToFetch).reversed())
    }
    
    private func prioritizeFeedItems() {
        feedItems.removeAll()
        
        feedItems.append(contentsOf: tweets)
        tweets.removeAll()
        
        while !hackerNews.isEmpty || !redditPosts.isEmpty {
            if !hackerNews.isEmpty {
                feedItems.append(hackerNews.removeLast())
            }
            
            let numberOfSubreddits = subredditNames.count
            
            for _ in 0 ..< numberOfSubreddits {
                if !redditPosts.isEmpty {
                    feedItems.append(redditPosts.removeLast())
                }
            }
        }
    }
    
    // MARK: - Update Menu Bar
    
    @MainActor private func updateCurrentItem() {
        // Update history
        if let feedItem = currentFeedItem {
            if !history.contains(feedItem) {
                history.append(feedItem)
            }
        }
        
        if !feedItems.isEmpty {
            let nextFeedItem = feedItems.removeFirst()
            if !history.contains(nextFeedItem) {
                if lastUpdatedDate == nil || Date().timeIntervalSince(lastUpdatedDate!) >= feedRefreshInterval - 1 {
                    currentFeedItem = nextFeedItem
                    lastUpdatedDate = Date()
                }
            }
            
        } else {
            if lastUpdatedDate == nil || Date().timeIntervalSince(lastUpdatedDate!) >= feedRefreshInterval - 1 {
                Task {
                    await fetchAll()
                    lastUpdatedDate = Date()
                }
            }
        }
        
        resetFeedTimer()
    }
    
    // MARK: - Save Preferences
    
    func onSaveButtonTapped(
        newTwitterUsernames: String,
        newSubredditNames: String,
        isHNSelected: Bool,
        isRedditSelected: Bool,
        feedRefreshInterval: Double
    ) async {
        lastUpdatedDate = nil
        
        self.isHackerNewsSelected = isHNSelected
        self.isRedditSelected = isRedditSelected
        self.feedRefreshInterval = feedRefreshInterval
        
        let arrayTwitterUsers = Array(newTwitterUsernames.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter(isValidChar(_:))
            .components(separatedBy: ",")
            .filter({ !$0.isEmpty })
        )
        
        self.twitterUsers = arrayTwitterUsers
        
        let arraySubredditNames = Array(newSubredditNames.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter(isValidChar(_:))
            .components(separatedBy: ",")
            .filter({ !$0.isEmpty })
        )
        
        self.subredditNames = arraySubredditNames
        
        UserDefaults.standard.set(arrayTwitterUsers, forKey: Constants.twitterUsersKey)
        UserDefaults.standard.set(arraySubredditNames, forKey: Constants.subredditsNamesKey)
        UserDefaults.standard.set(isHNSelected, forKey: Constants.isHackerNewsSelectedKey)
        UserDefaults.standard.set(isRedditSelected, forKey: Constants.isRedditSelectedKey)
        UserDefaults.standard.set(feedRefreshInterval, forKey: Constants.feedRefreshIntervalKey)
        
        await fetchAll()
    }
    
    // MARK: - Set Timers
    
    private func resetHackerNewsTimer() {
        hackerNewsTimerCancellable?.cancel()
        hackerNewsTimerCancellable = nil
        hackerNewsTimerCancellable = hackerNewsTimer
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.fetchHackerNews()
                    self.prioritizeFeedItems()
                    await self.updateCurrentItem()
                }
            })
    }
    
    private func resetRedditTimer() {
        redditTimerCancellable?.cancel()
        redditTimerCancellable = nil
        redditTimerCancellable = redditTimer
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.fetchReddit()
                    self.prioritizeFeedItems()
                    await self.updateCurrentItem()
                }
            })
    }
    
    private func resetTwitterTimer() {
        twitterTimerCancellable?.cancel()
        twitterTimerCancellable = nil
        twitterTimerCancellable = twitterTimer
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.fetchTweets()
                    self.prioritizeFeedItems()
                    await self.updateCurrentItem()
                }
            })
    }
    
    private func resetFeedTimer() {
        feedTimerCancellable?.cancel()
        feedTimerCancellable = nil
        if let currentFeedTimer = feedTimer {
            currentFeedTimer.upstream.connect().cancel()
            self.feedTimer = nil
        }
        
        feedTimer = Timer.publish(
            every: self.feedRefreshInterval,
            tolerance: 0.5,
            on: .main,
            in: .common
        ).autoconnect()
        
        feedTimerCancellable = feedTimer!
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                guard !self.isFeedSilenced else {
                    return
                }
                
                Task {
                    await self.updateCurrentItem()
                }
            })
    }
    
    private func resetCleanHistoryTimer() {
        cleanHistoryTimerCancellable?.cancel()
        cleanHistoryTimerCancellable = nil
        cleanHistoryTimerCancellable = cleanHistoryTimer
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                self.history = OrderedSet(self.history.suffix(Constants.maxHistoryItems))
            })
    }
    
    // MARK: - Helpers
    
    func croppedTitle(_ title: String, maxChars: Int? = nil) -> String {
        let max = maxChars ?? max(Constants.minMenuBarCharacters, menuBarMaxCharactersSubject)
        if title.count > max {
            return String(title.prefix(max)) + "..."
        } else {
            return title
        }
    }
    
    private func isValidChar(_ char: String.Element) -> Bool {
        return !char.unicodeScalars.contains(where: { !CharacterSet.alphanumerics.contains($0) && $0 != "_" && $0 != "," })
    }
    
    func onSilenceFeedTapped() {
        isFeedSilenced.toggle()
        lastUpdatedDate = nil
        
        if let feedItem = currentFeedItem {
            if !history.contains(feedItem) {
                history.append(feedItem)
            }
        }
    }
}
