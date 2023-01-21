import UIKit
import SCLAlertView
import NextLevel
import AVFoundation
import Combine
import JGProgressHUD


enum ContactCellType {
  case names
  case phones
  case emails
  case addresses
  case urls
  case birthday
  case dates
  case socialProfiles
  case instantMessages
}

class ContactDetailsViewController: UITableViewController {
  
  var contact: BBContact!
  var items : [ContactCellType] = [ .names ]
  var items2 = [(section:Int, item: [ContactCellType])]()
  
  private var cancellableBag = Set<AnyCancellable>()
  
  // Nav bar buttons
  var leftButtonBar = UIBarButtonItem()
  var rightButtonBar = UIBarButtonItem()
  
  private lazy var contactProfileImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.image = UIImage(systemName: "person.fill")?.withAlignmentRectInsets(UIEdgeInsets(top: -50, left: -50, bottom: -50, right: -50))
    return imageView
  }()
  
  private lazy var footerView: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 56))
    view.addSubview(deleteButton)
    deleteButton.pin.sizeToFit(.content).center()
    return view
  }()
  
  private lazy var deleteButton: UIButton = {
    let button = UIButton(type: .system)
    view.addSubview(button)
    button.setTitle("Delete", for: .normal)
    button.setTitleColor(.red, for: .normal)
    button.titleLabel?.font = UIFont.appFont(ofSize: 18)
    button.addTarget(self, action: #selector(deleteButtonPressed), for: .touchUpInside)
    return button
  }()
  
  init(contact: BBContact) {
    self.contact = contact
    
    super.init(nibName: nil, bundle: nil)
    
    if contact.phonesjson.count > 0 {
      items.append(.phones)
    }
    if contact.emailsjson.count > 0 {
      items.append(.emails)
    }
    if contact.urlsjson.count > 0 {
      items.append(.urls)
    }
    if contact.addressesjson.count > 0 {
      items.append(.addresses)
    }
    if contact.birthday.isEmpty == false {
      items.append(.birthday)
    }
    if contact.datesjson.count > 0 {
      items.append(.dates)
    }
    if contact.instantmessagesjson.count > 0 {
      items.append(.instantMessages)
    }
    if contact.socialprofilesjson.count > 0 {
      items.append(.socialProfiles)
    }
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

    title = "Contact Details".localized()
    
    tableView.backgroundColor = .systemGray6
    tableView.tableFooterView = UIView()
    tableView.parallaxHeader.view = contactProfileImageView
    tableView.parallaxHeader.height = 380
    tableView.parallaxHeader.mode = .centerFill
    tableView.parallaxHeader.minimumHeight = 0
    tableView.contentInset.bottom = 40
    tableView.register(ContactDetailsNamesCell.self, forCellReuseIdentifier: ContactDetailsNamesCell.ID)
    tableView.register(ContactDetailsMobileCell.self, forCellReuseIdentifier: ContactDetailsMobileCell.ID)
    tableView.register(ContactDetailsEmailCell.self, forCellReuseIdentifier: ContactDetailsEmailCell.ID)
    tableView.register(ContactDetailsAddressCell.self, forCellReuseIdentifier: ContactDetailsAddressCell.ID)
    tableView.register(ContactDetailsBaseCell.self, forCellReuseIdentifier: ContactDetailsBaseCell._ID)
    
    tableView.tableFooterView = footerView
    
    leftButtonBar = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneClick))
    rightButtonBar = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editClick))
    self.navigationItem.leftBarButtonItem = leftButtonBar
    self.navigationItem.rightBarButtonItem = rightButtonBar
      
    if let path = contact.profilePhotoPath {
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path, isDirectory: false))
        contactProfileImageView.image = UIImage(data: data)
        //        tableView.contentOffset.y = 100
      } catch {
        loge(error)
      }
    }
    
    contact.$profilePhotoPath.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (imagePath) in
      guard let strongSelf = self else { return }
      if let path = imagePath, let image = UIImage.fromPath(path) {
        strongSelf.contactProfileImageView.image = image
      } else {
        // Now assign image from asset catalogue & inset image
        strongSelf.contactProfileImageView.image = UIImage(systemName: "person.fill")?.withAlignmentRectInsets(UIEdgeInsets(top: -50, left: -50, bottom: -50, right: -50))
      }
    }).store(in: &cancellableBag)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Blackbox.shared.currentViewController = self
    
    if contact.registeredNumber.isEmpty {
      // Get started
      SCLAlertView().showInfo("Invalid contact", subTitle: "The contact number just added is not registered within the system, therefore it will not be displayed.")
    }
    
    tableView.reloadData()
  }
  
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    deleteButton.pin.center()
  }
  
  // MARK: - Table view data source
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    if section == 0 {
      return 0
    }
    return 30
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let view = UIView()
    view.isUserInteractionEnabled = false
    return view
  }
  
  @objc private func deleteButtonPressed() {
    let hud = JGProgressHUD(style: .dark)
    hud.show(in: AppUtility.getLastVisibleWindow())
    Blackbox.shared.deleteContactAsync(contact) { (success) in
      DispatchQueue.main.async { [weak self] in
        guard let strongSelf = self else { return }
        hud.dismiss()
        strongSelf.dismiss(animated: true, completion: nil)
      }
    }
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    let item = items[indexPath.section]
    switch item {
    case .names:
      return ContactDetailsNamesCell.calculateHeight(contact: contact!)
    case .addresses:
      return 86
    default:
      return 66
    }
  }
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return items.count
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
  
    let item = items[section]
    switch item {
    case .addresses:
      return contact.addressesjson.count
    case .birthday, .names:
      return 1
    case .dates:
      return contact.datesjson.count
    case .emails:
      return contact.emailsjson.count
    case .instantMessages:
      return contact.instantmessagesjson.count
    case .socialProfiles:
      return contact.socialprofilesjson.count
    case .phones:
      return contact.phonesjson.count
    case .urls:
      return contact.urlsjson.count
    }
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let item = items[indexPath.section]
    
    switch item {
    case .names:
      if let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailsNamesCell.ID) as? ContactDetailsNamesCell {
        cell.contact = contact
        return cell
      }
    case .phones:
      if let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailsMobileCell.ID) as? ContactDetailsMobileCell {
        cell.phoneNumber = contact.phonesjson[indexPath.row]
        cell.chatButton.addTarget(self, action: #selector(openChat), for: .touchUpInside)
        cell.videoCallButton.addTarget(self, action: #selector(videoCall), for: .touchUpInside)
        cell.callButton.addTarget(self, action: #selector(call), for: .touchUpInside)
        return cell
      }
    case .emails:
      if let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailsEmailCell.ID) as? ContactDetailsEmailCell {
        cell.email = contact.emailsjson[indexPath.row]
        return cell
      }
    case .urls:
      if let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailsBaseCell._ID) as? ContactDetailsBaseCell {
        cell.fieldNameLabel.text = contact.urlsjson[indexPath.row].tag
        cell.fieldNameLabel.sizeToFit()
        cell.fieldValueLabel.text = contact.urlsjson[indexPath.row].url
        cell.fieldValueLabel.sizeToFit()
        return cell
      }
    case .addresses:
      if let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailsAddressCell.ID) as? ContactDetailsAddressCell {
        let address = contact.addressesjson[indexPath.row]
        cell.fieldNameLabel.text = "Address".localized()
        cell.streetLabel.text = "\(address.street)"
        cell.countryLabel.text = "\(address.zip) \(address.city) \(address.state) \(address.country)"
        return cell
      }
    case .birthday:
      if let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailsBaseCell._ID) as? ContactDetailsBaseCell {
        cell.fieldNameLabel.text = "Birthday".localized().lowercased()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if contact.birthday.count > 0, let date = formatter.date(from: contact.birthday) {
          formatter.dateFormat = "MMMM dd, yyyy"
          cell.fieldValueLabel.text = formatter.string(from: date)
        }
        cell.fieldValueLabel.sizeToFit()
        cell.fieldNameLabel.sizeToFit()
        return cell
      }
    case .dates:
      if let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailsBaseCell._ID) as? ContactDetailsBaseCell {
        cell.fieldNameLabel.text = contact.datesjson[indexPath.row].tag
        cell.fieldValueLabel.text = contact.datesjson[indexPath.row].date
        cell.fieldValueLabel.sizeToFit()
        cell.fieldNameLabel.sizeToFit()
        return cell
      }
    case .instantMessages:
      if let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailsBaseCell._ID) as? ContactDetailsBaseCell {
        cell.fieldNameLabel.text = contact.instantmessagesjson[indexPath.row].tag
        cell.fieldValueLabel.text = contact.instantmessagesjson[indexPath.row].url
        cell.fieldValueLabel.sizeToFit()
        cell.fieldNameLabel.sizeToFit()
        return cell
      }
    case .socialProfiles:
      if let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailsBaseCell._ID) as? ContactDetailsBaseCell {
        cell.fieldNameLabel.text = contact.socialprofilesjson[indexPath.row].tag
        cell.fieldValueLabel.text = contact.socialprofilesjson[indexPath.row].url
        cell.fieldValueLabel.sizeToFit()
        cell.fieldNameLabel.sizeToFit()
        return cell
      }
    }
    
    return UITableViewCell()
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
  }
 
}

