import UIKit
import PinLayout

protocol ConferenceCallContactsSelectionViewControllerDelegate: class {
  func didSelectContacts(contacts: [BBContact])
}

class ConferenceCallContactsSelectionViewController: UIViewController {
  
  weak var delegate: ConferenceCallContactsSelectionViewControllerDelegate?
  
  private var contacts: [BBContact]!
  private var selectedContacts: [BBContact] = [BBContact]() {
    didSet {
      selectionScrollViewHeight = selectedContacts.isEmpty ? 0 : 84
    }
  }
  private var filteredContacts: [BBContact] = [BBContact]()
  private var maxSelectedContacts: Int
  
  private var keyboardHeight = CGFloat()
  private var selectionScrollViewHeight = CGFloat.zero {
    didSet {
      if oldValue != selectionScrollViewHeight {
        self.updateMembersView()
      }
    }
  }
  
  private var rootView: UIView = {
    let view = UIView()
    view.backgroundColor = .white
    return view
  }()
  
  private let topMiniBar: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 6))
    view.backgroundColor = .systemGray4
    view.cornerRadius = 3
    return view
  }()
  
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    label.text = "New Conference Call".localized()
    label.textColor = .black
    label.sizeToFit()
    return label
  }()
  
  private lazy var searchBar: UISearchBar = {
    let searchBar = UISearchBar()
    searchBar.delegate = self
    return searchBar
  }()
  private var searchString: String = ""

  private lazy var selectionScrollView: UICollectionView = {
    //Build layout
    let layout = UICollectionViewFlowLayout()
    layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    layout.scrollDirection = UICollectionView.ScrollDirection.horizontal
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    
    //Build collectin view
    let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
    collectionView.backgroundColor = ContactsPickerConfig.selectorStyle.backgroundColor
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.register(ContactsPickerHeaderCollectionCell.self, forCellWithReuseIdentifier: ContactsPickerHeaderCollectionCell.ID)
    return collectionView
  }()
  
  private lazy var tableView: UITableView = {
    let tableView:UITableView = UITableView()
    tableView.backgroundColor = ContactsPickerConfig.tableStyle.backgroundColor
    tableView.showsVerticalScrollIndicator = false
    tableView.showsHorizontalScrollIndicator = false
    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(ContactsPickerTableCell.self, forCellReuseIdentifier: ContactsPickerTableCell.ID)
    
    // Hide keyboard on single tap gesture
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
    gestureRecognizer.cancelsTouchesInView = false
    tableView.addGestureRecognizer(gestureRecognizer)
    
    return tableView
  }()
  
  private lazy var callButton: UIButton = {
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    button.backgroundColor = .systemGray6
    button.setImage(UIImage(systemName: "phone.fill"), for: .normal)
    button.cornerRadius = 25
    button.tintColor = .link
    button.alpha = 0
    button.addTarget(self, action: #selector(startConferenceCall), for: .touchUpInside)
    return button
  }()
  
  init(contacts: [BBContact], maxSelectedContacts: Int = 4) {
    self.contacts = contacts
    self.maxSelectedContacts = maxSelectedContacts
    super.init(nibName: nil, bundle: nil)
    self.view.addSubview(rootView)
    rootView.addSubview(topMiniBar)
    rootView.addSubview(titleLabel)
    rootView.addSubview(searchBar)
    rootView.addSubview(selectionScrollView)
    rootView.addSubview(tableView)
    rootView.addSubview(callButton)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    rootView.pin.all()
    
    topMiniBar.pin.hCenter().top(self.view.pin.safeArea.top+6)
    titleLabel.pin.below(of: topMiniBar, aligned: .center).marginTop(6)
    searchBar.pin.below(of: titleLabel).marginTop(6).left().right().height(60)
    selectionScrollView.pin.height(selectionScrollViewHeight).below(of: searchBar).left().right(74)
    tableView.pin.below(of: selectionScrollView).bottom(self.view.pin.safeArea.bottom).left().right()
    
    callButton.pin.centerLeft(to: selectionScrollView.anchor.centerRight).marginLeft(10)
  }

}

extension ConferenceCallContactsSelectionViewController {
  @objc func hideKeyboard() {
    searchBar.textField?.resignFirstResponder()
  }
  
  @objc func keyboardWillShow(notification: Notification) {
    guard let sizeValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
    setTableView(bottomInset: sizeValue.cgRectValue.height)
  }
  
  @objc func keyboardWillHide(notification: Notification) {
    resetScrollOffset()
  }
  
