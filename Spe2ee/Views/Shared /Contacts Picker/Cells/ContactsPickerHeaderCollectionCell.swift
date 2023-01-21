

import Foundation
import UIKit

/// Class to represent custom cell for tableview
public class ContactsPickerHeaderCollectionCell: UICollectionViewCell {
  static let ID = "ContactsPickerHeaderCollectionCell"
  
  /// Lazy var for label title
  open fileprivate(set) lazy var labelTitle: UILabel = {
    let label = UILabel()
    label.autoresizingMask = [.flexibleWidth]
    label.isOpaque = false
    label.backgroundColor = UIColor.clear
    label.textAlignment = NSTextAlignment.center
    label.adjustsFontSizeToFitWidth = false
    label.numberOfLines = 1
    label.textColor = ContactsPickerConfig.selectorStyle.title_color
    label.font = ContactsPickerConfig.selectorStyle.title_font
    return label
  }()
  
  /// Lazy var for label subtitle
  open fileprivate(set) lazy var imageAvatar: UIImageView = {
    let image = UIImageView()
    image.contentMode = .scaleAspectFill
    image.image = ContactsPickerConfig.placeholder_image
    image.layer.cornerRadius = CGFloat(ContactsPickerConfig.selectorStyle.selectionHeight-((ContactsPickerConfig.selectorStyle.avatarScale*2.0)*ContactsPickerConfig.tableStyle.avatarMargin))/2.0
    image.layer.masksToBounds = true
    return image
  }()
  
  /// Lazy var for initials label
  open fileprivate(set) lazy var initials: UILabel = {
    let label = UILabel()
    label.isOpaque = false
    label.backgroundColor = UIColor.gray
    label.textAlignment = NSTextAlignment.center
    label.lineBreakMode = .byWordWrapping
    label.minimumScaleFactor = 0.6
    label.adjustsFontSizeToFitWidth = true
    label.numberOfLines = 1
    label.textColor = ContactsPickerConfig.selectorStyle.initials_color
    label.font = ContactsPickerConfig.selectorStyle.initials_font
    label.layer.cornerRadius = CGFloat(ContactsPickerConfig.selectorStyle.selectionHeight-((ContactsPickerConfig.selectorStyle.avatarScale*2.0)*ContactsPickerConfig.tableStyle.avatarMargin))/2.0
    label.layer.masksToBounds = true
    return label
  }()
  
  /// Lazy var for remove button
  open fileprivate(set) lazy var removeButton: CellButton = {
    let button = CellButton()
    button.setImage(ContactsPickerConfig.selectorStyle.removeButtonImage, for: .normal)
    return button
  }()
  
  override init(frame: CGRect) {
    
    super.init(frame: frame)
    
    
    //Add subviews to current view
    [labelTitle, imageAvatar, initials, removeButton].forEach { addSubview($0) }
    backgroundColor = ContactsPickerConfig.selectorStyle.backgroundCellColor
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let avatarHeight = CGFloat(ContactsPickerConfig.selectorStyle.selectionHeight-((ContactsPickerConfig.selectorStyle.avatarScale*2.0)*ContactsPickerConfig.tableStyle.avatarMargin))
      
    imageAvatar.pin
      .hCenter()
      .top(6)
      .height(avatarHeight)
      .width(avatarHeight)
  
    initials.pin.topLeft(to: imageAvatar.anchor.topLeft).bottomRight(to: imageAvatar.anchor.bottomRight)
    
    removeButton.pin.top(6).right(8).width(18).height(18)

    labelTitle.sizeToFit()
    labelTitle.pin.below(of: imageAvatar).left(3).right(3)
    
  }
  
  
  
}
