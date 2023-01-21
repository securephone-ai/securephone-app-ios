
import Foundation

/// JSON Object for **bb_signup_newdevice**
struct SignupResponse: BBResponse {
  let answer: String
  let message: String
  let pwdconf: String
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case pwdconf
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.pwdconf = (try? container.decode(String.self, forKey: .pwdconf)) ?? ""
  }
}
