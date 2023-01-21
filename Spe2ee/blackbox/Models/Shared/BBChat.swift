import Foundation
import Combine
import DifferenceKit
import NotificationView
import BlackboxCore

/*
 This class contains the object shared between the OneToOne chat with a Contact and Group Chats
 It was created to remove duplicated code between the 2 classes
 */
class BBChat {
    
    // MARK: - private properties
    // we a fetch only one time when the chat appear in the chats list
    var isStartupFetchDone = false
    
    private let sendReceiptsSerialQueue = DispatchQueue(label: "send_receipts_serial_queue", qos: .userInitiated)
    let backgroundFetchAllMessagesQueue = DispatchQueue(label: "background_fetch_all_messages_queue")
    let addMessagesSerialQueue = DispatchQueue(label: "addMessagesSerialQueue_\(UUID().uuidString)")
    
    // MARK: - public properties
    
    /// Chat Messages
    var messagesSections: [MessagesSection] = []
    
    var unsentMessage: String = ""
    var chatAutoDeleteTimer: MessageAutoDeleteTimer = .never
    
    // MARK: - Message Notification Sound name
    var messageNotificationSoundName: String = "Default"
    
    // MARK: - Combine Framework properties
    let messageAdded = PassthroughSubject<(addNewSection: Bool, message: Message), Never>()
    let deletedIndexPathsPublisher = PassthroughSubject<[IndexPath], Never>()
    
    @Published var unreadMessages: [String] = [] {
        didSet {
            Blackbox.shared.updateTotalUnreadMessages()
        }
    }
    @Published var isArchived = false
    @Published var starredMessages: [MessageViewModel] = []
    
    var oldestUnreadMsgID: String?
    @Published var unreadMessagesCount: Int = 0 {
        didSet {
            if unreadMessagesCount > 0 {
                logi(unreadMessagesCount)
            }
            if unreadMessagesCount < unreadMessages.count {
                unreadMessagesCount = unreadMessages.count
            }
        }
    }
    
    // The following 3 funcitons are used from within the chat
    func processAllMessages(newMessagesSections: [MessagesSection]) -> [MessagesSection]?  {
        if self.messagesSections.count == 0 {
            return newMessagesSections
        }
        else {
            var _messagesSections = self.messagesSections
            
            let changeset = StagedChangeset(source: _messagesSections, target: newMessagesSections)
            if !changeset.isEmpty {
                // Merge the message of the same section
                for (index1, section) in newMessagesSections.enumerated() {
                    
                    if let index2 = _messagesSections.firstIndex(where: { (_section) -> Bool in
                        return section.date.isInSameDay(date: _section.date)
                    }) {
                        if let firstMsgIdNew = newMessagesSections[index1].messages.first?.message.ID, let firstMsgIdOld = _messagesSections[index2].messages.first?.message.ID,
                           let lastMsgIdNew = newMessagesSections[index1].messages.last?.message.ID, let lastMsgIdOld = _messagesSections[index2].messages.last?.message.ID {
                            
                            if firstMsgIdNew == firstMsgIdOld && lastMsgIdNew == lastMsgIdOld {
                                _messagesSections[index2].messages = newMessagesSections[index1].messages
                            } else {
                                // merge messages
                                for msg in newMessagesSections[index1].messages {
                                    if let msgIndex = _messagesSections[index2].messages.firstIndex(where: { (msgCellVm) -> Bool in
                                        return msgCellVm.message.ID == msg.message.ID
                                    }) {
                                        _messagesSections[index2].messages[msgIndex].message.dateSent = msg.message.dateSent
                                        _messagesSections[index2].messages[msgIndex].message.dateReceived = msg.message.dateReceived
                                        _messagesSections[index2].messages[msgIndex].message.dateRead = msg.message.dateRead
                                    } else {
                                        if let lastmsg = _messagesSections[index2].messages.last {
                                            lastmsg.nextMessageSender = msg.message.sender
                                            msg.previousMessageSender = lastmsg.message.sender
                                        }
                                        _messagesSections[index2].messages.append(msg)
                                    }
                                }
                            }
                        }
                    } else {
                        // add a new section
                        _messagesSections.append(section)
                    }
                }
                
                // Sort the sections by date
                _messagesSections.sort { $0.date < $1.date }
                
                // Remove duplicated messages
                self.removeLastSectionDuplicatedMessages()
                
                // Sort the messages by ID
                for i in 0..<_messagesSections.count {
                    _messagesSections[i].messages.sort {
                        if let id1 = Int($0.message.ID), let id2 = Int($1.message.ID), id1 < id2 {
                            return true
                        }
                        return false
                    }
                }
                return _messagesSections
            } else {
                return nil
            }
        }
    }
    
    /// Process the old messages, merge them with the saved one and return the Merged version
    /// - Parameters:
    ///   - oldMessagesSections: Old messages section
    ///   - source: Original messages section
    /// - Returns: The merged messages section
    func processOldMessages(oldMessagesSections: [MessagesSection], source: [MessagesSection]? = nil) -> [MessagesSection]? {
        var _messagesSections = source == nil ? messagesSections : source!
        
        if oldMessagesSections.count > 0 {
            if _messagesSections.count == 0 {
                return oldMessagesSections
            } else {
                
                // Merge the message of the same section
                for (index1, section) in oldMessagesSections.enumerated() {
                    
                    if let index2 = _messagesSections.firstIndex(where: { (_section) -> Bool in
                        return section.date.isInSameDay(date: _section.date)
                    }) {
                        // Same Section, insert the messages at the start
                        if let firstMsg = _messagesSections[index2].messages.first, let lastMsg = oldMessagesSections[index1].messages.last {
                            lastMsg.nextMessageSender = firstMsg.message.sender
                            firstMsg.previousMessageSender = lastMsg.message.sender
                        }
                        _messagesSections[index2].messages.insert(contentsOf: oldMessagesSections[index1].messages, at: 0)
                    } else {
                        // add a new section
                        _messagesSections.append(section)
                    }
                }
                
                // Sort the sections by date
                _messagesSections.sort { $0.date < $1.date }
                return _messagesSections
            }
        }
        return nil
    }
    
