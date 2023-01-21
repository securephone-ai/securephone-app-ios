import Foundation
import UIKit
import DifferenceKit
import Combine
import BlackboxCore

enum ContactStatus: Equatable {
    case online
    case offline
    case lastSeen(String)
    
    public static func == (lhs: ContactStatus, rhs:ContactStatus) -> Bool {
        switch (lhs,rhs) {
        case (.online, .online):
            return true
        case (.offline, .offline):
            return true
        case (.lastSeen, .lastSeen):
            return true
        default:
            return false
        }
    }
}

class CurrentCallInfo {
    @Published var callStatus: CallStatus = .none {
        didSet {
            //      if callStatus == .answered || callStatus == .answeredAudioOnly || callStatus == .active {
            //        if callStartDate == nil {
            //          callStartDate = Date()
            //        }
            //      }
            if callStatus == .none || callStatus == .hangup || callStatus == .ended {
                isAudioReceiveStarted = false
            }
        }
    }
    var isAudioReceiveStarted: Bool = false
    var callID: String?
    var callSession: Int?
}


/// This Object represent a Contact and it is a wrapper around every Contact property and method
class BBContact: BBChat, Codable, Equatable, Differentiable {
    
    private let sendMessagesSerialQueue = DispatchQueue(label: "sendMessagesSerialQueue")
    
    var ID: String
    var mobileNumber: String?
    var prefix: String
    var name: String
    var middlename: String
    var surname: String
    var suffix: String
    var nickname: String
    var maidenname: String
    var phoneticname: String
    var phoneticmiddlename: String
    var phoneticsurname: String
    
    /// The Chat List item will always use the first element of this array as the Chat Recipient number
    var phonejsonreg: [PhoneNumber] = []
    var phonesjson: [PhoneNumber] = []
    var emailsjson: [Email] = []
    var addressesjson: [Address] = []
    var companyname: String
    var phoneticcompanyname: String
    var jobtitle: String
    var department: String
    var urlsjson: [ContactUrl] = []
    var birthday: String
    var datesjson: [ContactDate] = []
    var socialprofilesjson: [SocialProfile] = []
    var instantmessagesjson: [InstantMessage] = []
    var note: String
    
    var registeredNumber: String = ""
    var isSavedContact: Bool = false
    
    
    // MARK: - @Published properties
    // List of groups and roles this contacts belongs
    @Published var groups: [String: GroupRole] = [String : GroupRole]()
    @Published var profilePhotoPath: String?
    @Published var onlineStatus: ContactStatus = .offline {
        didSet {
            if onlineStatus == .offline {
                self.lastSeen = self.onlineVisibility ? Date() : nil
            }
        }
    }
    @Published var statusMessage: String = ""
    
    let isTyping = PassthroughSubject<(isTyping: Bool, group: BBGroup?), Never>()
    
    let initialMessagesFetched = PassthroughSubject<[MessagesSection], Never>()
    
    // MARK: - Call
    var callInfo: CurrentCallInfo = CurrentCallInfo()
    
    private var onlineVisibility: Bool = true
    private var lastSeen: Date? {
        didSet {
            if let date = lastSeen, onlineStatus != .online {
                if date.isInToday {
                    self.onlineStatus = .lastSeen("\("Last seen".localized().lowercased()) \("Today".localized().lowercased()) at \(date.timeString12Hour())")
                } else if date.isInYesterday {
                    self.onlineStatus = .lastSeen("\("Last seen".localized().lowercased()) \("Yesterday".localized().lowercased()) at \(date.timeString12Hour())")
                } else if date.isInCurrentWeek {
                    self.onlineStatus = .lastSeen("\("Last seen".localized().lowercased()) \(date.dayName())")
                } else if date.isInCurrentYear {
                    let dateString = Blackbox.shared.account.settings.calendar == .gregorian ? date.string(withFormat: "E, MMM d") : date.dateStringIslamic(withFormat: "E, MMM d")
                    self.onlineStatus = .lastSeen("\("Last seen".localized().lowercased()) \(dateString)")
                } else {
                    let dateString = Blackbox.shared.account.settings.calendar == .gregorian ? date.string(withFormat: "dd/MM/yyyy") : date.dateStringIslamic(withFormat: "dd/MM/yyyy")
                    self.onlineStatus = .lastSeen("\("Last seen".localized().lowercased()) \(date.string(withFormat: dateString))")
                }
            }
        }
    }
    
