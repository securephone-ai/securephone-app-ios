import Foundation

struct PhoneNumber: Codable, Equatable {
  let ID = UUID().uuidString
  var tag: String
  var phone: String
  var prefix: String
  
  private enum CodingKeys : String, CodingKey {
    case tag
    case phone
    case prefix
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.tag = (try? container.decode(String.self, forKey: .tag)) ?? ""
    self.phone = (try? container.decode(String.self, forKey: .phone)) ?? ""
    self.prefix = (try? container.decode(String.self, forKey: .prefix)) ?? ""
  }
  
  init() {
    self.tag = ""
    self.phone = ""
    self.prefix = ""
  }
  
  init(tag: String, phone: String, prefix: String = "") {
    self.tag = tag
    self.phone = phone
    self.prefix = prefix
  }
  
  public static func == (lhs: PhoneNumber, rhs: PhoneNumber) -> Bool {
    lhs.phone == rhs.phone && lhs.tag == rhs.tag && lhs.prefix == rhs.prefix
  }
}
