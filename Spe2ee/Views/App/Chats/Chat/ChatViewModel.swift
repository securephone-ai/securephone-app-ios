import Foundation
import UIKit
import Combine
import CoreFoundation
import MobileCoreServices
import DifferenceKit
import BlackboxCore

extension String: Differentiable {}
extension Date: Differentiable {}

enum AlertType {
    case messageCopied
    case messagesForwarded
    case messagesDeleted
    case screenshot(String)
    case screenRecorded
}

/// Array of MessageViewModel  in the same day.
struct MessagesSection: Hashable, Differentiable {
    
    // If `Self` conforming to `Hashable`.
    var differenceIdentifier: MessagesSection {
        return self
    }
    
    var date: Date
    var messages: [MessageViewModel]
    
    init(date: Date, messages: [MessageViewModel]) {
        self.date = date
        self.messages = messages
    }
    
    static func == (lhs: MessagesSection, rhs: MessagesSection) -> Bool {
        var isDateReceivedEqual = false
        let rhsDateReceived = Int(rhs.date.timeIntervalSince1970)
        let lhsDateReceived = Int(lhs.date.timeIntervalSince1970)
        if rhsDateReceived == lhsDateReceived {
            isDateReceivedEqual = true
        }
        
        return isDateReceivedEqual && lhs.messages == rhs.messages
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(messages)
    }
    
}

/// This class is the connection betwenn the View and the Model (Contact or Group messages) of the Chat Page.
class ChatViewModel {
    var contact: BBContact?
    var group: BBGroup?
    
    var messagesSections: [MessagesSection] {
        return isGroupChat ? group!.messagesSections : contact!.messagesSections
    }
    
    var unreadMessagesCount: Int {
        if let contact = self.contact {
            return contact.getRealUnreadMessagesViewModels().count
        } else if let group = self.group {
            return group.getRealUnreadMessagesViewModels().count
        }
        return 0
    }
    
    lazy var isGroupChat: Bool = {
        if let _ = contact {
            return false
        }
        return true
    }()
    
    lazy var chatID: String = {
        return isGroupChat ? group!.ID : contact!.registeredNumber
    }()
    
    var isFetching: Bool = false
    var isOldestMessageAlreadyFetched: Bool = false
    var hasUnreadMessagesBanner: Bool = false
    
    // Array of Tuples (key: Date, value: [MessageCellViewModel])
    private var sectionsLastIndex: Int {
        return messagesSections.count-1
    }
    
    var canUpdateUnreadMessageBanner: Bool = true
    
    // Combine Framework
    let initialMessagesFetched = PassthroughSubject<[MessagesSection], Never>()
    let newMessagesFetched = PassthroughSubject<[MessagesSection], Never>()
    let oldMessagesFetched = PassthroughSubject<[MessagesSection], Never>()
    let realodTableNeeded = PassthroughSubject<Void, Never>()
    let showAlertError = PassthroughSubject<(title: String, message: String), Never>()
    let screenshotTaken = PassthroughSubject<UIImage, Never>()
    
    let searchString = PassthroughSubject<String, Never>()
    @Published var isSearching = false
    
