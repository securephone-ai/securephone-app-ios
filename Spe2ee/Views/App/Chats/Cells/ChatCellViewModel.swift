import Foundation
import SCLAlertView
import Combine


class ChatCellViewModel {
  
  /// Chat cell Contact
  var contact: BBContact?
  
  /// Chat Cell Group
  var group: BBGroup?

  /// :nodoc:
  var name: String {
    if let contact = contact, contact.registeredNumber == Blackbox.shared.account.settings.supportInAppChatNumber {
      return "Calc support".localized()
    }
    return isGroup ? group!.description : contact!.completeName
  }
  
  /// :nodoc:
  var isGroup: Bool {
    if let _ = contact {
      return false
    }
    return true
  }

  /// :nodoc:
  var _lastMessage: Message?
  
  /// :nodoc:
  var lastMessage: Message? {
    get {
      if let contact = self.contact, contact.messagesSections.count > 0 {
        return contact.messagesSections[contact.messagesSections.count-1].messages.last?.message
      } else if let group = self.group, group.messagesSections.count > 0 {
        return group.messagesSections[group.messagesSections.count-1].messages.last?.message
      }
      return _lastMessage
    }
    set {
      _lastMessage = newValue
    }
  }
  
  @Published var isSelected = false
  let isEditing = PassthroughSubject<Bool, Never>()

  @Published var isLastMessageDeleted = false
  
  /// Initialize ChatCellViewModel for the specific Contact and with the last message
  /// - Parameters:
  ///   - contact: BBContact
  ///   - lastMessage: Message
  init(with contact: BBContact, lastMessage: Message?) {
    self.contact = contact
    self.lastMessage = lastMessage
    
    if let message = self.lastMessage, message.isAlertMessage {
      var contactName = "You"
      if message.sender != Blackbox.shared.account.registeredNumber {
        contactName = contact.getName()
      }
      
      var action = ""
      switch message.type {
      case .alertCopy:
        action = "copied this message.".localized()
      case .alertForward:
        action = "forwarded this message.".localized()
      case .alertDelete:
        action = "deleted this message.".localized()
      case .alertScreenshot:
        action = "took a screenshot.".localized()
      case .alertScreenRecording:
        action = "recorderd this chat.".localized()
      default:
        break
      }
      // Now that we have every info we need from the alert we can change the message body
      message.alertMsg = "_*\(contactName)* \(action)_"
    }
  }
  
  /// Initialize ChatCellViewModel for the specific Group and with the last message
  /// - Parameters:
  ///   - contact: BBGroup
  ///   - lastMessage: Message
  init(with group: BBGroup, lastMessage: Message?) {
    self.group = group
    self.lastMessage = lastMessage
    
    if let message = self.lastMessage, message.isAlertMessage {
      var contactName = "You"
      if message.sender != Blackbox.shared.account.registeredNumber {
        contactName = group.getGroupMember(message: message).getName()
      }
      
      var action = ""
      switch message.type {
      case .alertCopy:
        action = "copied this message.".localized()
      case .alertForward:
        action = "forwarded this message.".localized()
      case .alertDelete:
        action = "deleted this message.".localized()
      case .alertScreenshot:
        action = "took a screenshot.".localized()
      case .alertScreenRecording:
        action = "recorderd this chat.".localized()
      default:
        break
      }
      // Now that we have every info we need from the alert we can change the message body
      message.alertMsg = "_*\(contactName)* \(action)_"
    }
  }
  
}

extension ChatCellViewModel {
  
  /// Unarchive Chat
  /// - Parameter block: completion block
  func unarchiveChatAsync(completion block: ((Bool)->Void)?) {
    if let contact = contact {
      BBChat.unarchiveChatAsync(contact: contact, completion: block)
    } else if let group = group {
      BBChat.unarchiveGroupChatAsync(group: group, completion: block)
    }
  }
  
  /// Archive Chat
  /// - Parameter block: completion block
  func archiveChatAsync(comletion block: ((Bool)->Void)?) {
    if let contact = contact {
      BBChat.archiveChatAsync(contact: contact, completion: block)
    } else if let group = group {
      BBChat.archiveGroupChatAsync(group: group, completion: block)

    }
  }
}