    public lazy var color: UIColor = {
        let randomColor = UIColor.random()
        if let darkerColor = randomColor.darker() {
            return darkerColor
        }
        return randomColor
    }()
    
    // MARK: Convert Json names
    private enum CodingKeys : String, CodingKey {
        case ID = "id"
        case mobileNumber = "mobilenumber"
        case prefix
        case name
        case middlename
        case surname
        case suffix
        case nickname
        case maidenname
        case phoneticname
        case phoneticmiddlename
        case phoneticsurname
        case phonejsonreg
        case phonesjson
        case emailsjson
        case addressesjson
        case companyname
        case phoneticcompanyname
        case jobtitle
        case department
        case urlsjson
        case birthday
        case datesjson
        case socialprofilesjson
        case instantmessagesjson
        case note
    }
    
    // MARK: Initilizer
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.ID = (try? container.decode(String.self, forKey: .ID)) ?? ""
        self.prefix = (try? container.decode(String.self, forKey: .prefix)) ?? ""
        self.mobileNumber = (try? container.decode(String.self, forKey: .mobileNumber)) ?? nil
        self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
        self.middlename = (try? container.decode(String.self, forKey: .middlename)) ?? ""
        self.surname = (try? container.decode(String.self, forKey: .surname)) ?? ""
        self.suffix = (try? container.decode(String.self, forKey: .suffix)) ?? ""
        self.nickname = (try? container.decode(String.self, forKey: .nickname)) ?? ""
        self.maidenname = (try? container.decode(String.self, forKey: .maidenname)) ?? ""
        self.phoneticname = (try? container.decode(String.self, forKey: .phoneticname)) ?? ""
        self.phoneticmiddlename = (try? container.decode(String.self, forKey: .phoneticmiddlename)) ?? ""
        self.phoneticsurname = (try? container.decode(String.self, forKey: .phoneticsurname)) ?? ""
        self.phonejsonreg = (try? container.decode([PhoneNumber].self, forKey: .phonejsonreg)) ?? [PhoneNumber]()
        self.phonesjson = (try? container.decode([PhoneNumber].self, forKey: .phonesjson)) ?? [PhoneNumber]()
        self.emailsjson = (try? container.decode([Email].self, forKey: .emailsjson)) ?? [Email]()
        self.addressesjson = (try? container.decode([Address].self, forKey: .addressesjson)) ?? [Address]()
        self.companyname = (try? container.decode(String.self, forKey: .companyname)) ?? ""
        self.phoneticcompanyname = (try? container.decode(String.self, forKey: .phoneticcompanyname)) ?? ""
        self.jobtitle = (try? container.decode(String.self, forKey: .jobtitle)) ?? ""
        self.department = (try? container.decode(String.self, forKey: .department)) ?? ""
        self.urlsjson = (try? container.decode([ContactUrl].self, forKey: .urlsjson)) ?? [ContactUrl]()
        let birth = (try? container.decode(String.self, forKey: .birthday)) ?? ""
        self.birthday = birth == "0000-00-00" ? "" : birth
        self.datesjson = (try? container.decode([ContactDate].self, forKey: .datesjson)) ?? [ContactDate]()
        self.socialprofilesjson = (try? container.decode([SocialProfile].self, forKey: .socialprofilesjson)) ?? [SocialProfile]()
        self.instantmessagesjson = (try? container.decode([InstantMessage].self, forKey: .instantmessagesjson)) ?? [InstantMessage]()
        self.note = (try? container.decode(String.self, forKey: .note)) ?? ""
    }
    
    init(
        id: String = "", mobileNumber: String? = nil,  prefix: String = "", name: String = "",
        phoneticname: String = "", middlename: String = "", phoneticmiddlename: String = "",
        surname: String = "", phoneticsurname: String = "", maidenname: String = "", suffix: String = "",
        nickname: String = "", jobtitle: String = "", department: String = "", companyname: String = "",
        phoneticcompanyname: String = "", birthday: String = "", phones: [PhoneNumber], phonejsonreg: [PhoneNumber] = [],
        emails: [Email] = [Email](), addresses: [Address] = [Address](), urls: [ContactUrl] = [ContactUrl](),
        dates: [ContactDate] = [ContactDate](), socialProfiles: [SocialProfile] = [SocialProfile](),
        instantMessages: [InstantMessage] = [InstantMessage]() ) {
        
        self.mobileNumber = nil
        self.prefix = prefix
        self.name = name
        self.phoneticname = phoneticname
        self.middlename = middlename
        self.phoneticmiddlename = phoneticmiddlename
        self.surname = surname
        self.phoneticsurname = phoneticsurname
        self.maidenname = maidenname
        self.suffix = suffix
        self.nickname = nickname
        self.jobtitle = jobtitle
        self.birthday = birthday
        self.department = department
        self.companyname = companyname
        self.phoneticcompanyname = phoneticcompanyname
        self.phonesjson = phones
        self.emailsjson = emails
        self.addressesjson = addresses
        self.urlsjson = urls
        self.datesjson = dates
        self.socialprofilesjson = socialProfiles
        self.instantmessagesjson = instantMessages
        self.note = ""
        self.ID = id
        self.phonejsonreg = phonejsonreg
    }
    
    override init() {
        self.mobileNumber = nil
        self.prefix = ""
        self.name = ""
        self.phoneticname = ""
        self.middlename = ""
        self.phoneticmiddlename = ""
        self.surname = ""
        self.phoneticsurname = ""
        self.maidenname = ""
        self.suffix = ""
        self.nickname = ""
        self.jobtitle = ""
        self.birthday = ""
        self.department = ""
        self.companyname = ""
        self.phoneticcompanyname = ""
        self.phonesjson = []
        self.emailsjson = []
        self.addressesjson = []
        self.urlsjson = []
        self.datesjson = []
        self.socialprofilesjson = []
        self.instantmessagesjson = []
        self.note = ""
        self.ID = ""
        self.phonejsonreg = []
    }
    
    public static func == (lhs: BBContact, rhs: BBContact) -> Bool {
        lhs.ID == rhs.ID &&
            lhs.name == rhs.name &&
            lhs.prefix == rhs.prefix &&
            lhs.middlename == rhs.middlename &&
            lhs.surname == rhs.surname &&
            lhs.suffix == rhs.suffix &&
            lhs.nickname == rhs.nickname &&
            lhs.maidenname == rhs.maidenname &&
            lhs.phoneticname == rhs.phoneticname &&
            lhs.phoneticmiddlename == rhs.phoneticmiddlename &&
            lhs.phoneticsurname == rhs.phoneticsurname &&
            lhs.phonejsonreg == rhs.phonejsonreg &&
            lhs.phonesjson == rhs.phonesjson &&
            lhs.emailsjson == rhs.emailsjson &&
            lhs.addressesjson == rhs.addressesjson &&
            lhs.companyname == rhs.companyname &&
            lhs.phoneticcompanyname == rhs.phoneticcompanyname &&
            lhs.jobtitle == rhs.jobtitle &&
            lhs.department == rhs.department &&
            lhs.urlsjson == rhs.urlsjson &&
            lhs.birthday == rhs.birthday &&
            lhs.datesjson == rhs.datesjson &&
            lhs.socialprofilesjson == rhs.socialprofilesjson &&
            lhs.instantmessagesjson == rhs.instantmessagesjson &&
            lhs.note == rhs.note
    }
    
    var differenceIdentifier: String {
        return ID
    }
    
    func isContentEqual(to source: BBContact) -> Bool {
        return self == source
    }
    
}

