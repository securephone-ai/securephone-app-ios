import UIKit
import JGProgressHUD
import SCLAlertView
import Combine
import NextLevel
import AVFoundation
import BlackboxCore


protocol ContactInfoViewControllerDelegate: class {
  func didSelectSearch()
}

class ContactInfoViewController: UITableViewController {
  
  private var contact: BBContact!
  weak var delegate: ContactInfoViewControllerDelegate?
  private lazy var contactProfileImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.image = UIImage(systemName: "person.fill")?.withAlignmentRectInsets(UIEdgeInsets(top: -50, left: -50, bottom: -50, right: -50))
    return imageView
  }()
  private lazy var groupsInCommon: [ChatCellViewModel] = {
    let groups = Blackbox.shared.chatItems.reduce(into: [ChatCellViewModel]()) {
      if let chatCellViewModel = $1.getChatItemViewModel(), let group = chatCellViewModel.group {
        if group.members.contains(where: { (_contact) -> Bool in
          return _contact.registeredNumber == self.contact.registeredNumber
        }) {
          $0.append(chatCellViewModel)
        }
      }
    }
    return groups
  }()
  private var cancellable: AnyCancellable?
  
  init(contact: BBContact) {
    self.contact = contact
    super.init(nibName: nil, bundle: nil)
    
    self.hidesBottomBarWhenPushed = true
    
    self.contact.fetchStarredMessagesAsync { (success) in
      logi("Starredd messages fetched - \(success)")
    }
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.backgroundColor = .systemGray6
    tableView.register(GroupInfoDefaultCell.self, forCellReuseIdentifier: Constants.GroupInfoDefaultCell_ID)
    tableView.register(GroupInfoTemporaryCell.self, forCellReuseIdentifier: Constants.GroupInfoTemporaryCell_ID)
    tableView.register(GroupInfoMemberCell.self, forCellReuseIdentifier: Constants.GroupInfoMemberCell_ID)
    tableView.register(ContactInfoActionCell.self, forCellReuseIdentifier: Constants.ContactInfoActionCell_ID)
    
    tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 50))
    
    tableView.parallaxHeader.view = contactProfileImageView
    tableView.parallaxHeader.height = 380
    tableView.parallaxHeader.mode = .centerFill
    tableView.parallaxHeader.minimumHeight = 0
    
    tableView.contentInset.bottom = 50
    
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    navigationController?.navigationBar.prefersLargeTitles = false
    
    tableView.reloadData()
    
    contact.updateProfileStatusAsync()
    Blackbox.shared.currentViewController = self
    
    if let path = contact.profilePhotoPath {
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path, isDirectory: false))
        contactProfileImageView.image = UIImage(data: data)
//        tableView.contentOffset.y = 100
      } catch {
        loge(error)
      }
    }
    
    cancellable = contact.$profilePhotoPath.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (imagePath) in
      guard let strongSelf = self else { return }
      if let path = imagePath, let image = UIImage.fromPath(path) {
        strongSelf.contactProfileImageView.image = image
      } else {
        // Now assign image from asset catalogue & inset image
        strongSelf.contactProfileImageView.image = UIImage(systemName: "person.fill")?.withAlignmentRectInsets(UIEdgeInsets(top: -50, left: -50, bottom: -50, right: -50))
      }
    })
    
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 3
//    return groupsInCommon.count > 0 ? 6 : 5
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
       return contact.statusMessage.isEmpty ? 1 : 2
    } else if section == 1 {
      return 3
    }
    return 1
    
