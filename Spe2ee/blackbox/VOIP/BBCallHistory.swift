import Foundation
import DifferenceKit

enum BBCallDirection {
  case outbound
  case inbound
  case missed
}

enum BBCallType {
  case call
  case video
}


/// The Json Object for **bb_last_voicecalls**
struct BBCallHistory: Decodable, Hashable, Differentiable {
  
  var callID: String
  var recipient: String
  var name: String
  var direction: BBCallDirection
  var type: BBCallType = .call
  var dateSetup: Date
  var dateAnswer: Date?
  var dateHangup: Date?
  var duration: Int
  
  private enum CodingKeys : String, CodingKey {
    case callID = "callid"
    case recipient
    case name
    case direction
    case dateSetup = "dtsetup"
    case dateAnswer = "dtanswer"
    case dateHangup = "dthangup"
    case duration
    case video
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    // Metadata
    self.callID = (try? container.decode(String.self, forKey: .callID)) ?? ""
    self.recipient = (try? container.decode(String.self, forKey: .recipient)) ?? ""
    self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
    
    
    // Direction
    let direction = (try? container.decode(String.self, forKey: .direction)) ?? ""
    self.direction = direction == "outbound" ? .outbound : .inbound
    
    // Dates
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    var dateString = (try? container.decode(String.self, forKey: .dateSetup)) ?? ""
    self.dateSetup = dateFormatter.date(from: dateString) ?? Date()
    
    dateString = (try? container.decode(String.self, forKey: .dateAnswer)) ?? ""
    self.dateAnswer = dateFormatter.date(from: dateString) ?? nil
    dateString = (try? container.decode(String.self, forKey: .dateHangup)) ?? ""
    self.dateHangup = dateFormatter.date(from: dateString) ?? nil
    
    
    // Duration
    let duration = (try? container.decode(String.self, forKey: .duration)) ?? "0"
    self.duration = Int(duration) ?? 0
    if self.direction == .inbound, self.duration == 0 {
      self.direction = .missed
    }
    
    let video = (try? container.decode(String.self, forKey: .video)) ?? ""
    if video == "N" {
      type = .call
    } else {
      type = .video
    }
    
  }
  
  init() {
    self.callID = "asd"
    self.recipient = "701238712"
    self.name = "akjakdj"
    self.direction = .missed
    self.type = .call
    self.dateSetup = Date()
    self.dateAnswer = Date()
    self.dateHangup = Date()
    self.duration = 12
  }
  
  static func == (lhs: BBCallHistory, rhs: BBCallHistory) -> Bool {
    return lhs.callID == rhs.callID
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(callID)
  }
  
  // If `Self` conforming to `Hashable`.
  var differenceIdentifier: Self {
    return self
  }
  
}