// MARK: Utility functions
extension BBContact {
    
    /// Return the Contact initials
    ///       firstName = Jhon, surname=Smith    ->  "JS"
    /// - Returns: Return the Contact initials
    func getInitials() -> String {
        var initials = String()
        
        if !name.isEmpty {
            initials.append(String(name.prefix(1)))
        }
        
        if !surname.isEmpty {
            initials.append(String(surname.prefix(1)))
        } else if !phoneticsurname.isEmpty {
            initials.append(String(phoneticsurname.prefix(1)))
        } else if !middlename.isEmpty {
            initials.append(String(middlename.prefix(1)))
        } else if !phoneticmiddlename.isEmpty {
            initials.append(String(phoneticmiddlename.prefix(1)))
        } else if !maidenname.isEmpty {
            initials.append(String(maidenname.prefix(1)))
        } else if !suffix.isEmpty {
            initials.append(String(suffix.prefix(1)))
        } else if !nickname.isEmpty {
            initials.append(String(nickname.prefix(1)))
        } else {
            if name.count > 1 {
                initials = (String(name.prefix(2)))
            }
        }
        
        return initials.uppercased()
    }
    
    /// Return the Contact name or the contact number if the contact name is not present
    /// - Returns: contact name
    func getName() -> String {
        if let accountNumber = Blackbox.shared.account.registeredNumber, name == accountNumber {
            return "You".localized()
        }
        if !name.isEmpty {
            return name
        }
        if !phoneticname.isEmpty {
            return phoneticname
        }
        if !registeredNumber.isEmpty {
            return registeredNumber
        }
        if phonejsonreg.count > 0 {
            return phonejsonreg[0].phone
        }
        
        return ""
    }
    
