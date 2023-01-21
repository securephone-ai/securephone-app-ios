import Foundation
import Combine
import DifferenceKit
import BlackboxCore

enum GroupRole: String {
    case creator = "creator"
    case administrator = "administrator"
    case normal = "normal"
    
    func getName() -> String {
        switch self {
        case .administrator:
            return "admin".localized()
        case .creator:
            return "creator".localized()
        case .normal:
            return "default".localized()
        }
    }
}

/// This Object represent a Group Chat and it is a wrapper around every GroupChat property and method
class BBGroup: BBChat, Decodable {
    
    private let sendMessagesSerialQueue = DispatchQueue(label: "sendMessagesSerialQueue")
    private let fetchReadReceiptsSerialQueue: DispatchQueue
    
    
    
    // Server response fields
    var ID: String
    @Published var description: String
    @Published var role: GroupRole = .normal
    @Published var expiryDate: Date?
    
    // Group properties
    @Published var members: [BBContact]
    @Published var profileImagePath: String?
    
    private enum CodingKeys : String, CodingKey {
        case ID = "id"
        case description
        case role
        case members
        case groupImagePath = "groupphoto"
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.ID = (try? container.decode(String.self, forKey: .ID)) ?? ""
        self.description = (try? container.decode(String.self, forKey: .description)) ?? ""
        let roleString = (try? container.decode(String.self, forKey: .role)) ?? ""
        if roleString == "administrator" {
            self.role = .administrator
        }
        else if roleString == "creator" {
            self.role = .creator
        }
        else {
            self.role = .normal
        }
        self.members = (try? container.decode([BBContact].self, forKey: .members)) ?? [BBContact]()
        self.profileImagePath = (try? container.decode(String.self, forKey: .groupImagePath)) ?? ""
        
        self.fetchReadReceiptsSerialQueue = DispatchQueue(label: "\(self.ID)_fetchReadReceiptsSerialQueue")
    }
    
    init(id: String, description: String, role: GroupRole, members: [BBContact], imagePath: String = "") {
        self.ID = id
        self.description = description
        self.role = role
        self.members = members
        self.profileImagePath = imagePath
        
        self.fetchReadReceiptsSerialQueue = DispatchQueue(label: "\(self.ID)_fetchReadReceiptsSerialQueue")
    }
    
    deinit {
        //    logi("Group with ID: \(ID) deinitialized")
    }
}

extension BBGroup: Differentiable {
    var differenceIdentifier: String {
        return ID
    }
    
    func isContentEqual(to source: BBGroup) -> Bool {
        ID == source.ID && description == source.description && role == source.role && members == source.members
    }
}

// MARK: Group Manager Function
extension BBGroup {
    
    /// Fetch the Group profile image on a backgroun thread and Update the @Publisher profilePhotoPath property
    /// - Parameters:
    ///   - fileName: the fileName of the image
    func fetchProfileImageAsync(fileName: String) {
        guard fileName.isEmpty == false else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.getPhoto(fileName) else {
                loge("BlackboxCore.getPhoto unable to exectute")
                return
            }
            logPrettyJsonString(jsonString)
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SendFileMessageReponse.self, from: jsonString.data(using: .utf8)!)
                
