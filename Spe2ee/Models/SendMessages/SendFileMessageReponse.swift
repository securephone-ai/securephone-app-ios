
import Foundation

struct SendFileMessageReponse: BBResponse {
  let answer: String
  let message: String
  let filename: String
  let localFilename: String
  let msgid: String
  let msgref: String
  let autoDelete: Bool
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case filename
    case localFilename = "localfilename"
    case msgid
    case msgref
    case autodelete
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.filename = (try? container.decode(String.self, forKey: .filename)) ?? ""
    self.localFilename = (try? container.decode(String.self, forKey: .localFilename)) ?? ""
    self.msgid = (try? container.decode(String.self, forKey: .msgid)) ?? ""
    self.msgref = (try? container.decode(String.self, forKey: .msgref)) ?? ""
    let isAutoDelete = (try? container.decode(String.self, forKey: .autodelete)) ?? "0"
    self.autoDelete = isAutoDelete == "1"
  }
}
