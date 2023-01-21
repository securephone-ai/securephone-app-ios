import UIKit
import Combine
import JGProgressHUD

class AddGroupMembersViewController: UIViewController {
  
  private var group: BBGroup?
  
  private lazy var contacts: [BBContactsSection] = {
    guard let group = self.group else {
      return [BBContactsSection]()
    }
    
    var contacts: [BBContactsSection] = []
    for section in Blackbox.shared.contactsSections {
      
      let members = section.contacts.filter { (c1) -> Bool in
        return c1.registeredNumber.isEmpty == false && group.members.contains(where: { (c2) -> Bool in
          c1.registeredNumber == c2.registeredNumber
        }) == false
      }
      
      if members.count > 0 {
        contacts.append(BBContactsSection(sectionInitial: section.sectionInitial, contacts: members))
      }
    }
    
    return contacts
  }()
  
  // Title label
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 2
    label.textColor = .black
    label.textAlignment = .center
    
    let titleAttrStr = NSAttributedString(string: "Add Partecipants\n".localized(), attributes: [NSAttributedString.Key.font: UIFont.appFontBoldNoDynamic(ofSize: 15)])
    let mutableAttrStr = NSMutableAttributedString(attributedString: titleAttrStr)
    let membersCountAttrStr = NSAttributedString(string: "0 / 255".localized(), attributes: [NSAttributedString.Key.font: UIFont.appFontNoDynamic(ofSize: 13)])
    mutableAttrStr.append(membersCountAttrStr)
    label.attributedText = mutableAttrStr
    
    return label
  }()
  
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
    view.selectionScrollView.delegate = self
    view.selectionScrollView.dataSource = self
    view.selectionScrollView.register(ContactsPickerHeaderCollectionCell.self, forCellWithReuseIdentifier: ContactsPickerHeaderCollectionCell.ID)
    view.searchBar.delegate = self
    return view
  }()
  
  init(group: BBGroup) {
    self.group = group
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    
    navigationItem.titleView = titleLabel
    
    leftButtonBar = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissView))
    rightButtonBar = UIBarButtonItem(title: "Add", style: .plain, target: self, action: #selector(addButtonPressed))
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
  
  @objc func addButtonPressed() {
    guard let group = self.group else { return }
    
    if selectedContacts.count == 0 {
      return
    }
    
    let alertController = UIAlertController(title: "", message: nil, preferredStyle: .actionSheet)
    
    var alertTitle = ""
    if selectedContacts.count == 1 {
      alertTitle = "\("Add".localized()) \(selectedContacts[0].getName()) \("to".localized()) \"\(group.description)\" \("group".localized())?"
    }
    else if selectedContacts.count <= 4 {
      alertTitle = "Add".localized()
      for i in 0..<selectedContacts.count {
        if i == 0 {
          alertTitle = "\(alertTitle) \(selectedContacts[i].getName())"
        } else {
          alertTitle = "\(alertTitle), \(selectedContacts[i].getName())"
        }
        if i == selectedContacts.count-1 {
          alertTitle = "\(alertTitle) \("to".localized()) \"\(group.description)\" \("group".localized())?"
        }
      }
    }
    else if selectedContacts.count >= 5 {
      alertTitle = "Add".localized()
      for i in 0..<selectedContacts.count {
        if i == 0 {
          alertTitle = "\(alertTitle) \(selectedContacts[i].getName())"
        } else {
          alertTitle = "\(alertTitle), \(selectedContacts[i].getName())"
        }
        if i == 3 {
          let rest = selectedContacts.count - 4
          if rest == 1 {
            alertTitle = "\(alertTitle) \("and 1 other to".localized())"
          } else {
            alertTitle = "\(alertTitle) \("and".localized()) \(rest) \("others to".localized())"
          }
          alertTitle = "\(alertTitle) \"\(group.description)\" \("group".localized())?"
          break
        }
      }
    }
    else {
      alertTitle = "Add".localized()
      for i in 0..<selectedContacts.count {
        if i == 0 {
          alertTitle = "\(alertTitle) \(selectedContacts[i].getName())"
        } else {
          alertTitle = "\(alertTitle), \(selectedContacts[i].getName())"
        }
        if i == 3 {
          alertTitle = "\(alertTitle) \("and 1 other to".localized()) \"\(group.description)\" \("group".localized())?"
        }
      }
    }
    
    
    let attributedString = NSAttributedString(string: alertTitle, attributes: [
      NSAttributedString.Key.font : UIFont.appFontSemiBoldNoDynamic(ofSize: 20), //your font here
      NSAttributedString.Key.foregroundColor : UIColor.gray
    ])
    alertController.setValue(attributedString, forKey: "attributedTitle")
    
    let addAction = UIAlertAction(title: "Add".localized(), style: .default) { _ in
      
      let hud = JGProgressHUD(style: .dark)
      hud.textLabel.text = "\("Adding".localized()) \(self.selectedContacts.count) \(self.selectedContacts.count > 1 ? "partecipant".localized() : "partecipants".localized())"
      hud.show(in: UIApplication.shared.windows[0])
      self.dismissView()
      group.addMembersAsync(contacts: self.selectedContacts) { (success) in
        DispatchQueue.main.async {
          if success {
            hud.dismiss()
          } else {
            hud.textLabel.text = "Something went wrong while adding new members. Please try again to add the contacts that failed to be added.".localized()
            hud.dismiss(afterDelay: 3)
          }
        }
      }

    }
    let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
    
    alertController.addAction(addAction)
    alertController.addAction(cancel)
    
    self.present(alertController, animated: true, completion: nil)
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
    updateTitleLabel()
  }
  
  func updateTitleLabel() {
    let titleAttrStr = NSAttributedString(string: "\("Add Partecipants".localized())\n", attributes: [NSAttributedString.Key.font: UIFont.appFontBoldNoDynamic(ofSize: 15)])
    let mutableAttrStr = NSMutableAttributedString(attributedString: titleAttrStr)
    let membersCountAttrStr = NSAttributedString(string: "\(selectedContacts.count) / 255".localized(), attributes: [NSAttributedString.Key.font: UIFont.appFontNoDynamic(ofSize: 13)])
    mutableAttrStr.append(membersCountAttrStr)
    titleLabel.attributedText = mutableAttrStr
  }
}

