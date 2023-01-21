
import Foundation
import Contacts
import ContactsUI

public class ContactsHelper {
  
  //Contacts store
  public static var contactStore  = CNContactStore()
  
  /// Function to request access for PhoneBook
  ///
  /// - Parameter completionHandler: <#completionHandler description#>
  class func requestForAccess(_ completionHandler: @escaping (_ accessGranted: Bool) -> Void) {
    
    let authorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)
    
    switch authorizationStatus {
    case .authorized:
      completionHandler(true)
      
    case .denied, .notDetermined:
      self.contactStore.requestAccess(for: CNEntityType.contacts, completionHandler: { (access, accessError) -> Void in
        if access {
          completionHandler(access)
        }
        else {
          if authorizationStatus == CNAuthorizationStatus.denied {
            DispatchQueue.main.async(execute: { () -> Void in
              loge("\(accessError!.localizedDescription)\n\nPlease allow the app to access your contacts through the Settings.")
            })
          }
        }
      })
      
    default:
      completionHandler(false)
    }
  }
  
  /// Function to get contacts from device
  ///
  /// - Parameters:
  ///   - keys: array of keys to get
  ///   - completionHandler: callback function, contains contacts array as parameter
  class func getContacts(_ keys: [CNKeyDescriptor] = [CNContactGivenNameKey as CNKeyDescriptor,
                                                      CNContactFamilyNameKey as CNKeyDescriptor,
                                                      CNContactEmailAddressesKey as CNKeyDescriptor,
                                                      CNContactOrganizationNameKey as CNKeyDescriptor,
                                                      CNContactPhoneNumbersKey as CNKeyDescriptor,
                                                      CNContactViewController.descriptorForRequiredKeys()],
                         completionHandler: @escaping (_ success:Bool, _ contacts: [ContactItem]?) -> Void) {
    
    self.requestForAccess { (accessGranted) -> Void in
      if accessGranted {
        
        var contactsArray = [ContactItem]()
        
        let contactFetchRequest = CNContactFetchRequest(keysToFetch: self.allowedContactKeys())
        
        do {
          var row = 0
          try self.contactStore.enumerateContacts(with: contactFetchRequest, usingBlock: { (contact, stop) -> Void in
            
            var username    = "\(contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)) \(contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines))".trimmingCharacters(in: .whitespacesAndNewlines)
            var companyName = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if username.trimmingCharacters(in: .whitespacesAndNewlines) == "" && companyName != ""{
              username        = companyName
              companyName     = ""
            }

            if !username.isEmpty {
              let item_contact = ContactItem(row: row, title: username, description: companyName, image: nil, imageURL: nil, color: nil, userInfo: contact)
              contactsArray.append(item_contact)
              
              row += 1
            }
          })
          completionHandler(true, contactsArray)
        }
          
          //Catching exception as enumerateContactsWithFetchRequest can throw errors
        catch let error as NSError {
          loge(error.localizedDescription)
        }
      }else{
        completionHandler(false, nil)
      }
    }
  }
  
  /// Get allowed keys
  ///
  /// - Returns: array
  class func allowedContactKeys() -> [CNKeyDescriptor]{
    
    return [
      CNContactNamePrefixKey as CNKeyDescriptor,
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactMiddleNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactNameSuffixKey as CNKeyDescriptor,
      //CNContactNicknameKey,
      //CNContactPhoneticGivenNameKey,
      //CNContactPhoneticMiddleNameKey,
      //CNContactPhoneticFamilyNameKey,
      CNContactOrganizationNameKey as CNKeyDescriptor,
      //CNContactDepartmentNameKey,
      //CNContactJobTitleKey,
      //CNContactBirthdayKey,
      //CNContactNonGregorianBirthdayKey,
      //CNContactNoteKey,
      CNContactImageDataKey as CNKeyDescriptor,
      CNContactThumbnailImageDataKey as CNKeyDescriptor,
      CNContactImageDataAvailableKey as CNKeyDescriptor,
      //CNContactTypeKey,
      CNContactPhoneNumbersKey as CNKeyDescriptor,
      CNContactEmailAddressesKey as CNKeyDescriptor,
      //CNContactPostalAddressesKey,
      CNContactDatesKey as CNKeyDescriptor,
      //CNContactUrlAddressesKey,
      //CNContactRelationsKey,
      //CNContactSocialProfilesKey,
      //CNContactInstantMessageAddressesKey
    ]
    
  }
  
}
