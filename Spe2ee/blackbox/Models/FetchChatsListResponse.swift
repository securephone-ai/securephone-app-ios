import Foundation

struct FetchChatsListResponse: BBResponse {
  let answer: String
  let message: String
  let chats: [Message]
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case chats
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.chats = (try? container.decode([Message].self, forKey: .chats)) ?? [Message]()
  }
}
