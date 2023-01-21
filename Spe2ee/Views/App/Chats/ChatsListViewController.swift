import UIKit
import SwipeCellKit
import Combine
import DeviceKit
import JGProgressHUD
import SCLAlertView


class ChatsListViewController: BBViewController {
  
  var viewModel = ChatsViewModel()
  private var chatViewController: ChatViewController?
  
  let searchController = UISearchController(searchResultsController: nil)
  var isSearchBarEmpty: Bool {
    return searchController.searchBar.text?.isEmpty ?? true
  }
  
  private lazy var tableView: UITableView = {
    let tableView = UITableView()
    tableView.register(ChatCell.self, forCellReuseIdentifier: ChatCell.ID)
    tableView.register(UINib(nibName: "BroadcastNewGroupCell", bundle: nil), forCellReuseIdentifier: BroadcastNewGroupCell.ID)
    tableView.register(UINib(nibName: "ArchiveChatCell", bundle: nil), forCellReuseIdentifier: ArchiveChatCell.ID)
    tableView.allowsMultipleSelection = false
    tableView.delaysContentTouches = true
    tableView.delegate = self
    tableView.dataSource = self
    return tableView
  }()
  
  // Nav bar buttons
  var rightButtonBar = UIBarButtonItem()
  
  private var cancellableBag = Set<AnyCancellable>()
  
  // Keep track of the swiped cell to properly reset when edit mode change or new call is added.
  var count = 0
  var currentSwipedCell: ChatCell? = nil
  
  private var stackView: UIStackView = {
    let loading = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
    loading.startAnimating()
    let label = UILabel()
    label.text = "Connecting...".localized()
    label.font = UIFont.appFontLight(ofSize: 15)
    label.sizeToFit()
    let stackView = UIStackView(arrangedSubviews: [loading, label])
    stackView.spacing = 4
    return stackView
  }()
  
  deinit {
    logi("ChatsListViewController deinitialized")
  }
  
}

// MARK: - Lifecycle Functions
extension ChatsListViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
//    self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(startEditMode))
//    rightButtonBar = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"), style: .plain, target: self, action: #selector(addChatTap))
    rightButtonBar = UIBarButtonItem(title: "New Group".localized(), style: .plain, target: self, action: #selector(createNewGroup))
    self.navigationItem.rightBarButtonItem = rightButtonBar
    
    searchController.searchResultsUpdater = self as UISearchResultsUpdating
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "Search".localized()
    navigationItem.searchController = searchController
  
    self.view.addSubview(tableView)
    
    configureBinding()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    try? logi(FileManager.default.contentsOfDirectory(atPath: AppUtility.getDocumentsDirectory().path))
    
    let account = Blackbox.shared.account
    if account.isInternalPushregistered == false {
      account.isInternalPushregistered = true
    }
    
    title = "Chats".localized()
    navigationController?.navigationBar.prefersLargeTitles = true
    navigationController?.navigationBar.hideBottomLine()
    
    Blackbox.shared.chatListViewController = self

    chatViewController = nil
    
    tableView.reloadData()
    
    refreshChatList()
    AppUtility.removeWatermarkFromWindow()
  }
  
  /// Refresh the chats list and unread messages
  private func refreshChatList() {
    let blackbox = Blackbox.shared
    if blackbox.account.state == .registered {
      blackbox.fetchContactsAsync(limitsearch: 10000) { (success) in
        if success {
//          blackbox.fetchChatListAsync()
        }
      }
    }
    
    blackbox.fetchChatListAsync()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    tableView.pin.all()
  }
  
  /// Default table configuration
  func setupTable() {
    tableView.register(ChatCell.self, forCellReuseIdentifier: ChatCell.ID)
    tableView.register(UINib(nibName: "BroadcastNewGroupCell", bundle: nil), forCellReuseIdentifier: BroadcastNewGroupCell.ID)
    tableView.register(UINib(nibName: "ArchiveChatCell", bundle: nil), forCellReuseIdentifier: ArchiveChatCell.ID)
    tableView.allowsMultipleSelection = false
    tableView.delaysContentTouches = true
  }
  
  /// Configure Combine bindings
  func configureBinding() {
    
    viewModel.$isEditing.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (value) in
      guard let strongSelf = self else { return }
      if value {
        if strongSelf.currentSwipedCell != nil {
          strongSelf.currentSwipedCell?.hideSwipe(animated: true)
        }
        strongSelf.tableView.allowsMultipleSelection = true
        strongSelf.navigationItem.rightBarButtonItem = nil
        strongSelf.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(strongSelf.stopEditMode))
      } else {
//        strongSelf.tableView.allowsMultipleSelection = false
//        strongSelf.navigationItem.rightBarButtonItem = strongSelf.rightButtonBar
//        strongSelf.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(strongSelf.startEditMode))
      }
    }).store(in: &cancellableBag)
    
    Blackbox.shared.account.$state.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self](state) in
      guard let strongSelf = self else { return }
      
      switch state {
      case .registering:
        strongSelf.navigationItem.titleView = strongSelf.stackView
      default:
        strongSelf.navigationItem.titleView = nil
        break
      }
    }).store(in: &cancellableBag)
    
    Blackbox.shared.$chatItems
      .filter({ (chats) -> Bool in
        chats.count > 0
      })
      .throttle(for: .milliseconds(400), scheduler: DispatchQueue.main, latest: true)
      .sink(receiveValue: { [weak self] (chats) in
        guard let strongSelf = self else { return }
        strongSelf.tableView.reloadData()
      }).store(in: &cancellableBag)
    
  }
}