                if response.isSuccess(), strongSelf.profileImagePath != response.localFilename {
                    strongSelf.profileImagePath = response.localFilename
                }
            } catch {
                loge(error)
            }
        }
    }

    /// Update the Group profile image on a background thread
    /// - Parameters:
    ///   - image: The new image to use
    ///   - block: completion block --> return true if success, otherwise return false.
    func updateProfileImageAsync(imageUrl: URL, completion block: ((Bool) -> Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else {
                block?(false)
                return
            }
            
            if FileManager.default.fileExists(atPath: imageUrl.path) == false {
                block?(false)
                loge("file does not exist")
                return
            }
            
            do {
                
                guard let jsonString = BlackboxCore.groupSetProfilePhoto(strongSelf.ID, filePath: imageUrl.path) else {
                    loge("BlackboxCore.groupSetProfilePhoto unable to execute")
                    block?(false)
                    return
                }
                logPrettyJsonString(jsonString)
                
                let response = try JSONDecoder().decode(SendFileMessageReponse.self, from: jsonString.data(using: .utf8)!)
                DispatchQueue.main.async {
                    if !response.isSuccess() {
                        block?(false)
                    } else {
                        strongSelf.profileImagePath = response.localFilename
                        block?(true)
                    }
                }
                
                // Delete the image
                try FileManager.default.removeItem(at: imageUrl)
                
            } catch {
                block?(false)
                loge(error)
            }
        }
    }
    
    /// Update the Group members list on a background thread
    func updateMembersListAsync() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.groupGetMembers(strongSelf.ID) else {
                loge("Unable to execute")
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(FetchGroupMembersResponse.self, from: jsonString.data(using: .utf8)!)
                
                if response.isSuccess() {
                    let blackbox = Blackbox.shared
                    var members = [BBContact]()
                    for member in response.members {
                        if member.mobileNumber == blackbox.account.registeredNumber {
                            // This is our account, Update our Role
                            strongSelf.role = member.role
                        }
                        
                        
                        if let contact = blackbox.getContact(registeredNumber: member.mobileNumber) {
                            contact.groups[strongSelf.ID] = member.role
                            members.append(contact)
                        }
                        else if let contact = blackbox.getTemporaryContact(registeredNumber: member.mobileNumber) {
                            contact.groups[strongSelf.ID] = member.role
                            members.append(contact)
                        }
                        else {
                            let contact = BBContact()
                            contact.registeredNumber = member.mobileNumber
                            contact.name = member.name
                            contact.surname = member.surname
                            contact.groups[strongSelf.ID] = member.role
                            blackbox.temporaryContacts.append(contact)
                            members.append(contact)
                        }
                    }
                    
                    // Save he member into the chatlist group item.
                    let changeset = StagedChangeset(source: strongSelf.members, target: members)
                    
                    if !changeset.isEmpty {
                        strongSelf.members = members
                    }
                }
            } catch {
                loge(error)
            }
        }
    }
    
    /// Add a new Contact to the group on a background thread
    /// - Parameters:
    ///   - contact: The contact to add
    ///   - block: completion block --> return true if success, otherwise return false.
    func addMemberAsync(contact: BBContact, completion block: ((Bool)->Void)? = nil) {
        if contact.registeredNumber.isEmpty {
            block?(false)
        } else {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let strongSelf = self,
                      let jsonString = BlackboxCore.groupAddContact(strongSelf.ID, contactNumber: contact.registeredNumber) else {
                    loge("unable to execute")
                    block?(false)
                    return
                }
                logPrettyJsonString(jsonString)
                
                do {
                    let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                    if response.isSuccess() {
                        strongSelf.members.append(contact)
                        block?(true)
                    } else {
                        loge(response.message)
                        block?(false)
                    }
                } catch {
                    loge(error)
                }
            }
        }
    }
    
    /// Add an array of Contacts to the Group on a backgroun thread
    /// - Parameters:
    ///   - contacts: The array of contacts to add
    ///   - block: completion block --> return true if success, otherwise return false.
    func addMembersAsync(contacts: [BBContact], completion block: ((Bool)->Void)? = nil) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            
            if let pwdConf = Blackbox.shared.getPwdConf() {
                let pwdConfPtr = pwdConf.toMutablePointer()
                let idPtr = strongSelf.ID.toMutablePointer()
                defer {
                    pwdConfPtr?.deallocate()
                    idPtr?.deallocate()
                }
                
                var successCount = 0
                let decoder = JSONDecoder()
                for contact in contacts where contact.registeredNumber.isEmpty == false {
                    guard let jsonString = BlackboxCore.groupAddContact(strongSelf.ID, contactNumber: contact.registeredNumber) else {
                        loge("unable to add contact \(contact.completeName)")
                        block?(false)
                        return
                    }
                    logPrettyJsonString(jsonString)
                    do {
                        let response = try decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                        if response.isSuccess() {
                            successCount += 1
                            strongSelf.members.append(contact)
                        } else {
                            loge(response.message)
                        }
                    } catch {
                        loge(error)
                    }
                }
                
                if successCount == contacts.count {
                    block?(true)
                } else {
                    block?(false)
                }
                
            } else {
                block?(false)
            }
        }
    }
    
    /// Remove a contact from the Group on a Background Thread
    /// - Parameters:
    ///   - contact: The contact to remove
    ///   - block: completion block --> return true if success, otherwise return false.
    func removeMemberAsync(contact: BBContact, completion block: ((Bool)->Void)?) {
        
        if Blackbox.shared.isNetworkReachable == false {
            block?(false)
            return
        }
        
        if contact.registeredNumber.isEmpty {
            block?(false)
        }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.groupRemoveContact(strongSelf.ID, contactNumber: contact.registeredNumber) else {
                loge("Unable to remove contact \(contact.completeName) grom the group")
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    strongSelf.members = strongSelf.members.filter { $0.registeredNumber != contact.registeredNumber }
                    block?(true)
                } else {
                    block?(false)
                    loge(response.message)
                }
            } catch {
                loge(error)
                block?(false)
            }
        }
    }
    
    /// Update the Group description on a background thread
    /// - Parameters:
    ///   - description: New group description string
    ///   - block: completion block --> return true if success, otherwise return false.
    func updateDescriptionAsync(description: String, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.groupSetDescription(strongSelf.ID, description: description) else {
                loge("unable to execute")
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                DispatchQueue.main.async {
                    if response.isSuccess() {
                        strongSelf.description = description
                        block?(true)
                    } else {
                        loge(response.message)
                        block?(false)
                    }
                }
            } catch {
                loge(error)
                block?(false)
            }
        }
    }
    
    /// Change the role of a Contact on a background thread. (only if the caller is an admin or creator)
    /// - Parameters:
    ///   - contact: The Contact
    ///   - role: the new Role
    ///   - block: completion block --> return true if success, otherwise return false.
    func changeMemberRoleAsync(contact: BBContact, role: GroupRole, completion block: ((Bool)->Void)?) {
        guard self.role != .normal else {
            block?(false)
            return
        }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.groupChangeRole(strongSelf.ID, contactNumber: contact.registeredNumber, role: role.rawValue) else {
                loge("unable to change \(contact.name) role")
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    contact.groups[strongSelf.ID] = role
                    block?(true)
                } else {
                    block?(false)
                }
            } catch {
                loge(error)
                block?(false)
            }
        }
    }
    
    /// Delete a group on a background thread
    /// - Parameter block: completion block --> return true if success, otherwise return false.
    func deleteGroupAsync(completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.groupDestroy(strongSelf.ID) else {
                loge("unable to delete the group")
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if !response.isSuccess() {
                    loge(response.message)
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
    
    /// Fetch the receipt of each contact of the group for a specific message on a background thread
    /// - Parameters:
    ///   - message: The message
    ///   - block: completion block --> return the array of receipts
    func fetchReadReceiptsAsync(message: Message, completion block: (([MessageReceipt]?)->Void)?) {
        fetchReadReceiptsSerialQueue.async {
            guard let jsonString = BlackboxCore.groupGetMessageReadReceipts(message.ID) else {
                loge("unable to execute")
                block?(nil)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(FetchReadReceiptsResponse.self, from: jsonString.data(using: .utf8)!)
                DispatchQueue.main.async {
                    if response.isSuccess() {
                        block?(response.receipts)
                    } else {
                        block?(nil)
                    }
                }
            } catch {
                loge(error)
            }
        }
    }
    
    
    /// Remove the group from the Chat List & Archived Chat list
    func removeGroupFromChats() {
        Blackbox.shared.chatItems.removeAll { (item) -> Bool in
            if let chatCellViewModel = item.getChatItemViewModel(), let group = chatCellViewModel.group, group.ID == ID {
                return true
            }
            return false
        }
        Blackbox.shared.archivedChatItems.removeAll { (item) -> Bool in
            if let group = item.group, group.ID == ID {
                return true
            }
            return false
        }
    }
    
    /// Set the group expiry date on a background thread
    /// - Parameters:
    ///   - expiryDate: the expiry date
    ///   - block: completion block --> return true if success, otherwise return false.
    func setGroupExpiryDate(expiryDate: Date?, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else {
                block?(false)
                return
            }
            // Convert to UTC time
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            var dateStr = "0000-00-00 00:00:00"
            if expiryDate != nil {
                dateStr = formatter.string(from: expiryDate!)
            }
            
            guard let jsonString = BlackboxCore.groupSetExpiryDate(strongSelf.ID, date: dateStr) else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    strongSelf.expiryDate = expiryDate
                    block?(true)
                } else {
                    strongSelf.expiryDate = nil
                    block?(false)
                }
            } catch {
                block?(false)
                loge(error)
            }
            
            
        }
    }
    
}


