
import Foundation

protocol BBResponse: Decodable {
    var answer: String { get }
    var message: String { get }
    func isSuccess() -> Bool
}

extension BBResponse {
    func isSuccess() -> Bool {
        return answer == "OK"
    }
}

///Base JSON object response for every message **{"answer" = "OK , "message"="xxxx""}
struct BaseResponse: BBResponse {
    let answer: String
    let message: String
    // Not every response return a token but most do, so we'll add it to the base response and set to empty if not present
    let id: String
    let msgid: String
    
    private enum CodingKeys : String, CodingKey {
        case answer
        case message
        case id
        case msgid
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
        self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
        self.id = (try? container.decode(String.self, forKey: .id)) ?? ""
        self.msgid = (try? container.decode(String.self, forKey: .msgid)) ?? ""
    }
}

