import UIKit
import PinLayout
import Combine

class FormBirthdayCell: UITableViewCell {
  static let ID = "FormBirthdayCell"
  static let totalHeight: CGFloat = 55
  
  var viewController: UIViewController?
  var cancellable: AnyCancellable?
  
  public var title: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 16)
    label.text = "Name".localized()
    label.sizeToFit()
    return label
  }()
  
  private lazy var datePicker: UIDatePicker = {
    let datePicker = UIDatePicker()
    datePicker.datePickerMode = .date
    datePicker.addTarget(self, action: #selector(dateChanged(datePicker:)), for: .valueChanged)
    
    let calendar = Calendar(identifier: .gregorian)
    
    let currentDate = Date()
    var components = DateComponents()
    components.calendar = calendar
    
    components.year = 150
    let maxDate = calendar.date(byAdding: components, to: currentDate)!
    
    components.year = -150
    let minDate = calendar.date(byAdding: components, to: currentDate)!
    
    datePicker.minimumDate = minDate
    datePicker.maximumDate = maxDate
    
    return datePicker
  }()
  
  lazy var dateButton: UIButton = {
    let button = UIButton(type: .system)
    button.contentHorizontalAlignment = .left
    button.tintColor = .black
    button.addTarget(self, action: #selector(openDatePicker), for: .touchUpInside)
    button.titleLabel?.font = UIFont.appFont(ofSize: 17)
    return button
  }()
  
  lazy var dateField: CancellableTextField = {
    let textField = CancellableTextField()
    textField.isHidden = true
    return textField
  }()
  
  override func prepareForReuse() {
    cancellable?.cancel()
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    selectionStyle = .none
    contentView.backgroundColor = .white
    
    contentView.addSubview(title)
    contentView.addSubview(dateField)
    contentView.addSubview(dateButton)
    
    dateField.textField.inputView = datePicker
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    title.sizeToFit()
    title.pin.left(18).width(18%).vCenter()
    dateButton.pin.right(of: title).vCenter(to: title.edge.vCenter).marginLeft(47).right().height(50)
  }
  
  @objc func openDatePicker() {
    dateField.textField.becomeFirstResponder()
    
    tableView?.scrollToRow(at: indexPath!, at: .top, animated: true)
  }
  
  @objc func dateChanged(datePicker: UIDatePicker) {
    if datePicker.date.isInToday {
      let formatter = DateFormatter()
      // initially set the format based on your datepicker date / server String
      formatter.dateFormat = "MMMM d"
      
      let date = formatter.string(from: datePicker.date) // string purpose I add here
      dateField.setText(text: date)
      dateButton.setTitle(date, for: .normal)
    } else {
      let formatter = DateFormatter()
      // initially set the format based on your datepicker date / server String
      formatter.dateFormat = "MMMM d, yyyy"
      
      let date = formatter.string(from: datePicker.date) // string purpose I add here
      dateField.setText(text: date)
      dateButton.setTitle(date, for: .normal)
    }
    
  }
  
}
