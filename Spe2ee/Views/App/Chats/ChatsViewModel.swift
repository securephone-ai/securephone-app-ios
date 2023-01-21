import Foundation
import UIKit
import Combine
import DifferenceKit


/// Represent all the possible Cells. But only the Chat cell hold the ChatCellViewModel data.
/// Archive cell that appear when scrolling down at index 0
/// Broadcast and New Group Cell at index 0 if the archive cell is not present otherwise index 1
/// The rest of the cells are all ChatCells
enum ChatItems: Hashable, Differentiable {
  case Archive
  case Chat(ChatCellViewModel)
  
  func getChatItemViewModel() -> ChatCellViewModel? {
    switch self {
    case .Chat(let item):
      return item
    default:
      return nil
    }
  }
  
  // If `Self` conforming to `Hashable`.
  var differenceIdentifier: ChatItems {
    return self
  }
  
  static func == (lhs: ChatItems, rhs: ChatItems) -> Bool {
    switch (lhs, rhs) {
    case (.Archive, .Archive):
      return true
    case (.Chat(let item), .Chat(let item2)):
      if let lhsLastMessage = item.lastMessage, let rhsLastMessage = item2.lastMessage, lhsLastMessage == rhsLastMessage {
        if let lhsContact = item.contact, let rhsContact = item2.contact, lhsContact.unreadMessagesCount == rhsContact.unreadMessagesCount {
          return true
        }
        if let lhsGroup = item.group, let rhsGroup = item2.group {
          if lhsGroup.unreadMessagesCount != rhsGroup.unreadMessagesCount {
            return false
          }
          if lhsGroup.description != rhsGroup.description {
            return false
          }
          return true
        }
      }
      return false
    default:
      return false
    }
  }
  
  func hash(into hasher: inout Hasher) {
    switch self {
    case .Archive:
      hasher.combine(0)
    case .Chat(let item):
      if let message = item.lastMessage {
        hasher.combine(message)
      }
    }
  }
  
  func getRawValue() -> String {
    switch self {
    case .Archive:
      return "Archive".localized()
    case .Chat(_):
      return "Chat".localized()
    }
  }

}

class ChatsViewModel: NSObject {
  //fileprivate var _chatItems = [ChatItems]()
  fileprivate var filteredChats: [ChatItems]?
  
  @Published var isEditing: Bool = false {
    didSet {
      for chatItem in Blackbox.shared.chatItems {
        guard let item = chatItem.getChatItemViewModel() else { continue }
        item.isEditing.send(isEditing)
        
        if isEditing == false, item.isSelected {
          item.isSelected = false
        }
      }
    }
  }
  
  var filterString: String = "" {
    didSet {
      if filterString == "" {
        filteredChats = nil
        return
      } else {
        filteredChats = Blackbox.shared.chatItems.filter { (item) -> Bool in
          guard let chat = item.getChatItemViewModel() else { return false }
          
          if chat.isGroup {
            guard let group = chat.group else { return false }
            return group.description.lowercased().starts(with: filterString.lowercased())
          } else {
            guard let contact = chat.contact else { return false }
            return contact.name.lowercased().starts(with: filterString.lowercased())
          }
        }
      }
    }
  }
}

extension ChatsViewModel {
  
  /**
   Return all the chats or the filtered chats
   */
  func getAllItems() -> [ChatItems] {
    if filteredChats != nil {
      return filteredChats!
    }
    return Blackbox.shared.chatItems
  }
  
  /**
   Return all the chats or the filtered chats
   */
  func getChatItems() -> [ChatItems] {
    if filteredChats != nil {
      return filteredChats!
    }
    return Blackbox.shared.chatItems.filter { $0.getChatItemViewModel() != nil }
  }
  
  
  /**
   Add the archive cell at index Zero when scrolling Down
   */
  func addArchiveCell() -> Bool {
    if Blackbox.shared.chatItems[0] != .Archive {
      Blackbox.shared.chatItems.insert(.Archive, at: 0)
      return true
    }
    return false
  }
  
  /**
   Add the archive cell at index Zero when scrolling Down
   */
  func removeArchiveCell() -> Bool {
    if Blackbox.shared.chatItems[0] == .Archive {
      Blackbox.shared.chatItems.remove(at: 0)
      return true
    }
    return false
  }
  
  /**
   Add single chat
   */
  func addChat(chat: ChatItems) {
    let hasItem = Blackbox.shared.chatItems.contains { (item) -> Bool in
      item.getChatItemViewModel()?.lastMessage?.dateSent == chat.getChatItemViewModel()?.lastMessage?.dateSent
    }
    
    if !hasItem {
      Blackbox.shared.chatItems.append(chat)
    }
  }
  
  /**
   Set the chat item/cell as Selected
   - parameter indexPath: Table Index Path
   */
  func selectChat(at index: Int) {
    guard let item = Blackbox.shared.chatItems[index].getChatItemViewModel() else { return }
    item.isSelected = true
  }
  
  /**
   Set the chat item/cell as Deselected
   - parameter indexPath: Table Index Path
   */
  func deselectChat(at index: Int) {
    guard let item = Blackbox.shared.chatItems[index].getChatItemViewModel() else { return }
    item.isSelected = false
  }
  
  /**
   Archive the chat at index Path
   - parameter indexPath: Table Index Path
   */
  func archiveChat(at index: Int, completion block:((Bool)->Void)?) {
    // TODO: Blackbox function to archive chats
    if let chatItemViewModel = Blackbox.shared.chatItems[index].getChatItemViewModel() {
      chatItemViewModel.archiveChatAsync(comletion: block)
    }
  }
  
  /**
   Archive the chat at index Path
   - parameter indexPath: Table Index Path
   */
  func muteChat(at index: Int) {
    // TODO: Blackbox function to archive chats

  }
  
  
  func chatContactNumber(item: ChatCellViewModel) {
    
  }
  
}

