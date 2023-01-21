import Foundation


struct Address: Codable, Equatable {
  
  let ID = UUID().uuidString
  var street = ""
  var city = ""
  var zip = ""
  var province = ""
  var state = ""
  var country = ""
  var pobox = ""
  
  private enum CodingKeys : String, CodingKey {
    case street = "address"
    case city
    case zip
    case province
    case state
    case country
    case pobox
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.street = (try? container.decode(String.self, forKey: .street)) ?? ""
    self.city = (try? container.decode(String.self, forKey: .city)) ?? ""
    self.zip = (try? container.decode(String.self, forKey: .zip)) ?? ""
    self.province = (try? container.decode(String.self, forKey: .province)) ?? ""
    self.state = (try? container.decode(String.self, forKey: .state)) ?? ""
    self.country = (try? container.decode(String.self, forKey: .country)) ?? ""
    self.pobox = (try? container.decode(String.self, forKey: .pobox)) ?? ""
  }
  
  init(street: String, city: String, zip: String, province: String, state: String, country: String, pobox: String) {
    self.street = street
    self.city = city
    self.zip = zip
    self.province = province
    self.state = state
    self.country = country
    self.pobox = pobox
  }
  
  public static func == (lhs: Address, rhs: Address) -> Bool {
    lhs.street == rhs.street &&
      lhs.city == rhs.city &&
      lhs.zip == rhs.zip &&
      lhs.province == rhs.province &&
      lhs.state == rhs.state &&
      lhs.state == rhs.state &&
      lhs.pobox == rhs.pobox
  }
  
}