extension AddGroupMembersViewController: UITableViewDataSource, UITableViewDelegate {
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
      label.text = contacts[section].sectionInitial
    }
    label.sizeToFit()
    label.pin.left(15).vCenter()
    
    return view
  }
  
  func numberOfSections(in tableView: UITableView) -> Int {
    if searchString.isEmpty {
      return contacts.count
    }
    return 1
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 56.0
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if searchString.isEmpty {
      return contacts[section].contacts.count
    }
    return filteredContacts.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    //Get Reference to Cell
    let cell: ContactsPickerTableCell = self.contentView.tableView.dequeueReusableCell(withIdentifier: ContactsPickerTableCell.ID) as! ContactsPickerTableCell
    cell.selectionStyle = .none
    
    var contact: BBContact!
    
    if !searchString.isEmpty {
      contact = filteredContacts[indexPath.row]
    } else {
      contact = contacts[indexPath.section].contacts[indexPath.row]
    }
    
    //Configure cell properties
    cell.labelTitle.text = contact.name
    cell.labelSubTitle.text = contact.registeredNumber
    if let imagePath = contact.profilePhotoPath {
      cell.imageAvatar.isHidden = false
      cell.initials.isHidden = true
      cell.imageAvatar.image = UIImage.fromPath(imagePath)
    } else {
      cell.initials.text = contact.getInitials()
      cell.imageAvatar.isHidden = true
      cell.initials.isHidden = false
    }
    cell.initials.backgroundColor = contact.color
    
    //Set initial state
    if selectedContacts.contains(contact) {
      cell.accessoryType = UITableViewCell.AccessoryType.checkmark
    } else {
      cell.accessoryType = UITableViewCell.AccessoryType.none
    }
    
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    contentView.hideKeyboard()
    
    var contact: BBContact!
    if searchString.isEmpty {
      contact = contacts[indexPath.section].contacts[indexPath.row]
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
    if !searchString.isEmpty {
      //searchBar.text = ""
      contentView.searchBar.text = ""
      contentView.searchBar.resignFirstResponder()
      searchString = ""
    }
    contentView.tableView.reloadRows(at: [indexPath], with: .none)
    contentView.selectionScrollView.reloadData()
    
    updateMembersView()
  }
}

extension AddGroupMembersViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
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
        guard let strongSelf = self else { return }
        for (section, element) in strongSelf.contacts.enumerated() {
          
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
extension AddGroupMembersViewController: UISearchBarDelegate {
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
        strongSelf.contacts.forEach { contactsSection in
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

extension AddGroupMembersViewController: CreateNewGroupViewControllerDelegate {
  func didRemoveContactWith(id: String) {
    self.selectedContacts.removeAll(where: { $0.ID == id })
    
    updateMembersView()
  }
}
