
import Foundation
import UIKit

extension UIFont {
  private enum Name: String {
    case helveticaNeueRegular = "HelveticaNeue"
    case proximaNovaLight = "HelveticaNeue-Light"
    case helveticaNeueMedium = "HelveticaNeue-Medium"
    case helveticaNeueBold = "HelveticaNeue-Bold"
    case helveticaNeueItalic = "HelveticaNeue-Italic"
    case helveticaNeueBoldItalic = "HelveticaNeue-BoldItalic"
    case helveticaNeueMediumItalic = "HelveticaNeue-MediumItalic"
  }
  
  /// Get a Regular font
  /// - Parameters:
  ///   - size: Font size
  ///   - textStyle: Text style
  /// - Returns: Return Regular font if UIAccessibility.isBoldTextEnabled is false or SemiBold if true.
  public static func appFont(ofSize size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
    return UIAccessibility.isBoldTextEnabled ?
      UIFontMetrics(forTextStyle: textStyle).scaledFont(for: UIFont(name: Name.helveticaNeueMedium.rawValue, size: size) ?? UIFont.systemFont(ofSize: size)) :
      UIFontMetrics(forTextStyle: textStyle).scaledFont(for: UIFont(name: Name.helveticaNeueRegular.rawValue, size: size) ?? UIFont.systemFont(ofSize: size))
  }
  
  /// Doens't resize with system font
  /// - Parameter size: Font size
  /// - Returns: Font
  public static func appFontNoDynamic(ofSize size: CGFloat) -> UIFont {
    return UIAccessibility.isBoldTextEnabled ?
      UIFont(name: Name.helveticaNeueMedium.rawValue, size: size) ?? UIFont.systemFont(ofSize: size) :
      UIFont(name: Name.helveticaNeueRegular.rawValue, size: size) ?? UIFont.systemFont(ofSize: size)
  }
  
  /// Get a Light  font type
  /// - Parameters:
  ///   - size: Font size
  ///   - textStyle: Text style
  /// - Returns: Return Light font if UIAccessibility.isBoldTextEnabled is false or Regular if true.
  public static func appFontLight(ofSize size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
    return UIAccessibility.isBoldTextEnabled ?
      appFont(ofSize: size, textStyle: textStyle) :
      UIFontMetrics(forTextStyle: textStyle).scaledFont(for: UIFont(name: Name.proximaNovaLight.rawValue, size: size) ?? UIFont.systemFont(ofSize: size))
  }
  
  
  /// Get a SemiBold font
  /// - Parameters:
  ///   - size: Font size
  ///   - textStyle: Text style
  /// - Returns: Return SemiBold if UIAccessibility.isBoldTextEnabled is false or Bold if true.
  public static func appFontSemiBold(ofSize size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
    return UIAccessibility.isBoldTextEnabled ?
      appFontBold(ofSize: size, textStyle: textStyle) :
      UIFontMetrics(forTextStyle: textStyle).scaledFont(for: UIFont(name: Name.helveticaNeueMedium.rawValue, size: size) ?? UIFont.systemFont(ofSize: size))
  }
  
  
  /// Doens't resize with system font
  /// - Parameter size: Font size
  /// - Returns: Font
  public static func appFontSemiBoldNoDynamic(ofSize size: CGFloat) -> UIFont {
    return UIAccessibility.isBoldTextEnabled ?
      UIFont(name: Name.helveticaNeueBold.rawValue, size: size) ?? UIFont.systemFont(ofSize: size) :
      UIFont(name: Name.helveticaNeueMedium.rawValue, size: size) ?? UIFont.systemFont(ofSize: size)
  }
  
  
  /// Get a SemiBold Italic font
  /// - Parameters:
  ///   - size: Font size
  ///   - textStyle: Text style
  /// - Returns: Return SemiBold if UIAccessibility.isBoldTextEnabled is false or Bold if true.
  public static func appFontSemiBoldItalic(ofSize size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
    return UIAccessibility.isBoldTextEnabled ?
    appFontBoldItalic(ofSize: size, textStyle: textStyle) :
    UIFontMetrics(forTextStyle: textStyle).scaledFont(for: UIFont(name: Name.helveticaNeueMediumItalic.rawValue, size: size) ?? UIFont.systemFont(ofSize: size))
  }
  
  /// Get a Bold font
  /// - Parameters:
  ///   - size: Font size
  ///   - textStyle: Text style
  /// - Returns: Return Bold Font.
  public static func appFontBold(ofSize size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
    return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: UIFont(name: Name.helveticaNeueBold.rawValue, size: size) ?? UIFont.systemFont(ofSize: size))
  }
  
  /// Doens't resize with system font
  /// - Parameter size: Font size
  /// - Returns: Font
  public static func appFontBoldNoDynamic(ofSize size: CGFloat) -> UIFont {
    return UIFont(name: Name.helveticaNeueBold.rawValue, size: size) ?? UIFont.systemFont(ofSize: size)
    
    return UIAccessibility.isBoldTextEnabled ?
      UIFont(name: Name.helveticaNeueMediumItalic.rawValue, size: size) ?? UIFont.systemFont(ofSize: size) :
      UIFont(name: Name.helveticaNeueItalic.rawValue, size: size) ?? UIFont.systemFont(ofSize: size)
    
  }
  
  /// Get a Bold Italic font
  /// - Parameters:
  ///   - size: Font size
  ///   - textStyle: Text style
  /// - Returns: Return Bold Font.
  public static func appFontBoldItalic(ofSize size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
    return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: UIFont(name: Name.helveticaNeueBoldItalic.rawValue, size: size) ?? UIFont.systemFont(ofSize: size))
  }
  
  /// Get a Italic font
  /// - Parameters:
  ///   - size: Font size
  ///   - textStyle: Text style
  /// - Returns: Return Italic font if UIAccessibility.isBoldTextEnabled is false or SemiBold Italic if true.
  public static func appFontItalic(ofSize size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
    return UIAccessibility.isBoldTextEnabled ?
      appFontSemiBoldItalic(ofSize: size, textStyle: textStyle) :
      UIFontMetrics(forTextStyle: textStyle).scaledFont(for: UIFont(name: Name.helveticaNeueItalic.rawValue, size: size) ?? UIFont.systemFont(ofSize: size))
  }
  
  /// Doens't resize with system font
  /// - Parameter size: Font size
  /// - Returns: Font
  public static func appFontItalicNoDynamic(ofSize size: CGFloat) -> UIFont {
    return UIAccessibility.isBoldTextEnabled ?
      UIFont(name: Name.helveticaNeueMediumItalic.rawValue, size: size) ?? UIFont.systemFont(ofSize: size) :
      UIFont(name: Name.helveticaNeueItalic.rawValue, size: size) ?? UIFont.systemFont(ofSize: size)
  }
  
  var isBold: Bool {
    return fontDescriptor.symbolicTraits.contains(.traitBold)
  }
  
  var isItalic: Bool {
    return fontDescriptor.symbolicTraits.contains(.traitItalic)
  }
  
  var isSemiBold: Bool {
    return fontDescriptor.postscriptName == Name.helveticaNeueMedium.rawValue
  }
  
}
