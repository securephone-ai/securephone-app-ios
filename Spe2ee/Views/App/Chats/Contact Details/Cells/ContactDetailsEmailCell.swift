import UIKit

class ContactDetailsEmailCell: ContactDetailsBaseCell {
  static let ID = "ContactDetailsEmailCell"
  
  var email: Email? {
    didSet {
      guard let item = self.email else { return }
      
      fieldNameLabel.text = item.tag
      fieldNameLabel.sizeToFit()
      
      fieldValueLabel.text = item.email
      fieldValueLabel.sizeToFit()
      
    }
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

}


