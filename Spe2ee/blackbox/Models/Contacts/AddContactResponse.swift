import Foundation

struct AddContactResponse: BBResponse {
  let answer: String
  let message: String
  var id: String
  var registeredPhones: [PhoneNumber]
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case id
    case registeredPhones = "phonejsonreg"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.id = (try? container.decode(String.self, forKey: .id)) ?? ""
    self.registeredPhones = (try? container.decode([PhoneNumber].self, forKey: .registeredPhones)) ?? [PhoneNumber]()
    
  }
}
