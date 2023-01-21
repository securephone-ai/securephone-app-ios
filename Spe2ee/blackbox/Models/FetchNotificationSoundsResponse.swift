import Foundation

/// JSON Object for **bb_get_notifications**
struct FetchNotificationSoundsResponse: BBResponse {
  var answer: String
  var message: String
  var notificationsSound: [BBNotificationSound]
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case notificationsSound = "notifications"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.notificationsSound = (try? container.decode([BBNotificationSound].self, forKey: .notificationsSound)) ?? [BBNotificationSound]()
  }
}


struct BBNotificationSound: Decodable {
  var contactNumber: String
  var groupChatId: String
  var soundName: String
  var priority: Bool
  var popup: Bool
  var vibration: Bool
  
  private enum CodingKeys : String, CodingKey {
    case contactNumber = "contactnumber"
    case groupChatId = "groupchatid"
    case soundName = "soundname"
    case priority
    case popup
    case vibration
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.contactNumber = (try? container.decode(String.self, forKey: .contactNumber)) ?? ""
    self.groupChatId = (try? container.decode(String.self, forKey: .groupChatId)) ?? ""
    self.soundName = (try? container.decode(String.self, forKey: .soundName)) ?? ""
    
    var ret = (try? container.decode(String.self, forKey: .priority)) ?? "N"
    self.priority = ret == "N"
    
    ret = (try? container.decode(String.self, forKey: .popup)) ?? "N"
    self.popup = ret == "N"
    
    ret = (try? container.decode(String.self, forKey: .vibration)) ?? "N"
    self.vibration = ret == "N"
  }
}
