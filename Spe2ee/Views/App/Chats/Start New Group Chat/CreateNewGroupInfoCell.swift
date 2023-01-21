import UIKit

class CreateNewGroupInfoCell: UITableViewCell {
  static let ID = "CreateNewGroupInfoCell"
  static let Height: CGFloat = 140.0
  
  var groupImageButton: RoundedButton = {
    let button = RoundedButton(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
    button.backgroundColor = .systemGray5
    button.setImage(UIImage(systemName: "camera"), for: .normal)
    button.imageView?.contentMode = .scaleAspectFill
    button.isCircle = true
    return button
  }()
  
  lazy var editImageButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Edit".localized(), for: .normal)
    button.titleLabel?.font = UIFont.appFont(ofSize: 13)
    button.tintColor = .link
    button.isHidden = true
    button.sizeToFit()
    return button
  }()
  
  private var firstLine: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 0.3))
    view.backgroundColor = .systemGray4
    return view
  }()
  
  private var secondLine: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 0.3))
    view.backgroundColor = .systemGray4
    return view
  }()
  
  lazy var groupNameTextField: UITextField = {
    let textField = UITextField()
    textField.placeholder = "Group Subject".localized()
    textField.delegate = self
    return textField
  }()
  
  private var groupNameLettersCountLabel: UILabel = {
    let label = UILabel()
    label.textColor = .systemGray4
    label.text = "25"
    label.sizeToFit()
    label.text = ""
    return label
  }()
  
  private var infoLabel: UILabel = {
    let label = UILabel()
    label.text = "Please provide a group subject and optional group icon".localized()
    label.font = UIFont.appFont(ofSize: 12)
    label.sizeToFit()
    label.textColor = .systemGray2
    return label
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    contentView.addSubview(groupImageButton)
    contentView.addSubview(editImageButton)
    contentView.addSubview(firstLine)
    contentView.addSubview(secondLine)
    contentView.addSubview(groupNameTextField)
    contentView.addSubview(groupNameLettersCountLabel)
    contentView.addSubview(infoLabel)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    groupImageButton.pin.top(30).left(25)
    
    editImageButton.pin.below(of: groupImageButton, aligned: .center).marginTop(2)
    
    firstLine.pin.right(of: groupImageButton).marginLeft(14).top(33).right(16)
    
    groupNameLettersCountLabel.pin.vCenter(to: groupImageButton.edge.vCenter).right(14)
    
    groupNameTextField.pin
      .centerLeft(to: groupImageButton.anchor.centerRight)
      .marginLeft(14)
      .right(to: groupNameLettersCountLabel.edge.left)
      .height(40)
    
    secondLine.pin.topLeft(to: groupNameTextField.anchor.bottomLeft).marginTop(4).right(16)
    
    infoLabel.pin.topLeft(to: secondLine.anchor.bottomLeft).marginTop(4).right(20)
    
  }
  
}

extension CreateNewGroupInfoCell: UITextFieldDelegate {
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    guard let textFieldText = textField.text,
      let rangeOfTextToReplace = Range(range, in: textFieldText) else {
        return false
    }
    let substringToReplace = textFieldText[rangeOfTextToReplace]
    let count = textFieldText.count - substringToReplace.count + string.count
    
    if count <= 25 {
      groupNameLettersCountLabel.text = count == 0 ? "" : String(25-count)
    }
    
    return count <= 25
  }
}
