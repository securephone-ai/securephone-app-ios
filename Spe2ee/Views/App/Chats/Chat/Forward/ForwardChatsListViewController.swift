import UIKit
import Combine

protocol ForwardChatsListViewControllerDelegate: class {
  func didFinishSelection(chats: [ChatItems])
  func didCancelSelection()
}

class ForwardChatsListViewController: UIViewController {
  
  // delegate
  weak var delegate: ForwardChatsListViewControllerDelegate?
  
  // Searched string
  var searchString  = ""
  var cancellable: AnyCancellable?
  private var chatItems = [ChatItems]()
  private var selectedContacts = [ChatItems]()
  private var filteredContacts = [ChatItems]()
  
  // Nav bar buttons
  private var leftButtonBar = UIBarButtonItem()
  open var rightButtonBar = UIBarButtonItem()
  private var rightButtonString: String!
  
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
  
  init(doneButtonTitle: String) {
    self.rightButtonString = doneButtonTitle
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    chatItems = Blackbox.shared.chatItems.filter { $0 != .Archive }
    
    leftButtonBar = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissView))
    rightButtonBar = UIBarButtonItem(title: rightButtonString.localized(), style: .plain, target: self, action: #selector(endSelection))
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
    guard let delegate = self.delegate else { return }
    delegate.didCancelSelection()
  }
  
  @objc func endSelection() {
    guard let delegate = self.delegate else { return }
    delegate.didFinishSelection(chats: selectedContacts)
    if isModal {
      self.dismiss(animated: true, completion: nil)
    } else {
      self.navigationController?.popViewController(animated: true)
    }
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

extension ForwardChatsListViewController: UITableViewDataSource, UITableViewDelegate {
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 56.0
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if searchString.isEmpty {
      return chatItems.count
    }
    return filteredContacts.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    //Get Reference to Cell
    let cell: ContactsPickerTableCell = self.contentView.tableView.dequeueReusableCell(withIdentifier: ContactsPickerTableCell.ID) as! ContactsPickerTableCell
    cell.selectionStyle = .none
    
    let chat: ChatItems = searchString.isEmpty ? chatItems[indexPath.row] : filteredContacts[indexPath.row]
    
    switch chat {
    case .Chat(let cellViewModel):
      //Configure cell properties
      cell.labelTitle.text = cellViewModel.name
      cell.labelSubTitle.text = cellViewModel.isGroup ? "" : cellViewModel.contact!.registeredNumber
      
      if let group = cellViewModel.group {        
        if let photoPath = group.profileImagePath, let image = UIImage.fromPath(photoPath) {
           cell.imageAvatar.image = image
        } else {
           cell.imageAvatar.image = UIImage(named: "avatar_profile_group")
        }

        cell.imageAvatar.isHidden = false
        cell.initials.isHidden = true
        cell.labelSubTitle.text = cellViewModel.group!.getMembersName()
      } else {
        cell.labelSubTitle.text = cellViewModel.isGroup ? "" : cellViewModel.contact!.registeredNumber
        cell.initials.text = cellViewModel.isGroup ? "" : cellViewModel.contact!.getInitials()
        cell.initials.isHidden = false
        cell.initials.backgroundColor = cellViewModel.isGroup ? .clear : cellViewModel.contact!.color
      }
      
      //Set initial state
      if selectedContacts.contains(chat) {
        cell.accessoryType = UITableViewCell.AccessoryType.checkmark
      } else {
        cell.accessoryType = UITableViewCell.AccessoryType.none
      }
      
      
      return cell
    default:
      return UITableViewCell()
    }
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let chat: ChatItems = searchString.isEmpty ? chatItems[indexPath.row] : filteredContacts[indexPath.row]
    switch chat {
    case .Chat(let cellViewModel):
      
      if selectedContacts.contains(chat) {
        selectedContacts.removeAll { (_chat) -> Bool in
          if let vm = _chat.getChatItemViewModel() {
            if vm.isGroup, cellViewModel.isGroup, vm.group!.ID == cellViewModel.group!.ID {
              return true
            } else if !vm.isGroup, !cellViewModel.isGroup, vm.contact!.ID == cellViewModel.contact!.ID {
              return true
            }
          }
          return false
        }
      } else {
        selectedContacts.append(chat)
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
    default:
      break
    }
  }
}

extension ForwardChatsListViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return selectedContacts.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ContactsPickerHeaderCollectionCell.ID, for: indexPath as IndexPath) as! ContactsPickerHeaderCollectionCell
    
    //Try to get item from delegate
    let chat = self.selectedContacts[indexPath.row]
    if let cellViewModel = chat.getChatItemViewModel() {
      //Add target for the button
      cell.removeButton.addTarget(self, action: #selector(handleTap(sender:)), for: .touchUpInside)
      cell.removeButton.indexPath = indexPath
      cell.labelTitle.text        = cellViewModel.name
      if let group = cellViewModel.group {
        
        if let path = group.profileImagePath, let image = UIImage.fromPath(path) {
          cell.imageAvatar.image = image
        } else {
          cell.imageAvatar.image = UIImage(named: "avatar_profile_group")
        }
        cell.imageAvatar.isHidden = false
        cell.initials.isHidden = true
      } else {
        cell.initials.text          = cellViewModel.isGroup ? "" : cellViewModel.contact!.getInitials()
        cell.initials.isHidden      = false
        cell.initials.backgroundColor = cellViewModel.isGroup ? .clear : cellViewModel.contact!.color
      }
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
      contentView.selectionScrollView.reloadData()
      contentView.tableView.reloadData()
      updateMembersView()
    }
  }
}

// MARK: Search bar delegate
extension ForwardChatsListViewController: UISearchBarDelegate {
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
        strongSelf.chatItems.forEach { (chat) in
          if let cellViewModel = chat.getChatItemViewModel(), cellViewModel.name.lowercased().contains(strongSelf.searchString.lowercased()) {
            strongSelf.filteredContacts.append(chat)
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



