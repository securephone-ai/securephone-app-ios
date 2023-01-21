import Foundation
import UIKit

extension ChatView: ContactsPickerDelegate {
  func didSelect(items: [ContactItem]) {
    // Send Contacts
    items.forEach {
      logi($0.title)
    }
  }
}