    @Published var selectedMessages: [MessageViewModel] = [MessageViewModel]()
    @Published var isForwardEditing: Bool = false {
        didSet {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let strongSelf = self else { return }
                let messagesSections = strongSelf.getMessagesSection()
                for item in messagesSections {
                    for cellViewModell in item.messages {
                        cellViewModell.isEditing = (false, strongSelf.isForwardEditing)
                        if strongSelf.isForwardEditing == false {
                            cellViewModell.isSelected = false
                        }
                    }
                }
            }
        }
    }
    @Published var isDeleteEditing: Bool = false {
        didSet {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let strongSelf = self else { return }
                let messagesSections = strongSelf.getMessagesSection()
                for item in messagesSections {
                    for cellViewModell in item.messages {
                        cellViewModell.isEditing = (strongSelf.isDeleteEditing, false)
                        if strongSelf.isDeleteEditing == false {
                            cellViewModell.isSelected = false
                        }
                    }
                }
            }
        }
    }
    @Published var longPressedMessagePoint = CGPoint()
    
    
    // MARK: - Initialization
    init(contact: BBContact) {
        self.contact = contact
        loadMessages()
        
        self.contact?.fetchAutoDeleteTimerAsync()
    }
    
    init(group: BBGroup) {
        self.group = group
        loadMessages()
        
        self.group?.updateMembersListAsync()
        self.group?.fetchAutoDeleteTimerAsync()
    }
    
    deinit {
        logi("ChatViewModel deinitialized")
    }
    
    /// Load messages.
    /// If some messages are presents, we fetch 10000 new messages strarting from the oldest messages. This will allow us to
    /// 1) fetch new messages if presents
    /// 2) Update our messages if needed
    /// Else
    /// We just fetch the last 40 messages
    private func loadMessages() {
        
        if let contact = self.contact {
            
            if contact.messagesSections.count > 0 {
                
                //        self.refreshDataSourceUnreadMessagesBannerPosition()
                
                fetchNewMessagesAsync()
                
                if contact.unreadMessagesCount >= contact.unreadMessages.count {
                    contact.unreadMessagesCount -= contact.unreadMessages.count
                }
                else {
                    contact.unreadMessagesCount = 0
                }
                
            }
            else {
                // Here we have an empty Table.
                // We force set initialMessagesFetched so that our ChatView will react to the event and reload the table
                contact.fetchMessagesAsync { [weak self] (messagesSections) in
                    guard let strongSelf = self else { return }
                    if let messagesSections = messagesSections {
                        var msgSections: [MessagesSection] = []
                        if let initialMessagesSections = contact.processAllMessages(newMessagesSections: messagesSections) {
                            msgSections = initialMessagesSections
                        }
                        else {
                            msgSections = messagesSections
                        }
                        
                        if let firstSection = msgSections.first, let firstMsgVM = firstSection.messages.first,
                           let oldestUnreadString = contact.oldestUnreadMsgID, let oldestUnread = Int(oldestUnreadString),
                           let currentOldest = Int(firstMsgVM.message.ID), oldestUnread < currentOldest {
                            // we have old unread messages
                            contact.fetchMessagesAsync(fromId: oldestUnreadString, toId: firstMsgVM.message.ID, limit: 0) { (_messagesSection) in
                                if let sections = _messagesSection {
                                    if let newMessagesSections = contact.processOldMessages(oldMessagesSections: sections, source: msgSections) {
                                        strongSelf.initialMessagesFetched.send(newMessagesSections)
                                    }
                                }
                            }
                        }
                        else {
                            strongSelf.initialMessagesFetched.send(msgSections)
                        }
                    } else {
                        strongSelf.initialMessagesFetched.send([])
                    }
                }
            }
        }
        else if let group = self.group {
            
            if group.messagesSections.count > 0 {
                
                //        self.refreshDataSourceUnreadMessagesBannerPosition()
                
                fetchNewMessagesAsync()
                
                if group.unreadMessagesCount >= group.unreadMessages.count {
                    group.unreadMessagesCount -= group.unreadMessages.count
                }
                else {
                    group.unreadMessagesCount = 0
                }
            }
            else {
                // Here we have an empty Table.
                // We force set initialMessagesFetched so that our ChatView will react to the event and reload the table
                group.fetchMessagesAsync { [weak self] (messagesSections) in
                    guard let strongSelf = self else { return }
                    
                    if let messagesSections = messagesSections {
                        var msgSections: [MessagesSection] = []
                        if let initialMessagesSections = group.processAllMessages(newMessagesSections: messagesSections) {
                            msgSections = initialMessagesSections
                        } else {
                            msgSections = messagesSections
                        }
                        
                        if let firstSection = msgSections.first, let firstMsgVM = firstSection.messages.first, let oldestUnreadString = group.oldestUnreadMsgID, let oldestUnread = Int(oldestUnreadString), let currentOldest = Int(firstMsgVM.message.ID), oldestUnread < currentOldest {
                            // we have old unread messages
                            group.fetchMessagesAsync(fromId: oldestUnreadString, toId: firstMsgVM.message.ID, limit: 0) { (_messagesSection) in
                                if let sections = _messagesSection {
                                    if let newMessagesSections = group.processOldMessages(oldMessagesSections: sections, source: msgSections) {
                                        strongSelf.initialMessagesFetched.send(newMessagesSections)
                                    }
                                }
                            }
                        }
                        else {
                            strongSelf.initialMessagesFetched.send(msgSections)
                        }
                    }
                    else {
                        strongSelf.initialMessagesFetched.send([])
                    }
                }
            }
        }
    }
    
}

