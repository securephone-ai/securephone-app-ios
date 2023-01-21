
import Foundation
import UIKit


/// Define the type of datasource
public enum ContactsPickerSourceType : Int {
  case phone  =   0
  case custom =   1
}

/// Main static class
public class ContactsPicker {
  
  public var isDataGrouped: Bool = true
  
  public var dataSourceType: ContactsPickerSourceType? = .phone {
    didSet {
      if dataSourceType == .phone {
        getContacts()
      } else {
        items = [ContactItem]()
      }
    }
  }
  
  /// Delegate reference
  var delegate: ContactsPickerDelegate? {
    didSet {
      if dataSourceType == .phone {
        getContacts()
      } else {
        items = [ContactItem]()
      }
    }
  }
  
  init(sourceType: ContactsPickerSourceType) {
    self.dataSourceType = sourceType
  }
  
  var items: [ContactItem] = [ContactItem]()
  var groupedItems: [(key: String, value: [ContactItem])]?
  var filteredItems: [ContactItem] = [ContactItem]()
  
  var dataSource: ContactsPickerDataSource?
  
  /// Array of initial items selected
  var initialSelected: [ContactItem] = [ContactItem]()
  
  /// Function to present a selector in a UIViewContoller claass
  ///
  /// - Parameter to: UIViewController current visibile
  func Show(to: UIViewController) {
    
    // Create instance of selector
    let selector = ContactsPickerViewController()
    selector.contactsPicker = self
    
    // Set initial items
    selector.selectedItems = initialSelected
    selector.presentedModally = true
    
    //Create navigation controller
    let navController = UINavigationController(rootViewController: selector)
    navController.modalPresentationStyle = ContactsPickerConfig.modalStyle
    
    // Present selectora
    to.present(navController, animated: true, completion: nil)
  }
  
  /// Function to present a selector in a UIViewContoller claass
  ///
  /// - Parameter to: UIViewController current visibile
  func Push(from: UINavigationController) {
    let selector = ContactsPickerViewController()
    selector.contactsPicker = self
    selector.selectedItems = initialSelected
    selector.presentedModally = false
    from.pushViewController(selector, animated: true)
  }
  
  private func getContacts() {
    // Retrieve contacts from phone
    ContactsHelper.getContacts { (success, data) in
      self.items = data!.sorted(by: { (first, second) -> Bool in
        return first.title.lowercased() < second.title.lowercased()
      })
      
      self.groupedItems = Dictionary(grouping: data!) { (item) -> String in
        return String(item.title.lowercased().prefix(1))
      }.sorted(by: { (first, second) -> Bool in
        let (key, _) = first
        let (key2, _) = second
        return key.lowercased() < key2.lowercased()
      })
    }
  }
  
  class func image(named name: String) -> UIImage? {
    let image = UIImage(named: name) ?? UIImage(named: name, in: Bundle(for: self), compatibleWith: nil)
    return image
  }
}

// User's avatar color
public struct ThemeColors {
  static let emeraldColor         = UIColor(red: (46/255), green: (204/255), blue: (113/255), alpha: 1.0)
  static let sunflowerColor       = UIColor(red: (241/255), green: (196/255), blue: (15/255), alpha: 1.0)
  static let pumpkinColor         = UIColor(red: (211/255), green: (84/255), blue: (0/255), alpha: 1.0)
  static let asbestosColor        = UIColor(red: (127/255), green: (140/255), blue: (141/255), alpha: 1.0)
  static let amethystColor        = UIColor(red: (155/255), green: (89/255), blue: (182/255), alpha: 1.0)
  static let peterRiverColor      = UIColor(red: (52/255), green: (152/255), blue: (219/255), alpha: 1.0)
  static let pomegranateColor     = UIColor(red: (192/255), green: (57/255), blue: (43/255), alpha: 1.0)
  static let lightGrayColor       = UIColor(red:0.79, green:0.78, blue:0.78, alpha:1)
}

/// Public struct for configuration and customizations
public struct ContactsPickerConfig {
  
