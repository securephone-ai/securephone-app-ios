import Foundation

struct ContactDate: Codable, Equatable {
  let ID = UUID().uuidString
  var tag = ""
  var date = ""
  
  private enum CodingKeys : String, CodingKey {
    case tag
    case date
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.tag = (try? container.decode(String.self, forKey: .tag)) ?? ""
    self.date = (try? container.decode(String.self, forKey: .date)) ?? ""
  }
  
  init(tag: String, date: String) {
    self.tag = tag
    self.date = date
  }
  
  public static func == (lhs: ContactDate, rhs: ContactDate) -> Bool {
    lhs.tag == rhs.tag && lhs.date == rhs.date
  }
}