// MARK: - Utility Functions
extension ChatViewModel {
    
    /// Return the MessageCellViewModel at the specified  IndexPath
    /// - Parameter indexPath: Indexpath
    func getMessageViewModel(at indexPath: IndexPath) -> MessageViewModel? {
        let messagesSection = contact != nil ? contact!.messagesSections : group!.messagesSections
        
        if indexPath.section < messagesSection.count, indexPath.row < messagesSection[indexPath.section].messages.count {
            return messagesSection[indexPath.section].messages[indexPath.row]
        } else {
            return nil
        }
    }
    
    
    /// Return the date of a specific messages section
    /// - Parameter section: Section index
    func getMessagesSectionDate(at section: Int) -> Date {
        return contact != nil ? contact!.messagesSections[section].date : group!.messagesSections[section].date
    }
    
    
    /// Returnt all the messages of a specific Messages Section
    /// - Parameter index: Section index
    func getMessages(at section: Int) -> [MessageViewModel]? {
        if let contact = self.contact {
            if contact.messagesSections.count > section {
                return contact.messagesSections[section].messages
            }
        } else if let group = self.group {
            if group.messagesSections.count > section {
                return group.messagesSections[section].messages
            }
        }
        return nil
    }
    
    
    /// Return the total number of messages of a specific Messages Section.
    /// - Parameter index: Section index
    func getMessagesCount(at section: Int) -> Int {
        if let messages = getMessages(at: section) {
            return messages.count
        }
        return 0
    }
    
    
    /// Return the totalnumber of messages
    func getMessagesCount() -> Int {
        return contact != nil ? contact!.messagesSections.reduce(0) { $0 + $1.messages.count } : group!.messagesSections.reduce(0) { $0 + $1.messages.count }
    }
    
    
    /// Return the last message IndexPath
    func getLastMessageIndexPath() -> IndexPath? {
        if let contact = self.contact {
            if contact.messagesSections.count == 0 {
                return nil
            } else {
                let lastSection = contact.messagesSections.count - 1
                let lastRow = getMessagesCount(at: lastSection) - 1
                return IndexPath(row: lastRow, section: lastSection)
            }
        } else {
            if group!.messagesSections.count == 0 {
                return nil
            } else {
                let lastSection = group!.messagesSections.count - 1
                let lastRow = getMessagesCount(at: lastSection) - 1
                return IndexPath(row: lastRow, section: lastSection)
            }
        }
    }
    
    
    /// Return the last MessageCellViewModel
    func getLastMessage() -> MessageViewModel? {
        guard let lastIndexPath = self.getLastMessageIndexPath() else { return nil }
        return getMessageViewModel(at: lastIndexPath)
    }
    
    
    /// Return the Index Path, if present in the grouped array, of a message based on his ID
    /// - Parameter msgID: message ID
    func getIndexPathMessage(msgID: String, section: Int? = nil) -> IndexPath? {
        if let contact = contact {
            return contact.getMessageIndexPath(msgID: msgID, section: section)
        }
        else if let group = group {
            return group.getMessageIndexPath(msgID: msgID, section: section)
        }
        return nil
    }
    
    /// Return the Index Path, if present in the grouped array, of a message based on his ID
    /// - Parameter msgID: message ID
    func getIndexPathMessage(msgRef: String, section: Int? = nil) -> IndexPath? {
        let messagesSections = getMessagesSection()
        if section != nil {
            for (row, messageVM) in messagesSections[section!].messages.enumerated() where messageVM.message.msgRef == msgRef {
                return IndexPath(row: row, section: section!)
            }
        }
        else {
            for (section, group) in messagesSections.enumerated() {
                for (row, messageViewModel) in group.messages.enumerated() where messageViewModel.message.msgRef == msgRef {
                    return IndexPath(row: row, section: section)
                }
            }
        }
        return nil
    }
    
