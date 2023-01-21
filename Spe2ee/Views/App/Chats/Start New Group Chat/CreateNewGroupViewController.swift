import UIKit
import Combine
import JGProgressHUD

protocol CreateNewGroupViewControllerDelegate: class {
  func didRemoveContactWith(id: String)
}

class CreateNewGroupViewController: UITableViewController {
  weak var delegate: CreateNewGroupViewControllerDelegate?
  
  private var members: [BBContact] = [BBContact]()
  private var groupDescription: String = ""
  private var groupImage: UIImage?
  private var imagePicker: ImagePicker!
  private var rightButtonBar = UIBarButtonItem()
  private var cancellable: AnyCancellable?
  
  private lazy var imagePickerController: UIImagePickerController = {
    let picker = UIImagePickerController()
    picker.sourceType = .photoLibrary
    picker.mediaTypes = ["public.image"]
    picker.modalPresentationStyle = .fullScreen
    picker.delegate = self
    return picker
  }()
  
  init(members: [BBContact]) {
    self.members = members
    
    super.init(nibName: nil, bundle: nil)
    
    self.tableView.separatorStyle = .none
    self.tableView.allowsSelection = false
    self.tableView.register(CreateNewGroupInfoCell.self, forCellReuseIdentifier: CreateNewGroupInfoCell.ID)
    self.tableView.register(MembersCollectionCell.self, forCellReuseIdentifier: MembersCollectionCell.ID)
    
//    imagePicker = ImagePicker(presentationController: self, delegate: self)
    
    rightButtonBar = UIBarButtonItem(title: "Create".localized(), style: .plain, target: self, action: #selector(createGroup))
    rightButtonBar.isEnabled = false
    self.navigationItem.rightBarButtonItem = rightButtonBar
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    if section == 0 {
      return 0
    }
    return 25
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    if section == 0 {
      return UIView()
    }
    
    let header = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 25))
    header.backgroundColor = .systemGray6
    
    let label = UILabel()
    label.text = "\("PARTECIPANTS".localized().uppercased()): \(members.count) \("OF 256".localized())"
    label.font = UIFont.appFont(ofSize: 13)
    label.textColor = .systemGray2
    label.sizeToFit()
    
    header.addSubview(label)
    label.pin.vCenter().left(20)
    
    return header
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.section == 0 {
      return CreateNewGroupInfoCell.Height
    } else {
      return MembersCollectionCell.calculateHeight(members: members, tableWidth: tableView.frame.width)
    }
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 0 {
      if let cell = tableView.dequeueReusableCell(withIdentifier: CreateNewGroupInfoCell.ID, for: indexPath) as? CreateNewGroupInfoCell {
        //cell.cancellable = cell.groupNameTextField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.groupDescritpion, on: self)
        cancellable = cell.groupNameTextField.textPublisher.receive(on: DispatchQueue.main).sink { [weak self ](string) in
          guard let strongSelf = self else { return }
          strongSelf.groupDescription = string
          strongSelf.rightButtonBar.isEnabled = string.count == 0 ? false : true
        }
        cell.groupImageButton.addTarget(self, action: #selector(selectGroupImage(_ :)), for: .touchUpInside)
        cell.editImageButton.addTarget(self, action: #selector(selectGroupImage(_ :)), for: .touchUpInside)
        return cell
      }
    } else {
      if let cell = tableView.dequeueReusableCell(withIdentifier: MembersCollectionCell.ID, for: indexPath) as? MembersCollectionCell {
        cell.members = self.members
        cell.delegate = self
        return cell
      }
    }
    
    return UITableViewCell()
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
  }
  
  @objc func selectGroupImage(_ sender: UIButton) {
//    self.imagePicker.present(from: sender)
    self.present(imagePickerController, animated: true, completion: nil)
  }
  
  @objc func createGroup() {
    let hud = JGProgressHUD(style: .dark)
    hud.textLabel.text = "Creating group".localized()
    hud.show(in: self.view)
    
    Blackbox.shared.createGroupAsync(description: groupDescription, members: members) { (group, error) in
      if error == nil, let group = group {
        if let img = self.groupImage?.fixedOrientation(), let imgData = img.jpegData(compressionQuality: 1) {
            let imgUrl = AppUtility.getTemporaryDirectory().appendingPathComponent("tmpImage.jpeg")
            do {
                if FileManager.default.fileExists(atPath: imgUrl.path) {
                    try FileManager.default.removeItem(at: imgUrl)
                }
                
                try imgData.write(to: imgUrl)
                group.updateProfileImageAsync(imageUrl: imgUrl) { (success) in
                    DispatchQueue.main.async {
                        hud.dismiss()
                        if !success {
                            // TODO: Handle Errors
                        }
                        Blackbox.shared.chatListViewController?.openChat(group: group)
                    }
                }
            } catch {}
        } else {
          hud.dismiss()
          Blackbox.shared.chatListViewController?.openChat(group: group)
        }
      } else {
        // TODO: Check error
      }
    }
  }
}

extension CreateNewGroupViewController: MembersCollectionCellDlegate {
  func removedMember(at index: Int) {
    if index <  self.members.count {
      let contact = self.members[index]
      members.remove(at: index)
      self.tableView?.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .none)
      guard let delegate = self.delegate else { return }
      delegate.didRemoveContactWith(id: contact.ID)
    }
  }
}

extension CreateNewGroupViewController: ImagePickerDelegate {
  func didSelect(image: UIImage?) {
    let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as! CreateNewGroupInfoCell
    guard let _groupImage = image else {
      cell.groupImageButton.setImage(UIImage(systemName: "camera"), for: .normal)
      groupImage = nil
      return
    }
    groupImage = _groupImage
    cell.groupImageButton.setImage(groupImage, for: .normal)
    cell.editImageButton.isHidden = false
  }
}


// MARK: - Attachements
extension CreateNewGroupViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as! CreateNewGroupInfoCell
    if let mediaType = info[.mediaType] as? NSString {
      if mediaType == "public.image" {
        if let image = info[.originalImage] as? UIImage {
          // Gallery Image
          groupImage = image
          cell.groupImageButton.setImage(groupImage, for: .normal)
          cell.editImageButton.isHidden = false

        } else if let image = info[.editedImage] as? UIImage {
          // TODO: Save the image as imageHolder.jpeg -> Encrypt first -> Delete imageHolder.jpeg -> then send.
          groupImage = image
          cell.groupImageButton.setImage(groupImage, for: .normal)
          cell.editImageButton.isHidden = false
          // Photo Edited original
//          if let data = image.jpegData(compressionQuality: 1) {
//            let fileUrl = AppUtility.getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).jpeg")
//            try? data.write(to: fileUrl)
//
//          }
        }
      }
      
    }
    imagePickerController.dismiss(animated: true, completion: nil)
  }
}
