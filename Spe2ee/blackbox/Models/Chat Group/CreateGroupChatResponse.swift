
import Foundation


/// JSON Object for **bb_new_groupchat**
struct CreateGroupChatResponse: BBResponse {
  let answer: String
  let message: String
  let groupID: String
  
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case groupID = "groupid"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.groupID = (try? container.decode(String.self, forKey: .groupID)) ?? ""
  }
}
