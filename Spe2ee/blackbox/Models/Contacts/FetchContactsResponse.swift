import Foundation


/// JSON object for **bb_get_contacts**
struct FetchContactsResponse: BBResponse {
  let answer: String
  let message: String
  let contacts: [BBContact]
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case contacts
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.contacts = (try? container.decode([BBContact].self, forKey: .contacts)) ?? [BBContact]()
    
  }
}
