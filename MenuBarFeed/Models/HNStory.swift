//
//  HNStory.swift
//  MenuBarFeed
//
//  Created by Fred Murakawa on 04/10/22.
//

import Foundation

struct HNStory: Decodable, FeedItemProtocol {
    let id: String
    let author = "hn"
    let title: String
    var url: String { "https://news.ycombinator.com/item?id=\(id)" }
    let source = Source.hackerNews
    
    enum CodingKeys: CodingKey {
        case author, id, title, url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title).unescape
        let intID = try container.decode(Int.self, forKey: .id)
        id = "\(intID)"
    }
}