    /// Process the new messages, merge them with the saved one and return the Merged version
    /// - Parameter newMessagesSections: New messages
    /// - Returns: The merged messages section
    func processNewMessages(newMessagesSections: [MessagesSection]) -> [MessagesSection]? {
        if newMessagesSections.count > 0 {
            if self.messagesSections.count == 0 {
                return newMessagesSections
            }
            else {
                
                var _messagesSections = self.messagesSections
                
                // Merge the message of the same section
                for (index1, section) in newMessagesSections.enumerated() {
                    
                    if let index2 = _messagesSections.firstIndex(where: { (_section) -> Bool in
                        return section.date.isInSameDay(date: _section.date)
                    }) {
                        
                        // Update the previous message sender with the first message of the new messages.
                        if let _ = _messagesSections[index2].messages.last, let nextMsg = newMessagesSections[index1].messages.first {
                            _messagesSections[index2].messages.last?.nextMessageSender = nextMsg.message.sender
                            nextMsg.previousMessageSender = _messagesSections[index2].messages.last?.message.sender
                        }
                        
                        // Safety Check. Even if we are fetching new message we'll check if a message
                        // with the same ID already exist and update its properties
                        for newMessageViewModel in newMessagesSections[index1].messages {
                            if let messageIndex = _messagesSections[index2].messages.firstIndex(where: { (msgViewModel) -> Bool in
                                return msgViewModel.message.ID == newMessageViewModel.message.ID
                            }) {
                                
                                if  _messagesSections[index2].messages[messageIndex].message.dateSent != newMessageViewModel.message.dateSent {
                                    _messagesSections[index2].messages[messageIndex].message.dateSent = newMessageViewModel.message.dateSent
                                }
                                
                                if _messagesSections[index2].messages[messageIndex].message.dateReceived != newMessageViewModel.message.dateReceived {
                                    _messagesSections[index2].messages[messageIndex].message.dateReceived = newMessageViewModel.message.dateReceived
                                }
                                
                                if _messagesSections[index2].messages[messageIndex].message.dateRead != newMessageViewModel.message.dateRead {
                                    _messagesSections[index2].messages[messageIndex].message.dateRead = newMessageViewModel.message.dateRead
                                }
                            } else {
                                _messagesSections[index2].messages.append(newMessageViewModel)
                            }
                        }
                        
                        
                    } else {
                        // New section, add it to the end
                        _messagesSections.append(section)
                    }
                }
                
                // We are done adding these new messages to the section.
                // We'll sort them to be sure that everything is sorted correctly
                
                // Sort the sections by date
                _messagesSections.sort { $0.date < $1.date }
                
                // Sort the messages by ID
                for i in 0..<_messagesSections.count {
                    _messagesSections[i].messages.sort {
                        if let id1 = Int($0.message.ID), let id2 = Int($1.message.ID), id1 < id2 {
                            return true
                        }
                        return false
                    }
                }
                
                return _messagesSections
            }
        }
        
        return nil
    }
    
    /// Convert Messages array to MessageViewModel array
    func convertToViewModels(messages: [Message]) -> [MessageViewModel] {
        if let group = self as? BBGroup {
            return messages.map { return MessageViewModel(message: $0, contact: group.getGroupMember(message: $0), group: group) }
        } else {
            return messages.map { return MessageViewModel(message: $0, contact: self as! BBContact) }
        }
    }
    
    /// Check if a message is already present within the collection.
    /// - Parameter message: message
    func isMessagePresent(message: Message) -> Bool {
        return messagesSections.contains { $0.messages.contains { $0.message.ID == message.ID } }
    }
    
