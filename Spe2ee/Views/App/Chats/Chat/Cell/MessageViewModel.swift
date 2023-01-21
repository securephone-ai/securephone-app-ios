import UIKit
import MobileCoreServices
import DifferenceKit
import CwlUtils
import BlackboxCore


/// This clas is a Wrapper around Message and is used as the Message Cell View Model.
class MessageViewModel: Hashable, Differentiable {
  private var fileStatusTimer: DispatchTimer?
  private var fileStatusTimerStartTime = DispatchTime.now()
  private var thumbnailGenerationQueue = DispatchQueue(label: "thumbnailGenerationQueue_\(UUID().uuidString)", qos: .userInitiated)
  
  let message: Message

  private var contactRegNumber: String
  private var groupID: String? = nil
  
  var contact: BBContact {
    if let contact =  Blackbox.shared.getContact(registeredNumber: contactRegNumber) {
      return contact
    }
    if let contact = Blackbox.shared.getTemporaryContact(registeredNumber: contactRegNumber) {
      return contact
    }
    let contact = BBContact()
    contact.registeredNumber = self.message.status == .incoming ? message.sender : message.recipient
    Blackbox.shared.temporaryContacts.append(contact)
    return contact
  }
  
  lazy var contactName: String = {
    return contact.getName()
  }()
  
  lazy var contactColor: UIColor = {
    return contact.color
  }()
  
  var group: BBGroup? {
    if message.isGroupChat {
      for chat in Blackbox.shared.chatItems {
        if let chatCellViewModel = chat.getChatItemViewModel(), let group = chatCellViewModel.group, group.ID == message.groupID {
          return group
        }
      }
    }
    return nil
  }
  
  var groupReceipts: [MessageReceipt]?
  
  var cellHeight: CGFloat {
    if let interfaceOrientation = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.interfaceOrientation {
      // Use interfaceOrientation
      return interfaceOrientation.isPortrait ? bubbleSizePortrait.height : bubbleSizeLandscape.height
    }
    return 0.0
  }
  
  var bubbleSizePortrait: CGSize = .zero
  var bubbleSizeLandscape: CGSize = .zero
  var recalculateSize = false
  
  lazy var messageSentTime: String  = {
    return message.dateSent.timeString12Hour()
  }()
  
  lazy var alertText: NSAttributedString = {
    if let alertMsg = message.alertMsg {
      return alertMsg.attributedForChat
    }
    return "".attributedForChat
  }()
  
  lazy var isSent: Bool = {
    // TODO: Check sender number against the user account number using Blackbox function
    return message.sender == Blackbox.shared.account.registeredNumber
  }()

  private var _videoThumbnail: UIImage?
  func getVideoThumbnail() -> UIImage? {
    if _videoThumbnail == nil {
      _videoThumbnail = AppUtility.generateVideoThumbnail(fileName: message.localFilename, filekey: message.fileKey)
      return _videoThumbnail
        
    } else {
      return _videoThumbnail
    }
  }
  

  // MARK: - Reply variables
  var isReply: Bool {
    return repliedMessageID.isEmpty == false && repliedMessageID != "0" && message.type != .deleted
  }
  var repliedMessageID: String {
    return message.replyToMsgID
  }
  
  lazy var repliedMessageBody: String = {
    let components = message.replyToText.components(separatedBy: ":#").filter { !$0.isEmpty }
    if components.count > 1 {
      let type = components[0]
      
      switch type {
      case "txt":
        return components[1]
      case "location":
        return ""
      case "file":
        if components.count > 2 {
          return components[2]
        }
        return ""
      default:
        break
      }
    }
    return ""
  }()
  
  lazy var repliedMessageType: MessageType = {
    // Parse the text and extract what we need to show the reply
    let components = message.replyToText.components(separatedBy: ":#").filter { !$0.isEmpty }
    if components.count > 1 {
      let type = components[0]
      let content = components[1]
      
      switch type {
      case "txt":
        return .text
      case "location":
        return .location
      case "file":
        return Message.getFileType(fileExtension: content)
      default:
        return .text
      }
    }
    return .text
  }()
  
  lazy var repliedMessageContactName: String = {
    let components = message.replyToText.components(separatedBy: ":#").filter { !$0.isEmpty }
    if let contactNumber = components.last {
      let blackbox = Blackbox.shared
      if contactNumber == blackbox.account.registeredNumber {
        return "You".localized()
      }
      if let contact = Blackbox.shared.getContact(registeredNumber: contactNumber) {
        return contact.getName()
      }
      if let contact = Blackbox.shared.getTemporaryContact(registeredNumber: contactNumber) {
        return contact.getName()
      }
    }
    
    let messagesSections = self.group != nil ? self.group!.messagesSections : self.contact.messagesSections
    for section in messagesSections {
      for messageViewModel in section.messages where messageViewModel.message.ID == repliedMessageID {
        return messageViewModel.isSent ? "You".localized() : messageViewModel.contact.getName()
      }
    }
    return "You".localized()
  }()
  
