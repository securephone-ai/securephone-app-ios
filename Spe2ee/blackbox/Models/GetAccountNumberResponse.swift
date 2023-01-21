
import Foundation

/// JSON Object for **bb_get_registered_mobilenumber**
struct GetAccountNumberResponse: BBResponse {
  var answer: String
  var message: String
  var mobilenumber: String?
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case mobilenumber
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.mobilenumber = (try? container.decode(String.self, forKey: .mobilenumber)) ?? nil
  }
}
