import UIKit
import Combine

class SelectGroupChatMembersViewController: UIViewController {
  
  // Searched string
  var searchString  = ""
  var cancellable: AnyCancellable?
  private var selectedContacts = [BBContact]()
  private var filteredContacts = [BBContact]()
  
  // Nav bar buttons
  var leftButtonBar = UIBarButtonItem()
  var rightButtonBar = UIBarButtonItem()
  
  private lazy var contentView: ContactsPickerView = {
    let view = ContactsPickerView()
    view.tableView.delegate = self
    view.tableView.dataSource = self
    view.tableView.register(ContactsPickerTableCell.self, forCellReuseIdentifier: ContactsPickerTableCell.ID)
    view.tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.ID)
    view.selectionScrollView.delegate = self
    view.selectionScrollView.dataSource = self
    view.selectionScrollView.register(ContactsPickerHeaderCollectionCell.self, forCellWithReuseIdentifier: ContactsPickerHeaderCollectionCell.ID)
    view.searchBar.delegate = self
    return view
  }()
  
  var isSearchBarEmpty: Bool {
    return contentView.searchBar.text?.isEmpty ?? true
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    
    leftButtonBar = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissView))
    rightButtonBar = UIBarButtonItem(title: "Next".localized(), style: .plain, target: self, action: #selector(nextClick))
    rightButtonBar.isEnabled = false
    self.navigationItem.leftBarButtonItem = leftButtonBar
    self.navigationItem.rightBarButtonItem = rightButtonBar
    
    self.cancellable = Blackbox.shared.$contactsSections.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (_) in
      guard let strongSelf = self else { return }
      strongSelf.contentView.tableView.reloadData()
    })
    
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    contentView.tableView.reloadData()
    contentView.selectionScrollView.reloadData()
  }
  
  override func loadView() {
    view = contentView
  }
  
  @objc func dismissView() {
    if isModal {
      self.dismiss(animated: true, completion: nil)
    } else {
      self.navigationController?.popViewController(animated: true)
    }
  }
  
  @objc func nextClick() {
    // GO NEXT PAGE
    let vc = CreateNewGroupViewController(members: selectedContacts)
    vc.delegate = self
    self.navigationController?.pushViewController(vc, animated: true)
  }
  
  func updateMembersView() {
    if selectedContacts.count <= 1 {
      contentView.selectionScrollViewHeight = selectedContacts.count == 0 ? CGFloat.zero : 84
      
      rightButtonBar.isEnabled = selectedContacts.count == 0 ? false : true
      UIView.animate(withDuration: 0.2) {
        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()
      }
    }
  }
  
}

extension SelectGroupChatMembersViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 30
  }
  
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let view = UIView()
    view.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 30)
    view.backgroundColor = .systemGray5
    
    let label = UILabel()
    view.addSubview(label)
    
    if searchString.count > 0 {
      label.text = "Search Results".localized()
    } else {
      label.text = Blackbox.shared.contactsSections[section].sectionInitial
    }
    label.pin.left(15).right(15).top().bottom()
    
    return view
  }
  
  func numberOfSections(in tableView: UITableView) -> Int {
    if searchString.isEmpty {
      return Blackbox.shared.contactsSections.count
    }
    return 1
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return ContactCell.getCellRequiredHeight()
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if searchString.isEmpty {
      return Blackbox.shared.contactsSections[section].contacts.count
    }
    return filteredContacts.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    //Get Reference to Cell
//    let cell: ContactsPickerTableCell = self.contentView.tableView.dequeueReusableCell(withIdentifier: ContactsPickerTableCell.ID) as! ContactsPickerTableCell
//    cell.selectionStyle = .none
//
//    var contact: BBContact!
//
//    if !searchString.isEmpty {
//      contact = filteredContacts[indexPath.row]
//    } else {
//      contact = Blackbox.shared.contactsSections[indexPath.section].contacts[indexPath.row]
//    }
//
//    //Configure cell properties
//    cell.labelTitle.text = contact.name
//    cell.labelSubTitle.text = contact.registeredNumber
//    if let imagePath = contact.profilePhotoPath {
//      cell.imageAvatar.isHidden = false
//      cell.initials.isHidden = true
//      cell.imageAvatar.image = UIImage.fromPath(imagePath)
//    } else {
//      cell.initials.text = contact.getInitials()
//      cell.imageAvatar.isHidden = true
//      cell.initials.isHidden = false
//    }
//    cell.initials.backgroundColor = contact.color
//
//    //Set initial state
//    if selectedContacts.contains(contact) {
//      cell.accessoryType = UITableViewCell.AccessoryType.checkmark
//    } else {
//      cell.accessoryType = UITableViewCell.AccessoryType.none
//    }
//
//    return cell
    
    
    let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.ID, for: indexPath) as! ContactCell
    if isSearchBarEmpty == false {
      let contact = filteredContacts[indexPath.row]
      cell.contactName.text = "\(contact.name) \(contact.surname)"
      cell.contactNumber.text = contact.registeredNumber
      cell.status.text = ""
      
      if let imagePath = contact.profilePhotoPath {
        cell.avatar.contentMode = .scaleAspectFill
        cell.avatar.image = UIImage.fromPath(imagePath)
      }
      
      //Set initial state
      if selectedContacts.contains(contact) {
        cell.accessoryType = UITableViewCell.AccessoryType.checkmark
      } else {
        cell.accessoryType = UITableViewCell.AccessoryType.none
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
      
      //Set initial state
      if selectedContacts.contains(contact) {
        cell.accessoryType = UITableViewCell.AccessoryType.checkmark
      } else {
        cell.accessoryType = UITableViewCell.AccessoryType.none
      }
    }
    
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    var contact: BBContact!
    if searchString.isEmpty {
      contact = Blackbox.shared.contactsSections[indexPath.section].contacts[indexPath.row]
    } else {
      contact = filteredContacts[indexPath.row]
    }

    if selectedContacts.contains(contact) {
      selectedContacts.removeAll { (_contact) -> Bool in
        _contact.ID == contact.ID
      }
    } else {
      selectedContacts.append(contact)
    }
    rightButtonBar.isEnabled = selectedContacts.count == 0 ? false: true
 
    // Reset search
    if searchString.isEmpty == false {
      //searchBar.text = ""
      contentView.searchBar.text = ""
      contentView.searchBar.resignFirstResponder()
      searchString = ""
      contentView.tableView.reloadData()
    } else {
      contentView.tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    contentView.selectionScrollView.reloadData()
    updateMembersView()
  }
}