// MARK: -  Utility Functions
extension BBGroup {
    
    /// Return the members name, separated by a comma
    /// - Returns: Comma separated names
    func getMembersName() -> String {
        var names = ""
        for (index, member) in members.enumerated() {
            let name = member.getName()
            if index == 0 {
                names = name
            } else {
                names = "\(names), \(name)"
            }
        }
        return names
    }
    
}

// MARK: Send Messages
extension BBGroup {
    
    /// Send a text message on a background Thread
    /// - Parameters:
    ///   - message: The message to send
    ///   - appendMessageToTable: Flag used to append the message to the TableView
    ///   - block: completion block --> Return an error string if unsuccessful
    func sendMessageAsync(_ message: Message, appendMessageToTable: Bool = true, completion block: errorResponse<String>) {
        BBChat.unarchiveGroupChatIfNeeded(group: self)
        
        message.groupID = self.ID
        if appendMessageToTable {
            appendMessage(message, contact: getGroupMember(message: message), group: self)
        }
        sendMessagesSerialQueue.async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.groupSendTextMessage(strongSelf.ID, body: message.body, replyToMessageId: message.replyToMsgID, replyBody: message.replyToText) else {
                loge("groupSendTextMessage unable to exectute")
                block?("Send text message in group unable to execute".localized())
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(SendTextMessageResponse.self, from: jsonString.data(using: .utf8)!)
                
                if !response.isSuccess() {
                    block?(response.message)
                } else {
                    message.deliveredToServer = true
                    message.ID = response.msgid
                    message.msgRef = response.msgref
                    message.autoDelete = response.autoDelete
                    strongSelf.refreshChatList(message: message)
                    block?(nil)
                }
            } catch {
                loge(error)
            }

        }
        
    }
    
    /// Send a file, with text if not empty, on a background thread
    /// - Parameters:
    ///   - message: The message
    ///   - appendMessageToTable: Flag used to append the message to the TableView
    ///   - block: completion block --> Return an error string if unsuccessful
    func sendFileAsync(_ message: Message, appendMessageToTable: Bool = true, completion block: errorResponse<String>) {
        BBChat.unarchiveGroupChatIfNeeded(group: self)
        
        message.groupID = self.ID
        if appendMessageToTable {
            appendMessage(message, contact: getGroupMember(message: message), group: self)
        }
        
        sendMessagesSerialQueue.async { [weak self] in
            guard let strongSelf = self,
                  let pwdConf = Blackbox.shared.getPwdConf(),
                  let filePath = message.originalFilePath != nil ? message.originalFilePath : message.localFilename,
                  let jsonString = BlackboxCore.groupSendFileMessage(strongSelf.ID, filePath: filePath, body: message.body, replyToMessageId: message.replyToMsgID, replyBody: message.replyToText) else {
                loge("groupSendFileMessage unable to execute")
                block?("Send file in a group unable to execute".localized())
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(SendFileMessageReponse.self, from: jsonString.data(using: .utf8)!)
                
                if !response.isSuccess() {
                    block?(response.message)
                } else {
                    message.deliveredToServer = true
                    message.ID = response.msgid
                    message.filename = response.filename
                    message.localFilename = response.localFilename
                    message.fileSize = AppUtility.getFileSize(response.localFilename)
                    message.msgRef = response.msgref
                    message.autoDelete = response.autoDelete
                    message.originalFilePath = nil
                    
                    strongSelf.refreshChatList(message: message)
                    block?(nil)
                }
                
            } catch {
                loge(error)
            }
            
        }
    }
    
    /// Send the location on a background thread
    /// - Parameters:
    ///   - message: The message
    ///   - appendMessageToTable: Flag used to append the message to the TableView
    ///   - block: completion block --> Return an error string if unsuccessful
    func sendLocationAsync(_ message: Message, appendMessageToTable: Bool = true, completion block: errorResponse<String>) {
        BBChat.unarchiveGroupChatIfNeeded(group: self)
        
        message.groupID = self.ID
        if appendMessageToTable {
            appendMessage(message, contact: getGroupMember(message: message), group: self)
        }
        
        sendMessagesSerialQueue.async { [weak self] in
            guard  let strongSelf = self,
                   let jsonString = BlackboxCore.groupSendLocationMessage(strongSelf.ID,
                                                                         latitude: String(message.body.split(separator: ",")[0]),
                                                                         longitude: String(message.body.split(separator: ",")[1]),
                                                                         replyToMessageId: message.replyToMsgID,
                                                                         replyBody: message.replyToText) else {
                loge("groupSendLocationMessage unable to exectute")
                block?("Send location in group unable to execute".localized())
                return
            }
            logPrettyJsonString(jsonString)
            do {
                let response = try JSONDecoder().decode(SendTextMessageResponse.self, from: jsonString.data(using: .utf8)!)
                
                if !response.isSuccess() {
                    block?(response.message)
                } else {
                    message.deliveredToServer = true
                    message.ID = response.msgid
                    message.msgRef = response.msgref
                    message.autoDelete = response.autoDelete
                    strongSelf.refreshChatList(message: message)
                    block?(nil)
                }
            } catch {
                loge(error)
            }
        }
    }
    
    /// Send the Typing notification
    func sendTypingAsync() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.groupSendTyping(strongSelf.ID) else { return }
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if !response.isSuccess() {
                    loge(response.message)
                }
            } catch {
                loge(error)
            }
        }
    }
    
    
    /// Delete the Chat on a background thread
    /// - Parameter block: completion block --> return true if success, otherwise return false.
    func clearChatAsync(completion block:((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.groupClearChat(strongSelf.ID) else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    strongSelf.messagesSections.removeAll()
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
    
}


extension BBGroup {
    
    /// Get the member of a group from a message object
    /// - Parameter message: The message
    /// - Returns: Return the Member of a Group based on the Message
    func getGroupMember(message: Message) -> BBContact {
        //    for contact in members where !contact.ID.isEmpty && contact.ID != "0" {
        for contact in members where contact.registeredNumber == message.sender {
            return contact
        }
        // generate a contact based on the message info
        let contactNumber = PhoneNumber(tag: "mobile", phone: message.sender)
        return BBContact(id: message.contactID, name: message.contactName, phones: [contactNumber], phonejsonreg: [contactNumber])
    }
    
    /// Return the contact based on the registered Number
    /// - Parameter registeredNumber: The registere Number of the contact
    /// - Returns: Return the contact based on the registered Number
    func getGroupMember(registeredNumber: String) -> BBContact? {
        for contact in members where contact.registeredNumber == registeredNumber {
            return contact
        }
        // generate a contact based on the message info
        return nil
    }
    
}




