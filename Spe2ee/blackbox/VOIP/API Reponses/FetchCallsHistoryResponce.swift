import Foundation


/// JSON Object for **bb_last_voicecalls**
struct FetchCallsHistoryResponce: BBResponse {
  let answer: String
  let message: String
  let callsHistory: [BBCallHistory]
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case callsHistory = "voicecalls"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.callsHistory = (try? container.decode([BBCallHistory].self, forKey: .callsHistory)) ?? [BBCallHistory]()
  }
  
}
