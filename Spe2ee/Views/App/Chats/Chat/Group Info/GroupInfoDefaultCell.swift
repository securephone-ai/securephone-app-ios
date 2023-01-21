
import UIKit

class GroupInfoDefaultCell: UITableViewCell {
  
  var settingImageView: UIImageView = {
    let image = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    image.contentMode = .scaleAspectFit
    image.isUserInteractionEnabled = false
    return image
  }()
  
  var settingLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    label.textColor = .black
    label.isUserInteractionEnabled = false
    return label
  }()
  
  var settingDetailLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    label.textColor = .systemGray2
    label.isUserInteractionEnabled = false
    return label
  }()
  
  var disclosureIndicator: UIImageView = {
    var imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
    imageView.image = UIImage(systemName: "chevron.right", withConfiguration: config)
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .systemGray2
    imageView.isUserInteractionEnabled = false
    return imageView
  }()
  
  // MARK: - Initializers
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupCell()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupCell()
  }
  
  private func setupCell() {
    contentView.addSubview(settingImageView)
    contentView.addSubview(settingLabel)
    contentView.addSubview(settingDetailLabel)
    contentView.addSubview(disclosureIndicator)
  }
  
  override func prepareForReuse() {
    disclosureIndicator.isHidden = false
    settingImageView.image = nil
    settingDetailLabel.text = nil
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    settingLabel.sizeToFit()
    settingDetailLabel.sizeToFit()
    
    if AppUtility.isArabic {
      disclosureIndicator.pin.left(14).vCenter()
      if settingImageView.image != nil {
        settingImageView.pin.right(14).vCenter()
        settingLabel.pin.horizontallyBetween(settingImageView, and: disclosureIndicator).marginHorizontal(10).vCenter()
      } else {
        settingLabel.pin.right(16).vCenter().left(60)
      }
      
      settingDetailLabel.pin.centerLeft(to: disclosureIndicator.anchor.centerRight).marginLeft(8)
    } else {
      if settingImageView.image != nil {
        settingImageView.pin.left(14).vCenter()
        settingLabel.pin.right(of: settingImageView).marginLeft(10).vCenter().right(60)
      } else {
        settingLabel.pin.left(16).vCenter().right(60)
      }
      
      disclosureIndicator.pin.right(14).vCenter()
      settingDetailLabel.pin.centerRight(to: disclosureIndicator.anchor.centerLeft).marginRight(8)
    }
    

    
    separatorInset.left = settingLabel.frame.origin.x
  }

}
