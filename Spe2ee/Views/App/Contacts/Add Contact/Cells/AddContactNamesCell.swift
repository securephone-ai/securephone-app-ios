import Foundation
import Combine
import PinLayout

class AddContactNamesCell: UITableViewCell {
  
  private var cancellableBag = Set<AnyCancellable>()
  
  private var rootView = UIView()
  
  private let titleLabel: UILabel = {
    let label = UILabel(text: "Name")
    label.font = UIFont.appFontBold(ofSize: 17)
    label.frame = CGRect(x: 0, y: 0, width: 0, height: label.requiredHeight)
    label.adjustsFontForContentSizeCategory = true
    return label
  }()
  
  private let firstNameTextField: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "First name".localized()
    return textView
  }()
  
  private let surnameTextField: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Surname".localized()
    textView.showBorderLines = true
    return textView
  }()
  
  private let titleTextField: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Title".localized()
    return textView
  }()

  var contactForm: ContactForm! {
    didSet {
      firstNameTextField.textField.textPublisher.assign(to: \.name, on: contactForm).store(in: &cancellableBag)
      surnameTextField.textField.textPublisher.assign(to: \.surname, on: contactForm).store(in: &cancellableBag)
      titleTextField.textField.textPublisher.assign(to: \.title, on: contactForm).store(in: &cancellableBag)
      
      firstNameTextField.textField.text = contactForm.name
      surnameTextField.textField.text = contactForm.surname
      titleTextField.textField.text = contactForm.title
    }
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    contentView.addSubview(titleLabel)
    contentView.addSubview(firstNameTextField)
    contentView.addSubview(surnameTextField)
    contentView.addSubview(titleTextField)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cancellableBag.cancellAndRemoveAll()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    titleLabel.pin.start(16).top(4).sizeToFit(.content)
    firstNameTextField.pin.start(110).vCenter(to: titleLabel.edge.vCenter).end().height(CancellableTextField.getRequiredHeight())
    surnameTextField.pin.below(of: firstNameTextField, aligned: .start).end().height(CancellableTextField.getRequiredHeight())
    titleTextField.pin.below(of: surnameTextField, aligned: .start).end().height(CancellableTextField.getRequiredHeight())
  }
}

extension AddContactNamesCell {
  static func getRequiredHeight() -> CGFloat { return CancellableTextField.getRequiredHeight() * 3 }
}