    /// Add a MessageCellViewModel to the Selected messages collection
    /// - Parameter cellViewModel: MessageCellViewModel to add.
    func addSelectedMessage(cellViewModel: MessageViewModel) {
        selectedMessages.append(cellViewModel)
    }
    
    /// Remove an item from the Selected Messages collection
    /// - Parameter cellViewModel: The MessageCellViewModel to remove
    func removeFromSelectedMessages(cellViewModel: MessageViewModel) {
        selectedMessages.removeAll { $0.message.ID == cellViewModel.message.ID }
    }
    
    
    /// Clear Selected Messages collection
    func removeSelectedMessages() {
        guard selectedMessages.count > 0 else { return }
        selectedMessages.removeAll()
    }
    
    
    /// Return a group member from a Message object
    /// - Parameter message: The message
    func getGroupMember(using message: Message) -> BBContact {
        if group != nil {
            for contact in group!.members where !contact.ID.isEmpty && contact.ID != "0" {
                if contact.registeredNumber == message.sender || contact.registeredNumber == message.recipient {
                    return contact
                }
            }
        }
        // generate a contact based on the message info
        let contactNumber = PhoneNumber(tag: "mobile", phone: message.sender)
        return BBContact(id: message.contactID, name: message.contactName, phones: [contactNumber], phonejsonreg: [contactNumber])
    }
    
    
    /// Return the total number of sections
    func getMessagesSection() -> [MessagesSection] {
        return contact != nil ? contact!.messagesSections : group!.messagesSections
    }
    
    
    /// Fetch a batch of messages previous of our most old message in the Messages Section collections
    /// - Parameter block: completion block
    func fetchOldMessagesAsync(completion block: @escaping(()->Void )) {
        if isOldestMessageAlreadyFetched {
            block()
            return
        }
        
        let messagesSections = getMessagesSection()
        // Get the last message id
        var toMsgID = 0
        if messagesSections.count > 0, let id = Int(messagesSections[0].messages[0].message.ID) {
            toMsgID = id-1
        }
        if let contact = self.contact {
            contact.fetchMessagesAsync(toId: String(toMsgID), limit: 80) { (messagesSections) in
                if let messagesSections = messagesSections {
                    if let newMessagesSections = contact.processOldMessages(oldMessagesSections: messagesSections) {
                        self.oldMessagesFetched.send(newMessagesSections)
                    }
                } else {
                    self.isOldestMessageAlreadyFetched = true
                }
                block()
            }
        } else {
            group!.fetchMessagesAsync(toId: String(toMsgID), limit: 80) { (messagesSections) in
                if let messagesSections = messagesSections {
                    if let newMessagesSections = self.group!.processOldMessages(oldMessagesSections: messagesSections) {
                        self.oldMessagesFetched.send(newMessagesSections)
                    }
                } else {
                    self.isOldestMessageAlreadyFetched = true
                }
                block()
            }
        }
    }
    
    
    
