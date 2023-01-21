import Combine
import UIKit
import PinLayout

class FormPhoneCell: UITableViewCell {
  static let ID = "FormPhoneCell"
  static let totalHeight: CGFloat = 110.0
  
  private var cancellableBag = Set<AnyCancellable>()
  
  var phoneNumber: PhoneJson? {
    didSet {
      guard let phoneNumber = self.phoneNumber else { return }
      
      phonePrefix.textPublisher.receive(on: DispatchQueue.main).assign(to: \.prefix, on: phoneNumber).store(in: &cancellableBag)
      phoneNumberTextField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.number, on: phoneNumber).store(in: &cancellableBag)
      
      phoneTypeButton.setTitle(phoneNumber.tag, for: .normal)
      phoneTypeButton.sizeToFit()
      phonePrefix.text = phoneNumber.prefix
      phonePrefix.sizeToFit()
      phoneNumberTextField.text = phoneNumber.number
    }
  }
  
  var viewController: UIViewController?
  
  private var title: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 16)
    label.text = "Phone".localized()
    label.sizeToFit()
    return label
  }()
  
  private lazy var phoneTypeButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle( "Mobile".localized(), for: .normal)
    button.titleLabel?.font = UIFont.appFont(ofSize: 17)
    button.tintColor = .link
    button.addTarget(self, action: #selector(phoneTypeButtontap), for: .touchUpInside)
    button.contentHorizontalAlignment = .left
    return button
  }()
  
  private var phoneTypeButtonRightArrow: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 14, height: 14))
    imageView.contentMode = .scaleAspectFit
    imageView.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(weight: .medium))
    imageView.tintColor = .systemGray4
    return imageView
  }()
  
  private lazy var countryButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle( "Saudi Arabia".localized(), for: .normal)
    button.titleLabel?.font = UIFont.appFont(ofSize: 17)
    button.tintColor = .black
    button.contentHorizontalAlignment = .left
    button.addTarget(self, action: #selector(countryButtonTap), for: .touchUpInside)
    return button
  }()
  
  private var countryButtonRightArrow: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
    imageView.contentMode = .scaleAspectFit
    imageView.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(weight: .medium))
    imageView.tintColor = .systemGray4
    return imageView
  }()
  
  private var countryLineSeparator: UIView = {
    let view = UIView()
    view.backgroundColor = .systemGray4
    return view
  }()
  
  private lazy var phonePrefix: UITextField = {
    let textField = UITextField()
    textField.font = UIFont.appFont(ofSize: 17)
    textField.placeholder = "+"
    textField.delegate = self
    textField.keyboardType = .decimalPad
    textField.addTarget(self, action: #selector(phonePrefixDidChange), for: .editingChanged)
    return textField
  }()
  
  private lazy var phoneNumberTextField: UITextField = {
    let textField = UITextField()
    textField.font = UIFont.appFont(ofSize: 17)
    textField.placeholder = "Phone".localized()
    textField.keyboardType = .decimalPad
    textField.delegate = self
    textField.sizeToFit()
    return textField
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    selectionStyle = .none
    contentView.backgroundColor = .white
    
    contentView.addSubview(title)
    contentView.addSubview(phoneTypeButton)
    contentView.addSubview(phoneTypeButtonRightArrow)
    
    contentView.addSubview(countryButtonRightArrow)
    contentView.addSubview(countryButton)
    contentView.addSubview(countryLineSeparator)
    
    contentView.addSubview(phonePrefix)
    contentView.addSubview(phoneNumberTextField)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    title.pin.left(18).width(18%).top(16)
    
    phoneTypeButton.pin.topLeft(to: title.anchor.bottomLeft).marginTop(25)
    phoneTypeButtonRightArrow.pin.vCenter(to: phoneTypeButton.edge.vCenter).right(of: phoneTypeButton).marginLeft(2).marginTop(1)
    
    countryButton.pin.centerLeft(to: title.anchor.centerRight).marginLeft(47).right().height(50)
    countryButtonRightArrow.pin.vCenter(to: countryButton.edge.vCenter).right(15)
    countryLineSeparator.pin.height(0.3).topLeft(to: countryButton.anchor.bottomLeft).right()
    
    phonePrefix.pin.vCenter(to: phoneTypeButton.edge.vCenter).left(to: countryButton.edge.left)
    phoneNumberTextField.pin.topLeft(to: phonePrefix.anchor.topRight).height(of: phonePrefix).marginLeft(8).right()
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cancellableBag.cancellAndRemoveAll()
  }
  
}

