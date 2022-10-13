enum Source: CaseIterable, Hashable, Equatable {
    case twitter
    case hackerNews
    case reddit
}

protocol FeedItemProtocol {
    var id: String { get }
    var author: String { get }
    var title: String { get }
    var url: String { get }
    var source: Source { get }
}

struct FeedItem: Hashable {
    
    let item: any FeedItemProtocol
    
    var authorAndTitle: String {
        switch item.source {
        case .twitter:
            return "@\(item.author): \(item.title)".replacingOccurrences(of: "\n", with: " ")
        case .hackerNews:
            return "\(item.author): \(item.title)"
        case .reddit:
            return "r/\(item.author): \(item.title)"
        }
    }
    
    static func == (lhs: FeedItem, rhs: FeedItem) -> Bool {
        return lhs.item.id == rhs.item.id &&
        lhs.item.author == rhs.item.author &&
        lhs.item.title == rhs.item.title &&
        lhs.item.source == rhs.item.source
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(item.id)
        hasher.combine(item.author)
        hasher.combine(item.title)
        hasher.combine(item.url)
        hasher.combine(item.source)
    }
}
