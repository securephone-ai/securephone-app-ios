import Foundation


struct FetchAutoDeleteTimerResponse: BBResponse {
  let answer: String
  let message: String
  let seconds: Int
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case seconds = "autodeleteseconds"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    
    let secondsString = (try? container.decode(String.self, forKey: .seconds)) ?? "autodeleteseconds"
    if let seconds = Int(secondsString) {
      self.seconds = seconds
    } else {
      self.seconds = 0
    }
  }
}
