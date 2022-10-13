//
//  Tweet.swift
//  MenuBarFeed
//
//  Created by Fred Murakawa on 04/10/22.
//

import Foundation

struct Tweets: Decodable {
    let data: [Tweet]?
}

struct Tweet: Decodable, FeedItemProtocol {
        
    let id: String
    var author: String = ""
    let title: String
    var url: String { "https://twitter.com/\(author)/status/\(id)" }
    let source = Source.twitter
    
    enum CodingKeys: String, CodingKey {
        case id
        case title = "text"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title).unescape
        id = try container.decode(String.self, forKey: .id)
    }
}

struct TwitterUsers: Codable {
    let data: [User]?
}

struct User: Codable {
    let id, name, username: String
}