// MARK: - Actions
extension ChatsListViewController {
  
  @objc func startEditMode() {
    viewModel.isEditing = true
  }
  
  @objc func stopEditMode() {
    viewModel.isEditing = false
  }
  
  @objc func addChatTap() {
    let addChat = StartNewChatViewController()
    let navController = UINavigationController(rootViewController: addChat)
    let device = Device.current
    if !device.hasSensorHousing {
      navController.modalPresentationStyle = .fullScreen
    }
    present(navController, animated: true)
  }
  
  @objc func createNewGroup() {
    let vc = SelectGroupChatMembersViewController()
    let navController = UINavigationController(rootViewController: vc)
    let device = Device.current
    if !device.hasSensorHousing {
      navController.modalPresentationStyle = .fullScreen
    }
    
    present(navController, animated: true, completion: nil)
  }
  
}

// MARK: - Table view data source & delegate
extension ChatsListViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if viewModel.getAllItems().count == 0 {
      return 0
    }
    switch viewModel.getAllItems()[indexPath.row] {
    case .Archive:
      return 44;
    case .Chat(_):
      let cell = ChatCell()
      cell.displayNameLabel.text = "A"
      cell.lastMessageLabel.text = "A"
      cell.lastMessageUsernameLabel.text = "A"
      return cell.displayNameLabel.requiredHeight + cell.lastMessageLabel.requiredHeight + cell.lastMessageUsernameLabel.requiredHeight + 30
    }
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return viewModel.getAllItems().count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if viewModel.getAllItems().count == 0 {
      return UITableViewCell()
    }
    switch viewModel.getAllItems()[indexPath.row] {
    case .Archive:
      if let cell = tableView.dequeueReusableCell(withIdentifier: ArchiveChatCell.ID, for: indexPath) as? ArchiveChatCell {
        cell.separatorInset.left = 0
        let archivedChatCounts = Blackbox.shared.archivedChatItems.count
        cell.archivedChatsCountLabel.text = archivedChatCounts > 0 ? String(archivedChatCounts) : ""
        return cell
      }
    case .Chat(let viewModel):
      if let cell = tableView.dequeueReusableCell(withIdentifier: ChatCell.ID, for: indexPath) as? ChatCell {
        cell.viewModel = viewModel;
        cell.delegate = self
        
        // select/deselect the cell
        if viewModel.isSelected {
          if !cell.isSelected {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
          }
        }
        else {
          if cell.isSelected {
            tableView.deselectRow(at: indexPath, animated: false)
          }
        }
        
        //        let messagesSections = viewModel.isGroup ? viewModel.group!.messagesSections : viewModel.contact!.messagesSections
        
        return cell
      }
    }
    
    return UITableViewCell()
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if viewModel.isEditing {
      viewModel.selectChat(at: indexPath.row)
    } else {
      logi()
      tableView.deselectRow(at: indexPath, animated: true)
      
      switch viewModel.getAllItems()[indexPath.row] {
      case .Archive:
        let archiveView = ArchivedChatsTableViewController()
        guard let navigation = navigationController else { return }
        //        navigation.navigationBar.prefersLargeTitles = false
        title = ""
        
        // Let the interface remove the Title otherwise it will appear for a split second during the navigation animation.
        navigation.pushViewController(archiveView, animated: true)
      case .Chat(let chat):
        if chat.isGroup {
          guard let group = chat.group else { return }
          openChat(group: group)
        } else {
          guard let contact = chat.contact else { return }
          openChat(contact: contact)
        }
      }
    }
  }
  
  func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
    viewModel.deselectChat(at: indexPath.row)
  }
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    
  }

}

