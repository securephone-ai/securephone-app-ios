import UIKit

class StorageCell: UITableViewCell {
  static let ID = "StorageCell_ID"

  let descriptionLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 16)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = .black
    return label
  }()
  
  let detailLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 16)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = .darkGray
    return label
  }()
  
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    contentView.addSubview(descriptionLabel)
    contentView.addSubview(detailLabel)
    
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  
  override func layoutSubviews() {
    super.layoutSubviews()
    detailLabel.sizeToFit()
    descriptionLabel.sizeToFit()
    detailLabel.pin.vCenter().right(16)
    descriptionLabel.pin.vCenter().left(16)
  }
}

