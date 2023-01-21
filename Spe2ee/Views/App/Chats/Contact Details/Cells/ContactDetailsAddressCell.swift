
import UIKit

class ContactDetailsAddressCell: UITableViewCell {
  static let ID = "ContactDetailsAddressCell"
 
  lazy var fieldNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    return label
  }()
  
  lazy var streetLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    label.textColor = .link
    return label
  }()
  
  lazy var countryLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    label.textColor = .link
    return label
  }()
  
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    selectionStyle = .none
    contentView.backgroundColor = .white
    
    contentView.addSubview(fieldNameLabel)
    contentView.addSubview(streetLabel)
    contentView.addSubview(countryLabel)
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    fieldNameLabel.pin.left(15).top(8)
    streetLabel.pin.topLeft(to: fieldNameLabel.anchor.bottomLeft).marginTop(4)
    countryLabel.pin.topLeft(to: streetLabel.anchor.bottomLeft).marginTop(4)
    
  }
}


