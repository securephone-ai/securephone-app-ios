import Foundation
import Combine
import JGProgressHUD

class AddContactView: UIView {
  
  private var cancellableBag = Set<AnyCancellable>()
  private let viewModel: AddContactViewModel!
  
  private var rootView = UIView()
  
  private lazy var tableView: UITableView = {
    let table = UITableView()
    table.backgroundColor = .white
    table.delegate = self
    table.dataSource = self
    table.register(cellWithClass: AddContactNamesCell.self)
    table.register(cellWithClass: AddContactPhoneCell.self)
    table.tableFooterView = UIView()
    table.contentInset.top = 20
    table.allowsSelection = false
    return table
  }()
  
  private let titleLabel: UILabel = {
    let label = UILabel(text: "New Contact".localized())
    label.font = UIFont.appFontSemiBold(ofSize: 16)
    label.adjustsFontForContentSizeCategory = true
    label.frame = CGRect(x: 0, y: 0, width: 0, height: label.requiredHeight)
    return label
  }()
  
  private lazy var saveButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Save".localized(), for: .normal)
    button.titleLabel?.font = UIFont.appFont(ofSize: 16)
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.addTarget(self, action: #selector(savePressed), for: .touchUpInside)
    button.isEnabled = true
    return button
  }()
  
  private lazy var cancelButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Cancel".localized(), for: .normal)
    button.titleLabel?.font = UIFont.appFont(ofSize: 16)
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.addTarget(self, action: #selector(cancelPressed), for: .touchUpInside)
    return button
  }()
  
  init(viewModel: AddContactViewModel) {
    self.viewModel = viewModel
    super.init(frame: .zero)
    addSubview(rootView)
    rootView.addSubview(titleLabel)
    rootView.addSubview(saveButton)
    rootView.addSubview(cancelButton)
    rootView.addSubview(tableView)
    
    backgroundColor = .white
    titleLabel.text = viewModel.isEditing ? "Edit Contact".localized() : "New Contact".localized()
    self.viewModel.contactForm.$isSaveEnabled.receive(on: DispatchQueue.main).assign(to: \.isEnabled, on: saveButton).store(in: &cancellableBag)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    rootView.pin.all(pin.safeArea)
    titleLabel.pin.top(14).hCenter().sizeToFit(.content)
    saveButton.pin.end(16).vCenter(to: titleLabel.edge.vCenter).sizeToFit(.content)
    cancelButton.pin.start(16).vCenter(to: titleLabel.edge.vCenter).sizeToFit(.content)
    tableView.pin.below(of: titleLabel).marginTop(20).start().end().bottom(20)
  }
  
  func setTitle(title: String) {
    titleLabel.text = title
  }
  
}

extension AddContactView {
  @objc private func savePressed() {
    guard let viewController = findViewController() else { return }
    
    let hud = JGProgressHUD(style: .dark)
    let blackbox = Blackbox.shared
    if viewModel.isEditing == false {
      guard blackbox.getContact(registeredNumber: viewModel.contactForm.number) == nil else {
        let alertController = UIAlertController(title: "Error".localized(), message: "A Contact with the same Number is already present in your Contacts list.".localized(), preferredStyle: .alert)
        let action1 = UIAlertAction(title: "OK".localized(), style: .default, handler: nil)
        alertController.addAction(action1)
        viewController.present(alertController, animated: true, completion: nil)
        return
      }
      
      hud.show(in: AppUtility.getLastVisibleWindow())
      viewModel.addContact { [weak self] (errorString) in
        guard let strongSelf = self else { return }
        hud.dismiss()
        if let error = errorString {
          let alertController = UIAlertController(title: "Error".localized(), message: error, preferredStyle: .alert)
          let action1 = UIAlertAction(title: "OK".localized(), style: .default, handler: nil)
          alertController.addAction(action1)
          viewController.present(alertController, animated: true, completion: nil)
        }
        else {
          strongSelf.cancelPressed()
        }
      }
    }
    else {
      hud.show(in: AppUtility.getLastVisibleWindow())
      viewModel.updateContact { [weak self] (errorString) in
        guard let strongSelf = self else { return }
        hud.dismiss()
        if let error = errorString {
          let alertController = UIAlertController(title: "Error".localized(), message: error, preferredStyle: .alert)
          let action1 = UIAlertAction(title: "OK".localized(), style: .default, handler: nil)
          alertController.addAction(action1)
          viewController.present(alertController, animated: true, completion: nil)
        }
        else {
          strongSelf.cancelPressed()
        }
      }
    }
    
  }
  
  @objc private func cancelPressed() {
    guard let parentVC = findViewController() else { return }
    parentVC.dismiss(animated: true, completion: nil)
  }
}

extension AddContactView: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 2
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.row == 0 {
      return AddContactNamesCell.getRequiredHeight()
    }
    if indexPath.row == 1 {
      return AddContactPhoneCell.getRequiredHeight() + 10
    }
    return 0
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.row == 0 {
      let cell = tableView.dequeueReusableCell(withClass: AddContactNamesCell.self)
      cell.contactForm = viewModel.contactForm
      return cell
    }
    if indexPath.row == 1 {
      let cell = tableView.dequeueReusableCell(withClass: AddContactPhoneCell.self)
      cell.contactForm = viewModel.contactForm
      return cell
    }
    return UITableViewCell()
  }
}