    /// Append the new message to the messages sections
    ///
    /// This function is called when:
    /// 1) A new message is send
    /// 2) A new message is received
    ///
    /// - Parameters:
    ///   - message: the message to appensd
    ///   - contact: the contact who sent the message
    ///   - group: the group from which the message is generated. Nil if not coming from a group
    func appendMessage(_ message: Message, contact: BBContact, group: BBGroup? = nil, isFromApplePush: Bool = false) {
        addMessagesSerialQueue.async {
            
            if message.containAttachment {
                message.fileTransferState = .zero
            }
            
            // Update the contact status to online
            if message.status == .incoming, contact.onlineStatus != .online, message.type.isSystemMessage() == false {
                contact.onlineStatus = .online
            }
            
            if message.type.isSystemMessageAutoDelete(), message.status == .incoming {
                // fetch the new auto-delete timer setted by the other party
                self.fetchAutoDeleteTimerAsync()
            }
            
            // If tha App is open and we are inside the chat from which the message is generated we simply raise the
            // event and add the message from the chat itself. Otherwise this can raise some random crash where one thread add
            // a message while another do the same (maybe by sending a new message)
            if let currentVC = Blackbox.shared.currentViewController, let chatVC = currentVC as? ChatViewController, let chatViewModel = chatVC.viewModel {
                // check if the Open chat is with the same contact that generated the message
                // OR
                // check if the Open chat is with the same Group from which the message has been sent
                if message.isGroupChat == false, let chatContact = chatViewModel.contact, contact.registeredNumber == chatContact.registeredNumber {
                    // raise the event
                    self.appendMessageEvent(message)
                    return
                }
                else if let chatGroup = chatViewModel.group, let group = group, group.ID == chatGroup.ID {  // check if the chat is with the right Contact
                    // raise the event
                    self.appendMessageEvent(message)
                    return
                }
            }
            
            if self.isMessagePresent(message: message) {
                return
            }
            
            
            // ************************************************************
            // ************************************************************
            // We reach this point if we are not inside the Chat from which the message is generated,
            // So we simply add it to the messages list from the background thread
            if self.messagesSections.count == 0 {
                let messageViewModel = MessageViewModel(message: message, contact: contact, group: group)
                self.messagesSections = [ MessagesSection(date: Date(), messages: [messageViewModel]) ]
                
                // Post the notification
                self.showNotification(messageViewModel: messageViewModel, contact: contact, group: group)
            }
            else {
                if let lastSection = self.messagesSections.last, lastSection.date.isInToday {
                    
                    let sectionIndex = self.messagesSections.count-1
                    
                    // update the previous message "next message Sender"
                    self.messagesSections[sectionIndex].messages.last?.nextMessageSender = message.sender
                    
                    // Append the new message
                    let messageViewModel = MessageViewModel(message: message, contact: contact, group: group)
                    messageViewModel.previousMessageSender = self.messagesSections[self.messagesSections.count-1].messages.last?.message.sender
                    self.messagesSections[sectionIndex].messages.append(messageViewModel)
                    
                    // Be sure that everything is sorted correctly
                    self.sortMessages()
                    
                    // Post the notification
                    self.showNotification(messageViewModel: messageViewModel, contact: contact, group: group)
                    
                } else {
                    // Create a new Section
                    let messageViewModel = MessageViewModel(message: message, contact: contact, group: group)
                    self.updatePreviousMessagesSender(messageViewModel: messageViewModel)
                    self.messagesSections.append(MessagesSection(date: Date(), messages: [messageViewModel]))
                    
                    // Post the notification
                    self.showNotification(messageViewModel: messageViewModel, contact: contact, group: group)
                }
            }
            
            // Remove any possible duplicate message from the list.
            self.removeLastSectionDuplicatedMessages()
            
            // Append to unread messages
            self.appendUnreadMessage(message, isFromApplePush: isFromApplePush)
        }
    }
    
    
    /// Sort the messages based on message ID
    /// - Parameter section:  imrpove the sorting Time by specifing the section index.
    private func sortMessages() {
        self.messagesSections[self.messagesSections.count-1].messages.sort {
            if let id1 = Int($0.message.ID), let id2 = Int($1.message.ID), id1 < id2 {
                return true
            }
            return false
        }
    }
    
    /// Update the associated message checkmark type on a background thread. Who subscribed to the @Published checkmarkType property will receive the update on the main Thread.
    /// - Parameters:
    ///   - msg: Receipt message containing the receipt info.
    func sendReadReceiptAsync(of message: Message) {
        AppUtility.isAppInForeground { (success) in
            if success {
                self.sendReceiptsSerialQueue.async {
                    
                    if message.dateRead != nil {
                        return
                    }
                    
                    if self.unreadMessagesCount > 0 {
                        self.unreadMessagesCount -= 1
                    }
                    
                    if let msgID = Int(message.ID) {
                        self.unreadMessages.removeAll {
                            if let id = Int($0) {
                                return id <= msgID
                            }
                            return false
                        }
                    }
                    Blackbox.shared.updateTotalUnreadMessages()
                    
                    guard let jsonString = BlackboxCore.sendReadReceipt(message.ID, toContactNumber: message.sender) else {
                        return
                    }
                    
                    do {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                        
                        if response.isSuccess() {
                            message.dateRead = Date()
                        }
                    } catch {
                        loge(error)
                    }
                }
            }
        }
    }
    
