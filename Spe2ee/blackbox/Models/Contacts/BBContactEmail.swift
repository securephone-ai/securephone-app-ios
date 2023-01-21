import Foundation

struct Email: Codable, Equatable {
  let ID = UUID().uuidString
  var tag: String
  var email: String
  
  private enum CodingKeys : String, CodingKey {
    case tag
    case email
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.tag = (try? container.decode(String.self, forKey: .tag)) ?? ""
    self.email = (try? container.decode(String.self, forKey: .email)) ?? ""
  }
  
  init() {
    self.tag = ""
    self.email = ""
  }
  
  init(tag: String, email: String) {
    self.tag = tag
    self.email = email
  }
  
  public static func == (lhs: Email, rhs: Email) -> Bool {
    lhs.email == rhs.email && lhs.tag == rhs.tag
  }
}
