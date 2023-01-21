import UIKit
import Combine
import SCLAlertView



//struct NamesFields {
//  var prefix: String = ""
//  var firstName: String = ""
//  var phoneticFirstName: String = ""
//  var middleName: String = ""
//  var phoneticMiddleName: String = ""
//  var lastName: String = ""
//  var phoneticLastName: String = ""
//  var maidenName: String = ""
//  var suffix: String = ""
//  var nickname: String = ""
//}

protocol AddNewContactViewControllerDelegate: class {
  func didAddContact(contact: BBContact)
}

class AddNewContactViewController: UIViewController {
  weak var delegate: AddNewContactViewControllerDelegate?
  
  //private var contact: BBContactForm = BBContactForm()
  public var viewModel: AddNewContactViewModel = AddNewContactViewModel()
  private var isMoreFieldsVisible: Bool = true
  private var isDeleteVisible: Bool = false
  private var keyboardHeight: CGFloat = 0
  
  private var cancellableBag = Set<AnyCancellable>()
  
  private var leftButtonBar = UIBarButtonItem()
  private var rightButtonBar = UIBarButtonItem()
  
  private lazy var formTable: UITableView = {
    let table = UITableView()
    table.backgroundColor = .white
    table.delegate = self
    table.dataSource = self
    table.register(FormNamesCell.self, forCellReuseIdentifier: FormNamesCell.ID)
    table.register(FormPhoneCell.self, forCellReuseIdentifier: FormPhoneCell.ID)
    table.register(FormBaseCell.self, forCellReuseIdentifier: FormBaseCell.ID)
    table.register(FormAddressCell.self, forCellReuseIdentifier: FormAddressCell.ID)
    table.register(FormDateCell.self, forCellReuseIdentifier: FormDateCell.ID)
    table.register(FormBirthdayCell.self, forCellReuseIdentifier: FormBirthdayCell.ID)
    table.tableFooterView = UIView()
    table.contentInset.top = 20
    return table
  }()
    
  var lastIndexPath: IndexPath {
    return IndexPath(row: formTable.numberOfRows(inSection: 0)-1, section: 0)
  }
  var secondLastPath: IndexPath {
    return IndexPath(row: formTable.numberOfRows(inSection: 0)-2, section: 0)
  }
  
  init(contact: BBContact?, updateContact: Bool = false) {
    super.init(nibName: nil, bundle: nil)
    if let contact = contact {
      viewModel = AddNewContactViewModel(contact: contact)
      isDeleteVisible = true
      viewModel.updateContact = updateContact && contact.isSavedContact
    } else {
      viewModel = AddNewContactViewModel(contact: BBContact())
      viewModel.updateContact = updateContact
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    
    // As of iOS 9 and later, no need to remove the observer
    // https://developer.apple.com/documentation/foundation/notificationcenter/1407263-removeobserver
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    
    self.title = "New Contact".localized()
    view.addSubview(formTable)
    
    leftButtonBar = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissView))
    rightButtonBar = UIBarButtonItem(title: "Save".localized(), style: .plain, target: self, action: #selector(saveContact))
    rightButtonBar.isEnabled = true
    viewModel.$isSaveEnabled.receive(on: DispatchQueue.main).assign(to: \.isEnabled, on: rightButtonBar).store(in: &cancellableBag)
    self.navigationItem.rightBarButtonItem = rightButtonBar
    self.navigationItem.leftBarButtonItem = leftButtonBar
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    formTable.pin
      .left(view.pin.safeArea.left)
      .right(view.pin.safeArea.right)
      .top(view.pin.safeArea.top)
      .bottom(keyboardHeight > 0 ? keyboardHeight+view.pin.safeArea.bottom : view.pin.safeArea.bottom)

  }
  
