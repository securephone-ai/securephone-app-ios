
import UIKit

class ContactDetailsBaseCell: UITableViewCell {
  static let _ID = "ContactDetailsBaseCell"
  
  private var maxWidth: CGFloat {
    return UIScreen.main.bounds.width-30
  }
  
  lazy var fieldNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    return label
  }()
  
  
  lazy var fieldValueLabel: UILabel = {
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
    contentView.addSubview(fieldValueLabel)
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    fieldNameLabel.pin.left(15).top(8)
    fieldValueLabel.pin.topLeft(to: fieldNameLabel.anchor.bottomLeft).marginTop(4)
    
  }
}


