import UIKit

class CountryCodeManager: NSObject {
  var countryCodesList = [CountryCode]()

  
  static func GetCountryCodes() -> [CountryCode]? {
    guard let filepath = Bundle.main.path(forResource: "CountryCodes", ofType: "json") else { return nil }
    do {
      let jsonData = try Data(contentsOf: URL(fileURLWithPath: filepath), options: .mappedIfSafe)
      let decoder = JSONDecoder()
      return try decoder.decode([CountryCode].self, from: jsonData)
    } catch {
      loge(error)
      return nil
    }
  }
}


