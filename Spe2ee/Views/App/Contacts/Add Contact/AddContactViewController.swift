import UIKit

class AddContactViewController: BBViewController {

  private let viewModel = AddContactViewModel(contact: nil)
  private lazy var rootView: AddContactView = { return AddContactView(viewModel: viewModel) }()
  
  override func loadView() {
    super.loadView()
    view = rootView
  }
  
}
