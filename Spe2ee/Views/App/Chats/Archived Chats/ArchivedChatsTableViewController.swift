import UIKit
import SwipeCellKit
import Combine
import JGProgressHUD


class ArchivedChatsTableViewController: UITableViewController {
  
  private var archivedChats: [ChatCellViewModel] {
    return Blackbox.shared.archivedChatItems
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "Archived Chats".localized()
    
    tableView.register(ChatCell.self, forCellReuseIdentifier: ChatCell.ID)
    tableView.rowHeight = 68
    
    navigationController?.navigationBar.prefersLargeTitles = false
    
    self.navigationItem.hidesBackButton = true
    let config = UIImage.SymbolConfiguration(pointSize: 18.5, weight: UIImage.SymbolWeight.semibold)
    let image = UIImage(systemName: "chevron.left", withConfiguration: config)
    let newBackButton = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(goBack))
    self.navigationItem.leftBarButtonItem = newBackButton
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: #selector(dismissView))
    
    Blackbox.shared.currentViewController = self
    
    tableView.reloadData()
  }
  
  // MARK: - Table view data source
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    let cell = ChatCell()
    cell.displayNameLabel.text = "A"
    cell.lastMessageLabel.text = "A"
    cell.lastMessageUsernameLabel.text = "A"
    return cell.displayNameLabel.requiredHeight + cell.lastMessageLabel.requiredHeight + cell.lastMessageUsernameLabel.requiredHeight + 30
  }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return Blackbox.shared.archivedChatItems.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if let cell = tableView.dequeueReusableCell(withIdentifier: ChatCell.ID, for: indexPath) as? ChatCell {
      let item = Blackbox.shared.archivedChatItems[indexPath.row]
      cell.viewModel = item;
      cell.delegate = self
      
      // select/deselect the cell
      if item.isSelected {
        if !cell.isSelected {
          tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
      } else {
        if cell.isSelected {
          tableView.deselectRow(at: indexPath, animated: false)
        }
      }
      return cell
    }
    return UITableViewCell()
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    let chat = archivedChats[indexPath.row]
    if let contact = chat.contact {
      openChat(contact: contact)
    } else if let group = chat.group {
      openChat(group: group)
    }
    
  }
  
  @objc func dismissView() {
    dismiss(animated: true, completion: nil)
  }
  
  @objc func goBack() {
    navigationController?.popViewController(animated: true)
  }
  
  func openChat(contact: BBContact) {
    guard let navigation = navigationController else { return }
    self.title = ""
    navigation.pushViewController(ChatViewController(viewModel: ChatViewModel(contact: contact)), animated: true)
  }
  
  func openChat(group: BBGroup) {
    guard let navigation = navigationController else { return }
    self.title = ""
    navigation.pushViewController(ChatViewController(viewModel: ChatViewModel(group: group)), animated: true)
  }

}

extension ArchivedChatsTableViewController: SwipeTableViewCellDelegate {
  func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> [SwipeAction]? {
    if orientation == .right {
      let archiveAction = SwipeAction(style: .default, title: "Unarchive".localized()) { [weak self] action, indexPath in
        guard let strongSelf = self else { return }
        action.fulfill(with: .reset)
        
        let hud = JGProgressHUD(style: .dark)
        hud.show(in: UIApplication.shared.windows[0])
        
        let chatCellViewModel = strongSelf.archivedChats[indexPath.row]
        chatCellViewModel.unarchiveChatAsync { (success) in
          DispatchQueue.main.async { 
            if success {
              let blackbox = Blackbox.shared
              blackbox.chatItems.append(.Chat(chatCellViewModel))
              blackbox.archivedChatItems.remove(at: indexPath.row)
              blackbox.sortChatItems()
              strongSelf.tableView.safeDeleteRow(at: indexPath, with: .automatic)
            }
            
            hud.dismiss()
          }
        }
      }
      archiveAction.backgroundColor = Constants.ArchiveSwipeActionColor
      
      let moreAction = SwipeAction(style: .default, title: "More".localized()) { action, indexPath in
        
      }
      
      // customize the action appearance
      archiveAction.image = UIImage(named: "archive")
      moreAction.image = UIImage(named: "more")
      return [archiveAction, moreAction]
    } else {
      let unreadAction = SwipeAction(style: .default, title: "Unread".localized()) { action, indexPath in
        action.fulfill(with: .reset)
      }
      unreadAction.backgroundColor = Constants.UnreadSwipeActionColor
      
      // customize the action appearance
      unreadAction.image = UIImage(named: "unread")
      return [unreadAction]
    }
  }
  
  func tableView(_ tableView: UITableView, editActionsOptionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions {
    var options = SwipeOptions()
    options.transitionStyle = .border
    options.expansionStyle = SwipeExpansionStyle(target: .edgeInset(30), additionalTriggers: [.overscroll(30)], elasticOverscroll: false, completionAnimation: .fill(.manual(timing: .with)))
    return options
  }
}

