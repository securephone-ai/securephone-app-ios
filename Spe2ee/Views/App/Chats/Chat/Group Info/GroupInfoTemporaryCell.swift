
import Foundation

protocol GroupInfoTemporaryCellDelegate: class {
  func didSelectDate(date: Date?, cell: GroupInfoTemporaryCell)
}

class GroupInfoTemporaryCell: GroupInfoDefaultCell {
  
  weak var delegate: GroupInfoTemporaryCellDelegate?
  
  lazy var temporarySwitch: UISwitch = {
    let switchView = UISwitch()
    switchView.addTarget(self, action: #selector(switchValueDidChange), for: .valueChanged)
    switchView.setOn(false, animated: false)
    return switchView
  }()
  
  let exitDateLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 15)
    label.textColor = .systemGray2
    label.isUserInteractionEnabled = false
    return label
  }()
  
  private let exitDateInfoLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 15)
    label.textColor = .black
    label.isUserInteractionEnabled = false
    label.text = "Will be deleted on:".localized()
    label.isHidden = true
    return label
  }()

  private lazy var uselessTextField: UITextField = {
    let textField = UITextField()
    textField.isHidden = true
    let toolBar = UIToolbar().ToolbarPiker(mySelect: #selector(setDate), dismissSelector: #selector(dismissDatePicker), target: self)
    textField.inputAccessoryView = toolBar
    return textField
  }()
  
  private lazy var datePicker: UIDatePicker = {
    let datePicker = UIDatePicker()
    datePicker.datePickerMode = .dateAndTime
    datePicker.addTarget(self, action: #selector(dateChanged(datePicker:)), for: .valueChanged)
    
    let calendar = Calendar(identifier: .gregorian)
    
    let currentDate = Date()
    var components = DateComponents()
    components.calendar = calendar
    
    components.year = 150
    let maxDate = calendar.date(byAdding: components, to: currentDate)!
    
    datePicker.maximumDate = maxDate
    datePicker.minimumDate = Date()?.advanced(by: 3600)
    
    return datePicker
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    contentView.addSubview(temporarySwitch)
    contentView.addSubview(exitDateInfoLabel)
    contentView.addSubview(exitDateLabel)
    contentView.addSubview(uselessTextField)
    uselessTextField.inputView = datePicker
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    disclosureIndicator.isHidden = true
    settingDetailLabel.isHidden = true
    
    exitDateInfoLabel.isHidden = exitDateLabel.text == nil
    if exitDateLabel.text != nil {
      settingLabel.pin.vCenter(-12)
    }
    
    if AppUtility.isArabic {
      temporarySwitch.pin.left(18).vCenter(to: settingLabel.edge.vCenter)
      exitDateInfoLabel.pin.topRight(to: settingLabel.anchor.bottomRight).marginTop(10).sizeToFit(.content)
      
      exitDateLabel.pin.left(16).sizeToFit(.content).vCenter(to: exitDateInfoLabel.edge.vCenter)
      exitDateLabel.textAlignment = .left
    } else {
      temporarySwitch.pin.right(18).vCenter(to: settingLabel.edge.vCenter)
      exitDateInfoLabel.pin.topLeft(to: settingLabel.anchor.bottomLeft).marginTop(10).sizeToFit(.content)
      
      exitDateLabel.pin.right(16).sizeToFit(.content).vCenter(to: exitDateInfoLabel.edge.vCenter)
      exitDateLabel.textAlignment = .right
    }

  }
  
  @objc private func switchValueDidChange(_ sender: UISwitch!) {
    if sender.isOn {
      UIView.performWithoutAnimation {
        guard let tableView = tableView else { return }
        uselessTextField.becomeFirstResponder()
        var contentOffset = tableView.contentOffset
        contentOffset.y = -20
        tableView.setContentOffset(contentOffset, animated: true)
      }
    }
    else {
      uselessTextField.resignFirstResponder()
      if exitDateLabel.text != nil {
        guard let delegate = delegate else { return }
        delegate.didSelectDate(date: nil, cell: self)
      }
    }
  }
  
  @objc private func dateChanged(datePicker: UIDatePicker) {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    
    let date = formatter.string(from: datePicker.date) // string purpose I add here
    logi(date)
  }
  
  @objc private func setDate() {
    guard let delegate = delegate else { return }
    delegate.didSelectDate(date: datePicker.date, cell: self)
    uselessTextField.resignFirstResponder()
  }
  
  @objc private func dismissDatePicker() {
    uselessTextField.resignFirstResponder()
    if exitDateLabel.text == nil {
      temporarySwitch.setOn(false, animated: true)
    }
  }
}

fileprivate extension UIToolbar {
  
  func ToolbarPiker(mySelect : Selector, dismissSelector: Selector, target: Any?) -> UIToolbar {
    
    let toolBar = UIToolbar()
    
    toolBar.barStyle = UIBarStyle.default
    toolBar.isTranslucent = true
    toolBar.tintColor = UIColor.black
    toolBar.sizeToFit()
    
    let doneButton = UIBarButtonItem(title: "Done".localized(), style: UIBarButtonItem.Style.plain, target: target, action: mySelect)
    let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
    let dismissButton = UIBarButtonItem(title: "Dismiss".localized(), style: UIBarButtonItem.Style.plain, target: target, action: dismissSelector)
    
    toolBar.setItems([ dismissButton, spaceButton, doneButton], animated: false)
    toolBar.isUserInteractionEnabled = true
    
    return toolBar
  }
  
}
