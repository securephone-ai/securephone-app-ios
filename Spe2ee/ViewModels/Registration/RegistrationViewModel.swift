
import Foundation
import Combine

class RegistrationViewModel {
  
  let countryName = CurrentValueSubject<String?, Never>(nil)
  let countryCode = CurrentValueSubject<String?, Never>(nil)
  var phoneNumber: String = ""
  var oneTimePassword: String = ""
  
  init() {
    countryCode.value = "+966"
    countryName.value = "Saudi Arabia"
  }
  
  func lookupCountryCode(_ code: String) {
    var countryCodeList = CountryCodeManager.GetCountryCodes()!
    
    if code == "+" {
      countryCode.value = ""
      countryName.value = "Invalid country code"
    } else {
      let sanitizedCode = "+\(code.replacingOccurrences(of: "+", with: ""))"
      countryCode.value = sanitizedCode
      if countryCodeList.count == 0 {
        countryCodeList = CountryCodeManager.GetCountryCodes()!
      }
      
      if sanitizedCode == "+1" {
        countryName.value = "United States"
      } else {
        let countries = countryCodeList.filter {
          return $0.code == sanitizedCode
        }
        if countries.count > 0 {
          countryName.value = countries[0].name
        } else {
          countryName.value = "Invalid country code"
        }
      }
    }
  }
  
}
