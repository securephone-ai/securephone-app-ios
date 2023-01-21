import Foundation
import UIKit


/// Class to represent custom cell for tableview
public class ContactsPickerTableCell: UITableViewCell {
  static let ID = "ContactsPickerTableCell"
  
  /// Lazy var for label title
  open fileprivate(set) lazy var labelTitle: UILabel = {
    let label = UILabel()
    label.autoresizingMask = [.flexibleWidth]
    label.isOpaque = false
    label.backgroundColor = UIColor.clear
    label.textAlignment = NSTextAlignment.left
    label.lineBreakMode = .byWordWrapping
    label.adjustsFontSizeToFitWidth = false
    label.numberOfLines = 1
    label.textColor = ContactsPickerConfig.tableStyle.title_color
    label.font = ContactsPickerConfig.tableStyle.title_font
    return label
  }()
  
  /// Lazy var for label subtitle
  open fileprivate(set) lazy var labelSubTitle: UILabel = {
    let label = UILabel()
    label.autoresizingMask = [.flexibleWidth]
    label.isOpaque = false
    label.backgroundColor = UIColor.clear
    label.textAlignment = NSTextAlignment.left
    label.lineBreakMode = .byWordWrapping
    label.minimumScaleFactor = 0.6
    label.adjustsFontSizeToFitWidth = true
    label.numberOfLines = 1
    label.textColor = ContactsPickerConfig.tableStyle.description_color
    label.font = ContactsPickerConfig.tableStyle.description_font
    return label
  }()
  
  /// Lazy var for label subtitle
  open fileprivate(set) lazy var imageAvatar: UIImageView = {
    let image = UIImageView()
    image.contentMode = .scaleAspectFill
    image.image = ContactsPickerConfig.placeholder_image
    image.layer.cornerRadius = CGFloat( (ContactsPickerConfig.tableStyle.tableRowHeight-(ContactsPickerConfig.tableStyle.avatarMargin*2))/2)
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
    label.textColor = ContactsPickerConfig.tableStyle.initials_color
    label.font  = ContactsPickerConfig.tableStyle.initials_font
    label.layer.cornerRadius = CGFloat( (ContactsPickerConfig.tableStyle.tableRowHeight-(ContactsPickerConfig.tableStyle.avatarMargin*2))/2)
    label.layer.masksToBounds = true
    return label
  }()
  
  /// Constructor
  ///
  /// - Parameters:
  ///   - style: style for cell
  ///   - reuseIdentifier: string for reuse
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String!) {
    //First Call Super
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    separatorInset.left = 64
    
    //Add subviews to current view
    [labelTitle, imageAvatar, labelSubTitle, initials].forEach { contentView.addSubview($0) }
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    if AppUtility.isArabic {
      let imageSize = CGFloat(ContactsPickerConfig.tableStyle.tableRowHeight-(ContactsPickerConfig.tableStyle.avatarMargin*2))
      imageAvatar.pin.right(12).vCenter().width(imageSize).height(imageSize)
      
      //Adjust initial label view frame
      initials.pin.topLeft(to: imageAvatar.anchor.topLeft).bottomRight(to: imageAvatar.anchor.bottomRight)
      
      //Adjust title view frame
      labelTitle.sizeToFit()
      if let text = labelSubTitle.text, text.count == 0 {
        labelTitle.pin.left(of: imageAvatar).marginHorizontal(8).top(15)
      } else {
        labelTitle.pin.left(of: imageAvatar).marginHorizontal(8).top(10)
      }
      
      labelSubTitle.sizeToFit()
      labelSubTitle.pin.topRight(to: labelTitle.anchor.bottomRight).marginVertical(1)
    } else {
      let imageSize = CGFloat(ContactsPickerConfig.tableStyle.tableRowHeight-(ContactsPickerConfig.tableStyle.avatarMargin*2))
      imageAvatar.pin.left(12).vCenter().width(imageSize).height(imageSize)
      
      //Adjust initial label view frame
      initials.pin.topLeft(to: imageAvatar.anchor.topLeft).bottomRight(to: imageAvatar.anchor.bottomRight)
      
      //Adjust title view frame
      labelTitle.sizeToFit()
      if let text = labelSubTitle.text, text.count == 0 {
        labelTitle.pin.right(of: imageAvatar).marginHorizontal(8).top(15)
      } else {
        labelTitle.pin.right(of: imageAvatar).marginHorizontal(8).top(10)
      }
      
      labelSubTitle.sizeToFit()
      labelSubTitle.pin.topLeft(to: labelTitle.anchor.bottomLeft).marginVertical(1)
    }
  }
  
}
