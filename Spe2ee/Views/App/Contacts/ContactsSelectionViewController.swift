import UIKit
import PinLayout
import Combine
import DeviceKit


class ContactsSelectionViewController: BBTableViewController {
  
  var cancellable: AnyCancellable?
  var rightButtonBar = UIBarButtonItem()
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .darkContent
  }
  
  //private lazy var groupedContacts = [(key: String, value: [BBContact])]()
  
  private var filteredContacts: [BBContact] = [BBContact]()
  
  private let searchController = UISearchController(searchResultsController: nil)
  var isSearchBarEmpty: Bool {
    return searchController.searchBar.text?.isEmpty ?? true
  }
  
  init() {
    super.init(nibName: nil, bundle: nil)
    
    self.cancellable = Blackbox.shared.$contactsSections.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (_) in
      guard let strongSelf = self else { return }
      strongSelf.tableView.reloadData()
    })
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.title = "Contacts".localized()
    
    rightButtonBar = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addContactPressed))
//    UIBarButtonItem(image: .add, landscapeImagePhone: .add, style: .plain, target: self, action: #selector(addContactPressed))
    navigationItem.rightBarButtonItem = rightButtonBar
    
    tableView.delegate = self
    tableView.dataSource = self
    tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.ID)
    tableView.contentInset.bottom = 30
    
    // Hide keyboard on single tap gesture
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
    gestureRecognizer.cancelsTouchesInView = false
    tableView.addGestureRecognizer(gestureRecognizer)
    
    self.tableView.backgroundColor = .white
    
    searchController.searchResultsUpdater = self as UISearchResultsUpdating
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "Search".localized()
    navigationItem.searchController = searchController
    
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Blackbox.shared.fetchContactsAsync(limitsearch: 10000, completion: nil)
    tableView.reloadData()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    navigationController?.navigationBar.prefersLargeTitles = true
    navigationItem.largeTitleDisplayMode = .automatic
    navigationController?.navigationBar.sizeToFit()
  }

  @objc private func addContactPressed() {
    present(AddContactViewController(), animated: true, completion: nil)
  }
}

extension ContactsSelectionViewController {
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    if isSearchBarEmpty == false {
      return 1
    }
    return Blackbox.shared.contactsSections.count
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    if section == 0 {
      return 0
    }
    return 30
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    if section == 0 {
      return UIView()
    }
    let view = UIView()
    view.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 30)
    view.backgroundColor = .systemGray5
    
    let label = UILabel()
    view.addSubview(label)
    label.text = isSearchBarEmpty ? Blackbox.shared.contactsSections[section].sectionInitial.uppercased() : "Search Results".localized()
    label.sizeToFit()
    label.pin.left(15).vCenter()
    
    return view
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if isSearchBarEmpty == false {
      return filteredContacts.count
    }
    
     return Blackbox.shared.contactsSections[section].contacts.count
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return ContactCell.getCellRequiredHeight()
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.ID, for: indexPath) as? ContactCell {
      if isSearchBarEmpty == false {
        let contact = filteredContacts[indexPath.row]
        cell.contactName.text = "\(contact.name) \(contact.surname)"
        cell.contactNumber.text = contact.registeredNumber
        cell.status.text = ""
        
        if let imagePath = contact.profilePhotoPath {
          cell.avatar.contentMode = .scaleAspectFill
          cell.avatar.image = UIImage.fromPath(imagePath)
        }
      } else {
        let contact = Blackbox.shared.contactsSections[indexPath.section].contacts[indexPath.row]
        cell.contactName.text = "\(contact.name) \(contact.surname)"
        cell.contactNumber.text = contact.registeredNumber
        cell.status.text = ""
        
        if let imagePath = contact.profilePhotoPath {
          cell.avatar.contentMode = .scaleAspectFill
          cell.avatar.image = UIImage.fromPath(imagePath)
        }
      }
      
      return cell
    }
    return UITableViewCell()
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    if isSearchBarEmpty {
      let contact = Blackbox.shared.contactsSections[indexPath.section].contacts[indexPath.row]

      // Open Contact Info
      let vc = ContactDetailsViewController(contact: contact)
      let navigation = UINavigationController(rootViewController: vc)
      navigation.modalPresentationStyle = .fullScreen
      self.present(navigation, animated: true, completion: nil)

    } else {
      let contact = filteredContacts[indexPath.row]
      // Open Contact Info
      let vc = ContactDetailsViewController(contact: contact)
      let navigation = UINavigationController(rootViewController: vc)
      navigation.modalPresentationStyle = .fullScreen
      self.present(navigation, animated: true, completion: nil)
    }
    
  }
  
}

extension ContactsSelectionViewController {
  @objc fileprivate func hideKeyboard() {
    searchController.searchBar.resignFirstResponder()
  }
}

extension ContactsSelectionViewController: AddNewContactViewControllerDelegate {
  func didAddContact(contact: BBContact) {
    //addContact(contact: contact)
    let vc = ContactDetailsViewController(contact: contact)
    let navigation = UINavigationController(rootViewController: vc)
    navigation.modalPresentationStyle = .fullScreen
    self.present(navigation, animated: true, completion: nil)
  }
}

// MARK: - Table Filter
extension ContactsSelectionViewController: UISearchResultsUpdating {
  
  func updateSearchResults(for searchController: UISearchController) {
    let searchBar = searchController.searchBar
    if let searchText = searchBar.text {
      DispatchQueue.main.async {
        if (searchText.isEmpty == false) {
          self.filteredContacts = Blackbox.shared.contactsSections.reduce(into: [BBContact](), {
            $0 = $1.contacts.filter({ (contact) -> Bool in
              contact.name.lowercased().contains(searchText.lowercased()) || contact.registeredNumber.contains(searchText)
            })
          })
        }
        self.tableView.reloadData()
      }
    }
  }
  
}
