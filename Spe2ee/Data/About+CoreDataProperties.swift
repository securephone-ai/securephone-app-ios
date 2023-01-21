
import Foundation
import CoreData


extension About {
  
  @nonobjc public class func aboutFetchRequest() -> NSFetchRequest<About> {
    return NSFetchRequest<About>(entityName: "About")
  }
  
  @NSManaged public var index: Int16
  @NSManaged public var status: String
  @NSManaged public var isSelected: Bool
  
}

