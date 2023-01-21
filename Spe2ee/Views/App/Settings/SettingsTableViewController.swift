import UIKit
import Combine
import JGProgressHUD
import BlackboxCore


class SettingsTableViewController: UITableViewController, UIGestureRecognizerDelegate {
    var cancellable : [AnyCancellable]?
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var profileNameLabel: UILabel!
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var versionLabel: UILabel!
    
    private var logoClickCounter = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings".localized()
        
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 44.0; // set to whatever your "average" cell height is
        
        profileImage.layer.cornerRadius = profileImage.frame.size.width/2
        profileImage.layer.masksToBounds = true
        profileImage.layer.borderWidth = 1
        profileImage.layer.borderColor = UIColor.systemGray3.cgColor
        profileImage.contentMode = .scaleAspectFill
        
        cancellable = [
            Blackbox.shared.account.$profilePhotoPath.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (path) in
                guard let strongSelf = self else { return }
                if let path = path, !path.isEmpty {
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: path, isDirectory: false))
                        strongSelf.profileImage.image = UIImage(data: data)
                    } catch {
                        strongSelf.profileImage.image = nil
                    }
                }
            }),
            
            Blackbox.shared.account.$name.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (name) in
                guard let strongSelf = self else { return }
                if let name = name {
                    strongSelf.profileNameLabel.text = name
                }
            })
        ]
        
        versionLabel.adjustsFontForContentSizeCategory = true
        versionLabel.textAlignment = .center
        
        logoImageView.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(logoImageViewSingleTap))
        tapGesture.delegate = self
        tapGesture.cancelsTouchesInView = false
        logoImageView.addGestureRecognizer(tapGesture)
        
        let longPressCell = UILongPressGestureRecognizer(target: self, action: #selector(logoImageViewLongPress))
        longPressCell.minimumPressDuration = 2
        longPressCell.delegate = self
        longPressCell.cancelsTouchesInView = false
        logoImageView.addGestureRecognizer(longPressCell)
        
        logoImageView.cornerRadius = 8
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Blackbox.shared.currentViewController = self
        
        versionLabel.text = Bundle.main.releaseVersionNumber
        
        logoClickCounter = 0
    }
    
    @objc func logoImageViewSingleTap() {
        logoClickCounter += 1
        if logoClickCounter == 7 {
            logoClickCounter = 0
            let alertController = UIAlertController(title: "Deactivate Calc".localized(),
                                                    message: "This will require contacting the System Administration to reactivate".localized(),
                                                    preferredStyle: .actionSheet)
            let confirmAction = UIAlertAction(title: "Confirm".localized(), style: .destructive) { _ in
                let hud = JGProgressHUD(style: .dark)
                hud.show(in: AppUtility.getLastVisibleWindow())
                BlackboxCore.wipeAllFiles()
                exit(0)
            }
            alertController.addAction(confirmAction)
            alertController.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    @objc func logoImageViewLongPress() {
        logi()
        
        let alertController = UIAlertController(title: "Log-out".localized(),
                                                message: "This will log you out and you will be required to enter your Master password to Login again".localized(),
                                                preferredStyle: .actionSheet)
        let confirmAction = UIAlertAction(title: "Confirm".localized(), style: .destructive) { _ in
            BlackboxCore.removeTemporaryFiles()
            BlackboxCore.removeTemporaryPwdConfFile()
            
            let blackbox = Blackbox.shared
            
            if let rootVC = UIApplication.shared.windows[0].rootViewController as? AppRootViewController {
                rootVC.viewControllers?.removeAll()
            }
            
            blackbox.networkManager?.stopListening()
            blackbox.networkManager = nil
            blackbox.appRootViewController = nil
            blackbox.callViewController = nil
            blackbox.chatViewController = nil
            blackbox.currentViewController = nil
            blackbox.chatListViewController = nil
            blackbox.contactsSections.removeAll()
            blackbox.temporaryContacts.removeAll()
            blackbox.callHistoryCellsViewModels.removeAll()
            blackbox.chatItems.forEach { (chatItem) in
                if let chatViewModel = chatItem.getChatItemViewModel() {
                    if let contact = chatViewModel.contact {
                        contact.messagesSections.removeAll()
                    } else if let group = chatViewModel.group {
                        group.messagesSections.removeAll()
                    }
                }
            }
            blackbox.chatItems = [.Archive]
            
            blackbox.archivedChatItems.forEach { (chatViewModel) in
                if let contact = chatViewModel.contact {
                    contact.messagesSections.removeAll()
                } else if let group = chatViewModel.group {
                    group.messagesSections.removeAll()
                }
            }
            blackbox.archivedChatItems.removeAll()
            blackbox.account.state = .offline
            Blackbox.shared.account.isInternalPushregistered = false
            
            UIApplication.shared.windows[0].rootViewController = LoginViewController()
            
        }
        alertController.addAction(confirmAction)
        alertController.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
        
    }
}

// MARK: - Table view data source & delegate
extension SettingsTableViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 12
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 2 {
            navigationController?.pushViewController(StarredMessagesViewController())
        } else if indexPath.row == 6 {
            navigationController?.pushViewController(StorageUsageTableViewController())
        } else if indexPath.row == 8 {
            navigationController?.pushViewController(HelpTableViewController())
        }
    }
    
}


