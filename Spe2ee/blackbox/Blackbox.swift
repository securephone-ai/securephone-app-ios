import Foundation
import Combine
import CallKit
import Alamofire
import BlackboxCore
import CwlUtils
import DifferenceKit

extension Notification.Name {
    static let newMessageReceived = Notification.Name("newMessageReceived")
}

typealias response<T> = ((T?, String?) -> Void)?
typealias errorResponse<T> = ((String?) -> Void)?


final class Blackbox {
    /// Singleton Initialization
    static let shared = Blackbox()
    private init() {
        providerDelegate = CallKitProviderDelegate(callManager: callManager)
        account = Account()
    }
    
    var updatingPassword: Bool = false
    
    // Account
    var account: Account
    var pwdConf: String?
    private var lastReceiedMessageTimeStamp: TimeInterval = .zero
    lazy var fetchTimer: DispatchTimer? = {
        let timer = DispatchTimer(countdown: .milliseconds(1500), repeating: .milliseconds(250), executingOn: DispatchQueue.global(qos: .background)) {
            self.fetchSingleMessageInternalPushAsync(fromLoop: true, completion: nil)
        }
        return timer
    }()
    
    // VOIP
    let callManager = BBCallManager()
    let voipAudioManager = VoipIOAudioManager()
    var providerDelegate: CallKitProviderDelegate?
    let decoder = JSONDecoder()
    
    // Async queues
    let fetchSingleMessageSerialQueue = DispatchQueue(label: "fetch_single_message_seria_queue", qos: .userInitiated)
    let fetchSingleMessageConcurrentQueue = DispatchQueue(label: "fetch_single_message_concurrent_queue", qos: .userInitiated, attributes: .concurrent)
    let fetchChatListSerialQueue = DispatchQueue(label: "fetch_chat_list_queue", qos: .userInitiated)
    
    var messagesQueue = 0
    let contactsSerialQueue = DispatchQueue(label: "blackbox_contacts_messages_queue", qos: .userInitiated)
    
    // Network
    var networkManager = NetworkReachabilityManager(host: "www.google.com")
    @Published var isNetworkReachable: Bool = false
    
    // Chat Footer
    var defaultFooterHeight: CGFloat = .zero
    
    /// Variables
    var pushToken: String?
    var pushVoipToken: String?
    
    // VIew Controllers references
    var currentViewController: UIViewController?
    var appRootViewController: AppRootViewController?
    var chatListViewController: ChatsListViewController?
    var chatViewController: ChatViewController?
    var callViewController: CallViewController?
    
    // MARK: - Store
    
    /// Tab "Calls" Table items
    @Published var callHistoryCellsViewModels = [CallHistoryCellViewModel]()
    
    /// Tab "Chats" table items
    @Published var chatItems: [ChatItems] =  [.Archive]
    
    /// Archived Chats
    @Published var archivedChatItems: [ChatCellViewModel] = []
    
    /// Saved Contacts
    @Published var contactsSections = [BBContactsSection]()
    
    /// For example, a group member that is not saved in your contacts list
    var temporaryContacts = [BBContact]()
    
}

// MARK: -  Static Functions
extension Blackbox {
    
    /// Return the pwdConf
    func getPwdConf(key: String? = nil) -> String? {
        if let pwdConf = Blackbox.shared.pwdConf, pwdConf.isEmpty == false {
            // already decrypted
            return pwdConf
        }
        else {
            if let key = key {
                // decrypt before saving in RAM for any use.
                let fileUrl = AppUtility.getDocumentsDirectory().appendingPathComponent("9154fed975b467fa8e56b1661cc1352fd1e726a34d8573449941b5a216124d44.enc")
                if FileManager.default.fileExists(atPath: fileUrl.path) {
                    do {
                        let data = try Data(contentsOf: fileUrl)
                        guard let pwdConf = BlackboxCore.decryptPwdConf(data, key: key, tempFolder: AppUtility.getDocumentsDirectory().path) else {
                            return nil
                        }
                        
                        // Store in RAM
                        let tmp = pwdConf
                            .replacingOccurrences(of: "\u{fffc}", with: "", options: NSString.CompareOptions.literal, range: nil)
                            .replacingOccurrences(of: "�", with: "", options: NSString.CompareOptions.literal, range: nil)
                            .trimmingCharacters(in: .whitespaces)
                        
                        let jsonObj = try decoder.decode(PwdConf.self, from: tmp.data(using: .utf8)!)
                        if !jsonObj.keyaes.isEmpty {
                            self.pwdConf = tmp
                            return self.pwdConf!
                        }
                    } catch {
                        loge(error)
                    }
                }
            }
        }
        DispatchQueue.main.async {
            if UIApplication.shared.windows[0].rootViewController is AppRootViewController ||
                UIApplication.shared.windows[0].rootViewController is AppStartViewController {
                
                // Force Request password to continue
                if let rootVC = UIApplication.shared.windows[0].rootViewController, rootVC is LoginViewController {
                    logi("already in LoginViewController")
                } else {
                    UIApplication.shared.windows[0].rootViewController = LoginViewController()
                }
            }
        }
        
        return nil
    }
    