  @objc private func keyboardWillChangeFrame(_ notification: Notification) {
    if let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
      let newHeight = UIScreen.main.bounds.height - endFrame.origin.y - view.safeAreaInsets.bottom
      if newHeight != keyboardHeight {
        keyboardHeight = newHeight <= 0 ? 0 : newHeight
        keyboardHeight += 10
        formTable.pin.top().bottom(keyboardHeight > 0 ? keyboardHeight+view.pin.safeArea.bottom : view.pin.safeArea.bottom)
      }
    }
  }
  
  @objc func dismissView() {
    dismiss(animated: true, completion: nil)
  }
  
  @objc func saveContact() {
    var contact = viewModel.getContact()
    
    if viewModel.updateContact {
      Blackbox.shared.updateContactAsync(contact: contact) { (_contact, error) in
        if error != nil {
          // TODO: Hanle Errors
          loge(error!)
          return
        }
        guard let cont = _contact else { return }
        contact = cont
        
        self.dismiss(animated: true, completion: nil)
        
        guard let delegate = self.delegate else { return }
        delegate.didAddContact(contact: contact)
      }
    } else {
      Blackbox.shared.addContactAsync(contact: contact) { (_contact, error) in
        if error != nil {
          // TODO: Hanle Errors
          loge(error!)
          return
        }
        guard let cont = _contact else { return }
        contact = cont
        
        self.dismiss(animated: true, completion: nil)
        
        guard let delegate = self.delegate else { return }
        delegate.didAddContact(contact: contact)
      }
    }
  }
}

extension AddNewContactViewController: UITableViewDataSource {
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath == lastIndexPath {
      return 46
    }
    if isDeleteVisible, indexPath == secondLastPath  {
      if indexPath == lastIndexPath || indexPath == secondLastPath {
        return 46
      }
    }
    
    switch viewModel.formItems[indexPath.row] {
    case .address(_):
      return FormAddressCell.totalHeight
    case .phone(_):
      return FormPhoneCell.totalHeight
    case .names:
      return FormNamesCell.calculateHeight(viewModel: viewModel)
    default:
      return FormBaseCell.totalHeight
    }
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    var count = viewModel.formItems.count + 1
    count = isDeleteVisible ? count+1 : count
    return count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if isDeleteVisible {
      if indexPath == lastIndexPath {
        // last cell
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.textColor = .red
        cell.textLabel?.text = "Delete Contact".localized()
        cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
        return cell
      }
      
      if indexPath == secondLastPath {
        // last cell
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.textColor = .link
        cell.textLabel?.text = isMoreFieldsVisible ? "more fields".localized() : "add other field".localized()
        cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
        return cell
      }
    } else if indexPath == lastIndexPath {
      // last cell
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.textColor = .link
      cell.textLabel?.text = isMoreFieldsVisible ? "more fields".localized() : "add other field".localized()
      cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
      return cell
    }
    
    let item = viewModel.formItems[indexPath.row]
    let contact = viewModel.contact
    
