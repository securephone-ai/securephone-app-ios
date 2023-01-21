import Foundation
import UIKit
import CoreFoundation
import MobileCoreServices
import Combine
import DifferenceKit
import BlackboxCore


enum CheckmarkType {
  case none
  case unSent
  case sent
  case received
  case read
}

enum DocumentType {
  case pdf
  case generic
  case text
  case microsoftWord
  case microsoftExcel
  case microsoftPowerPoint
  case applePages
  case appleNumbers
  case appleKeynote
}

enum SystemMessageType {
  case normal
  case autoDelete
  case missedCall
  case missedVideoCall
  case temporaryChat
  case groupContactRemoved
  case groupNameChanged
}

enum MessageType: Equatable {
  case status
  case audio
  case contact
  case document(DocumentType)
  case location
  case photo
  case video
  case text // text
//  case systemMessage // system messages
//  case systemMessageAutoDelete // system messages
  case systemMessage(SystemMessageType)
  case received // received receipt
  case read // received receipt
  case typing // received when someone start to type a message for you
  case deleted
  
  // Alert Messages
  case alertCopy
  case alertForward
  case alertDelete
  case alertScreenshot
  case alertScreenRecording
  
  // Unread Messages count row
  case unreadMessages
  
  
  public static func == (lhs: MessageType, rhs:MessageType) -> Bool {
    switch (lhs,rhs) {
    case (.status, .status):
      return true
    case (.audio, .audio):
      return true
    case (.contact, .contact):
      return true
    case (.document(_), .document(_)):
      return true
    case (.location, .location):
      return true
    case (.photo, .photo):
      return true
    case (.video, .video):
      return true
    case (.text, .text):
      return true
//    case (.systemMessage, .systemMessage):
//      return true
//    case (.systemMessageAutoDelete, .systemMessageAutoDelete):
//      return true
    case (.systemMessage(_), .systemMessage(_)):
      return true
    case (.received, .received):
      return true
    case (.read, .read):
      return true
    case (.typing, .typing):
      return true
    case (.deleted, .deleted):
      return true
    case (.alertCopy, .alertCopy):
      return true
    case (.alertForward, .alertForward):
      return true
    case (.alertDelete, .alertDelete):
      return true
    case (.alertScreenshot, .alertScreenshot):
      return true
    case (.alertScreenRecording, .alertScreenRecording):
      return true
    case (.unreadMessages, .unreadMessages):
      return true
    default:
      return false
    }
  }
  
  func isDocument() -> Bool {
    switch self {
    case .document(_):
      return true
    default:
      return false
    }
  }
  
  func isSystemMessage() -> Bool {
    switch self {
    case .systemMessage(_):
      return true
    default:
      return false
    }
  }
  
  func isSystemMessageAutoDelete() -> Bool {
    switch self {
    case .systemMessage(let type):
      return type == .autoDelete
    default:
      return false
    }
  }
  
}

enum MessageStatus {
  case incoming
  case outgoing
  case none
}

/// Represent the Message JSON 
class Message: BBResponse, Differentiable {
  
  /// Is the uniqueid of the message
  var ID: String
  let answer: String
  let message: String
  let mobileNumber: String
  
  /// Message Reference string, used in group messages
  var msgRef: String?
  var deliveredToServer: Bool {
    didSet {
      if deliveredToServer {
        checkmarkType = .sent
      }
    }
  }
  
  /// Is the phone number of the sender
  var sender: String
  
  /// Is the phone number of the recipient
  var recipient: String
  
  /// Is the text message
  var body: String
  
  var attributedText: NSAttributedString {
    return body.attributedForChat
  }
  
  // the replied Message ID
  var replyToMsgID: String
  // the replied Message Text to parse
  var replyToText: String
  
  // The following 2 only if the API Request is fetchChatList
  let contactID: String
  let contactName: String
  