    /// Send Read Receipt for each unread message on a background (serial) thread.
    func sendAllReadReceiptAsync() {
        AppUtility.isAppInForeground { (success) in
            if success {
                
                self.unreadMessages = []
                Blackbox.shared.updateTotalUnreadMessages()
                
                // We start 2 threads, one to reset the counter and another to send the receipts.
                let unreadMessagesViewModels = self.getRealUnreadMessagesViewModels()
                self.unreadMessagesCount = 0
                
                for msgViewModel in unreadMessagesViewModels {
                    msgViewModel.message.dateRead = Date()
                }
                
                self.sendReceiptsSerialQueue.async {
                    
                    if unreadMessagesViewModels.count > 0 {
                        logi("Sending all read receipts")
                        
                        for msgViewModel in unreadMessagesViewModels {
                            //            for i in 0..<unreadMessagesViewModels.count {
                            guard let jsonString = BlackboxCore.sendReadReceipt(msgViewModel.message.ID, toContactNumber: msgViewModel.message.sender) else {
                                return
                            }
                            //      logPrettyJsonString(jsonString)
                            
                            do {
                                let decoder = JSONDecoder()
                                let response = try decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                                
                                if !response.isSuccess() {
                                    msgViewModel.message.dateRead = nil
                                }
                            } catch {
                                loge(error)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Return the Unread Messages abailable in RAM
    /// - Returns: An array of unread MessageViewModel
    func getRealUnreadMessagesViewModels() -> [MessageViewModel] {
        return messagesSections.reduce(into: [MessageViewModel]()) {
            $0 += $1.messages.filter({ (messageViewModel) -> Bool in
                return messageViewModel.isSent == false &&
                    messageViewModel.isRead == false &&
                    messageViewModel.message.type.isSystemMessage() == false &&
                    messageViewModel.message.type != .deleted
            }).sorted(by: { (m1, m2) -> Bool in
                if let id1 = Int(m1.message.ID), let id2 = Int(m2.message.ID) {
                    return id1 < id2
                }
                return false
            })
        }
    }
    
    /// Set the message as Received.
    /// - Parameter message: The message
    func setMessageReceived(_ message: Message) {
        for section in messagesSections {
            for messageViewModel in section.messages where messageViewModel.message.ID == message.body && messageViewModel.message.dateReceived == nil {
                if let group = messageViewModel.group {
                    group.fetchReadReceiptsAsync(message: messageViewModel.message) { (receipts) in
                        if let receipts = receipts {
                            messageViewModel.groupReceipts = receipts
                            
                            let account = Blackbox.shared.account
                            guard let accountNumber = account.registeredNumber else { return }
                            
                            let receivedCount = receipts.reduce(into: Int(0)) {
                                if $1.recipient != accountNumber && $1.dateReceived != nil && $1.dateRead == nil {
                                    $0 += 1
                                }
                            }
                            
                            let readCount = receipts.reduce(into: Int(0)) {
                                if $1.recipient != accountNumber && $1.dateRead != nil {
                                    $0 += 1
                                }
                            }
                            
                            if receivedCount + readCount == group.members.count-1 {
                                messageViewModel.message.dateReceived = Date()
                            }
                        }
                    }
                }
                else {
                    messageViewModel.message.dateReceived = Date()
                }
            }
        }
    }
    
    /// Set the message as Read.
    /// - Parameter message: The message
    func setMessageRead(_ message: Message) {
        for section in messagesSections {
            for messageViewModel in section.messages where messageViewModel.message.ID == message.body && messageViewModel.message.dateRead == nil {
                if let group = messageViewModel.group {
                    group.fetchReadReceiptsAsync(message: messageViewModel.message) { (receipts) in
                        if let receipts = receipts {
                            messageViewModel.groupReceipts = receipts
                            
                            let account = Blackbox.shared.account
                            guard let accountNumber = account.registeredNumber else { return }
                            
                            let readCount = receipts.reduce(into: Int(0)) {
                                if $1.recipient != accountNumber && $1.dateRead != nil {
                                    $0 += 1
                                }
                            }
                            
                            if readCount == group.members.count-1 {
                                messageViewModel.message.dateRead = Date()
                            }
                        }
                    }
                }
                else {
                    messageViewModel.message.dateRead = Date()
                }
            }
        }
    }
    
    func getMessage(msgID: String) -> Message? {
        for section in messagesSections {
            for viewModel in section.messages where viewModel.message.ID == msgID {
                return viewModel.message
            }
        }
        return nil
    }
    
    func setMessageDeleted(messageID: String, isAutoDeleted: Bool) {
        for (indexSection, section) in messagesSections.enumerated() {
            for (indexRow, viewModel) in section.messages.enumerated() where viewModel.message.ID == messageID && viewModel.message.type != .deleted {
                viewModel.setMessageDeleted(isSelf: isAutoDeleted)
                deletedIndexPathsPublisher.send([IndexPath(row: indexRow, section: indexSection)])
            }
        }
    }
    
    /// Get an array Messages Section, compare the Receipts with the messages saved in RAM and Update the receipts dates if necessary
    /// - Parameter sections: The messages sections array used for the compare.
    func updateLocalMessagesReceipts(sections: [MessagesSection]) {
        var deletedIndexPaths = [IndexPath]()
        for (indexSection, section) in self.messagesSections.enumerated() {
            for (indexRow, messageViewModel) in section.messages.enumerated() {
                
                if let section2Index = sections.firstIndex(where: { (_section) -> Bool in
                    return section.date.isInSameDay(date: _section.date)
                }) {
                    if let message2Index = sections[section2Index].messages.firstIndex(where: { (msgViewModel) -> Bool in
                        return msgViewModel.message.ID == messageViewModel.message.ID
                    }) {
                        
                        if sections[section2Index].messages[message2Index].message.type == .deleted &&  messageViewModel.message.type != .deleted {
                            
                            //              setMessageDeleted(messageID: messageViewModel.message.ID, isAutoDeleted: messageViewModel.message.autoDelete)
                            messageViewModel.setMessageDeleted(isSelf: messageViewModel.message.autoDelete)
                            deletedIndexPaths.append(IndexPath(row: indexRow, section: indexSection))
                            
                        }
                        else {
                            if messageViewModel.message.dateSent != sections[section2Index].messages[message2Index].message.dateSent {
                                messageViewModel.message.dateSent = sections[section2Index].messages[message2Index].message.dateSent
                            }
                            
                            if messageViewModel.message.dateReceived != sections[section2Index].messages[message2Index].message.dateReceived,
                               sections[section2Index].messages[message2Index].message.dateReceived != nil {
                                messageViewModel.message.dateReceived = sections[section2Index].messages[message2Index].message.dateReceived
                            }
                            
                            if messageViewModel.message.dateRead != sections[section2Index].messages[message2Index].message.dateRead,
                               sections[section2Index].messages[message2Index].message.dateRead != nil {
                                messageViewModel.message.dateRead = sections[section2Index].messages[message2Index].message.dateRead
                            }
                            
                            // Update the auto Download settings
                            if messageViewModel.message.autoDownload != sections[section2Index].messages[message2Index].message.autoDownload {
                                messageViewModel.message.autoDownload = sections[section2Index].messages[message2Index].message.autoDownload
                            }
                        }
                    }
                }
            }
        }
        
        if deletedIndexPaths.isEmpty == false {
            deletedIndexPathsPublisher.send(deletedIndexPaths)
        }
        
    }
    
    /// Set the contact or group as the first item of the Chat list
    /// - Parameter message: the Chat last message
    func refreshChatList(message: Message) {
        let blackbox = Blackbox.shared
        
        if let contact = self as? BBContact {
            for (index, element) in blackbox.chatItems.enumerated() where element != .Archive {
                if let chat = element.getChatItemViewModel(), let chatContact = chat.contact, chatContact.registeredNumber == contact.registeredNumber {
                    chat.lastMessage = message
                    // copy the chat items
                    var items = blackbox.chatItems
                    items.remove(at: index)
                    items.insert(element, at: 1)
                    // update the chatItems only once
                    blackbox.chatItems = items
                    return
                }
            }
            // If no chat was found for the specified contact, we'll create it and add to the chats list.
            blackbox.chatItems.insert(ChatItems.Chat(ChatCellViewModel(with: contact, lastMessage: message)), at: 1)
        }
        else if let group = self as? BBGroup {
            for (index, element) in blackbox.chatItems.enumerated() where element != .Archive {
                if let chat = element.getChatItemViewModel(), let chatGroup = chat.group, chatGroup.ID == group.ID {
                    chat.lastMessage = message
                    // copy the chat items
                    var items = blackbox.chatItems
                    items.remove(at: index)
                    items.insert(element, at: 1)
                    // update the chatItems only once
                    blackbox.chatItems = items
                    return
                }
            }
            
            // If no chat was found for the specified contact, we'll create it and add to the chats list.
            blackbox.chatItems.insert(ChatItems.Chat(ChatCellViewModel(with: group, lastMessage: message)), at: 1)
        }
        
    }
    
    /// Set message as Starred on a background thread
    /// - Parameters:
    ///   - messageViewModel: The MessageViewModel
    ///   - block: completion block --> return true if success, otherwise return false.
    func setStarredMessage(messageViewModel: MessageViewModel, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.setStarredMessage(messageViewModel.message.ID) else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try Blackbox.shared.decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    messageViewModel.message.isStarred = true
                    self.starredMessages.append(messageViewModel)
                    if self.starredMessages.contains(messageViewModel) == false {
                        self.starredMessages.sort {
                            if let id1 = Int($0.message.ID), let id2 = Int($1.message.ID), id1 > id2 {
                                return true
                            }
                            return false
                        }
                    }
                    block?(true)
                } else {
                    block?(false)
                    loge(response.message)
                }
            } catch {
                block?(false)
                loge(error)
            }
        }
    }
    
    
    /// Unset the starred message on a background thread
    /// - Parameters:
    ///   - messageViewModel: The Message View Model
    ///   - block: completion block --> return true if success, otherwise return false.
    func unsetStarredMessage(messageViewModel: MessageViewModel, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.unsetStarredMessage(messageViewModel.message.ID) else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try Blackbox.shared.decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    messageViewModel.message.isStarred = false
                    self.starredMessages.removeAll { $0.message.ID == messageViewModel.message.ID }
                    
                    block?(true)
                } else {
                    block?(false)
                    loge(response.message)
                }
            } catch {
                block?(false)
                loge(error)
            }
        }
    }
    
    /// Fetch the Chat Auto Delete timer on a background thread and update the Chat **chatAutoDeleteTimer** property.
    /// - Parameter block: completion block --> return true if success, otherwise return false.
    func fetchAutoDeleteTimerAsync(completion block: ((Bool)->Void)? = nil) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = self is BBContact ?
                    BlackboxCore.contactGetAutoDeleteTimer((self as! BBContact).registeredNumber) :
                    BlackboxCore.groupGetAutoDeleteTimer((self as! BBGroup).ID) else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try Blackbox.shared.decoder.decode(FetchAutoDeleteTimerResponse.self, from: jsonString.data(using: .utf8)!)
                
                if response.isSuccess() {
                    strongSelf.chatAutoDeleteTimer = MessageAutoDeleteTimer.secondsToTimer(response.seconds)
                    block?(true)
                } else {
                    loge(response.message)
                    block?(false)
                }
                
            } catch {
                loge(error)
                block?(false)
            }
        }
    }
    
    /// Set the Chat Auto Delete Messages Timer on a background thread and update the Chat **chatAutoDeleteTimer** property.
    /// - Parameters:
    ///   - seconds: Timer in seconds
    ///   - block: completion block --> return true if success, otherwise return false.
    func setAutoDeleteMessagesAsync(seconds: Int, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = self is BBContact ?
                    BlackboxCore.contactSetAutoDeleteTimer((self as! BBContact).registeredNumber, seconds: seconds) :
                    BlackboxCore.groupSetAutoDeleteTimer((self as! BBGroup).ID, seconds: seconds) else {
                block?(false)
                return
            }
            
            do {
                let response = try Blackbox.shared.decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    strongSelf.chatAutoDeleteTimer = MessageAutoDeleteTimer.secondsToTimer(seconds)
                    block?(true)
                } else {
                    block?(false)
                    loge(response.message)
                }
            } catch {
                block?(false)
                loge(error)
            }
        }
    }
    
    /// Remove the Chat Messages from RAM
    func removeAllMessages() {
        for i in 0..<messagesSections.count {
            messagesSections[i].messages.removeAll()
        }
        messagesSections.removeAll()
    }
    
    /// Remove the Unread Message banner from messages
    func removeUnreadBanner() {
        for i in 0..<messagesSections.count {
            messagesSections[i].messages.removeAll { return $0.message.type == .unreadMessages }
        }
    }
    
    /// Refresh the Unread Banner Position within the messages. The Table **MUST** be reloaded after this function.
    /// - Returns: True if success
    func refreshUnreadBanner() -> Bool {
        // remove any unread messages banner if present
        removeUnreadBanner()
        
        // Add back the banner at the right position if needed
        let unreadMessages = getRealUnreadMessagesViewModels().map { (msgVM) -> String in
            return msgVM.message.ID
        }
        
        guard unreadMessages.count > 0, let firstUnreadIndex = getMessageIndexPath(msgID: unreadMessages[0]) else { return false }
        let unreadBannerMsg = Message(recipient: "")
        unreadBannerMsg.type = .unreadMessages
        let msgVM = MessageViewModel(message: unreadBannerMsg, contact: BBContact())
        messagesSections[firstUnreadIndex.section].messages.insert(msgVM, at: firstUnreadIndex.row)
        return true
    }
    
    /// Return the Index Path, if present in the grouped array, of a message based on his ID
    /// - Parameter msgID: message ID
    func getMessageIndexPath(msgID: String, section: Int? = nil) -> IndexPath? {
        if section != nil, messagesSections.count > section! {
            for (messageIndex, messageViewModel) in messagesSections[section!].messages.enumerated() where messageViewModel.message.ID == msgID {
                return IndexPath(row: messageIndex, section: section!)
            }
        }
        
        for (sectionIndex, section) in messagesSections.enumerated() {
            for (messageIndex, messageViewModel) in section.messages.enumerated() where messageViewModel.message.ID == msgID {
                return IndexPath(row: messageIndex, section: sectionIndex)
            }
        }
        
        return nil
    }
    
    
    // MARK: - Messages fetch functions
    
    /// Return True if the Chat is Open.
    var isChatOpen: Bool {
        guard let currentVC = Blackbox.shared.currentViewController, let chatVC = currentVC as? ChatViewController, let chatViewModel = chatVC.viewModel else { return false }
        if let contact = self as? BBContact, let chatContact = chatViewModel.contact, chatContact.registeredNumber == contact.registeredNumber {
            return true
        } else if let group = self as? BBGroup, let chatGroup = chatViewModel.group, chatGroup.ID == group.ID {
            return true
        }
        return false
    }
    
    /// This function is called when the Chat List Cell will appear.
    /// It will fetch the Messages of the chats (new or complete chat refresh on startup) on screen and update the **messagesSections** property ONLY if the chat is not open.
    func backgroundFetchMessages() {
        if isStartupFetchDone {
            // 1) if we already fetched once, we'll perform another initialFetch only if there are no messages but there are unread messages.
            // 2) Otherwise if the the chat has messages and there are unread one, we'll fetch only new messages.
            //
            // -> In both cases, once the fetch is complete and we were able to get these messages,
            // we'll update the messagesSection var ONLY IF the chat is not open.
            if messagesSections.count > 0 && self.unreadMessagesCount > 0 {
                //        if let lastSection = messagesSections.last {
                //          for msgViewModel in lastSection.messages where msgViewModel.message.ID == self.oldestUnreadMsgID {
                //            return
                //          }
                //        }
                // fetch new messages
                if let lastSection = self.messagesSections.last, let lastMsgViewModel = lastSection.messages.last, let msgID = Int(lastMsgViewModel.message.ID) {
                    let nextMsgId  = String(msgID + 1)
                    fetchMessagesAsync(fromId: nextMsgId, limit: 10000) { (messagesSections) in
                        guard let messagesSections = messagesSections,
                              self.isChatOpen == false,
                              let newMessagesSections = self.processNewMessages(newMessagesSections: messagesSections) else { return }
                        self.messagesSections = newMessagesSections
                    }
                }
            } else if messagesSections.count == 0 && self.unreadMessagesCount > 0 {
                initialFetch()
            }
        } else {
            initialFetch()
        }
    }
    
    /// Fetch the last 80 messages if unreadMessagesCount is less then 80
    /// Or
    /// Fetch unreadMessagesCount + 20 messages.
    private func initialFetch() {
        
        isStartupFetchDone = true
        
        var limit = 80
        if self.unreadMessagesCount > limit {
            limit = self.unreadMessagesCount + 20
        }
        
        fetchMessagesAsync(limit: limit) { (messagesSection) in
            guard let messagesSection = messagesSection, self.isChatOpen == false else { return }
            
            if let newMessagesSections = self.processAllMessages(newMessagesSections: messagesSection) {
                
                if let firstSection = newMessagesSections.first, let firstMsgVM = firstSection.messages.first, let oldestUnreadMsgIDString = self.oldestUnreadMsgID,
                   let oldestUnread = Int(oldestUnreadMsgIDString), let currentOldest = Int(firstMsgVM.message.ID), oldestUnread < currentOldest {
                    // we have older unread messages
                    self.fetchMessagesAsync(fromId: oldestUnreadMsgIDString, toId: firstMsgVM.message.ID, limit: 0) { (_messagesSection) in
                        guard let oldMessagesSections = _messagesSection, self.isChatOpen == false else {
                            self.messagesSections = newMessagesSections
                            return
                        }
                        
                        if let newMessagesSections2 = self.processOldMessages(oldMessagesSections: oldMessagesSections, source: newMessagesSections) {
                            self.messagesSections = newMessagesSections2
                        } else {
                            self.messagesSections = newMessagesSections
                        }
                    }
                }
                else {
                    self.messagesSections = newMessagesSections
                }
            }
            else {
                self.messagesSections = messagesSection
            }
        }
        
        fetchStarredMessagesAsync(completion: nil)
    }
    
    /// Fetch the chat starred messages
    /// - Parameter block: completion block --> return true if success, otherwise return false.
    func fetchStarredMessagesAsync(completion block: ((Bool) -> Void)?) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = self is BBGroup ?
                    BlackboxCore.groupGetStarredMessages((self as! BBGroup).ID) :
                    BlackboxCore.contactGetStarredMessages((self as! BBContact).registeredNumber) else {
                block?(false)
                return
            }
            do {
                let response = try Blackbox.shared.decoder.decode(FetchMessagesResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    self.starredMessages = self.convertToViewModels(messages: response.messages.filter { $0.groupID.isEmpty })
                        .filter {
                            return $0.message.type != .alertCopy &&
                                $0.message.type != .alertForward &&
                                $0.message.type != .alertScreenshot &&
                                $0.message.type != .alertScreenRecording &&
                                $0.message.type != .deleted &&
                                $0.message.type.isSystemMessage() == false
                        }
                        .sorted {
                            if let id1 = Int($0.message.ID), let id2 = Int($1.message.ID), id1 > id2 {
                                return true
                            }
                            return false
                        }
                    
                    block?(true)
                } else {
                    block?(false)
                    //            loge(response.message)
                }
            } catch {
                block?(false)
                loge(error)
            }
        }
    }
    
    /// Fetch the Chat messages
    /// - Parameters:
    ///   - fromId: from msg id
    ///   - toId: to msgid
    ///   - fromDate: from date
    ///   - toDate: to date
    ///   - limit: limit the number of messages returned. Setting this to Zero is equal to 100.000
    ///   - block: return the messages grouped by date
    func fetchMessagesAsync(fromId: String = "", toId: String = "", fromDate: String = "", toDate: String = "", limit: Int = 40, completion block: (([MessagesSection]?)->Void)?) {
        
        if Blackbox.shared.isNetworkReachable == false {
            block?(nil)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = self is BBContact ?
                    BlackboxCore.contactGetMessages((self as! BBContact).registeredNumber, msgIdFrom: fromId, msgIdTo: toId, dateFrom: fromDate, dateTo: toDate, limit: limit) :
                    BlackboxCore.groupGetMessages((self as! BBGroup).ID, msgIdFrom: fromId, msgIdTo: toId, dateFrom: fromDate, dateTo: toDate, limit: limit) else {
                block?(nil)
                return
            }
            
            if let contact = self as? BBContact, contact.registeredNumber == "100100" {
                logPrettyJsonString(jsonString)
            }
            do {
                let response = try Blackbox.shared.decoder.decode(FetchMessagesResponse.self, from: jsonString.data(using: .utf8)!)
                
                strongSelf.addMessagesSerialQueue.async {
                    if !response.isSuccess() {
                        block?(nil)
                        loge(response.message)
                    }
                    else {
                        // Update the Chat List
                        let msgsVM = strongSelf.convertToViewModels(messages: response.messages)
                        let newMessagesSections = BBChat.groupMessagesViewModelsByDate(msgsVM)
                        
                        block?(newMessagesSections)
                    }
                }
                
            } catch {
                block?(nil)
                loge(error)
            }
        }
        
    }
    
}

