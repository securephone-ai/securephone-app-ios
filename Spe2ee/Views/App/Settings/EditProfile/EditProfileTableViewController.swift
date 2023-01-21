import UIKit
import Combine
import JGProgressHUD
import BlackboxCore

class EditProfileTableViewController: UITableViewController {
    
    var cancellableBag = Set<AnyCancellable>()
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var editProfileView: EditProfileView!
    @IBOutlet weak var accountNumber: UILabel!
    @IBOutlet weak var calendarLabel: UILabel!
    @IBOutlet weak var lastSeenLabel: UILabel!
    @IBOutlet weak var lastSeenSwitch: UISwitch!
    @IBOutlet weak var useMasterPasswordSwitch: UISwitch!
    
    private var rightButtonBar = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
    private var leftButtonBar = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelPressed))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Edit Profile".localized()
        
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 100.0; // set to whatever your "average" cell height is
        tableView.backgroundColor = .systemGray6
        tableView.contentInset.bottom = 10
        
        
        editProfileView.setImagePicker(viewController: self, cropImage: false)
        editProfileView.delegate = self
        
        accountNumber.text = Blackbox.shared.account.registeredNumber
        editProfileView.profileName.returnKeyType = .done
        editProfileView.profileName.delegate = self
        editProfileView.counterLabel.isHidden = true
        
        
        Blackbox.shared.account.$profilePhotoPath.receive(on: DispatchQueue.main).sink { [weak self] (path) in
            guard let strongSelf = self else { return }
            if let path = path, !path.isEmpty {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path, isDirectory: false))
                    strongSelf.editProfileView.profileImageButton.setBackgroundImage(UIImage(data: data), for: .normal)
                } catch {
                    strongSelf.editProfileView.profileImageButton.setImage(nil, for: .normal)
                }
                strongSelf.editProfileView.profileImageButton.setTitle("", for: .normal)
            } else {
                strongSelf.editProfileView.profileImageButton.setImage(nil, for: .normal)
                strongSelf.editProfileView.profileImageButton.setTitle("Add Photo".localized().lowercased(), for: .normal)
            }
        }.store(in: &cancellableBag)
        
        Blackbox.shared.account.$name.receive(on: DispatchQueue.main).sink { [weak self] name in
            guard let strongSelf = self else { return }
            strongSelf.editProfileView.profileName.text = name
        }.store(in: &cancellableBag)
        
        Blackbox.shared.account.$statusMessage
            .receive(on: DispatchQueue.main).sink { [weak self] value in
                guard let strongSelf = self else { return }
                strongSelf.statusLabel.text = value?.localized()
            }.store(in: &cancellableBag)
        
        statusLabel.text = "Available".localized()
        lastSeenLabel.text = "Last seen".localized()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        calendarLabel.text = Blackbox.shared.account.settings.calendar.toString()
        lastSeenSwitch.isOn = Blackbox.shared.account.settings.onlineVisibility
        useMasterPasswordSwitch.isOn = UserDefaults.standard.bool(forKey: "auto_login")
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 13
    }
    
    @objc func donePressed() {
        resetEditMode()
        if let name = editProfileView.profileName.text {
            Blackbox.shared.account.updateProfileNameAsync(name: name.trimmingCharacters(in: .whitespacesAndNewlines)) { (success) in
                if !success {
                    // TODO: Handle Error
                }
            }
        }
    }
    
    @objc func cancelPressed() {
        resetEditMode()
        editProfileView.profileName.text = Blackbox.shared.account.name
    }
    
    
    
    @IBAction func lastSeenChanged(_ sender: Any) {
        let hud = JGProgressHUD(style: .dark)
        hud.show(in: AppUtility.getLastVisibleWindow())
        
        let isOn = lastSeenSwitch.isOn
        DispatchQueue.global(qos: .background).async {
            let blackbox = Blackbox.shared
            guard let jsonString = BlackboxCore.accountSetSettings(blackbox.account.settings.calendar.toString().lowercased(),
                                                                   language: blackbox.account.settings.language,
                                                                   onlineVisibility: isOn,
                                                                   autoDownloadPhotos: AutoDownload(UInt32(blackbox.account.settings.autoDownloadPhotos.toInt())),
                                                                   autoDownloadAudios: AutoDownload(UInt32(blackbox.account.settings.autoDownloadAudios.toInt())),
                                                                   autoDownloadVideos: AutoDownload(UInt32(blackbox.account.settings.autoDownloadVideos.toInt())),
                                                                   autoDownloadDocuments: AutoDownload(UInt32(blackbox.account.settings.autoDownloadDocuments.toInt()))) else {
                DispatchQueue.main.async {
                    hud.dismiss()
                }
                return
            }
            
            logPrettyJsonString(jsonString)
            
            DispatchQueue.main.async {
                do {
                    let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                    if response.isSuccess() {
                        logi("Settings succesfully changed")
                    } else {
                        loge("Settings change Failed")
                    }
                } catch {
                    loge(error)
                }
                
                hud.dismiss()
            }
            
        }
    }
    
    @IBAction func useMasterPasswordSwitch(_ sender: Any) {
        guard let useMasterPwdSwitch = sender as? UISwitch else {
            return
        }
        if useMasterPwdSwitch.isOn {
            let alertController = UIAlertController(title: "Change Master password".localized(),
                                                    message: "We strongly recommend that you leave this option OFF. Setting this ON will let anyone, who has access to your phone, open the app and see its content.".localized(),
                                                    preferredStyle: .alert)
            let action = UIAlertAction(title: "Proceed", style: .destructive) { _ in
                UserDefaults.standard.set(true, forKey: "auto_login")
            }
            
            let action2 = UIAlertAction(title: "Cancel", style: .default) { _ in
                useMasterPwdSwitch.setOn(false, animated: true)
            }
            
            alertController.addAction(action)
            alertController.addAction(action2)
            present(alertController, animated: true, completion: nil)
        } else {
            UserDefaults.standard.set(false, forKey: "auto_login")
        }
    }
}

extension EditProfileTableViewController: EditProfileViewDelegate {
    func imageSelected(image: UIImage?) {
        // temporary save the image to file
        if let img = image {
            Blackbox.shared.account.updateProfilePhotoAsync(image: img) { (result) in
                if !result {
                    // TODO: Handle error
                }
            }
        }
    }
}

extension EditProfileTableViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.navigationItem.rightBarButtonItem = rightButtonBar
        self.navigationItem.leftBarButtonItem = leftButtonBar
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Done pressed
        resetEditMode()
        if let name = textField.text {
            Blackbox.shared.account.updateProfileNameAsync(name: name.trimmingCharacters(in: .whitespacesAndNewlines)) { (success) in
                if !success {
                    // TODO: Handle Error
                }
            }
        }
        return true
    }
    
    func resetEditMode() {
        editProfileView.profileName.resignFirstResponder()
        self.navigationItem.rightBarButtonItem = nil
        self.navigationItem.leftBarButtonItem = nil
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let textFieldText = textField.text,
              let rangeOfTextToReplace = Range(range, in: textFieldText) else {
            return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        
        if count <= 25 {
            editProfileView.counterLabel.text = String(25-count)
        }
        return count <= 25
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return false
    }
    
}