//    switch section {
//    case 0:
//      return contact.statusMessage.isEmpty ? 1 : 2
//    case 1:
//      return 1
//    case 2:
//      return 2
//    case 3, 4, 5:
//      return 1
//    default:
//      return 0
//    }
  }
  
  private func rowHeight() -> CGFloat {
    let label = UILabel(frame: CGRect(x: 0, y: 0, width: view.width, height: CGFloat.greatestFiniteMagnitude))
    label.numberOfLines = 0
    label.lineBreakMode = NSLineBreakMode.byWordWrapping
    label.font = UIFont.appFont(ofSize: 17)
    label.text = "A"
    label.sizeToFit()
    return label.frame.height
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    switch indexPath.section {
    case 0:
      return rowHeight() + 40
    default:
      return rowHeight() + 34
    }
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 14
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let view = UIView()
    view.isUserInteractionEnabled = false
    return view
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
    case 0:
      // Index 0 = Group name
      // Index 1 = Group description
      
      if indexPath.row == 0 {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.ContactInfoActionCell_ID) as! ContactInfoActionCell
        cell.contactNameLabel.text = contact.getName()
        cell.contactNameLabel.font = UIFont.appFontSemiBold(ofSize: 17, textStyle: .body)
        cell.contactNumberLabel.text = contact.registeredNumber
        cell.contactNumberLabel.font = UIFont.appFont(ofSize: 13)
        cell.chatButton.addTarget(self, action: #selector(openChat), for: .touchUpInside)
        cell.videoCallButton.addTarget(self, action: #selector(videoCall), for: .touchUpInside)
        cell.callButton.addTarget(self, action: #selector(call), for: .touchUpInside)
        
        return cell
      }
      else {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
        cell.settingLabel.text = contact.statusMessage
        cell.settingLabel.font = UIFont.appFont(ofSize: 13, textStyle: .footnote)
        cell.settingLabel.textColor = .systemGray
        cell.disclosureIndicator.isHidden = true
        return cell
      }
      
    case 1:
      if indexPath.row == 0 {
        // For now show only chat search
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
        cell.settingLabel.text = "Starred Messages".localized()
        cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
        cell.settingLabel.textColor = .black
        cell.settingImageView.image = UIImage(named: "info_starred_messages")
        cell.settingDetailLabel.text = contact.starredMessages.count > 0 ? String(contact.starredMessages.count) : "None".localized()
        return cell
        
      } else if indexPath.row == 1 {
        // For now show only chat search
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
        cell.settingLabel.text = "Custom Tone".localized()
        cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
        cell.settingLabel.textColor = .black
        cell.settingImageView.image = UIImage(named: "info_note")
        
        let comps = contact.messageNotificationSoundName.components(separatedBy: "-")
        if comps.count >= 2 {
          var name = comps[0]
          name.removeLast()
          cell.settingDetailLabel.text = "\("tone".localized()) - \(comps[1].replacingFirstOccurrenceOfString(target: ".wav", withString: ""))"
        } else {
          cell.settingDetailLabel.text = "Default".localized()
        }
        
        return cell
      } else {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
        cell.settingLabel.text = "Chat Search".localized()
        cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
        cell.settingLabel.textColor = .black
        cell.settingImageView.image = UIImage(named: "info_search")
        return cell
      }

    case 2:
      
      return clearChatCell()
      
      // Index 0 = Mute
      // Index 1 = Custom tone
//      let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
//      if indexPath.row == 0 {
//        cell.settingLabel.text = "Mute".localized()
//        cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
//        cell.settingLabel.textColor = .black
//        cell.settingImageView.image = UIImage(named: "info_mute")
//      } else if indexPath.row == 1 {
//        cell.settingLabel.text = "Custom Tone".localized()
//        cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
//        cell.settingLabel.textColor = .black
//        cell.settingImageView.image = UIImage(named: "info_note")
//      }
//      return cell
    case 3:
      // Groups in Common
      if groupsInCommon.count > 0 {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
        cell.settingLabel.text = "Groups In Common".localized()
        cell.settingDetailLabel.text = String(groupsInCommon.count)
        cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
        cell.settingLabel.textColor = .black
        cell.settingImageView.image = UIImage(named: "info_groups")
        return cell
      } else {
        return contactDetailsCell()
      }
    case 4:
      if groupsInCommon.count > 0 {
        return contactDetailsCell()
      } else {
        return clearChatCell()
      }
    case 5:
      return clearChatCell()
    default:
      return UITableViewCell()
    }
    
  }
  
  func clearChatCell() -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.textLabel?.text = "Clear Chat".localized()
    cell.textLabel?.textColor = contact.messagesSections.count > 0 ? .red : .systemGray
    cell.selectionStyle = contact.messagesSections.count > 0 ? .default : .none
    return cell
  }
  
  func contactDetailsCell() -> GroupInfoDefaultCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
    cell.settingLabel.text = "Contact Details".localized()
    cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
    cell.settingLabel.textColor = .black
    cell.settingImageView.image = UIImage(named: "info_contact_details")
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    switch indexPath.section {
    case 0:
      if indexPath.row == 0 {
        
      } else {
        
      }
    case 1:
      if indexPath.row == 0 {
        // Starred Messages
        navigationController?.pushViewController(StarredMessagesViewController(contact: contact))
        
      } else if indexPath.row == 1 {
        
        let vc = NotificationSoundSelectionViewController(preSelectedTone: contact.messageNotificationSoundName)
        vc.delegate = self
        present(vc, animated: true, completion: nil)
        
      } else if indexPath.row == 2 {
        if let delegate = delegate {
          delegate.didSelectSearch()
          Blackbox.shared.openChat(contact: contact)
        } else {
          let chatVM = ChatViewModel(contact: contact)
          let chatVC = ChatViewController(viewModel: chatVM)
          chatVM.isSearching = true
          navigationController?.pushViewController(chatVC)
        }
      }
    case 2:
      clearChat()
    case 3:
      if groupsInCommon.count > 0 {
        // groups in common
      } else {
        // Contact Details
        openContactInfo()
      }
    case 4:
      if groupsInCommon.count > 0 {
        // Contact Details
        openContactInfo()
      } else {
        // Clear Chat
        clearChat()
      }
    case 5:
      // Clear Chat
      clearChat()
    default:
      break
    }
    
  }
  
  private func openContactInfo() {
    // Contact Details
    let vc = ContactDetailsViewController(contact: contact)
    navigationController?.pushViewController(vc)
  }
  
  private func clearChat() {
    if contact.messagesSections.count > 0 {
      let alertController = UIAlertController(title: "Delete messages".localized(), message: nil, preferredStyle: .actionSheet)
      let deleteAction = UIAlertAction(title: "Delete all messages".localized(), style: .destructive) { _ in
        let hud = JGProgressHUD(style: .dark)
        hud.show(in: AppUtility.getLastVisibleWindow())
        self.contact.clearChatAsync { (success) in
          DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            if success == false {
              SCLAlertView().showError("Error", subTitle: "Something went wrong while clearing the chat. Pelase check your connectivity and try again".localized())
            } else {
              strongSelf.tableView.reloadData()
            }
            hud.dismiss()
          }
        }
      }
      
      alertController.addAction(deleteAction)
      alertController.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
}

extension ContactInfoViewController {
  
  func isYou(contact: BBContact) -> Bool {
    return contact.registeredNumber == Blackbox.shared.account.registeredNumber
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
      navigationController?.pushViewController(ChatViewController(viewModel: ChatViewModel(contact: contact)), animated: true)
//      Blackbox.shared.openChat(contact: contact)
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

extension ContactInfoViewController: NotificationSoundSelectionViewControllerDelegate {
  func didSelectTone(named: String) {
    
    DispatchQueue.global(qos: .background).async { [self] in
        guard let jsonString = BlackboxCore.contactSetNotificationSound(contact.registeredNumber, soundName: named) else {
            return
        }
        logPrettyJsonString(jsonString)
        
        do {
            let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
            if response.isSuccess() {
                // OK
                contact.messageNotificationSoundName = named
                DispatchQueue.main.async {
                    tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .automatic)
                }
                
            } else {
                loge(response.message)
                DispatchQueue.main.async {
                    SCLAlertView().showError("Error", subTitle: "Something went wrong while contacting the server and we weren't able to update the Notification Sound.".localized())
                }
            }
        } catch {
            loge(error)
        }
    }
  }
}
