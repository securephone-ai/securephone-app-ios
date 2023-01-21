
import Foundation


/// JSON Object for **bb_get_read_receipts_groupmsg**
struct FetchReadReceiptsResponse: BBResponse {
  let answer: String
  let message: String
  let receipts: [MessageReceipt]
  
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case receipts
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    self.receipts = (try? container.decode([MessageReceipt].self, forKey: .receipts)) ?? [MessageReceipt]()
  }
}


struct MessageReceipt: Decodable {
  var recipient: String
  var dateReceived: Date?
  var dateRead: Date?
  var contact: BBContact?
  
  private enum CodingKeys : String, CodingKey {
    case recipient
    case dateReceived = "dtreceived"
    case dateRead = "dtread"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.recipient = (try? container.decode(String.self, forKey: .recipient)) ?? ""
    
    // Dates
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    var dateString = (try? container.decode(String.self, forKey: .dateReceived)) ?? ""
    self.dateReceived = dateFormatter.date(from: dateString)
    
    dateString = (try? container.decode(String.self, forKey: .dateRead)) ?? ""
    self.dateRead = dateFormatter.date(from: dateString) ?? nil
  }
  
  init(contact: BBContact, dateReceived: Date?, dateRead: Date?) {
    self.contact = contact
    self.recipient = contact.registeredNumber
    self.dateReceived = dateReceived
    self.dateRead = dateRead
  }
  
}
