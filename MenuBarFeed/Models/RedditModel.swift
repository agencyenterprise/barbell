import Foundation

struct Post: Identifiable, FeedItemProtocol, Hashable, Equatable {
    
    let id: String
    let author: String
    let title: String
    let url: String
    let source = Source.reddit
    let subreddit: String
    let permalink: String
    let subredditNamePrefixed: String
    let createdAt: Double
    let stickied: Bool
}

// MARK: - Decodable
extension Post: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case author
        case title
        case url
        case subreddit
        case permalink
        case subredditNamePrefixed = "subreddit_name_prefixed"
        case createdAt = "created_utc"
        case stickied
        
        case data
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try values.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        
        id = try dataContainer.decode(String.self, forKey: .id)
        subreddit = try dataContainer.decode(String.self, forKey: .subreddit)
        title = try dataContainer.decode(String.self, forKey: .title).unescape
        author = try dataContainer.decode(String.self, forKey: .subreddit)
        let urlPath = try dataContainer.decode(String.self, forKey: .permalink)
        url = "https://www.reddit.com\(urlPath)"
        permalink = try dataContainer.decode(String.self, forKey: .permalink)
        subredditNamePrefixed = try dataContainer.decode(String.self, forKey: .subredditNamePrefixed)
        createdAt = try dataContainer.decode(Double.self, forKey: .createdAt)
        stickied = try dataContainer.decode(Bool.self, forKey: .stickied)
    }
}

struct Listing {
    var posts = [Post]()
}

// MARK: - Decodable
extension Listing: Decodable {
    enum CodingKeys: String, CodingKey {
        case posts = "children"
        case data
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let data = try values.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        
        posts = try data.decode([Post].self, forKey: .posts)
    }
}
