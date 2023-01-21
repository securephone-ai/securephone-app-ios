import Foundation

struct SendTextMessageResponse: BBResponse {
  let answer: String
  let message: String
  let msgid: String
  let msgref: String
  let autoDelete: Bool
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case msgid
    case msgref
    case autodelete
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.msgid = (try? container.decode(String.self, forKey: .msgid)) ?? ""
    self.msgref = (try? container.decode(String.self, forKey: .msgref)) ?? ""
    let isAutoDelete = (try? container.decode(String.self, forKey: .autodelete)) ?? "0"
    self.autoDelete = isAutoDelete == "1"
  }
}
