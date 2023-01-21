
import Foundation
import UIKit
import MapKit

protocol LocationPickerDelegate: class {
  func didSelectLocation(coordinate: CLLocationCoordinate2D)
}

class LocationPicker {
  weak var delegate: LocationPickerDelegate?
  
  init(delegate: LocationPickerDelegate) {
    self.delegate = delegate
  }
  
  /// Function to present a selector in a UIViewContoller claass
  ///
  /// - Parameter to: UIViewController current visibile
  public func Show(to: UIViewController) {
    let locationVC = SendLocationViewController(locationPicker: self)
    
    //Create navigation controller
    let navController = UINavigationController(rootViewController: locationVC)
    navController.modalPresentationStyle = .fullScreen
    
    // Present selectora
    to.present(navController, animated: true, completion: nil)
  }
}