extension SelectGroupChatMembersViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return selectedContacts.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ContactsPickerHeaderCollectionCell.ID, for: indexPath as IndexPath) as! ContactsPickerHeaderCollectionCell
    
    //Try to get item from delegate
    let contact = self.selectedContacts[indexPath.row]
    
    //Add target for the button
    cell.removeButton.addTarget(self, action: #selector(handleTap(sender:)), for: .touchUpInside)
    cell.removeButton.indexPath = indexPath
    cell.labelTitle.text        = contact.name
    cell.initials.backgroundColor = contact.color
    if let imagePath = contact.profilePhotoPath {
      cell.imageAvatar.isHidden = false
      cell.initials.isHidden = true
      cell.imageAvatar.image = UIImage.fromPath(imagePath)
    } else {
      cell.initials.text = contact.getInitials()
      cell.imageAvatar.isHidden = true
      cell.initials.isHidden = false
    }
    
    
    return cell
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return CGSize(width: CGFloat(70), height: CGFloat(70))
  }
  
  @objc func handleTap(sender: CellButton) {
    guard let indexPath = sender.indexPath else { return }
    if indexPath.row < selectedContacts.count {
      let contact = selectedContacts[indexPath.row]
      selectedContacts.remove(at: indexPath.row)
      contentView.selectionScrollView.reloadData()
      
      DispatchQueue.global(qos: .background).async { [weak self] in
        for (section, element) in Blackbox.shared.contactsSections.enumerated() {
          
          if let row = element.contacts.firstIndex(where: { (_contact) -> Bool in
            contact.ID == _contact.ID
          }) {
            DispatchQueue.main.async { [weak self] in
              guard let strongSelf = self else { return }
              strongSelf.contentView.tableView.reloadRows(at: [IndexPath(row: row, section: section)], with: .none)
            }
          }
        }
      }
      updateMembersView()
    }
  }
}

// MARK: Search bar delegate
extension SelectGroupChatMembersViewController: UISearchBarDelegate {
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    self.searchString = searchText
    
    filteredContacts.removeAll()
    
    if (searchText.isEmpty) {
      self.perform(#selector(self.hideKeyboardWithSearchBar(_:)), with: searchBar, afterDelay: 0)
      self.searchString = ""
      self.contentView.tableView.reloadData()
    } else {
      
      DispatchQueue.main.async { [weak self] in
        guard let strongSelf = self else { return }
        
        // TODO: Improve the search by cheching the Cell Title name text.
        strongSelf.filteredContacts.removeAll()
        Blackbox.shared.contactsSections.forEach { contactsSection in
          for contact in contactsSection.contacts where contact.name.lowercased().contains(strongSelf.searchString.lowercased()) {
            strongSelf.filteredContacts.append(contact)
          }
        }
        
        strongSelf.contentView.tableView.reloadData()
      }
    }
  }
  
  @objc func hideKeyboardWithSearchBar(_ searchBar:UISearchBar){
    searchBar.resignFirstResponder()
  }
  
  func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool{
    return true
  }
}

extension SelectGroupChatMembersViewController: CreateNewGroupViewControllerDelegate {
  func didRemoveContactWith(id: String) {
    self.selectedContacts.removeAll(where: { $0.ID == id })
    
    updateMembersView()
  }
}
