
import Foundation

enum OnlineStatus {
  case online
  case offline
}

/// JSON Object for **bb_get_profileinfo**
struct FetchAccountInfoResponse: BBResponse {
  let answer: String
  let message: String
  // Not every response return a token but most do, so we'll add it to the base response and set to empty if not present
  
//  {"answer":"OK","message":"Profile Info","name":"Mr. Ali","status":"In Meeting","lastseen":"2020-03-01 10:20:22","photoname":"62d72ae4bdc7fd6547f4953739fd1dac5e7aa982871075f1c65940d895ba2576","token":"","uidrecipient":"1234567890"}
  let name: String
  let onlineStatus: OnlineStatus
  var onlineVisibility: Bool = false
  let statusMessage: String
  let lastSeen: Date
  let photoName: String
  let uidRecipient: String
  let forceUpdate: Bool
  let currentAppVersion: String
  let currentIOSVersion: String
  let updateUrl: String
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case name
    case onlineStatus = "onlinestatus"
    case statusMessage = "status"
    case lastSeen = "lastseen"
    case photoName = "photoname"
    case uidRecipient = "uidrecipient"
    case forceUpdate = "forceupdate"
    case currentAppVersion = "currentappversion"
    case currentIOSVersion = "updateversionios"
    case updateUrl = "updateurlios"
    case onlineVisibility = "onlinevisibility"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
    self.statusMessage = (try? container.decode(String.self, forKey: .statusMessage)) ?? ""
    self.photoName = (try? container.decode(String.self, forKey: .photoName)) ?? ""
    self.uidRecipient = (try? container.decode(String.self, forKey: .uidRecipient)) ?? ""
    self.currentAppVersion = (try? container.decode(String.self, forKey: .currentAppVersion)) ?? ""
    self.currentIOSVersion = (try? container.decode(String.self, forKey: .currentIOSVersion)) ?? ""
    self.updateUrl = (try? container.decode(String.self, forKey: .updateUrl)) ?? ""
    
    let hasUpdate = (try? container.decode(String.self, forKey: .forceUpdate)) ?? ""
    self.forceUpdate = hasUpdate == "Y"
    
    let onStatus = (try? container.decode(String.self, forKey: .onlineStatus)) ?? ""
    self.onlineStatus = onStatus == "online" ? .online : .offline
    
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let dateString = (try? container.decode(String.self, forKey: .lastSeen)) ?? ""
    self.lastSeen = dateFormatter.date(from: dateString) ?? Date()
    
    let onlineVisibility = (try? container.decode(String.self, forKey: .onlineVisibility)) ?? ""
    self.onlineVisibility = onlineVisibility == "Y"
  }
  
}
