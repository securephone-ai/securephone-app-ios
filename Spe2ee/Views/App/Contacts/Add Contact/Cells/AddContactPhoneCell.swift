import Combine
import UIKit
import PinLayout

class AddContactPhoneCell: UITableViewCell {
  
  private var cancellableBag = Set<AnyCancellable>()
  
  var contactForm: ContactForm! {
    didSet {
      numberTextField.textField.textPublisher.assign(to: \.number, on: contactForm).store(in: &cancellableBag)
      numberTextField.textField.text = contactForm.number
    }
  }
  
  private var titleLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 16)
    label.text = "Phone".localized()
    label.sizeToFit()
    return label
  }()

  private let numberTextField: CancellableTextField = {
    let cancelableTF = CancellableTextField()
    cancelableTF.textField.placeholder = "Number".localized()
    cancelableTF.maxLenght = 6
    cancelableTF.textField.keyboardType = .numberPad
    return cancelableTF
  }()

  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    selectionStyle = .none
    contentView.backgroundColor = .white
    
    contentView.addSubview(titleLabel)
    contentView.addSubview(numberTextField)

  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    titleLabel.pin.start(16).vCenter().sizeToFit(.content)
    numberTextField.pin.start(110).vCenter().end().height(CancellableTextField.getRequiredHeight())
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cancellableBag.cancellAndRemoveAll()
  }
  
}

extension AddContactPhoneCell {
  static func getRequiredHeight() -> CGFloat { return CancellableTextField.getRequiredHeight() }
}
