import Foundation

enum NetworkError: Error {
    case invalidResponse
}

final class WebService {
    
    private let dateFormatter = ISO8601DateFormatter()
    
    func getHackerNewsStories() async -> [FeedItem] {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "hacker-news.firebaseio.com"
        urlComponents.path = "/v0/topstories.json"
        urlComponents.queryItems = [
            URLQueryItem(name: "orderBy", value: "\"$priority\""),
            URLQueryItem(name: "limitToFirst", value: "\(Constants.maxItemsToFetch)")
        ]
        
        guard let url = urlComponents.url else {
            return []
        }
        
        let request = URLRequest(url: url)
        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            print("Error: Fetch ids failed")
            return []
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Error: Status Code = \((response as? HTTPURLResponse)?.statusCode ?? 400)")
            return []
        }
        
        let decoder = JSONDecoder()
        var stories = [HNStory]()
        
        guard let indexes = (try? decoder.decode([Int].self, from: data)) else {
            print("Error: Decode failed")
            return []
        }

        for index in indexes {
            let storyUrl = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(index).json")!

            guard let (data, response) = try? await URLSession.shared.data(from: storyUrl) else {
                print("Error: Fetch news failed")
                continue
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error: Status Code = \((response as? HTTPURLResponse)?.statusCode ?? 400)")
                continue
            }

            do {
                let story = try decoder.decode(HNStory.self, from: data)
                stories.append(story)
            } catch {
                print(error.localizedDescription)
                continue
            }
        }

        return stories.map(FeedItem.init)
    }
    
    private func getUsersId(from users: [String]) async -> [String] {
        guard let bearerToken = Self.getToken() else {
            print("API key does not exist")
            return []
        }
        
        if !users.isEmpty {
            let userNames = users.joined(separator: "%2C")
            var request = URLRequest(url: URL(string: "https://api.twitter.com/2/users/by?usernames=\(userNames)&user.fields=id")!)
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    print((response as? HTTPURLResponse)?.statusCode ?? "\(response)")
                    return []
                }
                
                do {
                    let tweets = try JSONDecoder().decode(TwitterUsers.self, from: data)
                    return tweets.data?.map(\.id) ?? []
                } catch {
                    print(error.localizedDescription)
                    return []
                }
            } catch {
                print(error.localizedDescription)
                return []
            }
        }
        
        return []
    }
    
    func getTweets(from users: [String]) async -> [FeedItem] {
        guard let bearerToken = Self.getToken() else {
            print("API key does not exist")
            return []
        }
        
        guard !users.isEmpty else {
            print("No Twitter user set")
            return []
        }
        
        let ids = await getUsersId(from: users)
        
        var items = [FeedItem]()
        
        let tweetsStartDate = Date(timeIntervalSinceNow: Constants.twitterStartFetchDate)
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "api.twitter.com"
        urlComponents.queryItems = [
            URLQueryItem(name: "start_time", value: dateFormatter.string(from: tweetsStartDate)),
            URLQueryItem(name: "tweet.fields", value: "created_at")
        ]

        for (i, id) in ids.enumerated() {
            urlComponents.path = "/2/users/\(id)/tweets"
            
            guard let url = urlComponents.url else {
                continue
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            guard let (data, response) = try? await URLSession.shared.data(for: request) else {
                print("Error: Fetch tweets failed")
                continue
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error: Status Code = \((response as? HTTPURLResponse)?.statusCode ?? 400)")
                continue
            }
            
            do {
                let tweets = try JSONDecoder().decode(Tweets.self, from: data)
                
                guard let newTweets = tweets.data else {
                    continue
                }
                
                let newItems = newTweets.map { tweet -> Tweet in
                    var updatedTweet = tweet
                    updatedTweet.author = users[i]
                    return updatedTweet
                }
                
                items.append(contentsOf: newItems.map(FeedItem.init))
            } catch {
                print(error.localizedDescription)
                continue
            }
        }
        
        return items
    }
    
    func getReddits(for subreddits: [String]) async -> [String: [FeedItem]] {
        guard !subreddits.isEmpty else {
            print("No subreddit set")
            return [:]
        }
        
        var items = [String: [FeedItem]]()
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "www.reddit.com"
        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: "\(Constants.maxItemsToFetch)"),
            URLQueryItem(name: "raw_json", value: "1")
        ]

        for subreddit in subreddits {
            urlComponents.path = "/r/\(subreddit)/hot.json"
            
            guard let url = urlComponents.url else {
                continue
            }
            
            let request = URLRequest(url: url)
            guard let (data, response) = try? await URLSession.shared.data(for: request) else {
                print("Error: Fetch reddits failed")
                continue
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error: Status Code = \((response as? HTTPURLResponse)?.statusCode ?? 400)")
                continue
            }
            
            do {
                let reddits = try JSONDecoder().decode(Listing.self, from: data)
                
                guard reddits.posts.isEmpty != true else {
                    continue
                }
                
                items[subreddit] = reddits.posts.filter({ !$0.stickied }).reversed().map(FeedItem.init)
            } catch {
                print(error.localizedDescription)
                continue
            }
        }
        
        return items
    }
    
    private static func getToken() -> String? {
        let bearerToken = Bundle.main.object(forInfoDictionaryKey: "BEARER_TOKEN") as? String
        
        guard let bearerToken = bearerToken, !bearerToken.isEmpty else {
            print("API key does not exist")
            return nil
        }
        
        return bearerToken
    }
}
