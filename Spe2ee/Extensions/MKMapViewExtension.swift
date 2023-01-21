
import Foundation
import MapKit

extension MKMapView {
  
  /// Remove the Apple Logo and Label at the bottom of the map
  func removeAppleLogo() {
    // Hive Apple Logo and label from the map
    layoutMargins.bottom = -50
    // Re-Center the map
    layoutMargins.top = -50
  }
}
