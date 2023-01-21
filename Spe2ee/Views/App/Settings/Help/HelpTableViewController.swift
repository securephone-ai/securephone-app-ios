import UIKit

class HelpTableViewController: UITableViewController {
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .portrait
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.backgroundColor = .systemGray6
    tableView.tableFooterView = UIView()
    
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Blackbox.shared.currentViewController = self  
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    tableView.visibleCells.forEach {
      $0.setNeedsLayout()
      $0.layoutIfNeeded()
    }
  }
  
  // MARK: - Table view data source
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.row == 0 {
      return 140
    }
    return 50
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 5
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

    if indexPath.row == 0 {
      cell.selectionStyle = .none
      let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.width, height: 140))
      let imageView = UIImageView(image: UIImage(named: "support_help"))
      imageView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
      let label = UILabel()
      label.font = UIFont.appFont(ofSize: 16)
      label.adjustsFontForContentSizeCategory = true
      label.text = "You can reach out support staff by choosing one of the following methods".localized()
      label.textAlignment = .center
      label.numberOfLines = 0
      
      view.addSubview(imageView)
      view.addSubview(label)
      imageView.pin.hCenter().top(25)
      label.pin.below(of: imageView).left(20).right(20).bottom()
      
      cell.contentView.addSubview(view)
      cell.accessoryType = .none
      cell.backgroundColor = .clear
      cell.separatorInset.left = 0
    }
    else if indexPath.row == 1 {
      cell.textLabel?.text = "Live Chat".localized()
      cell.separatorInset.left = 0
    }
    else if indexPath.row == 2 {
      
      cell.selectionStyle = .none
      cell.backgroundColor = .clear
      cell.separatorInset.left = 0
      
      let label = UILabel()
      label.font = UIFont.appFont(ofSize: 14)
      label.adjustsFontForContentSizeCategory = true
      label.text = "In-App live chat with one of our support specialist.".localized()
      label.numberOfLines = 0
      label.textColor = .gray
      label.frame = CGRect(x: 16, y: 2, width: tableView.width-32, height: 48)
      cell.contentView.addSubview(label)
      
    }
    else if indexPath.row == 3 {
      cell.textLabel?.text = "In-app Call".localized()
      cell.separatorInset.left = 0
    }
    else if indexPath.row == 4 {
      cell.selectionStyle = .none
      cell.backgroundColor = .clear
      cell.separatorInset.left = 3000
      
      let label = UILabel()
      label.font = UIFont.appFont(ofSize: 14)
      label.adjustsFontForContentSizeCategory = true
      label.text = "Speak to one of our support specialist on in-app call.".localized()
      label.numberOfLines = 0
      label.textColor = .gray
      label.frame = CGRect(x: 16, y: 2, width: tableView.width-32, height: 48)
      cell.contentView.addSubview(label)
      
    }
    else if indexPath.row == 5 {
      cell.textLabel?.text = "Phone Call".localized()
    }
    else if indexPath.row == 6 {

      cell.backgroundColor = .clear
      cell.selectionStyle = .none
      
      let label = UILabel()
      label.font = UIFont.appFont(ofSize: 14)
      label.adjustsFontForContentSizeCategory = true
      label.text = "Speak to one of our support specialist on your GSM number.".localized()
      label.numberOfLines = 0
      label.textColor = .gray
      label.frame = CGRect(x: 16, y: 2, width: tableView.width-32, height: 48)
      cell.contentView.addSubview(label)
      
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let blackbox = Blackbox.shared
    if indexPath.row == 1 {
      if blackbox.account.settings.supportInAppChatNumber.isEmpty {
        return
      }
      if let _contact = blackbox.getContact(registeredNumber: blackbox.account.settings.supportInAppChatNumber) {
        blackbox.openChat(contact: _contact)
      } else if let _contact = blackbox.getTemporaryContact(registeredNumber: blackbox.account.settings.supportInAppChatNumber) {
        blackbox.openChat(contact: _contact)
      } else {
        // create a temporary the contact
        let contact = BBContact()
        contact.name = "App-Support".localized()
        contact.phonejsonreg = [PhoneNumber(tag: "mobile", phone: blackbox.account.settings.supportInAppChatNumber)]
        contact.phonesjson = [PhoneNumber(tag: "mobile", phone: blackbox.account.settings.supportInAppChatNumber)]
        contact.registeredNumber = blackbox.account.settings.supportInAppChatNumber
        contact.isSavedContact = false
        // Add it to the temporary contacts
        blackbox.temporaryContacts.append(contact)
        navigationController?.pushViewController(ChatViewController(viewModel: ChatViewModel(contact: contact)))
      }
    } else if indexPath.row == 3 {
      if blackbox.account.settings.supportInAppChatNumber.isEmpty {
        return
      }
      if let _contact = blackbox.getContact(registeredNumber: blackbox.account.settings.supportInAppCallNumber) {
        blackbox.callManager.startCall(contact: _contact)
      } else if let _contact = blackbox.getTemporaryContact(registeredNumber: blackbox.account.settings.supportInAppCallNumber) {
        blackbox.callManager.startCall(contact: _contact)
      } else {
        // create a temporary the contact
        let contact = BBContact()
        contact.name = "App-Support".localized()
        contact.phonejsonreg = [PhoneNumber(tag: "mobile", phone: blackbox.account.settings.supportInAppCallNumber)]
        contact.phonesjson = [PhoneNumber(tag: "mobile", phone: blackbox.account.settings.supportInAppCallNumber)]
        contact.registeredNumber = blackbox.account.settings.supportInAppCallNumber
        contact.isSavedContact = false
        // Add it to the temporary contacts
        blackbox.temporaryContacts.append(contact)
        blackbox.callManager.startCall(contact: contact)
      }
    } else if indexPath.row == 2 {
      
    }
  }
  

}