  var isRead: Bool {
    return message.dateRead == nil ? false : true
  }
  
  var isDownloadComplete: Bool {
      guard FileManager.default.fileExists(atPath: message.localFilename.replacingOccurrences(of: "\0enc", with: ".enc")) else { return false }
      let fileSizeOnDevice = AppUtility.getFileSize(message.localFilename.replacingOccurrences(of: "\0enc", with: ".enc"))
    return message.fileSize > 0 && fileSizeOnDevice > 0 && message.fileSize == fileSizeOnDevice
  }
  
  var isDownloading: Bool {
    return FileManager.default.fileExists(atPath: "\(message.localFilename).download")
  }
  
  var showDownloadButton: Bool {
    return message.autoDownload == false && FileManager.default.fileExists(atPath: message.localFilename) == false && isDownloading == false
  }
  
//  var nextMessageSender: String = ""
  
  var isSingleEmoji: Bool {
    return false
  }
  var isBodyAboveDate: Bool = false
  
  @Published var isSelected = false
  @Published var isEditing: (delete: Bool, forward: Bool) = (false, false)
  @Published var alpha: CGFloat = 1.0
  @Published var isAudioPlaying = false {
    didSet {
      // Stop any other audio that is playing
      if isAudioPlaying {
        DispatchQueue.global(qos: .background).async { [weak self] in
          guard let strongSelf = self else { return }
          for section in strongSelf.contact.messagesSections {
            for messageViewModel in section.messages where messageViewModel.message.type == .audio && messageViewModel.isAudioPlaying && messageViewModel.message.ID != strongSelf.message.ID {
              logi(messageViewModel.message.dateSent.timeString12Hour())
              messageViewModel.isAudioPlaying = false
            }
          }
        }
      }
    }
  }
  @Published var nextMessageSender: String = ""
  @Published var searchedStringsRange: [NSRange] = []
  
  var previousMessageSender: String?