    switch item {
    case .names:
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormNamesCell.ID, for: indexPath) as? FormNamesCell {
        cell.viewModel = viewModel
        return cell
      }
    case .jobTitle:
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormBaseCell.ID, for: indexPath) as? FormBaseCell {
        cell.title.text = "Job title".localized()
        cell.cancellableTextField.textField.placeholder = "Job title".localized()
        cell.cancellableTextField.textField.text = contact.jobtitle.count > 0 ? contact.jobtitle : ""
        cell.cancellable = cell.cancellableTextField.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.jobtitle, on: contact)
        return cell
      }
    case .department:
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormBaseCell.ID, for: indexPath) as? FormBaseCell {
        cell.title.text = "Department".localized()
        cell.cancellableTextField.textField.placeholder = "Department".localized()
        cell.cancellableTextField.textField.text = contact.department.count > 0 ? contact.department : ""
        cell.cancellable = cell.cancellableTextField.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.department, on: contact)
        return cell
      }
    case .company:
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormBaseCell.ID, for: indexPath) as? FormBaseCell {
        cell.title.text = "Company".localized()
        cell.cancellableTextField.textField.placeholder = "Company".localized()
        cell.cancellableTextField.textField.text = contact.companyname.count > 0 ? contact.companyname : ""
        cell.cancellable = cell.cancellableTextField.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.companyname, on: contact)
        return cell
      }
    case .phoneticCompanyName:
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormBaseCell.ID, for: indexPath) as? FormBaseCell {
        cell.title.text = "Phonetic company name".localized()
        cell.cancellableTextField.textField.placeholder = "Phonetic company name".localized()
        cell.cancellableTextField.textField.text = contact.phoneticcompanyname.count > 0 ? contact.phoneticcompanyname : ""
        cell.cancellable = cell.cancellableTextField.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.phoneticcompanyname, on: contact)
        return cell
      }
    case .phone(let phoneNumber):
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormPhoneCell.ID, for: indexPath) as? FormPhoneCell {
        cell.phoneNumber = phoneNumber
        cell.viewController = self
        return cell
      }
    case .email(let email):
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormBaseCell.ID, for: indexPath) as? FormBaseCell {
        cell.title.text = "Email".localized()
        cell.cancellableTextField.textField.placeholder = "Email".localized()
        cell.cancellableTextField.textField.text = email.email.count > 0 ? email.email : ""
        cell.cancellable = cell.cancellableTextField.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.email, on: email)
        return cell
      }
    case .address(let addressJson):
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormAddressCell.ID, for: indexPath) as? FormAddressCell {
        cell.addressJson = addressJson
        cell.viewController = self
        return cell
      }
    case .url(let urljson):
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormBaseCell.ID, for: indexPath) as? FormBaseCell {
        cell.title.text = "URL".localized()
        cell.cancellableTextField.textField.placeholder = "URL".localized()
        cell.cancellableTextField.textField.text = urljson.url.count > 0 ? urljson.url : ""
        cell.cancellable = cell.cancellableTextField.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.url, on: urljson)
        return cell
      }
    case .birthday:
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormBirthdayCell.ID, for: indexPath) as? FormBirthdayCell {
        cell.title.text = "Birthday".localized()
        cell.dateField.textField.placeholder = "Birthday".localized()

        cell.cancellable = cell.dateField.textField.textPublisher.receive(on: DispatchQueue.main).map({ (str) -> String in
          let formatter = DateFormatter()
          formatter.dateFormat = "MMMM dd, yyyy"
          if let date = formatter.date(from: str) {
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let str = formatter.string(from: date)
            return str
          }
          return ""
        }).assign(to: \.birthday, on: contact)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if contact.birthday.count > 0, let date = formatter.date(from: contact.birthday) {
          formatter.dateFormat = "MMMM dd, yyyy"
          let str = formatter.string(from: date)
          cell.dateField.setText(text: str)
          cell.dateButton.setTitle(str, for: .normal)
        } else {
          let formatter = DateFormatter()
          // initially set the format based on your datepicker date / server String
          formatter.dateFormat = "MMMM d, yyyy"
          let dateStr = formatter.string(from: Date()) // string purpose I add here
          cell.dateField.setText(text: dateStr)
          cell.dateButton.setTitle(dateStr, for: .normal)
        }
        
        return cell
      }
    case .date(let date):
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormDateCell.ID, for: indexPath) as? FormDateCell {
        cell.dateJson = date
        cell.viewController = self
        return cell
      }
    case .socialProfile(let profile):
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormBaseCell.ID, for: indexPath) as? FormBaseCell {
        cell.title.text = "Social profile".localized()
        cell.cancellableTextField.textField.placeholder = "Social profile".localized()
        cell.cancellableTextField.textField.text = profile.url.count > 0 ? profile.url : ""
        cell.cancellable = cell.cancellableTextField.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.url, on: profile)
        return cell
      }
    case .instantMessage(let IM):
      if let cell = tableView.dequeueReusableCell(withIdentifier: FormBaseCell.ID, for: indexPath) as? FormBaseCell {
        cell.title.text = "Instant message".localized()
        cell.cancellableTextField.textField.placeholder = "Instant message".localized()
        cell.cancellableTextField.textField.text = IM.url.count > 0 ? IM.url : ""
        cell.cancellable = cell.cancellableTextField.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.url, on: IM)
        return cell
      }
    }
    
    return UITableViewCell()
  }
  
}