    /// Fetch from 20 messages before the replyMsgId to our oldest msgID
    /// - Parameter block: completion block
    func fetchOldMessagesForReplyAsync(replyMsgId: String, completion block: @escaping(()->Void )) {
        let messagesSections = getMessagesSection()
        
        // We're goint to fetch from 20 messages before the replyMsgId to our oldest msgID
        if let id = Int(replyMsgId) {
            let fromID = String(id > 80 ? id-80 : 0)
            
            // Get the oldest msgid we have in RAM
            var toMsgID = 0
            if messagesSections.count > 0, let id = Int(messagesSections[0].messages[0].message.ID) {
                toMsgID = id-1
            }
            
            if let contact = self.contact {
                contact.fetchMessagesAsync(fromId: fromID, toId: String(toMsgID), limit: 0) { [weak self] (messagesSections) in
                    guard let strongSelf = self else { return }
                    if let messagesSections = messagesSections {
                        if let newMessagesSections = contact.processOldMessages(oldMessagesSections: messagesSections) {
                            strongSelf.oldMessagesFetched.send(newMessagesSections)
                        }
                    } else {
                        strongSelf.isOldestMessageAlreadyFetched = true
                    }
                    block()
                }
            } else if let group = group {
                group.fetchMessagesAsync(fromId: fromID, toId: String(toMsgID), limit: 0) { [weak self] (messagesSections) in
                    guard let strongSelf = self else { return }
                    if let messagesSections = messagesSections {
                        if let newMessagesSections = group.processOldMessages(oldMessagesSections: messagesSections) {
                            strongSelf.oldMessagesFetched.send(newMessagesSections)
                        }
                    } else {
                        strongSelf.isOldestMessageAlreadyFetched = true
                    }
                    block()
                }
            }
        }
    }
    
    
    /// Fetch a new batch of messages reveiced after our most recent message present in the Messages Sections collection.
    /// - Parameter block: completion block
    func fetchNewMessagesAsync(completion block: (() -> Void)? = nil) {
        
        if let lastIndexPath = self.getLastMessageIndexPath(), let lastMessage = self.getMessageViewModel(at: lastIndexPath), let msgID = Int(lastMessage.message.ID) {
            let nextMsgId  = String(msgID + 1)
            
            if let contact = self.contact {
                contact.fetchMessagesAsync(fromId: nextMsgId, limit: 10000) { [weak self] (messagesSections) in
                    guard let strongSelf = self else { return }
                    if let messagesSections = messagesSections {
                        if let newMessagesSections = contact.processNewMessages(newMessagesSections: messagesSections) {
                            strongSelf.newMessagesFetched.send(newMessagesSections)
                        }
                    }
                    else {
                        // If there is no new message, we update the receipts here. Otherwise the Combine notification event will Fire and the
                        // Update will be done there because the messages section will be updated after that point.
                        strongSelf.updateReceiptsAsync()
                        strongSelf.sendAllReadReceipt()
                    }
                }
            } else if let group = group {
                group.fetchMessagesAsync(fromId: nextMsgId, limit: 10000) { [weak self] (messagesSections) in
                    guard let strongSelf = self else { return }
                    if let messagesSections = messagesSections {
                        if let newMessagesSections = group.processNewMessages(newMessagesSections: messagesSections) {
                            strongSelf.newMessagesFetched.send(newMessagesSections)
                        }
                    }
                    else {
                        // If there is no new message, we update the receipts here. Otherwise the Combine notification event will Fire and the
                        // Update will be done there because the messages section will be updated after that point.
                        strongSelf.updateReceiptsAsync()
                        strongSelf.sendAllReadReceipt()
                    }
                }
            }
        }
        
    }
    
    func refreshDataSourceUnreadMessagesBannerPosition() {
        canUpdateUnreadMessageBanner = true
        if let contact = contact {
            hasUnreadMessagesBanner = contact.refreshUnreadBanner()
        }
        else if let group = group {
            hasUnreadMessagesBanner = group.refreshUnreadBanner()
        }
    }
    
    /// Fetch messages from the server and update the Receipts Dates on a background thread.
    /// This method will not add any message to the list, it is just used to update the messages Receipts checkmarks.
    /// (Combine framework notification event when the receipts date change)
    func updateReceiptsAsync() {
        if let contact = contact {
            if let firstSection = contact.messagesSections.first, let firstMessageViewModel = firstSection.messages.first,
               let lastSection = contact.messagesSections.last, let lastMessageViewModel = lastSection.messages.last {
                
                contact.fetchMessagesAsync(fromId: firstMessageViewModel.message.ID, toId: lastMessageViewModel.message.ID) { (messagesSections) in
                    if let messagesSections = messagesSections {
                        contact.updateLocalMessagesReceipts(sections: messagesSections)
                    }
                }
            }
        }
        else if let group = group {
            if let firstSection = group.messagesSections.first, let firstMessageViewModel = firstSection.messages.first,
               let lastSection = group.messagesSections.last, let lastMessageViewModel = lastSection.messages.last {
                
                group.fetchMessagesAsync(fromId: firstMessageViewModel.message.ID, toId: lastMessageViewModel.message.ID) { (messagesSections) in
                    if let messagesSections = messagesSections {
                        group.updateLocalMessagesReceipts(sections: messagesSections)
                    }
                }
            }
        }
    }
    
