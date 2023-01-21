import UIKit
import JGProgressHUD
import SCLAlertView
import Combine
import NextLevel
import AVFoundation
import BlackboxCore



class ChatGroupInfoTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: ContactInfoViewControllerDelegate?
    
    private var group: BBGroup!
    private var cancellableBag = Set<AnyCancellable>()
    private lazy var canClearChat: Bool  = {
        for section in group.messagesSections {
            let messagesCount = section.messages.count { $0.message.type.isSystemMessage() == false }
            if messagesCount > 0 {
                return true
            }
        }
        return false
    }()
    private lazy var imagePickerController: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = self
        return picker
    }()
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.addSubview(groupProfileImageView)
        view.addSubview(changeImageButton)
        view.backgroundColor = .systemGray6
        return view
    }()
    
    private lazy var groupProfileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .systemGray
        imageView.image = UIImage(systemName: "person.3.fill")?.withAlignmentRectInsets(UIEdgeInsets(top: -50, left: -50, bottom: -50, right: -50))
        return imageView
    }()
    
    private lazy var changeImageButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: UIImage.SymbolWeight.light)), for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        button.cornerRadius = 25
        button.backgroundColor = .darkGray
        button.tintColor = .white
        button.addTarget(self, action: #selector(selectGroupImage), for: .touchUpInside)
        return button
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .systemGray6
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(GroupInfoTemporaryCell.self, forCellReuseIdentifier: Constants.GroupInfoTemporaryCell_ID)
        tableView.register(GroupInfoDefaultCell.self, forCellReuseIdentifier: Constants.GroupInfoDefaultCell_ID)
        tableView.register(GroupInfoMemberCell.self, forCellReuseIdentifier: Constants.GroupInfoMemberCell_ID)
        
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 50))
        
        return tableView
    }()
    
    init(group: BBGroup) {
        self.group = group
        super.init(nibName: nil, bundle: nil)
        
        self.group.fetchStarredMessagesAsync { (success) in
            logi("Starredd messages fetched - \(success)")
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        
        //    if group.role == .administrator || group.role == .creator {
        //      tableView.parallaxHeader.view = headerView
        //      tableView.parallaxHeader.height = 380
        //      tableView.parallaxHeader.mode = .bottomFill
        //    }
        
        tableView.parallaxHeader.view = headerView
        tableView.parallaxHeader.height = 380
        tableView.parallaxHeader.mode = .bottomFill
        
        if let path = group.profileImagePath, let image = UIImage.fromPath(path) {
            groupProfileImageView.image = image
        }
        
        group.$description.receive(on: DispatchQueue.main).sink { [weak self] (decription) in
            guard let strongSelf = self else { return }
            strongSelf.tableView.reloadRows(at: [IndexPath(item: 0, section: 0)], with: .automatic)
        }.store(in: &cancellableBag)
        
        group.$profileImagePath
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] (imagePath) in
                guard let strongSelf = self else { return }
                if let path = imagePath, let image = UIImage.fromPath(path) {
                    strongSelf.groupProfileImageView.image = image
                } else {
                    strongSelf.groupProfileImageView.image = UIImage(systemName: "person.3.fill")?.withAlignmentRectInsets(UIEdgeInsets(top: -50, left: -50, bottom: -50, right: -50))
                }
            }).store(in: &cancellableBag)
        
        group.$role.receive(on: DispatchQueue.main).sink { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.tableView.reloadData()
        }.store(in: &cancellableBag)
        
        group.$members
            .receive(on: DispatchQueue.main)
            .throttle(for: .milliseconds(1500), scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: { [weak self](members) in
                guard let strongSelf = self else { return }
                if strongSelf.group.role == .administrator || strongSelf.group.role == .creator {
                    if strongSelf.tableView.numberOfRows(inSection: 3) == members.count+1 { //Add Partecipants cell
                        return
                    }
                } else {
                    if strongSelf.tableView.numberOfRows(inSection: 3) == members.count {
                        return
                    }
                }
                strongSelf.tableView.reloadData()
                //        strongSelf.tableView.performBatchUpdates({
                //          strongSelf.tableView.reloadSections(IndexSet(integer: 3), with: .automatic)
                //        }, completion: nil)
            }).store(in: &cancellableBag)
        
        if group.role != .normal {
            group.$expiryDate
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self](date) in
                    guard let strongSelf = self else { return }
                    strongSelf.tableView.performBatchUpdates({
                        strongSelf.tableView.reloadRows(at: [IndexPath(row: 1, section: 2)], with: .none)
                    }, completion: nil)
                }).store(in: &cancellableBag)
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        
        group.updateMembersListAsync()
        Blackbox.shared.currentViewController = self
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.pin.all()
        headerView.pin.all()
        groupProfileImageView.pin.bottom().right().left().top(self.view.pin.safeArea.top)
        changeImageButton.isHidden = group.role == .normal
        changeImageButton.pin.bottom(15).right(15)
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 6
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        switch section {
        case 0:
            return 1
        case 1:
            return 2
        case 2:
            return group.role == .normal ? 1 : 2
        case 3:
            return group.role == .normal ? group.members.count : group.members.count + 1
        case 4, 5:
            return 1
        default:
            return 0
        }
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0, 3:
            return rowHeight() + 40
        case 1, 4, 5:
            return rowHeight() + 34
        case 2:
            if indexPath.row == 0 || group.expiryDate == nil {
                return rowHeight() + 34
            } else {
                return rowHeight() + 34 + 14
            }
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 0.0
        case 3:
            return 52.0
        default:
            return 36.0
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            // Index 0 = Group name
            // Index 1 = Group description
            let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
            if indexPath.row == 0 {
                cell.settingLabel.text = group.description
                cell.settingLabel.font = UIFont.appFontSemiBold(ofSize: 17, textStyle: .body)
                cell.settingLabel.textColor = .black
            } else {
                cell.settingLabel.text = group.description
                cell.settingLabel.font = UIFont.appFont(ofSize: 13, textStyle: .footnote)
                cell.settingLabel.textColor = .systemGray
            }
            return cell
        case 1:
            // Index 0 = Media, Links, and Docs
            // Index 1 = Starred Messages
            // Index 2 = Chat Search
            //      let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
            //      if indexPath.row == 0 {
            //        cell.settingLabel.text = "Media, Links, and Docs".localized()
            //        cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
            //        cell.settingLabel.textColor = .black
            //        cell.settingImageView.image = UIImage(named: "info_media")
            //      } else if indexPath.row == 1 {
            //        cell.settingLabel.text = "Starred Messages".localized()
            //        cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
            //        cell.settingLabel.textColor = .black
            //        cell.settingImageView.image = UIImage(named: "starred")
            //      } else if indexPath.row == 2 {
            //        cell.settingLabel.text = "Chat Search".localized()
            //        cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
            //        cell.settingLabel.textColor = .black
            //        cell.settingImageView.image = UIImage(named: "info_search")
            //      }
            
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
                cell.settingLabel.text = "Starred Messages".localized()
                cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
                cell.settingLabel.textColor = .black
                cell.settingImageView.image = UIImage(named: "info_starred_messages")
                cell.settingDetailLabel.text = group.starredMessages.count > 0 ? String(group.starredMessages.count) : "None".localized()
                return cell
            }
            else {
                // For now show only chat search
                let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
                cell.settingLabel.text = "Chat Search".localized()
                cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
                cell.settingLabel.textColor = .black
                cell.settingImageView.image = UIImage(named: "info_search")
                return cell
            }
            
        // For now show only chat search
        //      let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
        //      cell.settingLabel.text = "Chat Search".localized()
        //      cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
        //      cell.settingLabel.textColor = .black
        //      cell.settingImageView.image = UIImage(named: "info_search")
        //      return cell
        case 2:
            // Index 0 = Mute
            // Index 1 = Custom tone
            // Index 2 = Group Settings, Present only if group admin or creator
            
            //      if indexPath.row == 0 {
            //        cell.settingLabel.text = "Mute".localized()
            //        cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
            //        cell.settingLabel.textColor = .black
            //        cell.settingImageView.image = UIImage(named: "info_mute")
            //      }
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoDefaultCell_ID) as! GroupInfoDefaultCell
                cell.settingLabel.text = "Custom Tone".localized()
                cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
                cell.settingLabel.textColor = .black
                cell.settingImageView.image = UIImage(named: "info_note")
                
                let comps = group.messageNotificationSoundName.components(separatedBy: "-")
                if comps.count >= 2 {
                    var name = comps[0]
                    name.removeLast()
                    cell.settingDetailLabel.text = "\(name) - \(comps[1].replacingFirstOccurrenceOfString(target: ".wav", withString: ""))"
                } else {
                    cell.settingDetailLabel.text = "Default".localized()
                }
                
                return cell
            } else if indexPath.row == 1 {
                let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoTemporaryCell_ID) as! GroupInfoTemporaryCell
                cell.selectionStyle = .none
                cell.delegate = self
                cell.settingLabel.text = "Temporary Group".localized()
                cell.settingLabel.font = UIFont.appFont(ofSize: 17, textStyle: .body)
                cell.settingLabel.textColor = .black
                cell.settingImageView.image = UIImage(named: "info_temp_conv")
                cell.temporarySwitch.isOn = group.expiryDate != nil
                
                if let expiryDate = group.expiryDate {
                    let formatter = DateFormatter()
                    formatter.timeZone = TimeZone(abbreviation: "UTC")
                    formatter.dateFormat = "MMMM d, yyyy"
                    cell.exitDateLabel.text = formatter.string(from: expiryDate)
                } else {
                    cell.exitDateLabel.text = nil
                }
                
                return cell
            }
        case 3:
            // Group Members
            
            let cell = tableView.dequeueReusableCell(withIdentifier: Constants.GroupInfoMemberCell_ID) as! GroupInfoMemberCell
            cell.contactNameLabel.font = UIFont.appFont(ofSize: 17)
            cell.roleLabel.font = UIFont.appFont(ofSize: 13)
            
            if indexPath.row == 0 {
                if group.role != .normal {
                    cell.contactNameLabel.textColor = .link
                    cell.roleLabel.isHidden = true
                    cell.avatarImageView.contentMode = .center
                    cell.avatarImageView.backgroundColor = .systemGray6
                    cell.avatarImageView.image = UIImage(systemName: "plus",
                                                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: UIImage.SymbolWeight.medium))
                    
                    cell.contactNameLabel.text = "Add partecipants".localized()
                } else {
                    cell.contactNameLabel.textColor = .black
                    cell.roleLabel.isHidden = false
                    cell.avatarImageView.contentMode = .scaleAspectFill
                    let contact = group.members[indexPath.row]
                    cell.avatarImageView.backgroundColor = .systemGray6
                    
                    if isYou(contact: contact) {
                        cell.contactNameLabel.text = "You".localized()
                        if let photoPath = Blackbox.shared.account.profilePhotoPath, let image = UIImage.fromPath(photoPath) {
                            cell.avatarImageView.image = image
                        } else {
                            cell.avatarImageView.image = UIImage(named: "avatar_profile.png")
                        }
                    } else {
                        cell.contactNameLabel.text = contact.getName()
                        if let photoPath = contact.profilePhotoPath, let image = UIImage.fromPath(photoPath) {
                            cell.avatarImageView.image = image
                        } else {
                            cell.avatarImageView.image = UIImage(named: "avatar_profile.png")
                        }
                    }
                    
                    
                    if let role = contact.groups[group.ID], role != .normal {
                        cell.roleLabel.text = role.getName()
                        cell.roleLabel.textColor = .systemGray2
                    } else {
                        cell.roleLabel.text = nil
                    }
                }
                
            } else {
                let memberIndex = group.role == .normal ? indexPath.row : indexPath.row - 1
                let contact = group.members[memberIndex]
                
                cell.avatarImageView.contentMode = .scaleAspectFill
                cell.contactNameLabel.textColor = .black
                cell.roleLabel.isHidden = false
                cell.avatarImageView.backgroundColor = .systemGray6
                
                if isYou(contact: contact) {
                    cell.contactNameLabel.text = "You".localized()
                    if let photoPath = Blackbox.shared.account.profilePhotoPath, let image = UIImage.fromPath(photoPath) {
                        cell.avatarImageView.image = image
                    } else {
                        cell.avatarImageView.image = UIImage(named: "avatar_profile.png")
                    }
                } else {
                    cell.contactNameLabel.text = contact.getName()
                    if let photoPath = contact.profilePhotoPath, let image = UIImage.fromPath(photoPath) {
                        cell.avatarImageView.image = image
                    } else {
                        cell.avatarImageView.image = UIImage(named: "avatar_profile.png")
                    }
                }
                
                if let role = contact.groups[group.ID], role != .normal {
                    cell.roleLabel.text = role.getName()
                    cell.roleLabel.textColor = .systemGray2
                } else {
                    cell.roleLabel.text = nil
                }
            }
            return cell
        case 4:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "Clear Chat".localized()
            cell.textLabel?.textColor = canClearChat ? .red : .systemGray
            cell.selectionStyle = canClearChat ? .default : .none
            return cell
        case 5:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "Exit Group".localized()
            cell.textLabel?.textColor = .red
            return cell
        default:
            return UITableViewCell()
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0, self.group.role != .normal {
            if indexPath.row == 0 {
                self.present(ChangeGroupNameViewController(group: self.group), animated: true, completion: nil)
            }
        }
        else if indexPath.section == 1 {
            if indexPath.row == 0 {
                navigationController?.pushViewController(StarredMessagesViewController(group: self.group))
            } else {
                guard let delegate = delegate else { return }
                delegate.didSelectSearch()
                navigationController?.popViewController()
            }
        }
        else if indexPath.section == 2 {
            if indexPath.row == 0 {
                let vc = NotificationSoundSelectionViewController(preSelectedTone: group.messageNotificationSoundName)
                vc.delegate = self
                present(vc, animated: true, completion: nil)
            }
        }
        else if indexPath.section == 3 {
            if indexPath.row == 0, group.role == .administrator || group.role == .creator {
                let vc = AddGroupMembersViewController(group: group)
                let navController = UINavigationController(rootViewController: vc)
                navController.modalPresentationStyle = .fullScreen
                navigationController?.present(navController, animated: true, completion: nil)
                return
            }
            
            let memberIndex = group.role == .normal ? indexPath.row : indexPath.row - 1
            let contact = group.members[memberIndex]
            
            if isYou(contact: contact) {
                return
            }
            
            let alertController = UIAlertController(title: contact.getName(), message: nil, preferredStyle: .actionSheet)
            alertController.popoverPresentationController?.permittedArrowDirections = .down
            
            let contactInfoAction = UIAlertAction(title: "Info".localized(), style: .default) { _ in
                let vc = ContactDetailsViewController(contact: contact)
                let navigation = UINavigationController(rootViewController: vc)
                navigation.modalPresentationStyle = .fullScreen
                self.present(navigation, animated: true, completion: nil)
            }
            let voiceCallAction = UIAlertAction(title: "Voice Call".localized(), style: .default) { _ in
                Blackbox.shared.callManager.startCall(contact: contact)
            }
            let videoCallAction = UIAlertAction(title: "Video Call".localized(), style: .default) { _ in
                if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized {
                    Blackbox.shared.callManager.startCall(contact: contact, video: true)
                } else {
                    NextLevel.requestAuthorization(forMediaType: AVMediaType.video) { (mediaType, status) in
                        if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized {
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
                                Blackbox.shared.callManager.startCall(contact: contact, video: true)
                            }
                        } else if status == .notAuthorized {
                            // gracefully handle when audio/video is not authorized
                            AppUtility.camDenied(viewController: self)
                        }
                    }
                }
            }
            let sendMessageAction = UIAlertAction(title: "Send Message".localized(), style: .default) { _ in
                self.title = ""
                self.navigationController?.pushViewController(ChatViewController(viewModel: ChatViewModel(contact: contact)), animated: true)
            }
            
            alertController.addAction(contactInfoAction)
            alertController.addAction(voiceCallAction)
            alertController.addAction(videoCallAction)
            alertController.addAction(sendMessageAction)
            
            if group.role == .administrator || group.role == .creator {
                
                if let role = contact.groups[group.ID], role == .administrator || role == .creator {
                    let makeGroupAdminAction = UIAlertAction(title: "Dismiss as Admin".localized(), style: .default) { _ in
                        
                        guard let cell = tableView.cellForRow(at: indexPath) as? GroupInfoMemberCell else { return }
                        cell.startActivity()
                        
                        self.group.changeMemberRoleAsync(contact: contact, role: .normal) { success in
                            DispatchQueue.main.async {
                                cell.roleLabel.text = ""
                                cell.stopActivity()
                                tableView.reloadRows(at: [indexPath], with: .automatic)
                            }
                        }
                        
                    }
                    alertController.addAction(makeGroupAdminAction)
                } else {
                    let dismissGroupAdminAction = UIAlertAction(title: "Make Group Admin".localized(), style: .default) { _ in
                        
                        guard let cell = tableView.cellForRow(at: indexPath) as? GroupInfoMemberCell else { return }
                        cell.startActivity()
                        
                        self.group.changeMemberRoleAsync(contact: contact, role: .administrator) { success in
                            DispatchQueue.main.async {
                                cell.stopActivity()
                                tableView.reloadRows(at: [indexPath], with: .automatic)
                            }
                        }
                        
                    }
                    alertController.addAction(dismissGroupAdminAction)
                }
                
                let removeFromGroupAction = UIAlertAction(title: "Remove From Group".localized(), style: .destructive) { _ in
                    
                    let alertController = UIAlertController(title: "\("Remove".localized()) \(contact.getName()) \("from".localized()) \"\(self.group.description)\" \("group".localized())?", message: nil, preferredStyle: .actionSheet)
                    let removeAction = UIAlertAction(title: "Remove".localized(), style: .destructive) { _ in
                        
                        guard let cell = tableView.cellForRow(at: indexPath) as? GroupInfoMemberCell else { return }
                        cell.startActivity()
                        
                        self.group.removeMemberAsync(contact: contact) { success in
                            DispatchQueue.main.async {
                                cell.stopActivity()
                                if success {
                                    tableView.safeDeleteRow(at: indexPath, with: .automatic)
                                } else {
                                    SCLAlertView().showError("Error".localized(), subTitle: "Something went wrong while removing this member. Please try again.".localized())
                                }
                            }
                        }
                    }
                    
                    alertController.addAction(removeAction)
                    alertController.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
                alertController.addAction(removeFromGroupAction)
            }
            
            
            let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
            alertController.addAction(cancel)
            
            // force actions background color to white
            if let view = alertController.view.subviews.first, let view2 = view.subviews.first {
                view2.subviews.forEach {
                    $0.backgroundColor = .white
                }
            }
            
            // iOS Bug: https://stackoverflow.com/a/58666480/1232289
            for subView in alertController.view.subviews {
                for constraint in subView.constraints where constraint.debugDescription.contains("width == - 16") {
                    subView.removeConstraint(constraint)
                }
            }
            
            self.present(alertController, animated: true, completion: nil)
        }
        else if indexPath.section == 4 {
            clearChat()
        }
        else if indexPath.section == 5 {
            if indexPath.row == 0 {
                // Exit group
                let alertController = UIAlertController(title: "\("Exit".localized()) \"\(group.description)\"?", message: nil, preferredStyle: .actionSheet)
                alertController.popoverPresentationController?.permittedArrowDirections = .down
                
                let exitAction = UIAlertAction(title: "Exit Group".localized(), style: .destructive) { (_) in
                    let contact = BBContact()
                    contact.registeredNumber = Blackbox.shared.account.registeredNumber!
                    
                    let hud = JGProgressHUD(style: .dark)
                    hud.show(in: UIApplication.shared.windows[0])
                    
                    self.group.removeMemberAsync(contact: contact) { (success) in
                        DispatchQueue.main.async { [weak self] in
                            guard let strongSelf = self else { return }
                            hud.dismiss()
                            if success {
                                strongSelf.group.removeGroupFromChats()
                                strongSelf.navigationController?.popToViewController(Blackbox.shared.chatListViewController!, animated: true)
                            } else {
                                SCLAlertView().showWarning("Something went wrong while exiting the group. Please try again.".localized(), subTitle: "")
                            }
                        }
                    }
                }
                
                alertController.addAction(exitAction)
                alertController.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    private func clearChat() {
        if canClearChat {
            let alertController = UIAlertController(title: "Delete messages".localized(), message: nil, preferredStyle: .actionSheet)
            let deleteAction = UIAlertAction(title: "Delete all messages".localized(), style: .destructive) { _ in
                let hud = JGProgressHUD(style: .dark)
                hud.show(in: AppUtility.getLastVisibleWindow())
                self.group.clearChatAsync { (success) in
                    DispatchQueue.main.async { [weak self] in
                        guard let strongSelf = self else { return }
                        if success == false {
                            SCLAlertView().showError("Error", subTitle: "Something went wrong while clearing the chat. Pelase check your connectivity and try again".localized())
                        } else {
                            strongSelf.canClearChat = false
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
    
    @objc func selectGroupImage(_ sender: UIButton) {
        //    self.imagePicker.present(from: sender)
        self.present(imagePickerController, animated: true, completion: nil)
    }
    
}

extension ChatGroupInfoTableViewController {
    func isYou(contact: BBContact) -> Bool {
        return contact.registeredNumber == Blackbox.shared.account.registeredNumber
    }
}


// MARK: - Attachements
extension ChatGroupInfoTableViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let mediaType = info[.mediaType] as? NSString {
            if mediaType == "public.image" {
                
                guard let image = info[.originalImage] as? UIImage ?? info[.editedImage] as? UIImage else {
                    return
                }
                
                groupProfileImageView.image = image
                
                if let img = image.fixedOrientation(), let imgData = img.jpegData(compressionQuality: 1) {
                    let imgUrl = AppUtility.getTemporaryDirectory().appendingPathComponent("tmpImage.jpeg")
                    do {
                        if FileManager.default.fileExists(atPath: imgUrl.path) {
                            try FileManager.default.removeItem(at: imgUrl)
                        }
                        
                        try imgData.write(to: imgUrl)
                        group.updateProfileImageAsync(imageUrl: imgUrl) { (success) in
                            if success == false {
                                DispatchQueue.main.async {
                                    SCLAlertView().showError("Error".localized(), subTitle: "Something went wrong while connecting to the server.".localized())
                                }
                            }
                        }
                    } catch {}
                }
            }
            
        }
        imagePickerController.dismiss(animated: true, completion: nil)
    }
}


extension ChatGroupInfoTableViewController: NotificationSoundSelectionViewControllerDelegate {
    func didSelectTone(named: String) {
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            guard let jsonString = BlackboxCore.groupSetNotificationSound(strongSelf.group.ID, soundName: named) else { return }
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    // OK
                    strongSelf.group.messageNotificationSoundName = named
                    DispatchQueue.main.async { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.tableView.reloadRows(at: [IndexPath(row: 1, section: 2)], with: .automatic)
                    }
                    
                } else {
                    loge(response.message)
                    DispatchQueue.main.async {
                        SCLAlertView().showError("Error",
                                                 subTitle: "Something went wrong while contacting the server and we weren't able to update the Notification Sound.".localized())
                    }
                }
            } catch {
                loge(error)
            }
        }
    }
}

extension ChatGroupInfoTableViewController: GroupInfoTemporaryCellDelegate {
    func didSelectDate(date: Date?, cell: GroupInfoTemporaryCell) {
        let hud = JGProgressHUD(style: .dark)
        hud.show(in: UIApplication.shared.windows[0])
        
        group.setGroupExpiryDate(expiryDate: date) { (success) in
            DispatchQueue.main.async {
                hud.dismiss()
            }
        }
    }
    
}