extension AddNewContactViewController: UITableViewDelegate {
  func addFormItem(item: FormCellType) {
    viewModel.formItems.append(item)
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if isDeleteVisible {
      if indexPath == lastIndexPath {

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: "Delete".localized(), style: .destructive) { _ in
          Blackbox.shared.deleteContactAsync(self.viewModel.getContact()) { (success) in
            DispatchQueue.main.async { [weak self] in
              guard let strongSelf = self else { return }
              if success {
                strongSelf.dismissView()
              } else {
                SCLAlertView().showError("Error".localized(), subTitle: "Delete contact unable to execute".localized())
              }
            }
          }
        }
        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
        
        alertController.addAction(deleteAction)
        alertController.addAction(cancel)
        
        self.present(alertController, animated: true, completion: nil)
      } else if indexPath == secondLastPath {
        addFields()
      }
    } else if lastIndexPath == indexPath  {
      addFields()
    }
  }
  
  func addFields() {
    if isMoreFieldsVisible {
      isMoreFieldsVisible = false
      
      viewModel.addItem(type: .company)
      viewModel.addItem(type: .email(EmailJson()))
      viewModel.addItem(type: .address(AddressJson()))
      
      formTable.reloadData()
      
    } else {
      let vc = ContactFormAddField(viewModel: viewModel)
      vc.delegate = self
      let navigation = UINavigationController(rootViewController: vc)
      navigation.modalPresentationStyle = .fullScreen
      present(navigation, animated: true, completion: nil)
    }
  }
}

extension AddNewContactViewController: ContactFormAddFieldDelegate {
  func didAddField(field: String) {
    // Names fields
    if field == "Prefix".localized() {
      viewModel.isPrefixVisible = true
    }
    if field == "Phonetic first name".localized() {
      viewModel.isPhoneticNameVisible = true
    }
    if field == "Middle name".localized() {
      viewModel.isMiddlenameVisible = true
    }
    if field == "Phonetic middle name".localized() {
      viewModel.isPhoneticMiddlenameVisible = true
    }
    if field == "Phonetic last name".localized() {
      viewModel.isPhoneticSurnameVisible = true
    }
    if field == "Maiden name".localized() {
      viewModel.isMaidennameVisible = true
    }
    if field == "Suffix".localized() {
      viewModel.isSuffixVisible = true
    }
    if field == "Nickname".localized() {
      viewModel.isNicknameVisible = true
    }
    
    // Job fiels
    if field == "Job title".localized() {
      viewModel.addItem(type: .jobTitle)
      viewModel.isJobtitleVisible = true
    }
    if field == "Department".localized() {
      viewModel.addItem(type: .department)
      viewModel.isDepartmentVisible = true
    }
    if field == "Phonetic company name".localized() {
      viewModel.addItem(type: .phoneticCompanyName)
      viewModel.isPhoneticCompanyNameVisible = true
    }
    
    // last section
    if field == "Phone".localized() {
      viewModel.addItem(type: .phone(PhoneJson()))
    }
    if field == "Email".localized() {
      viewModel.addItem(type: .email(EmailJson()))
    }
    if field == "Address".localized() {
      viewModel.addItem(type: .address(AddressJson()))
    }
    if field == "URL".localized() {
      viewModel.addItem(type: .url(UrlJson()))
    }
    if field == "Birthday".localized() {
      viewModel.isBirthdayVisible = true
      viewModel.addItem(type: .birthday)
    }
    if field == "Date".localized() {
      viewModel.addItem(type: .date(DateJson()))
    }
    if field == "Social profile".localized() {
      viewModel.addItem(type: .socialProfile(SocialProfileJson()))
    }
    if field == "Instant message".localized() {
      viewModel.addItem(type: .instantMessage(InstantMessageJson()))
    }
    
    formTable.reloadData()
  }
}
