import AppKit
import Combine

class MenuManager: NSObject, NSMenuDelegate {
    let statusMenu: NSMenu
    var menuIsOpen = false
    
    private var cancellables = Set<AnyCancellable>()
    private let viewModel: FeedListViewModel
    
    let itemsBeforeTasks = 3
    let itemsAfterTasks = 5
    
    init(statusMenu: NSMenu, viewModel: FeedListViewModel) {
        self.statusMenu = statusMenu
        self.viewModel = viewModel
        super.init()
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        showHistoryInMenu()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
        clearTasksFromMenu()
    }
    
    private func clearTasksFromMenu() {
        let stopAtIndex = statusMenu.items.count - itemsAfterTasks
        
        for _ in itemsBeforeTasks ..< stopAtIndex {
            statusMenu.removeItem(at: itemsBeforeTasks)
        }
    }
    
    private func showHistoryInMenu() {
        var index = itemsBeforeTasks
        
        for (i, feedItem) in viewModel.history.suffix(Constants.maxHistoryItems).reversed().enumerated() {
            let item = NSMenuItem()
            item.title = viewModel.croppedTitle(feedItem.authorAndTitle, maxChars: Constants.defaultHistoryMenuCharacters)
            item.target = self
            item.action = #selector(self.onHistoryItemClicked)
            item.tag = i
            statusMenu.insertItem(item, at: index)
            index += 1
        }
    }
    
    @objc func onHistoryItemClicked(_ item: NSMenuItem) {
        let history = Array(viewModel.history.suffix(Constants.maxHistoryItems).reversed())
        guard item.tag < Constants.maxHistoryItems else { return }
        let historyItem = history[item.tag]
        NSWorkspace.shared.open(URL(string: historyItem.item.url)!)
    }
}