private extension BBChat {
    
    func sortUnreadMessages() {
        unreadMessages.sort {
            if let id1 = Int($0), let id2 = Int($1) {
                return id1 < id2
            }
            return false
        }
    }
    
    func updatePreviousMessagesSender(messageViewModel: MessageViewModel) {
        if let lastSection = messagesSections.last, let lastMessage = lastSection.messages.last {
            messageViewModel.previousMessageSender = lastMessage.message.sender
        }
    }
    
    /// This method will proc the **messageAdded** Publisher. The ChatView, subscribed to this will update the table and dataSource accordingly.
    /// - Parameter message: the message to add to the Table.
    func appendMessageEvent(_ message: Message) {
        if self.messagesSections.count == 0 {
            messageAdded.send((addNewSection: true, message: message))
        } else {
            if let lastSection = self.messagesSections.last, lastSection.date.isInToday {
                messageAdded.send((addNewSection: false, message: message))
            } else {
                messageAdded.send((addNewSection: true, message: message))
            }
        }
    }
    
    func appendUnreadMessage(_ message: Message, isFromApplePush: Bool = false) {
        if message.type.isSystemMessage() == false, message.status == .incoming, message.dateRead == nil, message.type != .deleted {
            self.unreadMessages.append(message.ID)
            sortUnreadMessages()
            unreadMessagesCount = message.chatUnreadMessagesCount
            logi(message.chatUnreadMessagesCount)
            if unreadMessagesCount < unreadMessages.count {
                unreadMessagesCount = unreadMessages.count
            }
            if isFromApplePush == false {
                Blackbox.shared.updateTotalUnreadMessages()
            } else {
                AppUtility.setAppBadgeNumber(message.totUnreadMsgs)
            }
        }
    }
    