extension ChatsListViewController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    let searchBar = searchController.searchBar
    viewModel.filterString = searchBar.text!
    tableView.reloadData()
  }
}

extension ChatsListViewController: SwipeTableViewCellDelegate {
  func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> [SwipeAction]? {
    guard !viewModel.isEditing else { return nil }
    
    currentSwipedCell = tableView.cellForRow(at: indexPath) as? ChatCell
    
    if orientation == .right {
      let archiveAction = SwipeAction(style: .default, title: "Archive".localized()) { [weak self] action, indexPath in
        guard let strongSelf = self else { return }
        action.fulfill(with: .reset)
        
        let hud = JGProgressHUD(style: .dark)
        hud.show(in: UIApplication.shared.windows[0])
        
        let chatItem = strongSelf.viewModel.getAllItems()[indexPath.row]
        if let chatCellViewModel = chatItem.getChatItemViewModel() {
          chatCellViewModel.archiveChatAsync { (success) in
            DispatchQueue.main.async {
              if success {
                let blackbox = Blackbox.shared
                blackbox.archivedChatItems.append(chatCellViewModel)
                blackbox.chatItems.remove(at: indexPath.row)
                blackbox.sortArchivedChatItems()
                strongSelf.tableView.safeDeleteRow(at: indexPath, with: .top)
              }
              
              hud.dismiss()
            }
          }
        }
      }
      archiveAction.backgroundColor = Constants.ArchiveSwipeActionColor
      
      let moreAction = SwipeAction(style: .default, title: "More".localized()) { action, indexPath in
        guard let chat = self.viewModel.getAllItems()[indexPath.row].getChatItemViewModel() else { return }
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let muteChat = UIAlertAction(title: "Mute".localized(), style: .default) { _ in
          
        }
        alertController.addAction(muteChat)
        
        if let group = chat.group {
          let groupInfoAction = UIAlertAction(title: "Group Info".localized(), style: .default) { _ in
            self.title = ""
            self.navigationController?.pushViewController(ChatGroupInfoTableViewController(group: group), animated: true)
          }
          alertController.addAction(groupInfoAction)
        }
        else {
          let contactInfoAction = UIAlertAction(title: "Contact Info".localized(), style: .default) { _ in
            switch self.viewModel.getAllItems()[indexPath.row] {
            case .Chat(let chat):
              guard let contact = chat.contact else { return }
              // Open Contact Info
              let vc = ContactDetailsViewController(contact: contact)
              let navigation = UINavigationController(rootViewController: vc)
              navigation.modalPresentationStyle = .fullScreen
              self.present(navigation, animated: true, completion: nil)
            default:
              break
            }
          }
          alertController.addAction(contactInfoAction)
        }
        
        let clearChatAction = UIAlertAction(title: "Clear Chat".localized(), style: .default) { _ in
          let alertController = UIAlertController(title: "Delete messages".localized(), message: nil, preferredStyle: .actionSheet)
          let deleteAction = UIAlertAction(title: "Delete all messages".localized(), style: .destructive) { _ in
            let hud = JGProgressHUD(style: .dark)
            hud.show(in: AppUtility.getLastVisibleWindow())
            
            if let contact = chat.contact {
              contact.clearChatAsync { (success) in
                if success == false {
                  DispatchQueue.main.async {
                    hud.dismiss()
                    SCLAlertView().showError("Error".localized(), subTitle: "Something went wrong while clearing the chat. Pelase check your connectivity and try again".localized())
                  }
                } else {
                  Blackbox.shared.fetchChatListAsync { _ in
                    DispatchQueue.main.async { [weak self] in
                      guard let strongSelf = self else { return }
                      strongSelf.tableView.reloadData()
                      hud.dismiss()
                    }
                  }
                }
              }
            } else if let group = chat.group {
              group.clearChatAsync { (success) in
                if success == false {
                  DispatchQueue.main.async {
                    hud.dismiss()
                    SCLAlertView().showError("Error".localized(), subTitle: "Something went wrong while clearing the chat. Pelase check your connectivity and try again".localized())
                  }
                } else {
                  Blackbox.shared.fetchChatListAsync { _ in
                    DispatchQueue.main.async { [weak self] in
                      guard let strongSelf = self else { return }
                      strongSelf.tableView.reloadData()
                      hud.dismiss()
                    }
                  }
                }
              }
            }
          }
          alertController.addAction(deleteAction)
          alertController.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
          self.present(alertController, animated: true, completion: nil)
          
        }
        alertController.addAction(clearChatAction)
        
        if chat.isGroup {
          let exitGroupAction = UIAlertAction(title: "Exit Group".localized(), style: .destructive) { _ in
            
          }
          alertController.addAction(exitGroupAction)
        } else {
          let deleteChatAction = UIAlertAction(title: "Delete Chat".localized(), style: .destructive) { _ in
            
            let hud = JGProgressHUD(style: .dark)
            hud.show(in: AppUtility.getLastVisibleWindow())
            chat.contact!.clearChatAsync { (success) in
              if success {
                BBChat.archiveChatAsync(contact: chat.contact!) { [weak self] (success) in
                  guard let strongSelf = self else { return }
                  if success {
                    DispatchQueue.main.async { [weak self] in
                      guard let strongSelf = self else { return }
                      let blackbox = Blackbox.shared
                      blackbox.archivedChatItems.append(chat)
                      blackbox.chatItems.remove(at: indexPath.row)
                      blackbox.sortArchivedChatItems()
                      strongSelf.tableView.safeDeleteRow(at: indexPath, with: .top)
                      hud.dismissMT()
                    }
                  }
                }
              } else {
                hud.dismissMT()
              }
            }
          }
          alertController.addAction(deleteChatAction)
        }
        
        
        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
        alertController.addAction(cancel)
        
        self.present(alertController, animated: true, completion: nil)
      }
      
      // customize the action appearance
      archiveAction.image = UIImage(named: "archive")
      moreAction.image = UIImage(named: "more")
      return [archiveAction, moreAction]
    } else {
      
//      let unreadAction = SwipeAction(style: .default, title: "Unread".localized()) { action, indexPath in
//        action.fulfill(with: .reset)
//      }
//      unreadAction.backgroundColor = Constants.UnreadSwipeActionColor
//
//      let pinAction = SwipeAction(style: .default, title: "Pin".localized()) { action, indexPath in
//
//      }
//
//      // customize the action appearance
//      unreadAction.image = UIImage(named: "unread")
//      pinAction.image = UIImage(named: "pin")
//      return [unreadAction, pinAction]
      return nil
    }
  }
  
