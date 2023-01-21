import Foundation


/// pwdConf JSON  object
struct PwdConf: Decodable {
  let keyaes: String
  let ivaes: String
  let tagaes: String
  let keycamellia: String
  let ivcamellia: String
  let keychacha: String
  let ivchacha: String
  
  private enum CodingKeys : String, CodingKey {
    case keyaes
    case ivaes
    case tagaes
    case keycamellia
    case ivcamellia
    case keychacha
    case ivchacha
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self) 
    self.keyaes = (try? container.decode(String.self, forKey: .keyaes)) ?? ""
    self.ivaes = (try? container.decode(String.self, forKey: .ivaes)) ?? ""
    self.tagaes = (try? container.decode(String.self, forKey: .tagaes)) ?? ""
    self.keycamellia = (try? container.decode(String.self, forKey: .keycamellia)) ?? ""
    self.ivcamellia = (try? container.decode(String.self, forKey: .ivcamellia)) ?? ""
    self.keychacha = (try? container.decode(String.self, forKey: .keychacha)) ?? ""
    self.ivchacha = (try? container.decode(String.self, forKey: .ivchacha)) ?? ""
  }
}