    func removeLastSectionDuplicatedMessages() {
        // Remove any possible duplicate message from the list.
        if self.messagesSections.count > 0 {
            self.messagesSections[self.messagesSections.count-1].messages.removeDuplicates()
        }
    }
    
    /// Show the Top Notification Widget
    /// - Parameters:
    ///   - messageViewModel: the message view model
    ///   - contact: the contact
    ///   - group: the group
    func showNotification(messageViewModel: MessageViewModel, contact: BBContact, group: BBGroup?) {
        guard messageViewModel.isSent == false, Blackbox.shared.account.inOnCall == false else { return }
        
        AppUtility.isAppInForeground { (success) in
            if success {
                var title = contact.getName()
                if group != nil {
                    if title == "0000001" {
                        title = "\(group!.description)"
                    } else {
                        title = "\(title) @ \(group!.description)"
                    }
                }
                var image: UIImage? = nil
                if let group = group {
                    if let _image = UIImage.fromPath(group.profileImagePath) {
                        image = _image
                    } else {
                        image = UIImage(named: "avatar_profile_group")
                    }
                }
                else {
                    if let _image = UIImage.fromPath(contact.profilePhotoPath) {
                        image = _image
                    } else {
                        image = UIImage(named: "avatar_profile")
                    }
                }
                
                let message = messageViewModel.message.isAlertMessage ? messageViewModel.message.alertMsg?.getAttributedText() : messageViewModel.message.body.getAttributedText()
                
                MessageNotification.shared.show(title: title, message: message?.adjustDirectionBasedOnSystemLanguage(), image: image, object: messageViewModel) { (object) in
                    if let msgViewModel = object as? MessageViewModel {
                        if let group = msgViewModel.group {
                            Blackbox.shared.openChat(group: group)
                        } else {
                            Blackbox.shared.openChat(contact: msgViewModel.contact)
                        }
                    }
                }
            }
        }
    }
    
}


