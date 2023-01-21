import Foundation
import Combine


final class PhoneJson {
  var id = UUID().uuidString
  var tag = "mobile".localized()
  var prefix = "+966"
  var number = ""
}

final class EmailJson {
  var id = UUID().uuidString
  var tag = "email"
  var email = ""
}

final class AddressJson {
  var id = UUID().uuidString
  var street = ""
  var city = ""
  var zip = ""
  var province = ""
  var state = ""
  var country = ""
  var pobox = ""
}

final class UrlJson {
  var id = UUID().uuidString
  var tag = "url"
  var url = ""
}

final class DateJson {
  var id = UUID().uuidString
  var tag = "anniversary".localized()
  var date = ""
}

final class SocialProfileJson {
  var id = UUID().uuidString
  var tag = "Profile"
  var url = ""
}

final class InstantMessageJson {
  var id = UUID().uuidString
  var tag = "IM"
  var url = ""
}

enum FormCellType {
  case names
  case jobTitle
  case department
  case company
  case phoneticCompanyName
  case phone(PhoneJson)
  case email(EmailJson)
  case address(AddressJson)
  case url(UrlJson)
  case birthday
  case date(DateJson)
  case socialProfile(SocialProfileJson)
  case instantMessage(InstantMessageJson)
}

class AddNewContactViewModel: NSObject {
  var contact = BBContact()
  
  var id = ""
  
  var phonesjson: [PhoneJson] = [PhoneJson]()
  
  var emailsjson: [EmailJson] = [EmailJson]()
  var addressesjson: [AddressJson] = [AddressJson]()
  var datesjson: [DateJson] = [DateJson]()
  var socialprofiles: [SocialProfileJson] = [SocialProfileJson]()
  var instantmessages: [InstantMessageJson] = [InstantMessageJson]()
  var urlsjson: [UrlJson] = [UrlJson]()
  
  var isPrefixVisible: Bool = false
  var isMiddlenameVisible: Bool = false
  var isSuffixVisible: Bool = false
  var isNicknameVisible: Bool = false
  var isMaidennameVisible: Bool = false
  var isPhoneticNameVisible: Bool = false
  var isPhoneticMiddlenameVisible: Bool = false
  var isPhoneticSurnameVisible: Bool = false
  var isEmailVisible: Bool = false
  var isAddressesVisible: Bool = false
  var isPhoneticCompanyNameVisible: Bool = false
  var isJobtitleVisible: Bool = false
  var isDepartmentVisible: Bool = false
  var isBirthdayVisible: Bool = false
  
  var formItems: [FormCellType] = []
  
  var updateContact: Bool = false {
    didSet {
      if updateContact {
        isSaveEnabled = true
      }
    }
  }
  
  @Published var isSaveEnabled: Bool = false
  
  override init() {
    super.init()
    
    
  }
  
  init(contact: BBContact) {
    super.init()
    self.contact = contact
    
    id = contact.ID
    
    // Names fields
    addItem(type: .names)
    if !contact.prefix.isEmpty {
      isPrefixVisible = true
    }
    if !contact.phoneticname.isEmpty {
      isPhoneticNameVisible = true
    }
    if !contact.middlename.isEmpty {
      isMiddlenameVisible = true
    }
    if !contact.phoneticmiddlename.isEmpty {
      isPhoneticMiddlenameVisible = true
    }
    if !contact.phoneticsurname.isEmpty {
      isPhoneticSurnameVisible = true
    }
    if !contact.maidenname.isEmpty {
      isMaidennameVisible = true
    }
    if !contact.suffix.isEmpty {
      isSuffixVisible = true
    }
    if !contact.nickname.isEmpty {
      isNicknameVisible = true
    }
    
    // Phones
    if contact.phonesjson.count > 0 {
      contact.phonesjson.forEach {
        let jsonObject = PhoneJson()
        jsonObject.id = $0.ID
        jsonObject.tag = $0.tag
        jsonObject.number = $0.phone.replacingFirstOccurrenceOfString(target: $0.prefix, withString: "")
        jsonObject.prefix = "+\($0.prefix)"
        isSaveEnabled = true
        addItem(type: .phone(jsonObject))
      }
    } else {
      addItem(type: .phone(PhoneJson()))
    }
    
    // Job title
    if !contact.jobtitle.isEmpty {
      addItem(type: .jobTitle)
    }
    
    // Department
    if !contact.department.isEmpty {
      addItem(type: .department)
    }
    
    // Company name
    if !contact.companyname.isEmpty {
      addItem(type: .company)
    }
    
    // Phonetic Company name
    if !contact.phoneticcompanyname.isEmpty {
      addItem(type: .phoneticCompanyName)
    }
    
    // Email
    if contact.emailsjson.count > 0 {
      contact.emailsjson.forEach {
        let jsonObject = EmailJson()
        jsonObject.id = $0.ID
        jsonObject.tag = $0.tag
        jsonObject.email = $0.email
        addItem(type: .email(jsonObject))
      }
    }
    
    // Addresses
    if contact.addressesjson.count > 0 {
      contact.addressesjson.forEach {
        let jsonObject = AddressJson()
        jsonObject.id = $0.ID
        jsonObject.street = $0.street
        jsonObject.country = $0.country
        jsonObject.city = $0.city
        jsonObject.pobox = $0.pobox
        jsonObject.province = $0.province
        jsonObject.state = $0.state
        addItem(type: .address(jsonObject))
      }
    }
    
    // Urls
    if contact.urlsjson.count > 0 {
      contact.urlsjson.forEach {
        let jsonObject = UrlJson()
        jsonObject.id = $0.ID
        jsonObject.tag = $0.tag
        jsonObject.url = $0.url
        addItem(type: .url(jsonObject))
      }
    }
    
    // Birthday
    if !contact.birthday.isEmpty {
      addItem(type: .birthday)
    }
    
    // Dates
    if contact.datesjson.count > 0 {
      contact.datesjson.forEach {
        let dateJson = DateJson()
        dateJson.id = $0.ID
        dateJson.tag = $0.tag
        dateJson.date = $0.date
        addItem(type: .date(dateJson))
      }
    }
    
    // Social Profiles
    if contact.socialprofilesjson.count > 0 {
      contact.socialprofilesjson.forEach {
        let jsonObject = SocialProfileJson()
        jsonObject.id = $0.ID
        jsonObject.tag = $0.tag
        jsonObject.url = $0.url
        addItem(type: .socialProfile(jsonObject))
      }
    }
    
    // Social Profiles
    if contact.instantmessagesjson.count > 0 {
      contact.instantmessagesjson.forEach {
        let jsonObject = InstantMessageJson()
        jsonObject.id = $0.ID
        jsonObject.tag = $0.tag
        jsonObject.url = $0.url
        addItem(type: .instantMessage(jsonObject))
      }
    }
    
  }
  