    func getPwdConfUsingPassword(_ key: String) -> String? {
        // decrypt before saving in RAM for any use.
        let fileUrl = AppUtility.getDocumentsDirectory().appendingPathComponent("9154fed975b467fa8e56b1661cc1352fd1e726a34d8573449941b5a216124d44.enc")
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            do {
                let data = try Data(contentsOf: fileUrl)
                guard let pwdConf = BlackboxCore.decryptPwdConf(data, key: key, tempFolder: AppUtility.getDocumentsDirectory().path) else {
                    return nil
                }
                
                // Store in RAM
                let tmp = pwdConf
                    .replacingOccurrences(of: "\u{fffc}", with: "", options: NSString.CompareOptions.literal, range: nil)
                    .replacingOccurrences(of: "�", with: "", options: NSString.CompareOptions.literal, range: nil)
                    .trimmingCharacters(in: .whitespaces)
                
                let jsonObj = try decoder.decode(PwdConf.self, from: tmp.data(using: .utf8)!)
                if !jsonObj.keyaes.isEmpty {
                    self.pwdConf = tmp
                    return self.pwdConf!
                }
            } catch {
                loge(error)
            }
        }
        
        return nil
    }
    
    func isCorrectPassword(_ password: String) -> Bool {
        let fileUrl = AppUtility.getDocumentsDirectory().appendingPathComponent("9154fed975b467fa8e56b1661cc1352fd1e726a34d8573449941b5a216124d44.enc")
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            do {
                let data = try Data(contentsOf: fileUrl)
                guard let pwdConf = BlackboxCore.decryptPwdConf(data, key: password, tempFolder: AppUtility.getDocumentsDirectory().path) else {
                    return false
                }
                
                let tmp = pwdConf
                    .replacingOccurrences(of: "\u{fffc}", with: "", options: NSString.CompareOptions.literal, range: nil)
                    .replacingOccurrences(of: "�", with: "", options: NSString.CompareOptions.literal, range: nil)
                    .trimmingCharacters(in: .whitespaces)
                
                let jsonObj = try decoder.decode(PwdConf.self, from: tmp.data(using: .utf8)!)
                if !jsonObj.keyaes.isEmpty {
                    self.pwdConf = tmp
                    return true
                }
            } catch {
                loge(error)
            }
        }
        
        return false
    }
    
    /// Get a pointer to the decrypted pwdConf string
    /// - Returns:
    static func getPwdConfPointer() -> UnsafeMutablePointer<Int8>? {
        return Blackbox.shared.pwdConf?.toMutablePointer()
    }
    
    /// Check if pwdConf encrypted file exist
    /// - Returns:
    static func pwdConfExist() -> Bool {
        let fileUrl = AppUtility.getDocumentsDirectory().appendingPathComponent("9154fed975b467fa8e56b1661cc1352fd1e726a34d8573449941b5a216124d44.enc")
        return FileManager.default.fileExists(atPath: fileUrl.path)
    }
    
    static func alreadyLoggedIn() -> Bool {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("&#39.cfg")
        return FileManager.default.fileExists(atPath: fileUrl.path)
    }
    
    func isPwdConfValid() -> Bool {
        if let _ = getPwdConf(key: "") {
            return true
        }
        return false
    }
    
    func updateAccountPassword(currentPwd: String, newPwd: String, confirmPwd: String) -> String? {
        if let pwdConf = getPwdConfUsingPassword(currentPwd) {
            if newPwd != confirmPwd {
                return "Confirm password does not match"
            }
            
            let result = BlackboxCore.encryptPwdConf(pwdConf, key: newPwd)
            logi(result)
            return nil
        } else {
            return "Invalid current password."
        }
    }
    
}