  func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?, for orientation: SwipeActionsOrientation) {
    currentSwipedCell = nil
  }
  
  func tableView(_ tableView: UITableView, editActionsOptionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions {
    var options = SwipeOptions()
    options.transitionStyle = .border
    options.expansionStyle = SwipeExpansionStyle(target: .edgeInset(30), additionalTriggers: [.overscroll(30)], elasticOverscroll: false, completionAnimation: .fill(.manual(timing: .with)))
    return options
  }
  
}

extension ChatsListViewController {
  
  func openChat(contact: BBContact) {
    guard let navigation = navigationController else { return }
    self.title = ""
    
    for vc in navigation.viewControllers {
      if let chatVC = vc as? ChatViewController, let chatViewModel = chatVC.viewModel, let chatContact = chatViewModel.contact, contact.registeredNumber == chatContact.registeredNumber {
        navigation.popToViewController(vc)
        return
      }
    }
    
    chatViewController = ChatViewController(viewModel: ChatViewModel(contact: contact))
    navigation.pushViewController(chatViewController!) {
      // Remove any view between the ChatsListViewController and the new ChatViewController
      navigation.viewControllers.removeAll { (vc) -> Bool in
        if let _ = vc as? ChatsListViewController {
          return false
        } else if let chatVC = vc as? ChatViewController, let chatViewModel = chatVC.viewModel, let chatContact = chatViewModel.contact, contact.registeredNumber == chatContact.registeredNumber {
          return false
        }
        return true
      }
    }
 
    Blackbox.shared.appRootViewController?.selectedIndex = 0
    dismiss(animated: true, completion: nil)
    
  }
  
  func openChat(group: BBGroup) {
    guard let navigation = navigationController else { return }
    self.title = ""
    
    for vc in navigation.viewControllers {
      if let chatVC = vc as? ChatViewController, let chatViewModel = chatVC.viewModel, let chatGroup = chatViewModel.group, group.ID == chatGroup.ID {
        navigation.popToViewController(vc)
        return
      }
    }
    
    chatViewController = ChatViewController(viewModel: ChatViewModel(group: group))
    navigation.pushViewController(chatViewController!) {
      
      // Remove any view between the ChatsListViewController and the new ChatViewController
      navigation.viewControllers.removeAll { (vc) -> Bool in
        if let _ = vc as? ChatsListViewController {
          return false
        } else if let chatVC = vc as? ChatViewController, let chatViewModel = chatVC.viewModel, let chatGroup = chatViewModel.group, group.ID == chatGroup.ID {
          return false
        }
        return true
      }
    }

    Blackbox.shared.appRootViewController?.selectedIndex = 0
    dismiss(animated: true, completion: nil)

  }
  
}