  /// Is the id of the group chat, empty for one-to-one messages
  var groupID: String
  let groupDescription: String
  
  /// Is the date and time in UTC time of sending from sender to recipient
  var dateSent: Date
  
  /// Is the date and time in UTC of message received.
  var dateReceived: Date? {
    didSet {
      guard checkmarkType != .read else { return }
      checkmarkType = body.isEmpty && type == .text ? .none : .received
    }
  }
  
  /// Is the date and time in UTC of message received.
  var dateRead: Date? {
    didSet {
      checkmarkType = body.isEmpty && type == .text ? .none : .read
    }
  }
  
  /// If this message is deleted
  var dateDeleted: Date? {
    didSet {
      type = .deleted
    }
  }
  @Published var autoDelete: Bool = false
  
  /// Is the number of new message in the queue waiting for reading
  let queue: UInt
  
  // The following three will be present only if the type is equal to "file"
  
  // original file path used for upload
  var originalFilePath: String?
  
  /// Is the unique file name identifier in the platform
  var filename: String
  var fileKey: String
  
  /// Is  s the original file name as named from the sender
  var originFilename: String
  
  var fileSize: UInt64 = 0
  
  /// Only present in groups with Profile Image
  var groupPhoto: String?
  
  /// Only present if the contact has uploaded a photo
  var contactPhoto: String?
  var isForwarded: Bool = false
  var isArchived: Bool = false
  
  // Alert messages
  var alertMsgSenderRef: String?
  var alertMsgIdRef: String?
  var alertMsgTypeRef: MessageType?
  var alertMsgContentRef: String?
  var alertMsg: String?
  
  
  // MARK: - Metadata
  var chatUnreadMessagesCount: Int = 0
  var oldestUnreadMsgID: String?
  var totUnreadMsgs: Int = 0
  var groupDateExpiry: Date?
  var removedFromGroupContactNumber: String?
  @Published var autoDownload: Bool = true
  
  
  private enum CodingKeys : String, CodingKey {
    case ID = "msgid"
    case answer
    case message
    case mobileNumber = "mobilenumber"
    case sender
    case recipient
    case msgtype
    case body = "msgbody"
    case replyToMsgID = "repliedto"
    case replyToText = "repliedtotxt"
    case contactID = "contactid"
    case contactName = "contactname"
    case groupID = "groupid"
    case groupDescription = "groupdesc"
    case dateSent = "dtsent"
    case dateReceived = "dtreceived"
    case dateRead = "dtread"
    case queue = "queuemsgs"
    case filename
    case originFilename = "originfilename"
    case localFilename = "localfilename"
    case fileSize = "filesize"
    case groupPhoto = "groupphoto"
    case contactPhoto = "photoname"
    case isForwarded = "forwarded"
    case dateDeleted = "dtdeleted"
    case msgRef = "msgref"
    case isArchived = "archived"
    case isStarred = "starred"
    case autodelete
    case chatUnreadMessagesCount = "unreadmsg"
    case oldestReadMsgID = "olderunreadmsgid"
    case totUnreadMsgs = "totunreadmsg"
    case groupDateExpiry = "groupdtexpiry"
    case autoDownload = "autodownload"
    case fileKey = "keyfile"
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    var id = (try? container.decode(String.self, forKey: .ID)) ?? ""
    if id.isEmpty {
      // Try integer
      id = (try? String(container.decode(Int.self, forKey: .ID))) ?? ""
    }
    self.ID = id
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.msgRef = (try? container.decode(String.self, forKey: .msgRef)) ?? ""
    self.mobileNumber = (try? container.decode(String.self, forKey: .mobileNumber)) ?? ""
    self.sender = (try? container.decode(String.self, forKey: .sender)) ?? ""
    self.recipient = (try? container.decode(String.self, forKey: .recipient)) ?? ""
    self.msgtype = (try? container.decode(String.self, forKey: .msgtype)) ?? ""
    self.body = (try? container.decode(String.self, forKey: .body)) ?? ""
    self.replyToMsgID = (try? container.decode(String.self, forKey: .replyToMsgID)) ?? ""
    self.replyToText = (try? container.decode(String.self, forKey: .replyToText)) ?? ""
    