// MARK: - Chat Manager Functions
extension Blackbox {
    func openChat(contact: BBContact) {
        if let _ = currentViewController as? ChatViewController, let chatVC = self.chatViewController, let chatViewModel = chatVC.viewModel, let contactVC = chatViewModel.contact, contactVC.registeredNumber == contact.registeredNumber {
            return
        }
        guard let vc = self.chatListViewController else { return }
        vc.openChat(contact: contact)
        //    vc.dismiss(animated: true, completion: nil)
    }
    
    func openChat(group: BBGroup) {
        if let chatVC = self.chatViewController, let chatViewModel = chatVC.viewModel, let groupVC = chatViewModel.group, groupVC.ID == group.ID {
            return
        }
        guard  let vc = self.chatListViewController else { return }
        vc.openChat(group: group)
        //    vc.dismiss(animated: true, completion: nil)
    }
}

// MARK: - Common functions
private extension Blackbox {
    class private func getBaseResponse(response: String) -> BaseResponse? {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(BaseResponse.self, from: response.data(using: .utf8)!)
        } catch {
            loge(error)
            return nil
        }
    }
}

// Messages
extension Blackbox {
    /// Fetch the message when the push notification is received on a background thread. Completion block on main thread.
    /// - Parameter block: Reponse completion block
    func fetchSingleMessageInternalPushAsync(fromLoop: Bool = false, periodicCheck: Bool = false, completion block: (()->Void)?) {
        
        if periodicCheck {
            // Check if there are new messages in queue only after a certain time after the last message in received
            let nowTimeStamp = NSDate().timeIntervalSince1970
            logi(nowTimeStamp - lastReceiedMessageTimeStamp)
            if nowTimeStamp - lastReceiedMessageTimeStamp <= Double(Constants.CheckNewMessagesTimer) {
                return
            }
        }
        
        fetchSingleMessageConcurrentQueue.async { [weak self] in
            
            guard let strongSelf = self, strongSelf.account.state == .registered else {
                block?()
                return
            }
            
            strongSelf.lastReceiedMessageTimeStamp = NSDate().timeIntervalSince1970
            guard let jsonString = BlackboxCore.accountGetNewMessage() else {
                block?()
                return
            }
            
            do {
                let message = try JSONDecoder().decode(Message.self, from: jsonString.data(using: .utf8)!)
                
                if message.answer == "KO" {
                    logw("Fetch \(fromLoop ? "from loop " : "")Single message: EMPTY - In Queue: \(message.queue)")
                    block?()
                }
                else {
                    
                    if message.type == .status {
                        if let contact = strongSelf.getContact(registeredNumber: message.sender) {
                            contact.onlineStatus = message.body == "online" ? .online : .offline
                        }
                        else if let contact = strongSelf.getTemporaryContact(registeredNumber: message.sender) {
                            contact.onlineStatus = message.body == "online" ? .online : .offline
                        }
                    }
                    else if message.type == .deleted {
                        logi("Fetch \(fromLoop ? "from loop " : "")Single message: Message Deleted - In Queue: \(message.queue)")
                        strongSelf.setMessageDeletedInternalPush(message)
                    }
                    else if message.type == .received {
                        logi("Fetch \(fromLoop ? "from loop " : "")Single message: Message Received - In Queue: \(message.queue)")
                        // The body contain the real message ID
                        strongSelf.setMessageReceived(message)
                    }
                    else if message.type == .read {
                        logi("Fetch \(fromLoop ? "from loop " : "")Single message: Message Read - In Queue: \(message.queue)")
                        // The body contain the real message ID
                        strongSelf.setMessageRead(message)
                    }
                    else if message.type == .typing, message.sender != strongSelf.account.registeredNumber  {
                        logi("Fetch \(fromLoop ? "from loop " : "")Single message: Message Typing - In Queue: \(message.queue)")
                        // We've just received a Typing message from a contact
                        if message.isGroupChat {
                            strongSelf.setGroupChatTyping(message: message)
                        } else {
                            strongSelf.setChatContactTyping(message: message)
                        }
                    }
                    else {
                        
                        logi("Fetch \(fromLoop ? "from loop " : "")Internal Push - \(jsonString)")
                        
                        if message.isGroupChat, message.sender == message.recipient {
                            // self message
                            block?()
                            return
                        }
                        
                        // Process each message in a serial QUEUE to synchronize data.
                        strongSelf.fetchSingleMessageSerialQueue.async {
                            
                            // Update the Chat List and Append the message to the Contact or Group
                            if message.isGroupChat {
                                
                                // In case that we where removed from the group we update the chatItems and aexit the thread.
                                if message.type.isSystemMessage() && message.body.contains("You have been removed from Chat Group:") {
                                    strongSelf.chatItems = strongSelf.chatItems.filter {
                                        if $0 == .Archive {
                                            return true
                                        }
                                        if let chatItemViewModel = $0.getChatItemViewModel(), let group = chatItemViewModel.group, group.ID != message.groupID {
                                            return true
                                        }
                                        return false
                                    }
                                    
                                    return
                                }
                                
                                var group: BBGroup?
                                
                                // Create a new chat object if we where just added to a new group chat
                                if message.body.contains("You have been added to Chat Group:", caseSensitive: false), message.sender == "0000001" {
                                    // We have just received an invitation to a groupso we proceed to Create it and fetch his members
                                    group = BBGroup(id: message.groupID,
                                                    description: message.body.replacingFirstOccurrenceOfString(target: "You have been added to Chat Group: ", withString: ""),
                                                    role: .normal, members: [BBContact]())
                                    group?.updateMembersListAsync()
                                }
                                else {
                                    // Get the chat object from the chatItems (if present)
                                    for chat in strongSelf.chatItems {
                                        if let chatViewModel = chat.getChatItemViewModel(), let _group = chatViewModel.group, _group.ID == message.groupID {
                                            group = _group
                                        }
                                    }
                                }
                                
                                guard let _group = group else { return }
                                
                                // Some systems events messages may notify specific Events, like group name change or contact removed (or left) the group.
                                // Changed Group Name
                                if message.type.isSystemMessage() {
                                    switch message.type {
                                    case .systemMessage(let type):
                                        switch type {
                                        case .groupContactRemoved:
                                            guard let contactNumber = message.removedFromGroupContactNumber else { break }
                                            _group.members = _group.members.filter { $0.registeredNumber != contactNumber }
                                        case .groupNameChanged:
                                            _group.description = message.body.replacingOccurrences(of: "The group's name is changed to: ", with: "")
                                        default:
                                            break
                                        }
                                    default:
                                        break
                                    }
                                }
                                
                                _group.refreshChatList(message: message)
                                _group.appendMessage(message, contact: _group.getGroupMember(message: message), group: _group)
                                BBChat.unarchiveGroupChatIfNeeded(group: _group)
                                
                                
                                strongSelf.setGroupChatTyping(message: message, isTyping: false)
                                
                            }
                            else {
                                let contact = strongSelf.getContactFromMessage(message)
                                contact.refreshChatList(message: message)
                                contact.appendMessage(message, contact: contact)
                                strongSelf.setChatContactTyping(message: message, isTyping: false)
                                BBChat.unarchiveChatIfNeeded(contact: contact)
                            }
                            
                        }
                    }
                    
                }
                
                // fetch more messages
                strongSelf.messagesQueue = Int(message.queue)
                if strongSelf.messagesQueue > 0 {
                    if let timer = strongSelf.fetchTimer, timer.state == .disarmed {
                        strongSelf.fetchTimer?.arm()
                    }
                    else {
                        // Doing so we prevent the fetched from loop call to run if we receive an internal push in the last 2 seconds.
                        strongSelf.fetchTimer?.reset()
                    }
                }
                else {
                    if let timer = strongSelf.fetchTimer, timer.state == .armed {
                        // Disable timer
                        strongSelf.fetchTimer?.disarm()
                    }
                }
                
            } catch {
                block?()
                loge(error)
            }
            
        }
    }
    
