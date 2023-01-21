import UIKit
import PinLayout
import Combine

class FormDateCell: UITableViewCell {
  static let ID = "FormDateCell"
  static let totalHeight: CGFloat = 55
  
  var viewController: UIViewController?
  var cancellable: AnyCancellable?
  var dateJson: DateJson? {
    didSet {
      guard let dateJson = self.dateJson else { return }
      dateTypeButton.setTitle(dateJson.tag, for: .normal)
      
      if dateJson.date.isEmpty {
        let formatter = DateFormatter()
        // initially set the format based on your datepicker date / server String
        formatter.dateFormat = "MMMM d"
        
        let myString = formatter.string(from: Date()) // string purpose I add here
        dateField.text = myString
        
        dateButton.setTitle(myString, for: .normal)
      }
    }
  }
  
  public var dateTypeButton: UIButton = {
    let button = UIButton(type: .system)
    button.contentHorizontalAlignment = .left
    button.tintColor = .link
    button.titleLabel?.font = UIFont.appFont(ofSize: 16)
    button.titleLabel?.lineBreakMode = .byTruncatingTail
    return button
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
  
  private var dateTypeRightArrow: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 14, height: 14))
    imageView.contentMode = .scaleAspectFit
    imageView.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(weight: .medium))
    imageView.tintColor = .systemGray4
    return imageView
  }()
  
  private lazy var dateButton: UIButton = {
    let button = UIButton(type: .system)
    button.contentHorizontalAlignment = .left
    button.tintColor = .black
    button.addTarget(self, action: #selector(openDatePicker), for: .touchUpInside)
    button.titleLabel?.font = UIFont.appFont(ofSize: 17)
    return button
  }()
  
  private lazy var dateField: UITextField = {
    let textField = UITextField()
    textField.delegate = self
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
    
    contentView.addSubview(dateTypeRightArrow)
    contentView.addSubview(dateTypeButton)
    contentView.addSubview(dateField)
    contentView.addSubview(dateButton)

    dateField.inputView = datePicker
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    dateTypeButton.sizeToFit()
    dateTypeButton.pin.left(18).width(18%).vCenter()
    dateTypeRightArrow.pin.vCenter(to: dateTypeButton.edge.vCenter).right(of: dateTypeButton).marginLeft(2).marginTop(1)
    
    dateButton.pin.right(of: dateTypeButton).vCenter(to: dateTypeButton.edge.vCenter).marginLeft(47).right().height(50)
  }
  
  @objc func openDatePicker() {
    dateField.becomeFirstResponder()
    
    tableView?.scrollToRow(at: indexPath!, at: .top, animated: true)
  }
  
  @objc func dateChanged(datePicker: UIDatePicker) {
    guard let dateJson = self.dateJson else { return }
    
    if datePicker.date.isInToday {
      let formatter = DateFormatter()
      // initially set the format based on your datepicker date / server String
      formatter.dateFormat = "MMMM d"
      
      let date = formatter.string(from: datePicker.date) // string purpose I add here
      dateField.text = date
      dateButton.setTitle(date, for: .normal)
      dateJson.date = date
    } else {
      let formatter = DateFormatter()
      // initially set the format based on your datepicker date / server String
      formatter.dateFormat = "MMMM d, yyyy"
      
      let date = formatter.string(from: datePicker.date) // string purpose I add here
      dateField.text = date
      dateButton.setTitle(date, for: .normal)
      dateJson.date = date
    }
    
  }
  
}

extension FormDateCell: UITextFieldDelegate {

}
