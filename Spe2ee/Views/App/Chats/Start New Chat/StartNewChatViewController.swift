import UIKit
import PinLayout
import Combine
import DeviceKit


enum ItemType {
  case newGroup
  case newContact
  case contact
}

class StartNewChatViewController: UIViewController {
  
  var rightButtonBar : UIBarButtonItem = UIBarButtonItem()
  
  var cancellable: AnyCancellable?
  
  //private lazy var groupedContacts = [(key: String, value: [BBContact])]()
  
  private var filteredContacts: [BBContact] = [BBContact]()
  
  private lazy var contactsTable: UITableView = {
    let table = UITableView()
    table.delegate = self
    table.dataSource = self
    table.register(ContactCell.self, forCellReuseIdentifier: ContactCell.ID)
    table.contentInset.bottom = 30
    
    // Hide keyboard on single tap gesture
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
    gestureRecognizer.cancelsTouchesInView = false
    table.addGestureRecognizer(gestureRecognizer)
    
    return table
  }()
  
  private lazy var searchBar: UISearchBar = {
    let searchBar:UISearchBar = UISearchBar()
    //searchBar.translatesAutoresizingMaskIntoConstraints = false
    searchBar.delegate = self
    return searchBar
  }()
  private var searchString = ""
  
  init() {
    super.init(nibName: nil, bundle: nil)
    
    self.cancellable = Blackbox.shared.$contactsSections.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (_) in
      guard let strongSelf = self else { return }
      strongSelf.contactsTable.reloadData()
    })
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.title = "New Chat".localized()
    
    self.view.backgroundColor = .white
    self.view.addSubview(searchBar)
    self.view.addSubview(contactsTable)
    
    rightButtonBar.title = "Cancel".localized()
    rightButtonBar.action = #selector(dismissView)
    rightButtonBar.target = self
    self.navigationItem.rightBarButtonItem = rightButtonBar
    
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    searchBar.pin.top(view.pin.safeArea.top).left().right().height(60)
    contactsTable.pin.below(of: searchBar).marginTop(4).left().right().bottom(view.pin.safeArea.bottom)
  }
  
  @objc func dismissView() {
    self.dismiss(animated: true, completion: nil)
  }
}

extension StartNewChatViewController: UITableViewDataSource, UITableViewDelegate {
  func numberOfSections(in tableView: UITableView) -> Int {
    if !searchString.isEmpty {
      return 1
    }
    return 1 + Blackbox.shared.contactsSections.count
  }
  
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    if section == 0 {
      return 0
    }
    return 30
  }
  
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    if section == 0 {
      return UIView()
    }
    let view = UIView()
    view.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 30)
    view.backgroundColor = .systemGray5
    
    let label = UILabel()
    view.addSubview(label)
    label.text = searchString.count == 0 ? Blackbox.shared.contactsSections[section-1].sectionInitial.uppercased() : "Search Results".localized()
    label.sizeToFit()
    label.pin.left(15).right(15).vCenter()
    
    return view
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if !searchString.isEmpty {
      return filteredContacts.count
    }
    
    if section == 0 {
      return 1
    } else {
      return Blackbox.shared.contactsSections[section-1].contacts.count
    }
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
     return ContactCell.getCellRequiredHeight()
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.ID, for: indexPath) as? ContactCell {
      if searchString.isEmpty == false {
        cell.contactName.text = "\(filteredContacts[indexPath.row].name) \(filteredContacts[indexPath.row].surname)"
      } else {
        if indexPath.section == 0 {
          cell.avatar.tintColor = .link
          if indexPath.row == 0 {
            cell.avatar.image = UIImage(systemName: "person.3.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .medium))
            cell.avatar.contentMode = .center
            cell.contactName.text = "New Group".localized()
          } else {
            cell.avatar.image = UIImage(systemName: "person.badge.plus.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large))
            cell.avatar.contentMode = .center
            cell.contactName.text = "New Contact".localized()
          }
          cell.contactNumber.text = ""
        } else {
          let contact = Blackbox.shared.contactsSections[indexPath.section-1].contacts[indexPath.row]
          cell.contactName.text = "\(contact.name) \(contact.surname)"
          cell.contactNumber.text = contact.registeredNumber
          cell.status.text = ""
          
          if let imagePath = contact.profilePhotoPath {
            cell.avatar.contentMode = .scaleAspectFill
            cell.avatar.image = UIImage.fromPath(imagePath)
          }
        }
      }
      
      return cell
    }
    return UITableViewCell()
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    if searchString.isEmpty {
      if indexPath.section == 0 {
        if indexPath.row == 0 {
          navigationController?.pushViewController(SelectGroupChatMembersViewController(), animated: true)
        } else if indexPath.row == 1 {
          let vc = AddNewContactViewController(contact: nil)
          let device = Device.current
          vc.delegate = self
          let navController = UINavigationController(rootViewController: vc)
          if !device.hasSensorHousing {
            navController.modalPresentationStyle = .fullScreen
          }
          self.present(navController, animated: true, completion: nil)
        }
      } else {
        let contact = Blackbox.shared.contactsSections[indexPath.section-1].contacts[indexPath.row]
        Blackbox.shared.openChat(contact: contact)
      }
    } else {
      let contact = filteredContacts[indexPath.row]
      Blackbox.shared.openChat(contact: contact)
    }
  }
   
}

extension StartNewChatViewController {
  @objc fileprivate func hideKeyboard() {
    searchBar.resignFirstResponder()
  }
}

extension StartNewChatViewController: AddNewContactViewControllerDelegate {
  func didAddContact(contact: BBContact) {
    //addContact(contact: contact)
    let vc = ContactDetailsViewController(contact: contact)
    let navigation = UINavigationController(rootViewController: vc)
    navigation.modalPresentationStyle = .fullScreen
    self.present(navigation, animated: true, completion: nil)
  }
}

extension StartNewChatViewController: UISearchBarDelegate {
  // MARK: - UISearchBarDelegate
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    DispatchQueue.main.async {
      self.searchString = searchText
      if (searchText.isEmpty) {
        self.perform(#selector(self.hideKeyboardWithSearchBar(_:)), with: searchBar, afterDelay: 0)
        self.searchString = ""
      } else {
        
        self.filteredContacts.removeAll()
        Blackbox.shared.contactsSections.forEach { (contactsSection) in
          for contact in contactsSection.contacts where contact.name.lowercased().contains(self.searchString.lowercased()) {
            self.filteredContacts.append(contact)
          }
        }
      }
      self.contactsTable.reloadData()
    }
  }
  
  @objc func hideKeyboardWithSearchBar(_ searchBar:UISearchBar){
    searchBar.resignFirstResponder()
  }
  
  func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool{
    return true
  }
}

extension StartNewChatViewController: ContactsPickerDelegate {
  func didSelect(items: [ContactItem]) {
    // Comes from group selection
  }
}

extension StartNewChatViewController: ContactsPickerDataSource {
  func getItem(at indexPath: IndexPath) -> ContactItem {
    let spe2eeContact = Blackbox.shared.contactsSections[indexPath.section].contacts[indexPath.row]
    
    let contactItem = ContactItem(row: indexPath.row, spe2eeContact: spe2eeContact )
    return contactItem
  }
  
  func contactPickerRows(forSection section: Int) -> Int {
    return Blackbox.shared.contactsSections[section].contacts.count
  }
  
  func numberOfSectionsContactsPicker() -> Int {
    return Blackbox.shared.contactsSections.count
  }
}
