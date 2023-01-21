import UIKit

class SoundSelectionCell: UITableViewCell {
  static let ID = "SoundSelectionCell_ID"

  let checkImageView: UIImageView = {
    let imageView = UIImageView(image: UIImage(named: "check"))
    imageView.frame = CGRect(x: 0, y: 0, width: 15, height: 15)
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  
  let toneNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    label.adjustsFontForContentSizeCategory = true
    return label
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    contentView.addSubview(checkImageView)
    contentView.addSubview(toneNameLabel)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    checkImageView.pin.vCenter().left(16)
    toneNameLabel.pin.centerLeft(to: checkImageView.anchor.centerRight).marginLeft(16).right(14).sizeToFit(.width)
    
    separatorInset.left = toneNameLabel.frame.origin.x
  }
  
}

