import Foundation
import DifferenceKit

struct BBContactsSection: Differentiable {
  var sectionInitial: String
  var contacts: [BBContact]
  var differenceIdentifier: String {
    return sectionInitial
  }
  
  func isContentEqual(to source: BBContactsSection) -> Bool {
    return contacts == contacts
  }
}
