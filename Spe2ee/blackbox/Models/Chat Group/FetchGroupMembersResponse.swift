
import Foundation


/// JSON Object for **bb_get_list_members_groupchat**
struct FetchGroupMembersResponse: BBResponse {
  let answer: String
  let message: String
  let members: [GroupMember]
  
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case members
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.members = (try? container.decode([GroupMember].self, forKey: .members)) ?? [GroupMember]()
  }
}

struct GroupMember: Decodable {
  let id: String
  let name: String
  let surname: String
  let mobileNumber: String
  let role: GroupRole
  
  private enum CodingKeys : String, CodingKey {
    case id
    case name
    case surname
    case mobileNumber = "mobilenumber"
    case role
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = (try? container.decode(String.self, forKey: .id)) ?? ""
    self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
    self.surname = (try? container.decode(String.self, forKey: .surname)) ?? ""
    self.mobileNumber = (try? container.decode(String.self, forKey: .mobileNumber)) ?? ""
    
    let roleValue = (try? container.decode(String.self, forKey: .role)) ?? nil
    if let role = roleValue {
      if role == "administrator" {
        self.role = .administrator
      } else if role == "creator" {
        self.role = .creator
      } else {
        self.role = .normal
      }
    } else {
      self.role = .normal
    }

  }
  
}
