import Foundation
import PinLayout


class MessageInfoCell: UITableViewCell {
  var isGroup = false
  
  var leftImageView: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 20, y: 0, width: 20, height: 20))
    imageView.layer.masksToBounds = true
    return imageView
  }()
  
  var contentLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    return label
  }()
  
  var dateLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 13)
    label.textColor = .systemGray
    return label
  }()
  
  var timeLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 13)
    return label
  }()
  
  var pendingImageView: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 20, y: 0, width: 30, height: 10))
    imageView.layer.cornerRadius = 20
    imageView.image = UIImage(named: "empty_ellipses")
    imageView.contentMode = .scaleAspectFit
    imageView.isHidden = true
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
  
  func setupCell() {
    contentView.addSubview(leftImageView)
    contentView.addSubview(contentLabel)
    contentView.addSubview(dateLabel)
    contentView.addSubview(timeLabel)
    contentView.addSubview(pendingImageView)
    
    selectionStyle = .none
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    leftImageView.pin.left(20).vCenter().size(isGroup ? CGSize(width: 38, height: 38): CGSize(width: 20, height: 20))
    timeLabel.pin.right(20).vCenter()
    dateLabel.pin.left(of: timeLabel, aligned: .center).marginRight(4)
    contentLabel.pin.horizontallyBetween(leftImageView, and: dateLabel, aligned: .center).marginHorizontal(10)
    
    if isGroup == false {
      pendingImageView.pin.right(20).vCenter()
      leftImageView.cornerRadius = 10
    } else {
      pendingImageView.pin.hCenter().vCenter()
      leftImageView.cornerRadius = 19
    }
  }
}