    self.groupID = (try? container.decode(String.self, forKey: .groupID)) ?? ""
    if self.groupID == "0" {
      self.groupID = ""
    }
    self.groupDescription = (try? container.decode(String.self, forKey: .groupDescription)) ?? ""
    
    self.contactID = (try? container.decode(String.self, forKey: .contactID)) ?? ""
    self.contactName = (try? container.decode(String.self, forKey: .contactName)) ?? ""
    
    // Dates are in UTC time
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    var dateString = (try? container.decode(String.self, forKey: .dateSent)) ?? ""
    self.dateSent = dateFormatter.date(from: dateString) ?? Date()
    
    dateString = (try? container.decode(String.self, forKey: .dateReceived)) ?? ""
    self.dateReceived = dateFormatter.date(from: dateString) ?? nil

    dateString = (try? container.decode(String.self, forKey: .dateRead)) ?? ""
    self.dateRead = dateFormatter.date(from: dateString) ?? nil
    
    dateString = (try? container.decode(String.self, forKey: .dateDeleted)) ?? ""
    if dateString == "0000-00-00 00:00:00" {
      self.dateDeleted = nil
    } else {
      self.dateDeleted = dateFormatter.date(from: dateString) ?? nil
    }
    
    // Messages Queue
    let queue = (try? UInt(container.decode(String.self, forKey: .queue))) ?? 0
    self.queue = queue
    
    // Files
    var file = (try? container.decode(String.self, forKey: .filename)) ?? ""
    self.filename = (file != "" && !file.contains(".enc")) ? file + ".enc" : ""
    self.fileKey = (try? container.decode(String.self, forKey: .fileKey)) ?? ""
    self.originFilename = (try? container.decode(String.self, forKey: .originFilename)) ?? ""
    file = (try? container.decode(String.self, forKey: .localFilename)) ?? ""
    file = (file != "" && !file.contains(".enc")) ? file + ".enc" : ""
    self.localFilename = file.replacingOccurrences(of: "\0enc", with: ".enc")
    
    // Profile Photo
    self.groupPhoto = (try? container.decode(String.self, forKey: .groupPhoto)) ?? ""
    self.contactPhoto = (try? container.decode(String.self, forKey: .contactPhoto)) ?? ""
    self.isForwarded = ((try? container.decode(String.self, forKey: .isForwarded)) ?? "0") == "1"
    self.isArchived = ((try? container.decode(String.self, forKey: .isArchived)) ?? "N") == "Y"
    self.autoDownload = ((try? container.decode(String.self, forKey: .autoDownload)) ?? "N") == "Y"
    self.isStarred = ((try? container.decode(String.self, forKey: .isStarred)) ?? "0") == "1"
    self.autoDelete = ((try? container.decode(String.self, forKey: .autodelete)) ?? "0") == "1"
    
    let fileSizeString = (try? container.decode(String.self, forKey: .fileSize)) ?? "0"
    if let fileSize = UInt64(fileSizeString)  {
      self.fileSize = fileSize
    }
    
    self.chatUnreadMessagesCount = (try? container.decode(Int.self, forKey: .chatUnreadMessagesCount)) ?? 0
    if self.chatUnreadMessagesCount == 0 {
      if let chatUnreadMessages = try? container.decode(String.self, forKey: .chatUnreadMessagesCount), let tot = Int(chatUnreadMessages) {
        self.chatUnreadMessagesCount = tot
      }
    }
    
    if let oldestReadMsgId = try? container.decode(Int.self, forKey: .oldestReadMsgID) {
      self.oldestUnreadMsgID = String(oldestReadMsgId)
    }
    
