import Foundation

/// JSON Object for **bb_info_voicecall**
struct CallInfoResponse: BBResponse {
  let answer: String
  let message: String
  let callerID: String
  let contactID: String
  let contactName: String
  let callID: String
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case callerID = "callerid"
    case contactID = "contactid"
    case contactName = "contactname"
    case callID = "callid"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.callerID = (try? container.decode(String.self, forKey: .callerID)) ?? ""
    self.contactID = (try? container.decode(String.self, forKey: .contactID)) ?? ""
    self.contactName = (try? container.decode(String.self, forKey: .contactName)) ?? ""
    self.callID = (try? container.decode(String.self, forKey: .callID)) ?? ""
  }
  
}