    /// name + surname.
    ///
    /// Example = ** "Jhon Smith" **
    var completeName: String {
        return "\(name) \(surname)"
    }
    
    /// Fetch the Contact profile image on a backgroun thread and Update the @Publisher profilePhotoPath property
    /// - Parameters:
    ///   - fileName: the fileName of the image
    func fetchProfileImageAsync(fileName: String) {
        guard fileName.isEmpty == false else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.contactGetPhotoFileName(strongSelf.registeredNumber) else {
                loge("BlackboxCore.contactGetPhotoFileName unable to exectute")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SendFileMessageReponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess(), !response.filename.isEmpty {
                    guard let jsonString = BlackboxCore.getPhoto(fileName) else {
                        loge("BlackboxCore.getPhoto unable to exectute")
                        return
                    }
                    
                    // logi(json)
                    let response = try decoder.decode(SendFileMessageReponse.self, from: jsonString.data(using: .utf8)!)
                    
                    DispatchQueue.main.async {
                        if response.isSuccess(), strongSelf.profilePhotoPath != response.localFilename {
                            strongSelf.profilePhotoPath = response.localFilename
                        }
                    }
                }
            } catch {
                loge(error)
            }
            
        }
    }
    
    
    /// Update the Contact profile status on a background thread and Update the @Publisher onlineStatus property
    func updateProfileStatusAsync() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self ,
                  let jsonString = BlackboxCore.getProfileInfo(strongSelf.registeredNumber) else {
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try Blackbox.shared.decoder.decode(FetchAccountInfoResponse.self, from: jsonString.data(using: .utf8)!)
                if response.onlineStatus == .online {
                    strongSelf.onlineStatus = .online
                } else {
                    if strongSelf.onlineStatus != .offline {
                        strongSelf.onlineStatus = .offline
                    }
                }
                strongSelf.onlineVisibility = response.onlineVisibility
                
                strongSelf.lastSeen = strongSelf.onlineVisibility ? response.lastSeen : nil
                strongSelf.statusMessage = response.statusMessage
                
                if response.isSuccess() {
                } else {
                    loge(response.message)
                }
                
            } catch {
                loge(error)
            }
        }
    }
    
}

