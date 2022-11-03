import Foundation

struct Constants {
    static let maxHistoryItems: Int = 4
    static let defaultMenuBarCharacters: Int = 20
    static let minMenuBarCharacters: Int = 5
    static let defaultHistoryMenuCharacters: Int = 60
    static let maxItemsToFetch: Int = 22
    static let preferencesMenuWidth: CGFloat = 400
    static let preferencesMenuHeight: CGFloat = 508

    static let hackerNewsFetchPeriod: Double = 60 * 40 // 40 minutes
    static let twitterFetchPeriod: Double = 60 * 2 // 2 minutes
    static let twitterStartFetchDate: Double = -60 * 5 // Tweets in the last 5 minutes
    static let defaultFeedRefreshInterval: Double = 60 * 2 // 2 minuts
    
    static let silenceFeedPeriod: Double = 60 * 60 // 60 minutes


    //MARK: - User Defaults Keys
    
    static let twitterUsersKey = "barbell_twitterUsers"
    static let subredditsNamesKey = "barbell_subredditsNamesKey"
    static let isHackerNewsSelectedKey = "barbell_isHackerNewsSelected"
    static let isRedditSelectedKey = "barbell_isRedditSelected"
    static let menuBarMaxCharactersKey = "barbell_menuBarMaxCharacters"
    static let feedRefreshIntervalKey = "barbell_feedRefreshInterval"
}

extension UserDefaults {
    static func getSavedTwitterUsers() -> [String] {
        (UserDefaults.standard.object(forKey: Constants.twitterUsersKey) as? [String]) ?? []
    }
    
    static func getSavedSubredditNames() -> [String] {
        (UserDefaults.standard.object(forKey: Constants.subredditsNamesKey) as? [String]) ?? []
    }
    
    static func getIsHackerNewsSelected() -> Bool {
        if UserDefaults.standard.object(forKey: Constants.isHackerNewsSelectedKey) == nil {
            UserDefaults.standard.set(true, forKey: Constants.isHackerNewsSelectedKey)
        }
        return UserDefaults.standard.bool(forKey: Constants.isHackerNewsSelectedKey)
    }
    
    static func getIsRedditSelected() -> Bool {
        if UserDefaults.standard.object(forKey: Constants.isRedditSelectedKey) == nil {
            UserDefaults.standard.set(true, forKey: Constants.isRedditSelectedKey)
        }
        return UserDefaults.standard.bool(forKey: Constants.isRedditSelectedKey)
    }
    
    static func getFeedRefreshInterval() -> Double {
        if UserDefaults.standard.object(forKey: Constants.feedRefreshIntervalKey) == nil {
            UserDefaults.standard.set(Constants.defaultFeedRefreshInterval, forKey: Constants.feedRefreshIntervalKey)
        }
        return UserDefaults.standard.double(forKey: Constants.feedRefreshIntervalKey)
    }
}

extension String {
    var unescape: String {
        let characters = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'"
        ]
        var str = self
        for (escaped, unescaped) in characters {
            str = str.replacingOccurrences(of: escaped, with: unescaped, options: NSString.CompareOptions.literal, range: nil)
        }
        return str
    }
}