    func deleteMessagesAsync(messages: [MessageViewModel]) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            
            // Recreate the selected messages array
            var messagesViewModels = [MessageViewModel]()
            for messageViewModel in messages {
                let message = messageViewModel.message.copy() as! Message
                message.ID = messageViewModel.message.ID
                messagesViewModels.append(MessageViewModel(message: message, contact: messageViewModel.contact, group: messageViewModel.group))
                // Change the text of the cell
                messageViewModel.setMessageDeleted()
            }
            
            if let paths = strongSelf.convertMessagesToIndexPath(messages: messages) {
                // Notify the messages table thaat these messages have been deleted so that the table can reload the cells to show the new text.
                strongSelf.contact?.deletedIndexPathsPublisher.send(paths)
                strongSelf.group?.deletedIndexPathsPublisher.send(paths)
            }
            strongSelf.selectedMessages.removeAll()
            
            let queue = OperationQueue()
            var lock = os_unfair_lock()
            for messageViewModel in messagesViewModels {
                queue.addOperation {
                    guard let jsonString = BlackboxCore.deleteMessage(messageViewModel.message.ID) else {
                        return
                    }
                    logPrettyJsonString(jsonString)
                    
                    do {
                        let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                        if response.isSuccess() || response.message.contains("Message id has not been found") {
                            os_unfair_lock_lock(&lock)
                            messagesViewModels.removeAll{ $0.message.ID == messageViewModel.message.ID }
                            os_unfair_lock_unlock(&lock)
                        }
                    } catch {
                        loge(error)
                    }
                }
            }
            
            queue.waitUntilAllOperationsAreFinished()
            
            // At this point messagesViewModels should be empty and we succesfully deleted all messaged.
            // But if for some resons we failed to delete some of them, we recursively call this function after a couple of seconds to finish the job.
            if messagesViewModels.isEmpty == false {
                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 2) {
                    strongSelf.deleteMessagesAsync(messages: messagesViewModels)
                }
            }
        }
    }
    
    func sendAllReadReceipt() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.contact?.sendAllReadReceiptAsync()
            strongSelf.group?.sendAllReadReceiptAsync()
        }
    }
    
    func getUnreadMessagesBannerIndexPath() -> IndexPath? {
        let messagesSections = contact != nil ? contact!.messagesSections : group!.messagesSections
        for (sectionIndex, section) in messagesSections.enumerated() {
            if let rowIndex = section.messages.firstIndex(where: { (msgViewModel) -> Bool in
                return msgViewModel.message.type == .unreadMessages
            }) {
                return IndexPath(row: rowIndex, section: sectionIndex)
            }
        }
        return nil
    }
    
    /// Remove messages if total messages count > 200
    func removeOldMessages() {
        var messagesCount = getMessagesCount()
        while messagesCount > 300 {
            if messagesSections[0].messages.count == 0 {
                contact?.messagesSections.removeFirst()
                group?.messagesSections.removeFirst()
            }
            contact?.messagesSections[0].messages.removeFirst()
            group?.messagesSections[0].messages.removeFirst()
            messagesCount -= 1
        }
    }
}

// MARK: - Send Messages Functions
extension ChatViewModel {
    
    private func containsBlackListedUrl(_ string: String) -> String?  {
        let blackListedUrls = Blackbox.shared.account.settings.blackListedUrls
        for url in blackListedUrls {
            if string.contains(url, caseSensitive: false) {
                return url
            }
        }
        return nil
    }
    