extension ContactDetailsViewController {
  @objc func doneClick() {
    dismiss(animated: true, completion: nil)
  }
  
  @objc func editClick() {
//    let vc = AddNewContactViewController(contact: contact, updateContact: true)
//    vc.delegate = self
//    let navigation = UINavigationController(rootViewController: vc)
//    navigation.modalPresentationStyle = .fullScreen
//    self.present(navigation, animated: true, completion: nil)
    let vc = EditContactViewController(contact: contact)
    vc.modalPresentationStyle = .fullScreen
    self.present(vc, animated: true, completion: nil)
  }
  
  @objc func openChat() {
    
    if let navigation = navigationController, let chatIndex = navigation.viewControllers.firstIndex(where: { (vc) -> Bool in
      if let chatVC = vc as? ChatViewController, let chatViewModel = chatVC.viewModel, let chatContact = chatViewModel.contact, chatContact.registeredNumber == contact.registeredNumber {
        return true
      }
      return false
    }) {
      navigation.popToViewController(navigation.viewControllers[chatIndex], animated: true)
    } else {
      Blackbox.shared.openChat(contact: contact)
    }
   
  }
  
  @objc func call() {
    Blackbox.shared.callManager.startCall(contact: contact)
  }
  
  @objc func videoCall() {
    if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized {
      Blackbox.shared.callManager.startCall(contact: contact, video: true)
    } else {
      NextLevel.requestAuthorization(forMediaType: AVMediaType.video) { (mediaType, status) in
        if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized {
          DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) { [weak self] in
            guard let strongSelf = self else { return }
            Blackbox.shared.callManager.startCall(contact: strongSelf.contact, video: true)
          }
        } else if status == .notAuthorized {
          // gracefully handle when audio/video is not authorized
          AppUtility.camDenied(viewController: self)
        }
      }
    }
  }
}


extension ContactDetailsViewController: AddNewContactViewControllerDelegate {
  func didAddContact(contact: BBContact) {
    self.contact = contact
    self.tableView.reloadData()
  }
}