  private func resetScrollOffset() {
    guard tableView.contentInset != .zero else { return }
    setTableView(bottomInset: 0)
  }
  
  private func setTableView(bottomInset: CGFloat) {
    tableView.contentInset = UIEdgeInsets(top: tableView.contentInset.top, left: 0, bottom: bottomInset + 8, right: 0)
  }
  
  func updateMembersView() {
    UIView.animate(withDuration: 0.2) {
      self.callButton.alpha = self.selectionScrollViewHeight == 0 ? 0 : 1
      self.view.setNeedsLayout()
      self.view.layoutIfNeeded()
    }
  }
  
  @objc func startConferenceCall() {
    self.dismiss(animated: true) {
      guard let delegate = self.delegate else {
        return
      }
      delegate.didSelectContacts(contacts: self.selectedContacts)
    }
  }
  
}

extension ConferenceCallContactsSelectionViewController: UITableViewDataSource, UITableViewDelegate {
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 58
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if searchString.isEmpty {
      return contacts.count
    }
    return filteredContacts.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    //Get Reference to Cell
    let cell: ContactsPickerTableCell = tableView.dequeueReusableCell(withIdentifier: ContactsPickerTableCell.ID) as! ContactsPickerTableCell
    cell.selectionStyle = .none
    
    var contact: BBContact!
    
    if searchString.isEmpty {
      contact = contacts[indexPath.row]
    } else {
      contact = filteredContacts[indexPath.row]
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
      if selectedContacts.count == maxSelectedContacts {
        cell.contentView.alpha = 0.2
      } else {
        cell.contentView.alpha = 1
      }
    }
    
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    var contact: BBContact!
    
    if searchString.isEmpty {
      contact = contacts[indexPath.row]
    } else {
      contact = filteredContacts[indexPath.row]
    }
    
    if let index = selectedContacts.firstIndex(of: contact) {
      selectedContacts.removeAll { (_contact) -> Bool in
        return _contact.registeredNumber == contact.registeredNumber
      }
      selectionScrollView.deleteItems(at: [IndexPath(row: index, section: 0)])
    } else {
      if selectedContacts.count == maxSelectedContacts {
        return
      }
      selectedContacts.append(contact)
      selectionScrollView.insertItems(at: [IndexPath(row: selectionScrollView.numberOfItems(inSection: 0), section: 0)])
    }
    
    // Reset search
    if searchString.isEmpty == false {
      //searchBar.text = ""
      searchBar.text = ""
      searchBar.resignFirstResponder()
      filteredContacts.removeAll()
      searchString = ""
    }
    tableView.reloadData()
    
    updateMembersView()
  
  }
  
}

extension ConferenceCallContactsSelectionViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return selectedContacts.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ContactsPickerHeaderCollectionCell.ID, for: indexPath as IndexPath) as! ContactsPickerHeaderCollectionCell
    
    // Try to get item from delegate
    let contact = self.selectedContacts[indexPath.row]
    //Add target for the button
    cell.removeButton.addTarget(self, action: #selector(handleTap(sender:)), for: .touchUpInside)
    cell.removeButton.indexPath = indexPath
    cell.labelTitle.text = contact.getName()

    
    if let photoPath = contact.profilePhotoPath, let image = UIImage.fromPath(photoPath) {
      cell.initials.isHidden = true
      cell.imageAvatar.image = image
    } else {
      cell.initials.text = contact.getInitials()
      cell.initials.isHidden = false
      cell.initials.backgroundColor = contact.color
    }
    
    return cell
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return CGSize(width: CGFloat(70), height: CGFloat(70))
  }
  
  @objc func handleTap(sender: CellButton) {
    guard let indexPath = sender.indexPath else { return }
    if indexPath.row < selectedContacts.count {
      selectedContacts.remove(at: indexPath.row)
      selectionScrollView.reloadData()
      tableView.reloadData()
      updateMembersView()
    }
  }
}

extension ConferenceCallContactsSelectionViewController: UISearchBarDelegate {
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    self.searchString = searchText
    
    if (searchText.isEmpty) {
      hideKeyboardWithSearchBar()
      searchString = ""
      filteredContacts.removeAll()
      tableView.reloadData()
    } else {
      filteredContacts = contacts.filter({ (contact) -> Bool in
        return contact.name.lowercased().contains(searchString.lowercased())
      })
      tableView.reloadData()
    }
    
  }
  
  func hideKeyboardWithSearchBar() {
    searchBar.resignFirstResponder()
  }
  
  func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool{
    return true
  }
}