extension BBChat {
    
    /// Take an Array of MessageViewModel and return and Array of MessagesSection.
    /// - Parameter messagesViewModels: source MessageViewModel array
    /// - Returns: Return an Array of MessagesSection (messages grouped by date).
    static func groupMessagesViewModelsByDate(_ messagesViewModels: [MessageViewModel]) -> [MessagesSection] {
        var placeHolder = [Date: Int]()
        var prevMessageeeee: MessageViewModel?
        var sections = [MessagesSection]()
        
        for viewModel in messagesViewModels {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let stringDate = formatter.string(from: viewModel.message.dateSent)
            
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            let sectionDate = formatter.date(from: stringDate)!.adding(.hour, value: 12)
            
            if placeHolder[sectionDate] != nil {
                if prevMessageeeee != nil {
                    prevMessageeeee?.nextMessageSender = viewModel.message.sender
                    viewModel.previousMessageSender = prevMessageeeee?.message.sender
                }
                sections[placeHolder[sectionDate]!].messages.append(viewModel)
                prevMessageeeee = viewModel
            } else {
                // set previous message to nil since this is the first message of the new section
                prevMessageeeee = viewModel
                placeHolder[sectionDate] = sections.count == 0 ? 0 : sections.count
                sections.append(MessagesSection(date: sectionDate, messages: [viewModel]))
            }
        }
        
        return sections;
    }
    
}