    if let totUnreadMessages = try? container.decode(String.self, forKey: .totUnreadMsgs), let tot = Int(totUnreadMessages) {
      self.totUnreadMsgs = tot
    }
    
    if let groupDateExpiry = try? container.decode(String.self, forKey: .groupDateExpiry), groupDateExpiry != "0000-00-00 00:00:00" {
      self.groupDateExpiry = dateFormatter.date(from: groupDateExpiry) ?? nil
    }
    

    // the message comes from the servers so it was 100% delivered.
    deliveredToServer = true
    // Se the correct Checkmark
    if status == .incoming || type == .text && body.isEmpty {
      checkmarkType = .none
    }
    else {
      if dateRead != nil {
        checkmarkType = .read
      }
      else if dateReceived != nil {
        checkmarkType = .received
      }
      else {
        checkmarkType = .sent
      }
    }
    
  }
  
  
  /// Initialize a new message object to send.
  /// - Parameters:
  ///   - recipient: recipient
  ///   - sender: sender
  ///   - body: body
  ///   - filePath: filePath
  ///   - type: message type
  init(recipient: String, body: String = "", filePath: String = "", type: String = "txt") {
    self.body = body
    self.dateSent = Date()
    self.dateReceived = nil
    self.dateRead = nil
    self.recipient = recipient
    self.ID = UUID().uuidString
    self.answer = ""
    self.message = ""
    self.mobileNumber = ""
    self.sender = Blackbox.shared.account.registeredNumber ?? ""
    self.msgtype = type
    self.replyToMsgID = ""
    self.replyToText = ""
    self.groupID = ""
    self.groupDescription = ""
    self.queue = 0
    self.originalFilePath = filePath
    self.filename = ""
    self.originFilename = URL(string: filePath)?.lastPathComponent ?? ""
    self.localFilename = ""
    self.contactName = ""
    self.contactID = ""
    self.groupPhoto = ""
    self.fileKey = ""
    
    // Set checkmark
    // The message object was just created so it is not delivered.
    deliveredToServer = false
    checkmarkType = .unSent
  }
  
  /// Used to copy a message
  init(body: String = "", type: String, originalFilePath: String?, filename: String, originFileName: String, localFilename: String) {
    self.recipient = ""
    self.sender = ""
    self.body = body
    self.msgtype = type
    self.originalFilePath = originalFilePath
    self.filename = filename
    self.originFilename = originFileName
    self.localFilename = localFilename
    
    self.dateSent = Date()
    self.dateReceived = nil
    self.dateRead = nil
    self.ID = UUID().uuidString
    self.answer = ""
    self.message = ""
    self.mobileNumber = ""
    self.replyToMsgID = ""
    self.replyToText = ""
    self.contactName = ""
    self.contactID = ""
    self.queue = 0
    self.groupID = ""
    self.groupDescription = ""
    self.fileKey = ""
    
    // The message object was just copied so it is not delivered.
    deliveredToServer = false
  }

  // MARK: - Combine Framework
  /// Is the filename complete of path to read the file from the local cache
  @Published var localFilename: String
  @Published var checkmarkType: CheckmarkType = .none
  @Published var fileTransferState: CGFloat = 100
  @Published var isStarred: Bool = false
  