  init(message: Message, contact: BBContact, group: BBGroup? = nil) {
    self.contactRegNumber = contact.registeredNumber
    self.message = message
//    self.contact = contact
//    self.group = group
    
    if message.type == .video, message.localFilename.isEmpty == false {
      // Generate the video Thumbnail on a background thread
//      DispatchQueue.global(qos: .background).async { [weak self] in
//        guard let strongSelf = self else { return }
//        _ = strongSelf.getVideoThumbnail()
//      }
    }
    
    // If this is an alert message we change the message body.
    if self.message.isAlertMessage {
      if message.isAlertMessage {
        var contactName = "You".localized()
        if isSent == false {
          contactName = contact.name.isEmpty == false ? contact.name : contact.registeredNumber
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
        message.alertMsg = "*_\(contactName)* \(action)_"
      }
    }

  }

  // If `Self` conforming to `Hashable`.
  var differenceIdentifier: MessageViewModel {
    return self
  }
  
  static func == (lhs: MessageViewModel, rhs: MessageViewModel) -> Bool {
    return lhs.message == rhs.message
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(message)
  }
  
  func setMessageDeleted(isSelf: Bool = false) {
    recalculateSize = true
    message.isForwarded = false
    message.replyToMsgID = ""
    message.replyToText = ""
    message.dateDeleted = Date()
    
    if isSelf {
      message.body = "This message has been self disappeared automatically".localized()
    } else {
      message.body = message.status == .outgoing ? "_\("You deleted this message".localized())_" : "_\("This message has been deleted".localized())_"
    }

  }
  
  /// Refrresh the file download state every 250ms and check if the download is complete.
  func refreshFileTransferStateAsync() {
    if fileStatusTimer == nil {
      
      // Start a timer that will be called every 150 milliseconds.
      // This timer will update the Message file transfer state and will stop when the file reach 100
      //
      // Problem      - File transfer state stacked at 99% and restart 2 times when different threads try to fetchthe same mesage and download the same file
      // Workaround:  - If the file get stack at 99% for 90+ seconds, the file transfer state is forced to 100%
      //
      var lastSavedTransferState = message.fileTransferState
      var lastSavedTransferStateStartTime = DispatchTime.now()
      fileStatusTimer = DispatchTimer(countdown: .milliseconds(100), repeating: .milliseconds(250), executingOn: DispatchQueue(label: "UpdateFileStatusTimer_\(message.ID)", qos: .background)) { [weak self] in
        guard let strongSelf = self, strongSelf.fileStatusTimer != nil else { return }
        
        var fileName = ""
        var isDownload = false
        if let originalFilePath = strongSelf.message.originalFilePath, originalFilePath.isEmpty == false {
          // Upload
          fileName = originalFilePath
        }
        else if strongSelf.message.localFilename.isEmpty == false {
          // Downloads
          isDownload = true
          fileName = strongSelf.message.localFilename
        }
        
        guard fileName.isEmpty == false else { return }
        var fileTransferState = CGFloat(BlackboxCore.getFileTransferProgress(fileName))
        
        //logi("File Transfer state of: \(fileName) --------> \(fileTransferState)")
        logi("File transfer state: \(fileTransferState)")
        
        if fileTransferState == -1 {
          // file Not found
          fileTransferState = 0
        }
        
        if fileTransferState == -100 {
          // File download/upload was interrupted.
          strongSelf.stopRefreshFileTransferState()
          return
        }
        
        if strongSelf.isDownloadComplete {
          fileTransferState = 100
          strongSelf.message.fileTransferState = fileTransferState
          
          if isDownload {
              strongSelf.message.localFilename = fileName.replacingOccurrences(of: "\0enc", with: ".enc")
            strongSelf.message.originalFilePath = nil
          }
          strongSelf.stopRefreshFileTransferState()
        }
        else {
          if fileTransferState == 100 && lastSavedTransferState == 100 && FileManager.default.fileExists(atPath: fileName) == false {
            // this can happen when app goes from background to foreground and the file has been deleted
            // So we set the % to zero since the file does not exist
            fileTransferState = 0
          }
          else if fileTransferState == 100 && 1..<100 ~= lastSavedTransferState && FileManager.default.fileExists(atPath: fileName) == false {
            // this can happen when the Downlod is finished but decription is not (Video Files can usually trigger this)
            // So we set the % to 99 since it is not completed...
            fileTransferState = 99
          }
          
          if fileTransferState == 100 {
            // This can happen when BlackboxCore.getFileTransferProgress return 100 but the file is still being downloaded..
            // We don't know the % because what is returned is wrong, so we set it to zero.
            fileTransferState = 0
          }
          
          strongSelf.message.fileTransferState = fileTransferState
          
//          if strongSelf.message.fileTransferState == 99 {
//            // Still decrypting...
//            // Stop the refresh timer after 40 seconds
//            let now = DispatchTime.now()
//            let nanoTime = now.uptimeNanoseconds - strongSelf.fileStatusTimerStartTime.uptimeNanoseconds
//            let timeInterval = Double(nanoTime) / 1_000_000_000 // convert to seconds.
//
//           if timeInterval.truncatingRemainder(dividingBy: 15) < 1 {
////              strongSelf.message.fileTransferState = 100
//              strongSelf.downloadFileAsync()
//            }
//          }
//          else
          if lastSavedTransferState == strongSelf.message.fileTransferState {
            // Stop the refresh timer if the download % is stack at the same value for 20+ seconds
            let now = DispatchTime.now()
            let nanoTime = now.uptimeNanoseconds - lastSavedTransferStateStartTime.uptimeNanoseconds
            let timeInterval = Double(nanoTime) / 1_000_000_000 // convert to seconds.

            // retry to download every 20 seconds
            if 20...100 ~= timeInterval && timeInterval.truncatingRemainder(dividingBy: 20) < 1 {
              strongSelf.downloadFileAsync()
            }
            
            // Stop everything after 100 seconds
            if timeInterval > 100 {
              // Unable to download
              strongSelf.stopRefreshFileTransferState()
            }
          }
          else {
            lastSavedTransferStateStartTime = DispatchTime.now()
            lastSavedTransferState = strongSelf.message.fileTransferState
          }
        }
      }
      
      self.fileStatusTimerStartTime = DispatchTime.now()
      fileStatusTimer?.arm()
      
    } else {
//      self.fileStatusTimerStartTime = DispatchTime.now()
//      fileStatusTimer?.reset()
    }
  }
  
  /// Stop the refresh download timer
  func stopRefreshFileTransferState() {
    fileStatusTimer?.disarm()
    if fileStatusTimer != nil {
      fileStatusTimer = nil
    }
  }
  
  /// download file
  func downloadFileAsync() {
    guard let jsonString = BlackboxCore.downloadMessageFileAsync(message.ID) else {
        return
    }
    do {
        let response = try Blackbox.shared.decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
        if response.isSuccess() {
            message.fileTransferState = 0
            refreshFileTransferStateAsync()
        }
    } catch {
        loge(error)
    }
  }
  
}

