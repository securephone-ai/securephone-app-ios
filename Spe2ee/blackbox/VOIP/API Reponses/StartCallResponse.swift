import Foundation


/// JSON Object for **bb_originate_voicecall**
struct StartCallResponse: BBResponse {
  let answer: String
  let message: String
  let serverIpAddress: String
  let portRead: String
  let portWrite: String
  let callID: String
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case serverIpAddress = "serveripaddress"
    case portRead = "portread"
    case portWrite = "portwrite"
    case callID = "callid"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.serverIpAddress = (try? container.decode(String.self, forKey: .serverIpAddress)) ?? ""
    self.portRead = (try? container.decode(String.self, forKey: .portRead)) ?? ""
    self.portWrite = (try? container.decode(String.self, forKey: .portWrite)) ?? ""
    self.callID = (try? container.decode(String.self, forKey: .callID)) ?? ""
  }
  
}
