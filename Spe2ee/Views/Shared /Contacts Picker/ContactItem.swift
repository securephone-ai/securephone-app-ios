

import Foundation
import UIKit


struct ContactItem {
  
  var spe2eeContact: BBContact? {
    didSet {
      
    }
  }
  
  public var title: String
  public var description: String?
  public var image: UIImage?
  public var imageURL: String?
  public var userInfo: Any?
  public var color: UIColor?
  public var row: Int?
  
  ///Unique identifier
  fileprivate(set) var id: Int?
  
  /// String representation for struct
  public var string: String {
    var describe = "\n+--------------------+"
    describe += "\n| title: \(title)"
    describe += "\n| description: \(String(describing: self.description))"
    describe += "\n| userInfo: \(String(describing: userInfo))"
    describe += "\n| title: \(title)"
    describe += "\n+--------------------+"
    return describe
  }
  
  /// Constructor for item struct used for Phone Contacts Items
  ///
  /// - Parameters:
  ///   - title: title, first line
  ///   - description: description, second line
  ///   - image: image asset
  ///   - imageURL: image url
  ///   - userInfo: optional information data
  public init(row: Int,
              title: String,
              description: String? = nil,
              image: UIImage? = nil,
              imageURL: String? = nil,
              color: UIColor? = nil,
              userInfo: Any? = nil) {
    
    self.title = title
    self.row   = row
    
    if let desc = description {
      self.description = desc
    }
    if let img = image {
      self.image = img
    }
    if let url = imageURL {
      self.imageURL = url
    }
    if let info = userInfo {
      self.userInfo = info
    }
    if let col = color {
      self.color = col
    } 
  }
  
  /// Constructor for item struct used for Phone Contacts Items
  ///
  /// - Parameters:
  ///   - title: title, first line
  ///   - description: description, second line
  ///   - image: image asset
  ///   - imageURL: image url
  ///   - userInfo: optional information data
  init(row: Int, spe2eeContact: BBContact) {
    
    self.title = "\(spe2eeContact.name) \(spe2eeContact.surname)"
    self.row   = row
    
    self.description = spe2eeContact.registeredNumber
    
    self.image = nil
    self.imageURL = nil
    self.userInfo = nil
    self.color = nil
  }
  
  /// Custom equal function to compare objects
  ///
  /// - Parameters:
  ///   - lhs: left object
  ///   - rhs: right object
  /// - Returns: True if two objects referer to the same row
  public static func ==(lhs: ContactItem, rhs: ContactItem) -> Bool{
    return lhs.row == rhs.row
  }
  
  /// Custom disequal function to compare objects
  ///
  /// - Parameters:
  ///   - lhs: left object
  ///   - rhs: right object
  /// - Returns: True if two objects does not referer to the same row
  public static func != (lhs: ContactItem, rhs: ContactItem) -> Bool{
    return lhs.row != rhs.row
  }
  
  /// Get initial letters
  ///
  /// - Returns: String 2 intials
  func getInitials() -> String {
    
    let tit = (title as NSString)
    var initials = String()
    if title != "" && tit.length >= 2
    {
      initials.append(tit.substring(to: 2))
    }
    
    return initials.uppercased()
  }
}