  func addItem(type: FormCellType) {
    switch type {
    case .names:
      formItems.insert(type, at: 0)
    case .phone(let phoneJson):
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .phone(_):
          lastIndex = index
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex+1)
      phonesjson.append(phoneJson)
    case .jobTitle:
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .phone(_):
          lastIndex = index + 1
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex)
    case .company:
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .phone(_), .jobTitle:
          lastIndex = index + 1
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex)
    case .department:
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .phone( _), .jobTitle, .company:
          lastIndex = index + 1
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex)
    case .phoneticCompanyName:
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .phone( _), .jobTitle, .company, .department:
          lastIndex = index + 1
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex)
    case .email(let emailJson):
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .company, .jobTitle, .department, .phoneticCompanyName, .email :
          lastIndex = index + 1
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex)
      emailsjson.append(emailJson)
    case.address(let address):
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .phone( _), .jobTitle, .department, .company, .phoneticCompanyName, .email, .address( _):
          lastIndex = index + 1
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex)
      addressesjson.append(address)
    case .url(let urljson):
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .phone( _), .jobTitle, .department, .company, .phoneticCompanyName, .email, .address( _), .url( _):
          lastIndex = index + 1
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex)
      urlsjson.append(urljson)
    case .birthday:
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .phone( _), .jobTitle, .department, .company, .phoneticCompanyName, .email, .address( _), .url( _):
          lastIndex = index + 1
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex)
    case .date(let date):
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .phone( _), .jobTitle, .department, .company, .phoneticCompanyName, .email, .address( _), .url( _), .birthday:
          lastIndex = index + 1
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex)
      datesjson.append(date)
    case .socialProfile(let profile):
      var lastIndex = 0
      for (index, element) in formItems.enumerated() {
        switch element {
        case .phone( _), .jobTitle, .department, .company, .phoneticCompanyName, .email, .address( _), .url( _), .birthday, .socialProfile( _):
        lastIndex = index + 1
        default:
          break
        }
      }
      formItems.insert(type, at: lastIndex)
      socialprofiles.append(profile)
    case .instantMessage(let IM):
      formItems.append(type)
      instantmessages.append(IM)
    }
  }
  
  func getContact() -> BBContact {
    self.contact.phonesjson = phonesjson.map { phone -> PhoneNumber in
      var prefix = phone.prefix
      if String(prefix.prefix(1)) == "+" {
        prefix = String(prefix.suffix(from: phone.number.index(phone.number.startIndex, offsetBy: 1)))
      }
      return PhoneNumber(tag: phone.tag, phone: "\(prefix)\(phone.number)", prefix: prefix)
    }
    
    self.contact.emailsjson = emailsjson.map { (email) -> Email in
      Email(tag: email.tag, email: email.email)
    }.filter { (item) -> Bool in
      item.email.count > 0
    }
    
    self.contact.addressesjson = addressesjson.map { (address) -> Address in
      Address(street: address.street, city: address.city, zip: address.zip, province: address.province, state: address.state, country: address.country, pobox: address.pobox)
    }.filter { (item) -> Bool in
      !item.street.isEmpty || !item.city.isEmpty || !item.zip.isEmpty || !item.province.isEmpty || !item.state.isEmpty || !item.country.isEmpty || !item.pobox.isEmpty
    }
    
    self.contact.urlsjson = urlsjson.map { (url) -> ContactUrl in
      ContactUrl(tag: url.tag, url: url.url)
    }.filter { (item) -> Bool in
      item.url.count > 0
    }
    
    self.contact.datesjson = datesjson.map { (date) -> ContactDate in
      ContactDate(tag: date.tag, date: date.date)
    }.filter { (item) -> Bool in
      item.date.count > 0
    }
    
    self.contact.socialprofilesjson = socialprofiles.map { (item) -> SocialProfile in
      SocialProfile(tag: item.tag, url: item.url)
    }.filter { (item) -> Bool in
      item.url.count > 0
    }
    
    self.contact.instantmessagesjson = instantmessages.map { (item) -> InstantMessage in
      InstantMessage(tag: item.tag, url: item.url)
    }.filter { (item) -> Bool in
      item.url.count > 0
    }
    
    return contact
  }
  
}
