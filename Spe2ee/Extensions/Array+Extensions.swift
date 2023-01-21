import Foundation
import UIKit
import Combine

extension Set where Element : AnyCancellable {
  
  func cancellAll() {
    for item in self {
      item.cancel()
    }
  }
  
  mutating func cancellAndRemoveAll() {
    cancellAll()
    self.removeAll()
  }
  
}