    /// Fetch the message when the push notification is received on a background thread. Completion block on main thread.
    /// - Parameter block: Reponse completion block
    func fetchSingleMessageApplePushAsync() {
        AppUtility.isAppInForeground { (success) in
            guard success == false else { return }
            
            self.fetchSingleMessageSerialQueue.async { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                let blackbox = Blackbox.shared
                func fetchMessages() {
                    guard let jsonString = BlackboxCore.accountGetNewMessageBackground() else {
                        return
                    }
                    logPrettyJsonString(jsonString)
                    
                    do {
                        let message = try JSONDecoder().decode(Message.self, from: jsonString.data(using: .utf8)!)
                        
                        if message.answer == "OK" {
                            
                            strongSelf.messagesQueue = Int(message.queue)
                            if strongSelf.messagesQueue > 0 {
                                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 0.4) {
                                    strongSelf.fetchSingleMessageApplePushAsync()
                                }
                            }
                            
                            if message.type == .typing || message.type == .deleted || message.type == .received || message.type == .read {
                                return
                            }
                            else if message.type == .status {
                                if let contact = strongSelf.getContact(registeredNumber: message.sender) {
                                    contact.onlineStatus = message.body == "online" ? .online : .offline
                                }
                                else if let contact = strongSelf.getTemporaryContact(registeredNumber: message.sender) {
                                    contact.onlineStatus = message.body == "online" ? .online : .offline
                                }
                            }
                            else {
                                if message.isGroupChat, message.sender == message.recipient {
                                    return
                                }
                                
                                // Update the Chat List and Append the message to the Contact or Group
                                if !message.groupID.isEmpty {
                                    
                                    if message.body.contains("You have been added to Chat Group:"), message.sender == "0000001" {
                                        // We have just received an invitation to a groupso we proceed to Create it and fetch his members
                                        let group = BBGroup(id: message.groupID,
                                                            description: message.body.replacingFirstOccurrenceOfString(target: "You have been added to Chat Group: ", withString: ""),
                                                            role: .normal, members: [BBContact]())
                                        group.updateMembersListAsync()
                                        group.refreshChatList(message: message)
                                        group.appendMessage(message, contact: group.getGroupMember(message: message), group: group, isFromApplePush: true)
                                    } else {
                                        strongSelf.chatItems.forEach {
                                            if let chatViewModel = $0.getChatItemViewModel(), let group = chatViewModel.group, group.ID == message.groupID {
                                                group.refreshChatList(message: message)
                                                group.appendMessage(message, contact: group.getGroupMember(message: message), group: group, isFromApplePush: true)
                                            }
                                        }
                                    }
                                    strongSelf.setGroupChatTyping(message: message, isTyping: false)
                                }
                                else {
                                    let contact = strongSelf.getContactFromMessage(message)
                                    contact.refreshChatList(message: message)
                                    contact.appendMessage(message, contact: contact, isFromApplePush: true)
                                    strongSelf.setChatContactTyping(message: message, isTyping: false)
                                }
                            }
                        }
                        
                    } catch {
                        loge(error)
                    }
                }
                
                if blackbox.account.state == .registered {
                    fetchMessages()
                } else {
                    blackbox.account.stateDidChange = {
                        if blackbox.account.state == .registered {
                            fetchMessages()
                        }
                    }
                }
            }
            
        }
    }
    
    /// Fetch the account chats list on a background thread and return the response on a main thread completion block
    
    /// Fetch the Chat list and update the **@Published property chatItems** on a background thread
    /// - Parameter block: completion block that return the chat items or nil if error or Empty
    func fetchChatListAsync(completion block: (([ChatItems]?)->())? = nil) {
        
        //    Exec.user.invokeAsync {
        Exec.queue(fetchChatListSerialQueue, .mutex).invokeAsync {
            //    fetchChatListSerialQueue.async {
            guard let jsonString = BlackboxCore.accountGetChatsList() else {
                loge("BlackboxCore.accountGetChatsList unable to exectute")
                block?(nil)
                return
            }
            do {
                let response = try JSONDecoder().decode(FetchChatsListResponse.self, from: jsonString.data(using: .utf8)!)
                
                if !response.isSuccess() && response.message.contains("No Chats found") == false {
                    block?(nil)
                }
                else {
                    var chats: [ChatItems] = [.Archive]
                    var archivedChats: [ChatCellViewModel] = []
                    
                    // Check if the Archive cell was present and in that case add it again.
                    //            if self.chatItems[0] == .Archive {
                    //              chats.insert(.Archive, at: 0)
                    //            }
                    
                    let sortedChats = response.chats.sorted(by: {$0.dateSent > $1.dateSent})
                    for chat in sortedChats {
                        
                        if chat.isGroupChat {
                            // If exist, just take it from the list instead of re-creating it.
                            var groupAdded = false
                            for item in self.chatItems {
                                if let viewModel = item.getChatItemViewModel(), viewModel.isGroup, let group = viewModel.group, group.ID == chat.groupID {
                                    group.description = chat.groupDescription
                                    
                                    if chat.isArchived {
                                        archivedChats.append(ChatCellViewModel(with: group, lastMessage: chat))
                                    }
                                    else {
                                        chats.append(.Chat(ChatCellViewModel(with: group, lastMessage: chat)))
                                        groupAdded = true
                                    }
                                    
                                    if let filename = chat.groupPhoto, !filename.isEmpty {
                                        group.fetchProfileImageAsync(fileName: filename)
                                    }
                                    
                                    group.oldestUnreadMsgID = chat.oldestUnreadMsgID
                                    group.unreadMessagesCount = chat.chatUnreadMessagesCount
                                    group.expiryDate = chat.groupDateExpiry
                                }
                            }
                            if groupAdded == false {
                                let group = BBGroup(id: chat.groupID, description: chat.groupDescription, role: .normal, members: [BBContact]())
                                
                                if chat.isArchived {
                                    archivedChats.append(ChatCellViewModel(with: group, lastMessage: chat))
                                } else {
                                    chats.append(.Chat(ChatCellViewModel(with: group, lastMessage: chat)))
                                }
                                
                                if let filename = chat.groupPhoto, !filename.isEmpty {
                                    group.fetchProfileImageAsync(fileName: filename)
                                }
                                
                                group.oldestUnreadMsgID = chat.oldestUnreadMsgID
                                group.unreadMessagesCount = chat.chatUnreadMessagesCount
                                group.expiryDate = chat.groupDateExpiry
                            }
                            
                        } else {
                            // Contact
                            if chat.sender == "0000001" {
                                continue
                            }
                            
                            let contact = self.getContactFromMessage(chat)
                            if chat.isArchived {
                                archivedChats.append(ChatCellViewModel(with: contact, lastMessage: chat))
                            } else {
                                chats.append(.Chat(ChatCellViewModel(with: contact, lastMessage: chat)))
                            }
                            
                            // Fetch the contact profile photo
                            if let filename = chat.contactPhoto, !filename.isEmpty {
                                contact.fetchProfileImageAsync(fileName: filename)
                            }
                            
                            contact.oldestUnreadMsgID = chat.oldestUnreadMsgID
                            contact.unreadMessagesCount = chat.chatUnreadMessagesCount
                        }
                    }
                    
                    // Compare and check if the chatItems list needs to be updated.
                    let changeset = StagedChangeset(source: self.chatItems, target: chats)
                    if !changeset.isEmpty {
                        self.chatItems = chats
                        
                        // Update the groups members list
                        self.chatItems.forEach {
                            if let chatItemViewModel = $0.getChatItemViewModel(), let group = chatItemViewModel.group {
                                group.updateMembersListAsync()
                            }
                        }
                    }
                    
                    // Compare and check if the archived chats lists needs to be updated.
                    self.archivedChatItems = archivedChats
                    
                    // Update the groups members list
                    self.archivedChatItems.forEach {
                        if let group = $0.group {
                            group.updateMembersListAsync()
                        }
                    }
                    
                    self.updateTotalUnreadMessages()
                    
                    logi(CFAbsoluteTimeGetCurrent())
                    
                    block?(self.chatItems)
                }
            } catch {
                block?(nil)
                loge(error)
            }
        }
        
        
    }
    
    func fetchChatsNotificationSoundAsync(completion block: ((Bool)->Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.getNotificationsSound() else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            do {
                let response = try JSONDecoder().decode(FetchNotificationSoundsResponse.self, from: jsonString.data(using: .utf8)!)
                
                if response.isSuccess() {
                    for notificationSound in response.notificationsSound {
                        if notificationSound.groupChatId.isEmpty || notificationSound.groupChatId == "0" {
                            if let contact = self.getContact(registeredNumber: notificationSound.contactNumber) {
                                contact.messageNotificationSoundName = notificationSound.soundName
                            } else if let contact = self.getTemporaryContact(registeredNumber: notificationSound.contactNumber) {
                                contact.messageNotificationSoundName = notificationSound.soundName
                            }
                        } else {
                            for chat in self.chatItems {
                                if let chatCellViewModel = chat.getChatItemViewModel(), let group = chatCellViewModel.group, group.ID == notificationSound.groupChatId {
                                    group.messageNotificationSoundName = notificationSound.soundName
                                    break
                                }
                            }
                        }
                    }
                    
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
    
    
    func updateTotalUnreadMessages() {
        AppUtility.isAppInForeground { [weak self] (success) in
            if success {
                guard let strongSelf = self else { return }
                var unreadMessages = 0
                for chat in strongSelf.chatItems {
                    if let chatViewModel = chat.getChatItemViewModel() {
                        if let contact = chatViewModel.contact {
                            //            unreadMessages += contact.unreadMessages.count
                            unreadMessages += contact.unreadMessagesCount
                        } else if let group = chatViewModel.group {
                            //            unreadMessages += group.unreadMessages.count
                            unreadMessages += group.unreadMessagesCount
                        }
                    }
                }
                AppUtility.setAppBadgeNumber(unreadMessages)
            }
        }
    }
    
    // MARK: - Chat items
    
    func getChatCellViewModel(for contact: BBContact) -> ChatCellViewModel? {
        for chatItem in chatItems {
            if let chatItemViewModel = chatItem.getChatItemViewModel(), let chatContact = chatItemViewModel.contact, chatContact.registeredNumber == contact.registeredNumber {
                return chatItemViewModel
            }
        }
        return nil
    }
    
    func getGroupChatCellViewModel(for group: BBGroup) -> ChatCellViewModel? {
        for chatItem in chatItems {
            if let chatItemViewModel = chatItem.getChatItemViewModel(), let chatGroup = chatItemViewModel.group, chatGroup.ID == group.ID {
                return chatItemViewModel
            }
        }
        return nil
    }
    
    func sortChatItems() {
        var sortedChatItems: [ChatItems] = []
        if self.chatItems[0] == .Archive {
            sortedChatItems.append(.Archive)
        }
        
        var chats = self.chatItems.reduce(into: [ChatItems]()) {
            if $1.getChatItemViewModel() != nil {
                $0.append($1)
            }
        }
        chats.sort { (c1, c2) -> Bool in
            if let c1Vm = c1.getChatItemViewModel(), let m1 = c1Vm.lastMessage, let c2vm = c2.getChatItemViewModel(), let m2 = c2vm.lastMessage {
                return m1.dateSent > m2.dateSent
            }
            return false
        }
        
        sortedChatItems.append(contentsOf: chats)
        self.chatItems = sortedChatItems
    }
    
    func sortArchivedChatItems() {
        archivedChatItems.sort {
            if let m1 = $0.lastMessage, let m2 = $1.lastMessage {
                return m1.dateSent > m2.dateSent
            }
            return false
        }
    }
    
    /// Return a saved BBContact is exist or create a new one based on the message Number or GroupID
    /// - Parameter message: message to parse
    private func getContactFromMessage(_ message: Message) -> BBContact {
        if let contact = getContact(registeredNumber: message.buddyNumberOrGroupId) {
            contact.isSavedContact = true
            return contact
        } else if let contact  = getTemporaryContact(registeredNumber: message.buddyNumberOrGroupId) {
            return contact
        }
        
        // create a temporary the contact
        let contact = BBContact()
        contact.ID = message.contactID
        contact.name = message.buddyNumberOrGroupId
        contact.phonejsonreg = [PhoneNumber(tag: "mobile", phone: message.buddyNumberOrGroupId)]
        contact.phonesjson = [PhoneNumber(tag: "mobile", phone: message.buddyNumberOrGroupId)]
        contact.registeredNumber = message.buddyNumberOrGroupId
        contact.isSavedContact = false
        // Add it to the temporary contacts
        temporaryContacts.append(contact)
        return contact
    }
    
    /// Set the message as Received by the server
    /// - Parameter chatID: the chatD is the recipient number or the groupID
    /// - Parameter msgID:  the msgID to update
    private func setMessageReceived(_ message: Message) {
        if message.isGroupChat {
            for chat in chatItems {
                if let chatVM = chat.getChatItemViewModel(), chatVM.isGroup, chatVM.group!.ID == message.buddyNumberOrGroupId {
                    chatVM.group!.setMessageReceived(message)
                }
            }
        } else {
            for chat in chatItems {
                if let chatVM = chat.getChatItemViewModel(), let contact = chatVM.contact, contact.registeredNumber == message.buddyNumberOrGroupId {
                    contact.setMessageReceived(message)
                }
            }
        }
    }
    
    
    /// The msgID of the message that we must delete is in the message Body
    /// - Parameter message: The message received with the internal push
    private func setMessageDeletedInternalPush(_ message: Message) {
        if message.isGroupChat {
            for chat in chatItems {
                if let chatVM = chat.getChatItemViewModel(), let group = chatVM.group, group.ID == message.buddyNumberOrGroupId {
                    group.setMessageDeleted(messageID: message.body, isAutoDeleted: message.autoDelete)
                    if let lastMessage = chatVM.lastMessage, lastMessage.ID == message.body {
                        chatVM.isLastMessageDeleted = true
                    }
                }
            }
        }
        else {
            for chat in chatItems {
                if let chatVM = chat.getChatItemViewModel(), let contact = chatVM.contact, contact.registeredNumber == message.buddyNumberOrGroupId {
                    contact.setMessageDeleted(messageID: message.body, isAutoDeleted: message.autoDelete)
                    if let lastMessage = chatVM.lastMessage, lastMessage.ID == message.body {
                        chatVM.isLastMessageDeleted = true
                    }
                }
            }
        }
    }
    
    /// Set the message as Received by the server
    /// - Parameter chatID: the chatD is the recipient number or the groupID
    /// - Parameter msgID:  the msgID to update
    private func setMessageRead(_ message: Message) {
        if message.isGroupChat {
            for chat in chatItems {
                if let chatVM = chat.getChatItemViewModel(), chatVM.isGroup, chatVM.group!.ID == message.buddyNumberOrGroupId {
                    chatVM.group!.setMessageRead(message)
                }
            }
        } else {
            for chat in chatItems {
                if let chatVM = chat.getChatItemViewModel(), let contact = chatVM.contact, contact.registeredNumber == message.buddyNumberOrGroupId {
                    contact.setMessageRead(message)
                }
            }
        }
    }
    
    private func setChatContactTyping(message: Message, isTyping: Bool = true) {
        if message.type.isSystemMessage() == false {
            for chat in self.chatItems {
                if let chatCellViewModel = chat.getChatItemViewModel(), let contact = chatCellViewModel.contact, contact.registeredNumber == message.buddyNumberOrGroupId {
                    if let chatVC = self.chatViewController, let chatViewModel = chatVC.viewModel, let currChatContact = chatViewModel.contact, currChatContact.registeredNumber == contact.registeredNumber {
                        // Update the contact status to online
                        if contact.onlineStatus != .online {
                            contact.onlineStatus = .online
                        }
                    }
                    contact.isTyping.send((isTyping, nil))
                    return
                }
            }
        }
    }
    
    private func setGroupChatTyping(message: Message, isTyping: Bool = true) {
        if message.type.isSystemMessage() == false {
            for chat in self.chatItems {
                if let chatCellViewModel = chat.getChatItemViewModel(), let group = chatCellViewModel.group, group.ID == message.buddyNumberOrGroupId {
                    for member in group.members where member.registeredNumber == message.sender {
                        if let chatVC = self.chatViewController, let chatViewModel = chatVC.viewModel, let currChatGroup = chatViewModel.group, currChatGroup.ID == message.buddyNumberOrGroupId {
                            // Update the contact status to online
                            if member.onlineStatus != .online {
                                member.onlineStatus = .online
                            }
                        }
                        member.isTyping.send((isTyping, group))
                        return
                    }
                }
            }
        }
    }
}


// MARK: - Group Functions
extension Blackbox {
    
    /// Create an Empty Group Chat
    /// - Parameter description: Group Description
    func createGroupAsync(description: String, members: [BBContact], completion block: response<BBGroup>) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.groupCreate(description) else {
                loge("groupCreate unable to exectute")
                block?(nil, "Create new group unable to execute".localized())
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(CreateGroupChatResponse.self, from: jsonString.data(using: .utf8)!)
                
                if !response.isSuccess() {
                    DispatchQueue.main.async {
                        block?(nil, response.message)
                    }
                } else {
                    let group = BBGroup(id: response.groupID, description: description, role: .creator, members: members)
                    
                    // Add group members
                    for member in members {
                        group.addMemberAsync(contact: member) { (result) in
                            if result == false {
                                group.deleteGroupAsync(completion: nil)
                                block?(nil, "Something went wrong while creating the Group. Please try again.")
                            }
                        }
                    }
                    
                    // Add the group to the chat list
                    let chatItem = ChatItems.Chat(ChatCellViewModel(with: group, lastMessage: nil))
                    strongSelf.chatItems.insert(chatItem, at: 1)
                    
                    DispatchQueue.main.async {
                        block?(group, nil)
                    }
                }
            } catch {
                loge(error)
            }
        }
    }
    
}
