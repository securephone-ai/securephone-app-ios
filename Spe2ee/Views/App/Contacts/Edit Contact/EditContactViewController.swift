import UIKit

class EditContactViewController: BBViewController {
  
  private let contact: BBContact!
  private lazy var rootView: AddContactView = {
    let view = AddContactView(viewModel: AddContactViewModel(contact: contact))
    return view
  }()
  
  init(contact: BBContact) {
    self.contact = contact
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    super.loadView()
    view = rootView
  }
}

