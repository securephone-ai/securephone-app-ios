import Foundation


/// JSON Object for **bb_status_videocall** - **bb_status_voicecall** - **bb_status_voicecall_id**
struct CallStatusResponse: BBResponse {
  let answer: String
  let message: String
  let calleID: String
  let status: String
  let conferenceMembersStatus: [ConferenceMemberStatus]?
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case calleID = "callid"
    case conferenceMembersStatus = "audioconference"
    case status
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.calleID = (try? container.decode(String.self, forKey: .calleID)) ?? ""
    self.status = (try? container.decode(String.self, forKey: .status)) ?? ""
    
    if let membersStatus = try? container.decode([ConferenceMemberStatus].self, forKey: .conferenceMembersStatus) {
      self.conferenceMembersStatus = membersStatus.filter { $0.status != .hangup }
    } else {
      self.conferenceMembersStatus = nil
    }
  }
  
}


struct ConferenceMemberStatus: Decodable {
  let callerID: String
  let calledID: String
  let status: CallStatus
  
  private enum CodingKeys : String, CodingKey {
    case callerID = "callerid"
    case calledID = "calledid"
    case status
  }
  
  init(from decoder: Decoder) throws {
    
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.callerID = (try? container.decode(String.self, forKey: .callerID)) ?? ""
    self.calledID = (try? container.decode(String.self, forKey: .calledID)) ?? ""
    
    let status = (try? container.decode(String.self, forKey: .status)) ?? ""
    switch status {
    case "setup":
      self.status = .setup
    case "ringing":
      self.status = .ringing
    case "answered":
      self.status = .answered
    case "hangup":
      self.status = .hangup
    default:
      self.status = .none
    }
    
  }
}
