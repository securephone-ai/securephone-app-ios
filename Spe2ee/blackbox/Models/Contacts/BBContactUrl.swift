import Foundation


struct ContactUrl: Codable, Equatable {
  let ID = UUID().uuidString
  var tag = ""
  var url = ""
  
  private enum CodingKeys : String, CodingKey {
    case url
    case tag
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
  
  public static func == (lhs: ContactUrl, rhs: ContactUrl) -> Bool {
    lhs.tag == rhs.tag && lhs.url == rhs.url
  }
}