// MARK: - Archive - Unarchive chats
extension BBChat {
    
    /// Archive a chat for the specific contact or group.
    /// - Parameters:
    ///   - contact: BBContact
    ///   - group: BBGroup
    ///   - block: completion block --> return true if success, otherwise return false.
    private static func archiveChat(contact: BBContact?, group: BBGroup?, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.contactArchiveChat(contact?.registeredNumber) ?? BlackboxCore.groupArchiveChat(group?.ID) else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try Blackbox.shared.decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if !response.isSuccess() {
                    loge(response.message)
                    // TODO: Retry if failed
                    block?(false)
                } else {
                    block?(true)
                }
            } catch {
                loge(error)
                block?(false)
            }
        }
    }
    
    /// UnArchive a chat for the specific contact or group.
    /// - Parameters:
    ///   - contact: BBContact
    ///   - group: BBGroup
    ///   - block: completion block --> return true if success, otherwise return false.
    private static func unarchiveChat(contact: BBContact?, group: BBGroup?, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.contactUnarchiveChat(contact?.registeredNumber) ?? BlackboxCore.groupUnarchiveChat(group?.ID) else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try Blackbox.shared.decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if !response.isSuccess() {
                    loge(response.message)
                    // TODO: Retry if failed
                    block?(false)
                } else {
                    block?(true)
                }
            } catch {
                loge(error)
                block?(false)
            }
        }
    }
    
    /// Archive a chat for the specific contact
    /// - Parameters:
    ///   - contact: BBContact
    ///   - block: completion block --> return true if success, otherwise return false.
    static func archiveChatAsync(contact: BBContact, completion block:((Bool)->Void)?) {
        archiveChat(contact: contact, group: nil, completion: block)
    }
    
    /// UnArchive a chat for the specific contact
    /// - Parameters:
    ///   - contact: BBContact
    ///   - block: completion block --> return true if success, otherwise return false.
    static func unarchiveChatAsync(contact: BBContact, completion block:((Bool)->Void)?) {
        unarchiveChat(contact: contact, group: nil, completion: block)
    }
    
    /// Archive a chat for the specific group.
    /// - Parameters:
    ///   - group: BBGroup
    ///   - block: completion block --> return true if success, otherwise return false.
    static func archiveGroupChatAsync(group: BBGroup, completion block:((Bool)->Void)?) {
        archiveChat(contact: nil, group: group, completion: block)
    }
    
    /// UnArchive a chat for the specific group
    /// - Parameters:
    ///   - group: BBGroup
    ///   - block: completion block --> return true if success, otherwise return false.
    static func unarchiveGroupChatAsync(group: BBGroup, completion block:((Bool)->Void)?) {
        unarchiveChat(contact: nil, group: group, completion: block)
    }
    
    /// Return the Archived chat for the specific Contact or **nil** if not present
    /// - Parameter contact: the Contact
    /// - Returns: Return the Archived chat for the specific contact or **nil** if not present
    private static func getArchivedContactChatCellViewModel(contact: BBContact) -> ChatCellViewModel? {
        for chat in Blackbox.shared.archivedChatItems {
            if let contactChat = chat.contact, contactChat.registeredNumber == contact.registeredNumber {
                return chat
            }
        }
        return nil
    }
    
    /// Return the Archived chat for the specific Group or **nil** if not present
    ///   - group: The BBGroup
    /// - Returns: Return the Archived chat for the specific contact or **nil** if not present
    private static func getArchivedGroupChatCellViewModel(group: BBGroup) -> ChatCellViewModel? {
        for chat in Blackbox.shared.archivedChatItems {
            if let groupChat = chat.group, groupChat.ID == group.ID {
                return chat
            }
        }
        return nil
    }
    
    /// Unarchive a chat when sending a new Message (if archived)
    /// - Parameter contact: the contact chat to unarchive
    static func unarchiveChatIfNeeded(contact: BBContact) {
        unarchiveChatAsync(contact: contact) { success in
            let blackbox = Blackbox.shared
            blackbox.archivedChatItems.removeAll {
                if let _contact = $0.contact, _contact.registeredNumber == contact.registeredNumber {
                    return true
                }
                return false
            }
        }
    }
    
    /// Unarchive a group chat when sending a new Message (if archived)
    /// - Parameter contact: the contact chat to unarchive
    static func unarchiveGroupChatIfNeeded(group: BBGroup) {
        if let chatCellViewModel = getArchivedGroupChatCellViewModel(group: group) {
            unarchiveGroupChatAsync(group: group) {success in
                let blackbox = Blackbox.shared
                blackbox.archivedChatItems.removeAll {
                    if let _group = $0.group, _group.ID == group.ID {
                        return true
                    }
                    return false
                }
                blackbox.chatItems.append(.Chat(chatCellViewModel))
                blackbox.sortChatItems()
            }
        }
    }
}

