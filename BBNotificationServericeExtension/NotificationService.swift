import UserNotifications

class NotificationService: UNNotificationServiceExtension {
  
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?
  
  override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
    
    if let bestAttemptContent = bestAttemptContent {
      if let token = bestAttemptContent.userInfo["tokenreceipt"] as? String {
        print("tokenreceipt -> \(token)")
        let tokenPtr = strdup(token)
        defer {
          tokenPtr?.deallocate()
        }
        
        if let result = bb_send_received_receipt(tokenPtr) {
          let json = String(cString: result)
          print(json)
        }
      }
      
      if bestAttemptContent.body == "New Message" {
        bestAttemptContent.body = NSLocalizedString("New Message", comment: "")
      }
      else if bestAttemptContent.body == "Missed Video Call" {
        bestAttemptContent.body = NSLocalizedString("Missed Video Call", comment: "")
      }
      else if bestAttemptContent.body == "Missed Audio Call" {
        bestAttemptContent.body = NSLocalizedString("Missed Audio Call", comment: "")
      }
      
      contentHandler(bestAttemptContent)
    }
  }
  
  override func serviceExtensionTimeWillExpire() {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
  
}