extension FormPhoneCell {
  @objc func countryButtonTap() {
    guard let viewController = self.viewController else { return }
    let vc = CountryCodeTableViewController()
    vc.delegate = self
    viewController.navigationController?.pushViewController(vc, animated: true)
  }
  
  @objc func phonePrefixDidChange() {
    phonePrefix.sizeToFit()
    phonePrefix.pin.vCenter(to: phoneTypeButton.edge.vCenter).left(to: countryButton.edge.left)
    phoneNumberTextField.pin.topLeft(to: phonePrefix.anchor.topRight).height(of: phonePrefix).marginLeft(8).right()
    
    lookupCountryCode(phonePrefix.text!)
  }
  
  @objc func phoneTypeButtontap() {
    guard let viewController = self.viewController else { return }
    
    let vc = PhoneTypeSelectionViewController(selectedType: phoneTypeButton.titleLabel!.text!)
    let navigation = UINavigationController(rootViewController: vc)
    vc.delegate = self
    navigation.modalPresentationStyle = .fullScreen
    viewController.present(navigation, animated: true, completion: nil)
  }
  
  func lookupCountryCode(_ code: String) {
    var countryCodeList = CountryCodeManager.GetCountryCodes()!
    
    if code == "+" {
      countryButton.setTitle("Invalid country code", for: .normal)
    } else {
      if countryCodeList.count == 0 {
        countryCodeList = CountryCodeManager.GetCountryCodes()!
      }
      
      if code == "+1" {
        countryButton.setTitle("United States", for: .normal)
      } else {
        let countries = countryCodeList.filter {
          return $0.code == code
        }
        if countries.count > 0 {
          countryButton.setTitle(countries[0].name, for: .normal)
        } else {
          countryButton.setTitle("Invalid country code", for: .normal)
        }
      }
    }
  }
}

extension FormPhoneCell: CountryCodeTableViewControllerDelegate {
  func didSelect(countryCode: CountryCode) {
    phonePrefix.text = countryCode.code
    phonePrefix.sizeToFit()
    countryButton.setTitle(countryCode.name, for: .normal)
    countryButton.sizeToFit()
  }
}

extension FormPhoneCell: UITextFieldDelegate {
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    guard let textFieldText = textField.text,
      let rangeOfTextToReplace = Range(range, in: textFieldText) else {
        return false
    }
    
    // Check for invalid input characters
    if !CharacterSet(charactersIn: "+0123456789").isSuperset(of: CharacterSet(charactersIn: string)) {
      // Invalid characters detected, disallow text change
      return false
    }
    
    let substringToReplace = textFieldText[rangeOfTextToReplace]
    let count = textFieldText.count - substringToReplace.count + string.count
    if textField == phonePrefix {
      if count == 1, string != "+" {
        phonePrefix.text = "+"
      }
      
      return count <= 4
    }
    else if textField == phoneNumberTextField {
      if let vc = viewController as? AddNewContactViewController {
        if  vc.viewModel.phonesjson[0].id == phoneNumber!.id, !vc.viewModel.updateContact {
          vc.viewModel.isSaveEnabled = count > 0
        }
      }
      return count <= 20
    }
    
    return true
  }
}

extension FormPhoneCell: PhoneTypeSelectionViewControllerDelegate {
  func didSelectPhoneType(type: String) {
    let currentTyep = phoneTypeButton.titleLabel!.text!
    if currentTyep != type {
      phoneNumber?.tag = type
      phoneTypeButton.setTitle(type, for: .normal)
      phoneTypeButton.setTitle(type, for: .normal)
      phoneTypeButton.sizeToFit()
      
      phoneTypeButton.pin.topLeft(to: title.anchor.bottomLeft).marginTop(25)
      phoneTypeButtonRightArrow.pin.vCenter(to: phoneTypeButton.edge.vCenter).right(of: phoneTypeButton).marginLeft(2).marginTop(1)
    }
  }
}
