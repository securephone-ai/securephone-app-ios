import UIKit

class CancellableTextField: UIView {
  
  static func getRequiredHeight() -> CGFloat {
    let textField = UITextField()
    textField.font = UIFont.appFont(ofSize: 17)
    textField.text = "A"
    textField.adjustsFontForContentSizeCategory = true
    textField.sizeToFit()
    return textField.height + 20
  }
  
  open var maxLenght: Int = 30
  
  private var topBorderLine: UIView = {
    let view = UIView()
    view.backgroundColor = .systemGray4
    view.isHidden = true
    return view
  }()

  private var bottomBorderLine: UIView = {
    let view = UIView()
    view.backgroundColor = .systemGray4
    view.isHidden = true
    return view
  }()
  
  var textField: UITextField = {
    let textField = UITextField()
    textField.font = UIFont.appFont(ofSize: 17)
    return textField
  }()
  
  var resetButton: UIButton = {
    let button = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
    button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .medium)), for: .normal)
    button.tintColor = .systemGray2
    button.isHidden = true
    button.addTarget(self, action: #selector(resetText), for: .touchUpInside)
    return button
  }()
  
  var showBorderLines = false {
    didSet {
      topBorderLine.isHidden = !showBorderLines
      bottomBorderLine.isHidden = !showBorderLines
    }
  }
  
  init() {
    super.init(frame: .zero)
    textField.delegate = self
    addSubview(textField)
    addSubview(resetButton)
    addSubview(topBorderLine)
    addSubview(bottomBorderLine)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    pin.height(CancellableTextField.getRequiredHeight())
    
    textField.pin.top().bottom().left().right(40)
    resetButton.pin.centerLeft(to: textField.anchor.centerRight)
    
    topBorderLine.pin.top().left().right().height(0.3)
    bottomBorderLine.pin.bottom().left().right().height(0.3)
  }

  @objc func resetText() {
    resetButton.isHidden = true
    textField.text = ""
    // Manually Notify when changing the textfield text programmatically. So that every Suybscriber get notified
    NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: textField, userInfo: nil)
  }
  
  public func setText(text: String) {
    textField.text = text
    // Manually Notify when changing the textfield text programmatically. So that every Suybscriber get notified
    NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: textField, userInfo: nil)
  }
    
}

extension CancellableTextField: UITextFieldDelegate {
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    guard let textFieldText = textField.text,
      let rangeOfTextToReplace = Range(range, in: textFieldText) else {
        return false
    }
    
    let substringToReplace = textFieldText[rangeOfTextToReplace]
    let count = textFieldText.count - substringToReplace.count + string.count
    if count > 0 {
      resetButton.isHidden = false
    } else {
      resetButton.isHidden = true
    }
    return count <= maxLenght
  }
  
  func textFieldDidBeginEditing(_ textField: UITextField) {
    if let string = textField.text, string.count > 0 {
      resetButton.isHidden = false
    } else {
      resetButton.isHidden = true
    }
  }
  
  func textFieldDidEndEditing(_ textField: UITextField) {
    resetButton.isHidden = true
  }
}