  /// Is the type of message sent back (“txt” is for text messages, “location” for gps location, “read” for read receipt, “received” for received receipt)
  private let msgtype: String
  lazy var type: MessageType = {
    
    if dateDeleted != nil {
      if self.autoDelete {
        self.body = "This message has been self disappeared automatically".localized()
      } else {
        self.body = self.status == .outgoing ? "_\("You deleted this message".localized())_" : "_\("This message has been deleted".localized())_"
      }
      self.replyToMsgID = ""
      self.replyToText = ""
      return .deleted
    }
    
    switch msgtype {
    case "status":
      return .status
    case "location":
      return .location
    case "file":

      if self.body.contains("alert:#screenshot") {
        return .alertScreenshot
      }
      
      let filename: NSString = originFilename.count > 0 ? originFilename as NSString : self.filename as NSString
      return Message.getFileType(fileExtension: filename.pathExtension)
    case "system":
      
      // Customize the body based on the system message
       
      if self.body.contains("[AUTODELETE]") {
      
    
        self.body = self.body.replacingOccurrences(of: "[AUTODELETE]", with: "")
        
        if let firstIndex = self.body.firstIndex(of: "["), let lastIndex = self.body.lastIndex(of: "]") {
          
          let seconds = body[firstIndex...lastIndex]
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "seconds", with: "")
          
          switch seconds {
          case "3600":
            self.body = "\("Messages will self disappear after".localized()) *\("1 hour".localized())* \("from this point".localized()).\n \("Tap here to change settings.".localized())"
          case "7200":
            self.body = "\("Messages will self disappear after".localized()) *\("2 hours".localized())* \("from this point".localized()).\n \("Tap here to change settings.".localized())"
          case "86400":
            self.body = "\("Messages will self disappear after".localized()) *\("1 day".localized())* \("from this point".localized()).\n \("Tap here to change settings.".localized())"
          case "172800":
            self.body = "\("Messages will self disappear after".localized()) *\("2 days".localized())* \("from this point".localized()).\n \("Tap here to change settings.".localized())"
          case "604800":
            self.body = "\("Messages will self disappear after".localized()) *\("1 week".localized())* \("from this point".localized()).\n \("Tap here to change settings.".localized())"
          default:
            self.body = "\("Self-disappearing messages have been canceled from this point.".localized())\n \("Tap here to change settings.".localized())"
          }
        }
        
        return .systemMessage(.autoDelete)
      }
      else if body.contains("<EXPIRYDATETIME>") {

        guard let date = self.body
          .replacingOccurrences(of: "This conversation will be deleted on ", with: "")
          .replacingOccurrences(of: "<EXPIRYDATETIME>", with: "")
          .replacingOccurrences(of: "</EXPIRYDATETIME>", with: "")
          .date(withFormat: "yyyy-MM-dd HH:mm:ss", timeZone: TimeZone(abbreviation: "UTC")) else {
          return .systemMessage(.normal)
        }
        
        self.body = "\("This conversation will be deleted on:".localized())\n \(date.dateString()) at \(date.timeString(ofStyle: .short))"
        return .systemMessage(.temporaryChat)
      }
      else if self.body.contains("You have been added to Chat Group") {
        self.body = self.body.replacingOccurrences(of: "You have been added to Chat Group", with: "You have been added to Chat Group".localized())
      }
      else if self.body.contains("Your role in the Chat Group") {
        self.body = self.body.replacingOccurrences(of: "Your role in the Chat Group", with: "Your role in the Chat Group".localized())
      }
      else if self.body.contains("has been changed to administrator") {
        self.body = self.body.replacingOccurrences(of: "has been changed to administrator", with: "has been changed to administrator".localized())
      }
      else if self.body.contains("You have created this Chat Group") {
        self.body = self.body.replacingOccurrences(of: "You have created this Chat Group", with: "You have created this Chat Group".localized())
      }
      else if self.body.contains("Missed audio call") {
        self.body = "\("Missed Audio Call".localized())\n\(self.dateSent.timeString12Hour())"
        return .systemMessage(.missedCall)
      }
      else if self.body.contains("Missed video call") {
        self.body = "\("Missed Video Call".localized())\n\(self.dateSent.timeString12Hour())"
        return .systemMessage(.missedVideoCall)
      }
      else if self.body.contains("has left this Chat Group", caseSensitive: false) {
        let contactNumber = self.body.replacingOccurrences(of: "has left this Chat Group", with: "").replacingOccurrences(of: "<CONTACTNUMBER>", with: "").replacingOccurrences(of: "</CONTACTNUMBER>", with: "").replacingOccurrences(of: " ", with: "")
        
        // Replace the contact number with his name
        if let contact = Blackbox.shared.getContact(registeredNumber: contactNumber) {
          self.body = "*\(contact.getName())* \("has left this Chat Group".localized())"
        }
        else if let contact = Blackbox.shared.getTemporaryContact(registeredNumber: contactNumber) {
          self.body = "*\(contact.getName())* \("has left this Chat Group".localized())"
        }
        
        // Save the contact number as reference used when we are going to actually remove the contact from the group
        self.removedFromGroupContactNumber = contactNumber
        
        return .systemMessage(.groupContactRemoved)
      }
      else if self.body.contains("has joined this Chat Group", caseSensitive: false) {
        let contactNumber = self.body.replacingOccurrences(of: "has joined this Chat Group", with: "").replacingOccurrences(of: "<CONTACTNUMBER>", with: "").replacingOccurrences(of: "</CONTACTNUMBER>", with: "").replacingOccurrences(of: " ", with: "")
        
        // Replace the contact number with his name
        if let contact = Blackbox.shared.getContact(registeredNumber: contactNumber) {
          self.body = "*\(contact.getName())* \("has joined this Chat Group".localized())"
        }
        else if let contact = Blackbox.shared.getTemporaryContact(registeredNumber: contactNumber) {
          self.body = "*\(contact.getName())* \("has joined this Chat Group".localized())"
        }
        
        return .systemMessage(.groupContactRemoved)
      }
      else if self.body.contains("The group's name is changed to:", caseSensitive: false) {
        return .systemMessage(.groupNameChanged)
      }
      
      return .systemMessage(.normal)
      
    case "received":
      return .received
    case "read":
      return .read
    case "typing":
      return .typing
    case "deleted":
      self.replyToMsgID = ""
      self.replyToText = ""
      return .deleted
    default:
      // Check if this is an alert message.
      if self.body.contains(":#") {
        let parts = self.body.components(separatedBy: ":#").filter { !$0.isEmpty }
        if parts.isEmpty == false {
          if parts[0] == "alert" {
            if parts.count > 1 {
              switch parts[1] {
              case "copy":
                if parts.count > 5 {
                  alertMsgSenderRef = parts[2]
                  alertMsgIdRef = parts[3]
                  if let type = getMessageTypeFromAlertString(parts[4]) {
                    alertMsgTypeRef = type
                    alertMsgContentRef = parts[5]
                    return .alertCopy
                  }
                }
              case "forward":
                if parts.count > 5 {
                  alertMsgSenderRef = parts[2]
                  alertMsgIdRef = parts[3]
                  if let type = getMessageTypeFromAlertString(parts[4]) {
                    alertMsgTypeRef = type
                    alertMsgContentRef = parts[5]
                    return .alertForward
                  }
                }
              case "delete":
                if parts.count > 5 {
                  alertMsgSenderRef = parts[2]
                  alertMsgIdRef = parts[3]
                  if let type = getMessageTypeFromAlertString(parts[4]) {
                    alertMsgTypeRef = type
                    alertMsgContentRef = parts[5]
                    return .alertDelete
                  }
                }
              case "screenrecording":
                return .alertScreenRecording
              case "screenshot":
                return .alertScreenshot
              default:
                break
              }
            }
          }
        }
      }
      
      return .text
    }
  }()
  
  var isAlertMessage: Bool {
    return type == .alertScreenRecording || type == .alertScreenshot || type == .alertDelete || type == .alertForward || type == .alertCopy
  }
  
  var containAttachment: Bool {
    return type == .audio || type == .photo || type == .video || type.isDocument()
  }
  
  lazy var status: MessageStatus = {
    return self.sender == Blackbox.shared.account.registeredNumber ? .outgoing : .incoming
  }()

  /// Return the  Contact number or groupchatid of the conversation
  lazy var buddyNumberOrGroupId: String = {
    if groupID.count > 0 {
      return groupID
    }
    return status == .outgoing ? recipient : sender
  }()
  
  // If `Self` conforming to `Hashable`.
  var differenceIdentifier: Message {
    return self
  }
  
}

