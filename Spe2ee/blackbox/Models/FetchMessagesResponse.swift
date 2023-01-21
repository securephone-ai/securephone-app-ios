
import Foundation

/// JSON object for **bb_get_msgs_fileasync** - **bb_get_starredmsg**
struct FetchMessagesResponse: BBResponse {
  let answer: String
  let message: String
  let messages: [Message]
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case messages
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.messages = (try? container.decode([Message].self, forKey: .messages)) ?? [Message]()
    
  }
}