  /// Modal Style
  public static var modalStyle: UIModalPresentationStyle = .fullScreen
  /// Background of main view
  public static var mainBackground: UIColor = UIColor.white
  /// View's title
  public static var viewTitle: String = "Select Multiple Contacts".localized()
  /// Title for done button
  public static var doneString: String = "Done"
  //Placeholder image during lazy load
  public static var placeholder_image : UIImage = ContactsPicker.image(named: "avatar_profile")!
  /// Array of colors to use in initials
  public static var colorArray: [UIColor] = [
    ThemeColors.amethystColor,
    ThemeColors.asbestosColor,
    ThemeColors.emeraldColor,
    ThemeColors.peterRiverColor,
    ThemeColors.pomegranateColor,
    ThemeColors.pumpkinColor,
    ThemeColors.sunflowerColor
  ]
  
  /// Define the style of tableview
  public struct tableStyle {
    
    //Background color of tableview
    public static var backgroundColor       :   UIColor = .white
    //Height of single row
    public static var tableRowHeight        :   Double  = 56.0
    //Margin between imageavatar and cell borders
    public static var avatarMargin          :   Double  = 6.0
    //Color for title label, first line
    public static var title_color           :   UIColor = .black
    //Font for title label
    public static var title_font            :   UIFont  = UIFont.boldSystemFont(ofSize: 17.0)
    //Color for description label, first line
    public static var description_color     :   UIColor = .gray
    //Font for description label
    public static var description_font      :   UIFont  = UIFont.systemFont(ofSize: 13.0)
    //Color for initials label
    public static var initials_color        :   UIColor = .white
    //Font for initials label
    public static var initials_font         :   UIFont  = UIFont.systemFont(ofSize: 18.0)
    
  }
  
  /// Define the style of scrollview
  public struct selectorStyle {
    
    //Image asset for remove button
    public static var removeButtonImage     :   UIImage = ContactsPicker.image(named: "remove")!
    //The height of selectorview, all subviews will be resized
    public static var selectionHeight       :   Double  = 70.0
    //Scale factor for size of imageavatar based on cell size
    public static var avatarScale           :   Double  = 1.7
    //Color for separator line between scrollview and tableview
    public static var separatorColor        :   UIColor = UIColor.lightGray
    //Height for separator line between scrollview and tableview
    public static var separatorHeight       :   Double  = 0.7
    //Background color of uiscrollview
    public static var backgroundColor       :   UIColor = .white
    //Color for title label
    public static var title_color           :   UIColor = .black
    //Font for title label
    public static var title_font            :   UIFont  = UIFont.systemFont(ofSize: 11.0)
    //Color for initials label
    public static var initials_color        :   UIColor = .white
    //Font for initials label
    public static var initials_font         :   UIFont  = UIFont.systemFont(ofSize: 18.0)
    //Background color of collectionviewcell
    public static var backgroundCellColor   :   UIColor = .clear
    
  }
  
}


/// A data source
protocol ContactsPickerDataSource {
  
  /// Ask delegate for current item in row
  func getItem(at indexPath: IndexPath) -> ContactItem
  
  /// Asks for the number of items
  func contactPickerRows(forSection section:Int) -> Int
  
  /// Asks for the number of sections
  func numberOfSectionsContactsPicker() -> Int
  
}

/// A delegate to handle
protocol ContactsPickerDelegate {
  
  /// Tell to delegate that user did end selection
  func didSelect(items: [ContactItem])
  
  /// Tell to delegate that item has been selected
  func didSelect(item: ContactItem)
  
  /// Tell to delegate that item has been unselected
  func didUnselect(item: ContactItem)
  
  /// Tell to delegate user has closed without select
  func didCloseSwiftMultiSelect()
  
  /// Tell to delegate user has closed without select
  func userDidSearch(searchString:String)
  
}

/// Make the delegate functios optionals
extension ContactsPickerDelegate {
  func didSelect(items: [ContactItem]) {}
  func didSelect(item: ContactItem) {}
  func didUnselect(item: ContactItem) {}
  func didCloseSwiftMultiSelect() {}
  func userDidSearch(searchString:String) {}
}


// MARK: - UIImageView
extension UIImageView {
  /// Set an image in UIImageView from remote URL
  ///
  /// - Parameter url: url of the image
  func setImageFromURL(stringImageUrl url: String){
    
    //Placeholder image
    image = ContactsPickerConfig.placeholder_image
    
    //Download async image
    DispatchQueue.global(qos: .background).async {
      if let url = URL(string: url) {
        do{
          
          let data = try Data.init(contentsOf: url)
          
          //Set image in the main thread
          DispatchQueue.main.async {
            self.image = UIImage(data: data)
          }
          
        } catch{
          
        }
      }
    }
  }
}