extension Message {
  
  var isGroupChat: Bool {
    return !groupID.isEmpty
  }

  func resetFileForward() {
    if let newPath = AppUtility.copyFile(localFilename, fileName: originFilename) {
      originalFilePath = newPath
      originFilename = URL(string: newPath)?.lastPathComponent ?? ""
      localFilename = ""
      filename = ""
    }
  }
  
  func setForwardedAsync(completion block:((Bool) -> Void)?) {
    DispatchQueue.global(qos: .background).async { [self] in
        guard let jsonString = BlackboxCore.setForwardedMessage(ID) else {
            return
        }
        logPrettyJsonString(jsonString)
        do {
            let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
            DispatchQueue.main.async {
                if response.isSuccess() {
                    block?(true)
                } else {
                    block?(false)
                }
            }
        } catch {
            loge(error)
        }
    }
  }
  
  static func getFileType(fileExtension: String) -> MessageType {
    guard let fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil)?.takeRetainedValue() else {
      return .text
    }
    
    if UTTypeConformsTo(fileUTI, kUTTypeImage) {
      // Photo
      return .photo
    }
    else if UTTypeConformsTo(fileUTI, kUTTypeMovie) {
      // Video
      return .video
    }
    else if UTTypeConformsTo(fileUTI, kUTTypeAudio) {
      // Audio
      return .audio
    }
    else if UTTypeConformsTo(fileUTI, kUTTypeText) {
      // Text
      return .document(.text)
    }
    else if UTTypeConformsTo(fileUTI, kUTTypePDF) {
      // PDF
      return .document(.pdf)
    }
    else if UTTypeConformsTo(fileUTI, "com.microsoft.word.doc" as CFString) || UTTypeConformsTo(fileUTI, "org.openxmlformats.wordprocessingml.document" as CFString) {
      // Microsoft Doc
      return .document(.microsoftWord)
    }
    else if UTTypeConformsTo(fileUTI, "com.microsoft.excel.xls" as CFString) || UTTypeConformsTo(fileUTI, "org.openxmlformats.spreadsheetml.sheet" as CFString) {
      // Microsoft Excel
      return .document(.microsoftExcel)
    }
    else if UTTypeConformsTo(fileUTI, "com.microsoft.powerpoint.ppt" as CFString) {
      // Microsoft Power point
      return .document(.microsoftPowerPoint)
    }
    else if UTTypeConformsTo(fileUTI, "com.apple.iwork.pages.pages" as CFString) || UTTypeConformsTo(fileUTI, "com.apple.iwork.pages.sffpages" as CFString) {
      // IWork Pages
      return .document(.applePages)
    }
    else if UTTypeConformsTo(fileUTI, "com.apple.iwork.numbers.numbers" as CFString) {
      // IWork Numbers
      return .document(.appleNumbers)
    }
    else if UTTypeConformsTo(fileUTI, "com.apple.iwork.keynote.key" as CFString) {
      // IWork Keynote
      return .document(.appleKeynote)
    }
//    else {
//      return .document(.generic)
//    }
    
