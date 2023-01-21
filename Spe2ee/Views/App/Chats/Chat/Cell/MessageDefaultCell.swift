import Foundation
import Combine

class MessageDefaultCell: UITableViewCell {
  open var cancellableBag = Set<AnyCancellable>()
  open var viewModel: MessageViewModel!
}
