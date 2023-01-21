import Foundation

struct InstantMessage: Codable, Equatable {
  let ID = UUID().uuidString
  var tag = ""
  var url = ""
  
  private enum CodingKeys : String, CodingKey {
    case tag
    case url
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.tag = (try? container.decode(String.self, forKey: .tag)) ?? ""
    self.url = (try? container.decode(String.self, forKey: .url)) ?? ""
  }
  
  init(tag: String, url: String) {
    self.tag = tag
    self.url = url
  }
  
  public static func == (lhs: InstantMessage, rhs: InstantMessage) -> Bool {
    lhs.tag == rhs.tag && lhs.url == rhs.url
  }
}