    return .text
  }
  
  static func dateToStringGregorian(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.amSymbol = "AM".localized()
    formatter.pmSymbol = "PM".localized()
    formatter.dateFormat = "h:mm a"
    formatter.timeZone = TimeZone.current
    return "\(formatter.string(from: date))"
    
    
//    if date.isInToday {
//      formatter.amSymbol = "AM".localized()
//      formatter.pmSymbol = "PM".localized()
//      formatter.dateFormat = "h:mm a"
//      formatter.timeZone = TimeZone.current
//      return "\(formatter.string(from: date))"
//    }
//    else if date.isInYesterday {
//      formatter.amSymbol = "AM".localized()
//      formatter.pmSymbol = "PM".localized()
//      formatter.dateFormat = "h:mm a"
//      formatter.timeZone = TimeZone.current
//      return "\(formatter.string(from: date))"
//    }
//    else if date.isInCurrentWeek {
//      formatter.dateFormat = "EEEE"
//      formatter.timeZone = TimeZone.current
//      return formatter.string(from: date)
//    }
//    else if date.isInCurrentYear {
//      formatter.dateFormat = "E, MMM d"
//      formatter.timeZone = TimeZone.current
//      return formatter.string(from: date)
//    }
//    else {
//      formatter.dateFormat = "dd/MM/yyyy"
//      formatter.timeZone = TimeZone.current
//      return formatter.string(from: date)
//    }
  }
  
  static func dateToStringIslamic(_ date: Date) -> String {
    if date.isInToday || date.isInYesterday || date.isInCurrentWeek {
      return dateToStringGregorian(date)
    }
    if date.isInCurrentYear {
      let islamic = NSCalendar(identifier: NSCalendar.Identifier.islamicUmmAlQura)
      if let components = islamic?.components(NSCalendar.Unit(rawValue: UInt.max), from: date),
        let year = components.year,
        let month = components.month,
        let day = components.day {
        return "\(year)-\(month)-\(day)"
      }
    }
    // fallback to gregorian
    return dateToStringGregorian(date)
  }
  
}