// MARK: Send Messages
extension BBContact {
    
    /// Send a text message on a background Thread
    /// - Parameters:
    ///   - message: The message to send
    ///   - appendMessageToTable: Flag used to append the message to the TableView
    ///   - block: completion block --> Return an error string if unsuccessful
    func sendMessageAsync(_ message: Message, appendMessageToTable: Bool = true, completion block: errorResponse<String>) {
        BBChat.unarchiveChatIfNeeded(contact: self)
        if appendMessageToTable {
            appendMessage(message, contact: self)
        }
        if !self.registeredNumber.isEmpty {
            sendMessagesSerialQueue.async { [weak self] in
                guard let strongSelf = self,
                      let jsonString = BlackboxCore.contactSendTextMessage(strongSelf.registeredNumber, body: message.body, replyToMessageId: message.replyToMsgID, replyBody: message.replyToText) else {
                    loge("BlackboxCore.contactSendTextMessage unable to exectute")
                    block?("Sent text message to contact unable to execute".localized())
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
    }
    
    /// Send a file, with text if not empty, on a background thread
    /// - Parameters:
    ///   - message: The message
    ///   - appendMessageToTable: Flag used to append the message to the TableView
    ///   - block: completion block --> Return an error string if unsuccessful
    func sendFileAsync(_ message: Message, appendMessageToTable: Bool = true, completion block: errorResponse<String>) {
        BBChat.unarchiveChatIfNeeded(contact: self)
        if appendMessageToTable {
            appendMessage(message, contact: self)
        }
        if !self.registeredNumber.isEmpty {
            sendMessagesSerialQueue.async { [weak self] in
                guard let strongSelf = self,
                      let filePath = message.originalFilePath,
                      let jsonString = BlackboxCore.contactSendFileMessage(strongSelf.registeredNumber,
                                                                           filePath: filePath,
                                                                           body: message.body,
                                                                           replyToMessageId: message.replyToMsgID,
                                                                           replyBody: message.replyToText) else {
                    loge("BlackboxCore.contactSendFileMessage unable to exectute")
                    block?("Sent file message to contact unable to execute".localized())
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
    }
    
    /// Send the location on a background thread
    /// - Parameters:
    ///   - message: The message
    ///   - appendMessageToTable: Flag used to append the message to the TableView
    ///   - block: completion block --> Return an error string if unsuccessful
    func sendLocationAsync(_ message: Message, appendMessageToTable: Bool = true, completion block: errorResponse<String>) {
        BBChat.unarchiveChatIfNeeded(contact: self)
        if appendMessageToTable {
            appendMessage(message, contact: self)
        }
        if !self.registeredNumber.isEmpty {
            sendMessagesSerialQueue.async { [weak self] in
                guard let strongSelf = self,
                      let jsonString = BlackboxCore.contactSendLocation(strongSelf.registeredNumber,
                                                                        latitude: String(message.body.split(separator: ",")[0]),
                                                                        longitude: String(message.body.split(separator: ",")[1]),
                                                                        replyToMessageId: message.replyToMsgID,
                                                                        replyBody: message.replyToText) else {
                    loge("BlackboxCore.contactSendLocation unable to exectute")
                    block?("Send location unable to execute")
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
    }
    
    /// Send the Typing notification
    func sendTypingAsync() {
        DispatchQueue.global(qos: .background).async { [self] in
            guard let jsonString = BlackboxCore.contactSendTyping(registeredNumber) else {
                return
            }
            //      logPrettyJsonString(jsonString)
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
                  let jsonString = BlackboxCore.contactClearChat(strongSelf.registeredNumber) else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try Blackbox.shared.decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
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

