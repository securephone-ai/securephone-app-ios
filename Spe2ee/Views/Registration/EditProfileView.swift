import UIKit

public protocol EditProfileViewDelegate: class {
  func imageSelected(image: UIImage?)
}

class EditProfileView: UIView {
  
  public weak var delegate: EditProfileViewDelegate?
  @IBOutlet var contentView: UIView!
  @IBOutlet weak var profileImageButton: RoundedButton!
  @IBOutlet weak var editButton: UIButton!
  @IBOutlet weak var profileName: UITextField!
  @IBOutlet weak var counterLabel: UILabel!
  
  fileprivate var imagePicker: ImagePicker!
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  func setupView() {
    Bundle.main.loadNibNamed("EditProfileView", owner: self, options: nil)
    addSubview(contentView)
    profileImageButton.imageView?.contentMode = .scaleAspectFill
    profileImageButton.tintColor = .link
    contentView.frame = self.bounds
    contentView.autoresizingMask = [.flexibleWidth, . flexibleHeight]
    profileName.delegate = self
    
    guard let name = profileName.text else { return }
    counterLabel.text = String(25-name.count)
  }
  
  @IBAction func profileImageClick(_ sender: Any) {
    self.imagePicker.present(from: sender as! UIButton)
  }
  
  @IBAction func editClick(_ sender: Any) {
    self.imagePicker.present(from: sender as! UIButton)
  }
  
  public func setImagePicker(viewController: UIViewController?, cropImage: Bool = true) {
    guard let vc = viewController else { return }
    imagePicker = ImagePicker(presentationController: vc, delegate: self, cropImage: cropImage)
  }
}

extension EditProfileView: ImagePickerDelegate {
  func didSelect(image: UIImage?) {
    guard let profileImage = image else {
      profileImageButton.setImage(nil, for: .normal)
      profileImageButton.setTitle("Add Photo".localized().lowercased(), for: .normal)
      editButton.isHidden = true
      return
    }
    profileImageButton.setImage(profileImage, for: .normal)
    profileImageButton.setTitle("", for: .normal)
    profileName.becomeFirstResponder()
    editButton.isHidden = false
    
    guard let del = delegate else { return }
    del.imageSelected(image: image)
  }
}

extension EditProfileView: UITextFieldDelegate {
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    guard let textFieldText = textField.text,
      let rangeOfTextToReplace = Range(range, in: textFieldText) else {
        return false
    }
    let substringToReplace = textFieldText[rangeOfTextToReplace]
    let count = textFieldText.count - substringToReplace.count + string.count
    
    if count <= 25 {
      counterLabel.text = String(25-count)
    }
    return count <= 25
  }
  
  func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    return false
  }
}