    /// Send text message to the current Chat
    /// - Parameters:
    ///   - text: the message body
    ///   - completion: completion block. 'addToSection paramenter se to true if the message has been added to a new group (section table)
    ///   - error: error block. Called if something went wrong
    func sendTextMessage(text: String,
                         replyTo replyMessage: Message? = nil) {
        let account = Blackbox.shared.account
        
        if account.settings.canShareUrl == false && text.containsURLs {
            showAlertError.send(("Forbidden".localized(), "You don't have permission to share URLs".localized()))
            return
        }
        
        if account.settings.canShareUrl, let blcklistedUrl = containsBlackListedUrl(text) {
            showAlertError.send(("Forbidden".localized(), "\("You can't send a message containing this blacklisted URL".localized()):\n \(blcklistedUrl)"))
            return
        }
        
        if account.isValid {
            let message = Message(recipient: chatID, body: text)
            
            let (replyToMsgID, replyTextToParse) = getReplyFields(message: replyMessage)
            message.replyToText = replyTextToParse
            message.replyToMsgID = replyToMsgID
            
            if let group = self.group {
                group.sendMessageAsync(message) { errorMessage in
                    if errorMessage != nil {
                        // TODO: Handle Error
                    }
                }
            } else if let contact = self.contact {
                contact.sendMessageAsync(message) { errorMessage in
                    if errorMessage != nil {
                        // TODO: Handle Error
                        
                    }
                }
            }
        } else {
            loge("Invalid Account Number")
        }
    }
    
    /// Send a file to the current Chat
    /// - Parameters:
    ///   - filePath: Complete file path
    ///   - completion: completion block. 'addToSection paramenter se to true if the message has been added to a new group (section table)
    ///   - error: error block. Called if something went wrong
    func sendFile(filePath: String,
                  body: String = "",
                  replyTo replyMessage: Message? = nil) {
        guard FileManager.default.fileExists(atPath: filePath) else { return }
        
        let account = Blackbox.shared.account
        
        if account.settings.allowedFileType.count > 0 {
            if Blackbox.shared.account.settings.allowedFileType.contains(filePath.pathExtension) {
                showAlertError.send(("Forbidden".localized(), "You can't send this type of files.".localized()))
                return
            }
        }
        
        if account.settings.canShareUrl == false && body.containsURLs {
            showAlertError.send(("Forbidden".localized(), "You don't have permission to share URLs".localized()))
            return
        }
        
        if account.settings.canShareUrl, let blcklistedUrl = containsBlackListedUrl(body) {
            showAlertError.send(("Forbidden".localized(), "\("You can't send a message containing this blacklisted URL".localized()):\n \(blcklistedUrl)"))
            return
        }
        
        let fileSize = AppUtility.getFileSize(filePath)
        if fileSize > Blackbox.shared.account.settings.maxDownloadableFileSize {
            showAlertError.send(("File is too big".localized(), "Files over \(Blackbox.shared.account.settings.maxDownloadableFileSize / 1_000_000)MB are not allowed.".localized()))
            return
        }
        
        if account.isValid {
            // 1) Add the message to the table
            // 2) execute the sendfile in async
            // 3) get the cache filename
            // 4) monitor the upload using the cache file name.
            
            // 1) Crete the message andadd it to the table
            let message = Message(recipient: chatID, body: body, filePath: filePath, type: "file")
            
            let (replyToMsgID, replyTextToParse) = getReplyFields(message: replyMessage)
            message.replyToText = replyTextToParse
            message.replyToMsgID = replyToMsgID
            
            // 2) Send file on a background thread
            if self.isGroupChat, let group = self.group {
                group.sendFileAsync(message) { errorMessage in
                    if errorMessage != nil {
                        loge(errorMessage!)
                    }
                }
            } else if let contact = self.contact {
                contact.sendFileAsync(message) { errorMessage in
                    if errorMessage != nil {
                        loge(errorMessage!)
                    }
                }
            }
        }
        else {
            loge("Invalid Account Number")
        }
        
    }
    
    /// Send location message to the current Chat
    /// - Parameters:
    ///   - latitude: latitude
    ///   - longitude: longitude
    ///   - completion: completion block. 'addToSection paramenter se to true if the message has been added to a new group (section table)
    ///   - error: error block. Called if something went wrong
    func sendLocationMessage(latitude: String,
                             longitude: String,
                             replyTo replyMessage: Message? = nil) {
        if Blackbox.shared.account.isValid {
            let message = Message(recipient: chatID, body: "\(latitude),\(longitude)", type: "location")
            
            let (replyToMsgID, replyTextToParse) = getReplyFields(message: replyMessage)
            message.replyToText = replyTextToParse
            message.replyToMsgID = replyToMsgID
            
            if self.isGroupChat, let group = self.group {
                group.sendLocationAsync(message) { errorMessage in
                    if errorMessage != nil {
                        loge(errorMessage!)
                    }
                }
            } else if let contact = self.contact {
                contact.sendLocationAsync(message) { errorMessage in
                    if errorMessage != nil {
                        loge(errorMessage!)
                    }
                }
            }
        } else {
            loge("Invalid Account Number")
        }
    }
    
    
    /// Send chat alerts "Screenshot", "Copy", "Forward" or "Recording" to the current Chat
    /// - Parameters:
    ///   - alert: The alert type
    ///   - message:
    func sendChatAlertAsync(alert: AlertType, message: Message? = nil) {
        var msgType = ""
        var msgContent = ""
        if let message = message {
            switch message.type {
            case .audio:
                msgType = "audio"
                msgContent = "Audio"
            case .text:
                msgType = "text"
                msgContent = message.body
            case .photo:
                msgType = "photo"
                msgContent = "Photo"
            case .video:
                msgType = "video"
                msgContent = "Video"
            case .location:
                msgType = "location"
                msgContent = "Location"
            case .document:
                msgType = "document"
                msgContent = "Document"
            case .contact:
                msgType = "contact"
                msgContent = "Contact"
            default:
                break
            }
        }
        
        var alertMessage = ""
        switch alert {
        case .messageCopied:
            if let message = message {
                alertMessage = "alert:#copy:#\(message.sender):#\(message.ID):#\(msgType):#\(msgContent)"
            }
        case .messagesForwarded:
            if let message = message {
                alertMessage = "alert:#forward:#\(message.sender):#\(message.ID):#\(msgType):#\(msgContent)"
            }
        case .messagesDeleted:
            if let message = message {
                alertMessage = "alert:#delete:#\(message.sender):#\(message.ID):#\(msgType):#\(msgContent)"
            }
        case .screenRecorded:
            alertMessage = "alert:#screenrecording"
        case .screenshot(let filePath):
            alertMessage = "alert:#screenshot"
        }
        
        sendTextMessage(text: alertMessage)
    }
    
}

private extension ChatViewModel {
    
    func getMessageColor(message: Message) -> UIColor {
        if contact != nil {
            return contact!.color
        } else {
            if group != nil {
                for contact in group!.members {
                    if contact.registeredNumber == message.sender || contact.registeredNumber == message.recipient {
                        return contact.color
                    }
                }
            }
        }
        return UIColor.random()
    }
    
    func getReplyFields(message: Message?) -> (msgID: String, textToParse: String) {
        guard let _message = message else { return ("", "") }
        var replyToText = ""
        
        switch _message.type {
        case .audio, .photo, .video, .document:
            let filename: NSString = _message.originFilename as NSString
            if _message.body.isEmpty {
                replyToText = "file:#\(filename.pathExtension):#\(_message.sender)"
            } else {
                replyToText = "file:#\(filename.pathExtension):#\(_message.body):#\(_message.sender)"
            }
        case .contact:
            replyToText = "contact:#xxx:#\(_message.sender)"
        case .location:
            replyToText = "location:#\(_message.body):#\(_message.sender)"
        default:
            replyToText = "txt:#\(_message.body):#\(_message.sender)"
        }
        
        return (_message.ID, replyToText)
    }
    
    func convertMessagesToIndexPath(messages: [MessageViewModel]) -> [IndexPath]? {
        var paths = [IndexPath]()
        messages.forEach {
            if let indexPath = getIndexPathMessage(msgID: $0.message.ID) {
                paths.append(indexPath)
            }
        }
        return paths.isEmpty ? nil : paths
    }
    
}