extension Message: Hashable {
  /// :nodoc:
  public static func == (lhs: Message, rhs: Message) -> Bool {
    var isDateReceivedEqual = false
    if lhs.dateReceived == nil && rhs.dateReceived == nil {
      isDateReceivedEqual = true
    }
    else if let lhsDateReceived = lhs.dateReceived, let rhsDateReceived = rhs.dateReceived {
      if lhsDateReceived.inSameDayAs(date: rhsDateReceived) {
        isDateReceivedEqual = true
      }
    }
    
    var isDateReadEqual = false
    if lhs.dateRead == nil && rhs.dateRead == nil {
      isDateReadEqual = true
    }
    else if let lhsDateRead = lhs.dateRead, let rhsDateRead = rhs.dateRead {
      if lhsDateRead.inSameDayAs(date: rhsDateRead) {
        isDateReadEqual = true
      }
    }
        
    let ret = lhs.ID == rhs.ID &&
      lhs.checkmarkType == rhs.checkmarkType &&
      lhs.sender == rhs.sender &&
      lhs.groupPhoto == rhs.groupPhoto &&
      lhs.dateSent == rhs.dateSent &&
      isDateReceivedEqual &&
      isDateReadEqual

    return ret
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(ID)
    hasher.combine(checkmarkType)
    hasher.combine(sender)
    hasher.combine(dateSent)
    if let date = dateReceived {
      hasher.combine(Int(date.timeIntervalSince1970))
    }
    if let date = dateRead {
      hasher.combine(Int(date.timeIntervalSince1970))
    }
  }
}

extension Message: NSCopying {
  // Needed for Forward
  func copy(with zone: NSZone? = nil) -> Any {
    // During the copy, if the message contain a file we need to add the extension to the fileName.
    let copy = Message(body: body, type: msgtype, originalFilePath: originalFilePath, filename: filename, originFileName: originFilename, localFilename: localFilename)
    return copy
  }
}

private extension Message {
  func getMessageTypeFromAlertString(_ string: String) -> MessageType? {
    switch string {
    case "audio":
      return .audio
    case "text":
      return .text
    case "photo":
      return .photo
    case "video":
      return .video
    case "location":
      return .location
    case "document":
      return .document(.generic)
    case "contact":
      return .contact
    default:
      return nil
    }
  }
}

