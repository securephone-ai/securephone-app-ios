import Combine
import ChromaColorPicker




/// Custom UITextView class. Handle Custom test formatting based on specific Tags.
class MessageInputTextView: UITextView, UITextViewDelegate {
  
  private var selectedColorRange = NSRange()
  let textDidChannge = PassthroughSubject<String, Never>()

  // MARK: - Color Picker UI
  private lazy var colorPickerParentView: UIView = {
    let view = UIView()
    view.backgroundColor = .clear
    let dismissOnTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissColorPickerParentView))
    dismissOnTapGesture.delegate = self
    view.addGestureRecognizer(dismissOnTapGesture)
    return view
  }()
  private lazy var colorPicker: ChromaColorPicker = {
    let colorPicker = ChromaColorPicker(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
    colorPicker.delegate = self
    colorPicker.addHandle(at: UIColor(red: 1, green: 203 / 255, blue: 164 / 255, alpha: 1))
    return colorPicker
  }()
  private lazy var brightnessSlider: ChromaBrightnessSlider = {
    let brightnessSlider = ChromaBrightnessSlider()
    brightnessSlider.connect(to: colorPicker)
    brightnessSlider.trackColor = UIColor.blue
    return brightnessSlider
  }()

  init() {
    super.init(frame: .zero, textContainer: nil)
    self.delegate = self
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action.description == "_lookup:" {
      return false
    }
    if action.description == "_promptForReplace:" {
      return false
    }
    if action.description == "_share:" {
      return false
    }
    if action.description == "makeTextWritingDirectionRightToLeft:" {
      return false
    }
    
    let menuController = UIMenuController.shared
    if var menuItems = menuController.menuItems, (menuItems.map { $0.action }).elementsEqual([.toggleBoldface, .toggleItalics, .toggleUnderline]) {
      // The font style menu is about to become visible
      // Add a new menu item for strikethrough style
      
//      menuItems.removeAll { $0.action == .toggleUnderline }
      for menu in menuItems {
        if menu.action == .toggleBoldface {
          menu.action = #selector(toggleBold)
        } else if menu.action == .toggleItalics {
          menu.action = #selector(toggleItalic)
        } else if menu.action == .toggleUnderline {
          menu.action = #selector(toggleUnderlinePressed)
        }
      }
      
      menuItems.append(UIMenuItem(title: "Strikethrough", action: .toggleStrikethrough))
      menuItems.append(UIMenuItem(title: "Color", action: .toggleColor))
      menuController.menuItems = menuItems
    }
    
    if action == #selector(MessageInputTextView.replace(_:withText:)) {
      return false
    }
    
    return super.canPerformAction(action, withSender: sender)
  }
  
  @objc func toggleStrikethrough(_ sender: Any?) {
    let attributedString = NSMutableAttributedString(attributedString: attributedText)
    
    let strokeEffect: [NSAttributedString.Key : Any] = [
      .strikethroughStyle: NSUnderlineStyle.single.rawValue,
      .strikethroughColor: UIColor.black,
    ]
    attributedString.addAttributes(strokeEffect, range: selectedRange)
    
    // Add symbols to format
    let attributes = [NSAttributedString.Key.foregroundColor: UIColor.systemGray, NSAttributedString.Key.font: UIFont.appFont(ofSize: 18)]
    let boldSymbol = NSAttributedString(string: "~", attributes: attributes)
    attributedString.insert(boldSymbol, at: self.selectedRange.location)
    attributedString.insert(boldSymbol, at: self.selectedRange.location+self.selectedRange.length+1)
        attributedString.insert(NSAttributedString(string: " ", attributes: [NSAttributedString.Key.foregroundColor: UIColor.black]), at: self.selectedRange.location+self.selectedRange.length+2)
    
    self.attributedText = attributedString
    self.select(self)
    self.selectedRange = NSRange(location: self.selectedRange.location-1, length: self.selectedRange.length)
  }
  
  @objc func toggleColor(_ sender: Any?) {
    showColorPicker()
  }
  
  @objc func toggleBold(_ sender: Any?) {
    let attributedString = NSMutableAttributedString(attributedString: self.attributedText)
    
    // Change text to bold
    let newFont = UIFont.appFontBold(ofSize: 18)
    attributedString.addAttributes([.font: newFont], range: self.selectedRange)
    
    // Add symbols to format
    let attributes = [NSAttributedString.Key.foregroundColor: UIColor.systemGray, NSAttributedString.Key.font: UIFont.appFont(ofSize: 18)]
    let boldSymbol = NSAttributedString(string: "*", attributes: attributes)
    attributedString.insert(boldSymbol, at: self.selectedRange.location)
    attributedString.insert(boldSymbol, at: self.selectedRange.location+self.selectedRange.length+1)
    attributedString.insert(NSAttributedString(string: " ",
                                               attributes: [NSAttributedString.Key.foregroundColor: UIColor.black]),
                            at: self.selectedRange.location+self.selectedRange.length+2)
    
    self.attributedText = attributedString
    self.select(self)
    self.selectedRange = NSRange(location: self.selectedRange.location-1, length: self.selectedRange.length)
  }
  
  @objc func toggleItalic(_ sender: Any?) {
    let attributedString = NSMutableAttributedString(attributedString: self.attributedText)
    
    // Change text to bold
    let newFont = UIFont.appFontItalic(ofSize: 18)
    attributedString.addAttributes([.font: newFont], range: self.selectedRange)
    
    // Add symbols to format
    let attributes = [NSAttributedString.Key.foregroundColor: UIColor.systemGray, NSAttributedString.Key.font: UIFont.appFont(ofSize: 18)]
    let boldSymbol = NSAttributedString(string: "_", attributes: attributes)
    attributedString.insert(boldSymbol, at: self.selectedRange.location)
    attributedString.insert(boldSymbol, at: self.selectedRange.location+self.selectedRange.length+1)
        attributedString.insert(NSAttributedString(string: " ", attributes: [NSAttributedString.Key.foregroundColor: UIColor.black]), at: self.selectedRange.location+self.selectedRange.length+2)
    
    self.attributedText = attributedString
    self.select(self)
    self.selectedRange = NSRange(location: self.selectedRange.location-1, length: self.selectedRange.length)
  }
  
  @objc func toggleUnderlinePressed(_ sender: Any?) {
    let attributedString = NSMutableAttributedString(attributedString: self.attributedText)
    
    // Change text to bold
    attributedString.addAttributes([.underlineStyle: 1], range: self.selectedRange)
    
    // Add symbols to format
    let attributes = [NSAttributedString.Key.foregroundColor: UIColor.systemGray, NSAttributedString.Key.font: UIFont.appFont(ofSize: 18)]
    let boldSymbol = NSAttributedString(string: "•", attributes: attributes)
    attributedString.insert(boldSymbol, at: self.selectedRange.location)
    attributedString.insert(boldSymbol, at: self.selectedRange.location+self.selectedRange.length+1)
        attributedString.insert(NSAttributedString(string: " ", attributes: [NSAttributedString.Key.foregroundColor: UIColor.black]), at: self.selectedRange.location+self.selectedRange.length+2)
    
    self.attributedText = attributedString
    self.select(self)
    self.selectedRange = NSRange(location: self.selectedRange.location-1, length: self.selectedRange.length)
  }
  
  func textViewDidChange(_ textView: UITextView) {
    if textView.text.isEmpty {
      textColor = .black
    }
    textDidChannge.send(textView.text)
    self.attributedText = self.attributedText.attributedStringForTextView()
//    self.attributedText = self.text.getAttributedText(fontSize: 18, replaceTagSymbols: false)
  }
  
  private func showColorPicker() {
    AppUtility.lockOrientation(.portrait)
    selectedColorRange = self.selectedRange
    resignFirstResponder()
    colorPickerParentView.removeSubviews()
    colorPickerParentView.addSubview(colorPicker)
    colorPickerParentView.addSubview(brightnessSlider)
    AppUtility.getLastVisibleWindow().addSubview(colorPickerParentView)
    colorPickerParentView.pin.all()
    colorPicker.pin.vCenter(-90).hCenter()
    brightnessSlider.pin.below(of: colorPicker, aligned: .center).marginTop(15).width(of: colorPicker).height(colorPicker.width * 0.1)
  }
  
  @objc private func dismissColorPickerParentView() {
    colorPickerParentView.removeFromSuperview()
    colorPickerParentView.removeSubviews()
    
    AppUtility.lockOrientation(.allButUpsideDown)

    let afterText = self.text.slicing(from: selectedColorRange.location+selectedColorRange.length, length: 1)
    if afterText == " " {
      let attributedString = NSMutableAttributedString(attributedString: attributedText)
      attributedString.addAttributes([.foregroundColor: UIColor.black,
                                      .font : UIFont.appFont(ofSize: 18, textStyle: .body)],
                                     range: NSRange(location: selectedColorRange.location+selectedColorRange.length, length: 1))
      self.attributedText = attributedString
    } else {
      let attributedString = NSMutableAttributedString(attributedString: attributedText)
      let attributedSpace = NSAttributedString(string: " ", attributes: [.foregroundColor : UIColor.black,
                                                                         .font : UIFont.appFont(ofSize: 18, textStyle: .body)])
      attributedString.append(attributedSpace)
      self.attributedText = attributedString
    }
    
    self.select(self)
    self.selectedRange = selectedColorRange
    
  }
  
  
  /// Return the attributed text and includes the colors Tags if presents
  func getTextToSendInChat() -> String {
    return self.attributedText.stringForChat()
  }
  
}

extension MessageInputTextView: ChromaColorPickerDelegate {
  func colorPickerHandleDidChange(_ colorPicker: ChromaColorPicker, handle: ChromaColorHandle, to color: UIColor) {
    let attributedString = NSMutableAttributedString(attributedString: attributedText)
    attributedString.removeAttribute(.foregroundColor, range: selectedColorRange)
    attributedString.addAttribute(.foregroundColor, value: color , range: selectedColorRange)
    self.attributedText = attributedString
  }
}

extension MessageInputTextView: UIGestureRecognizerDelegate {
  
}

fileprivate extension Selector {
  static let toggleBoldface = #selector(MessageInputTextView.toggleBoldface(_:))
  static let toggleItalics = #selector(MessageInputTextView.toggleItalics(_:))
  static let toggleUnderline = #selector(MessageInputTextView.toggleUnderline(_:))
  static let toggleStrikethrough = #selector(MessageInputTextView.toggleStrikethrough(_:))
  static let toggleColor = #selector(MessageInputTextView.toggleColor(_:))
}


fileprivate extension NSAttributedString {
  
  /// Replace Colors with tags
  /// - Returns: the string
  func stringForChat() -> String {
    var sourceString = self.string
    // we'll use this tupple to store our ranges and colors to insert them later from the end of the string (this way we don't mess our string indexes)
    var replacements: [(range: NSRange, hex: String)] = []

    self.enumerateAttribute(.foregroundColor, in:  NSRange(location: 0, length: self.length)) { (value, range, _) in
      if let color = value as? UIColor, (color.hexString != "#000000" && color.hexString != UIColor.systemGray.hexString) {
        logi(value)
        logi(range)
        replacements.insert((range, color.hexString), at: 0)
      }
    }
     
    for replacement in replacements {
      if let range = Range(replacement.range, in: sourceString) {
        sourceString.insert(contentsOf: "</color>", at: range.upperBound)
        sourceString.insert(contentsOf: "<color hex=\"\(replacement.hex)\">", at: range.lowerBound)
      }
    }
    
    return sourceString
  }
  
  func attributedStringForTextView(fontSize: CGFloat = 18.0) -> NSAttributedString {
    var attributedString = NSMutableAttributedString(attributedString: self)
    // *** Create instance of `NSMutableParagraphStyle`
    let paragraphStyle = NSMutableParagraphStyle()
    
    // *** set LineSpacing property in points ***
    paragraphStyle.lineSpacing = 2 // Whatever line spacing you want in points
    //    paragraphStyle.baseWritingDirection = AppUtility.isArabic ? .rightToLeft : .leftToRight
    
    // *** Apply attribute to string ***
    attributedString.addAttributes([
      .paragraphStyle: paragraphStyle,
      .font: UIFont.appFont(ofSize: fontSize, textStyle: .body)
    ], range: NSRange(location: 0, length: attributedString.length))
    
    
    attributedString = replaceTagWithBold(attributedString: attributedString, fontSize: fontSize)
    attributedString = replaceTagWithItalic(attributedString: attributedString, fontSize: fontSize)
    attributedString = replaceTagWithUnderline(attributedString: attributedString, fontSize: fontSize)
    attributedString = replaceTagWithStrikethrough(attributedString: attributedString)
    attributedString = fixColors(attributedString: attributedString)
    
    return attributedString
  }
  
  private func replaceTagWithBold(attributedString: NSMutableAttributedString, fontSize: CGFloat = 18.0, replaceTagSymbols: Bool = true) -> NSMutableAttributedString {
    if attributedString.string.count(of: "*") < 2 {
      return attributedString
    }
    
    let boldCount = attributedString.string.count(of: "*") / 2

    for _ in 0..<boldCount {
      var startIndex = -1
      for (index, char) in attributedString.string.enumerated() {
        if char == "*" {
          if startIndex == -1 {
            startIndex = index
          } else {
            let subStrLenght = index-(startIndex+1)
            let substringRange = NSRange(location: startIndex+1, length: subStrLenght)
            
            
            // Add Bold to italic if present
            let attributes = attributedString.attributedSubstring(from: substringRange)
            
            attributes.enumerateAttribute(.font, in: NSRange(0..<attributes.length)) {
              value, range, _ in
              // Confirm the attribute value is actually a font
              // AND
              // Check if the font is bold or not
              if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                attributedString.addAttributes(
                  [.font: UIFont.appFontBoldItalic(ofSize: fontSize, textStyle: .body)],
                  range: NSRange(location: substringRange.location + range.location, length: range.length)
                )
              } else {
                attributedString.addAttributes(
                  [.font: UIFont.appFontBold(ofSize: fontSize, textStyle: .body)],
                  range: NSRange(location: substringRange.location + range.location, length: range.length)
                )
              }
            }
            
            // color the symbols
            attributedString.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: startIndex, length: 1))
            attributedString.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: index, length: 1))
            
            break
          }
        }
      }
    }
    

    return attributedString
  }
  
  private func replaceTagWithItalic(attributedString: NSMutableAttributedString, fontSize: CGFloat = 18.0, replaceTagSymbols: Bool = true) -> NSMutableAttributedString {
    if attributedString.string.count(of: "_") < 2 {
      return attributedString
    }
    
    let italicsCount = attributedString.string.count(of: "_") / 2
    
    for _ in 0..<italicsCount {
      var startIndex = -1
      for (index, char) in attributedString.string.enumerated() {
        if char == "_" {
          if startIndex == -1 {
            startIndex = index
          } else {
            let subStrLenght = index-(startIndex+1)
            let substringRange = NSRange(location: startIndex+1, length: subStrLenght)
            
            // Add Italic to Bold if present
            let attributes = attributedString.attributedSubstring(from: substringRange)
            attributes.enumerateAttribute(.font, in: NSRange(0..<attributes.length)) {
              value, range, stop in
              // Confirm the attribute value is actually a font
              // AND
              // Check if the font is bold or not
              if let font = value as? UIFont, font.isBold {
                attributedString.addAttributes(
                  [.font:  UIFont.appFontBoldItalic(ofSize: fontSize, textStyle: .body)],
                  range: NSRange(location: substringRange.location + range.location, length: range.length)
                )
              } else if let font = value as? UIFont, font.isSemiBold {
                attributedString.addAttributes(
                  [.font: UIFont.appFontSemiBoldItalic(ofSize: fontSize, textStyle: .body)],
                  range: NSRange(location: substringRange.location + range.location, length: range.length)
                )
              } else {
                attributedString.addAttributes(
                  [.font: UIFont.appFontItalic(ofSize: fontSize, textStyle: .body)],
                  range: NSRange(location: substringRange.location + range.location, length: range.length)
                )
              }
            }
            
            // color the symbols
            attributedString.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: startIndex, length: 1))
            attributedString.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: index, length: 1))
            
            break
          }
        }
      }
    }
    
    return attributedString
  }
  
  private func replaceTagWithUnderline(attributedString: NSMutableAttributedString, fontSize: CGFloat = 18.0, replaceTagSymbols: Bool = true) -> NSMutableAttributedString {
    if attributedString.string.count(of: "•") < 2 {
      return attributedString
    }
    
    let italicsCount = attributedString.string.count(of: "•") / 2
    
    for _ in 0..<italicsCount {
      var startIndex = -1
      for (index, char) in attributedString.string.enumerated() {
        if char == "•" {
          if startIndex == -1 {
            startIndex = index
          } else {
            let subStrLenght = index-(startIndex+1)
            let substringRange = NSRange(location: startIndex+1, length: subStrLenght)
            attributedString.addAttributes([.underlineStyle: 1], range: substringRange)
            
            // color the symbols
            attributedString.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: startIndex, length: 1))
            attributedString.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: index, length: 1))
            
            break
          }
        }
      }
    }
    
    return attributedString
  }
  
  private func replaceTagWithStrikethrough(attributedString: NSMutableAttributedString, replaceTagSymbols: Bool = true) -> NSMutableAttributedString {
    if attributedString.string.count(of: "~") < 2 {
      return attributedString
    }
    
    var startIndex = -1
    for (index, char) in attributedString.string.enumerated() {
      if char == "~" {
        if startIndex == -1 {
          startIndex = index
        } else {
          let subStrLenght = index-(startIndex+1)
          let range = NSRange(location: startIndex+1, length: subStrLenght)
          let strokeEffect: [NSAttributedString.Key : Any] = [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .strikethroughColor: UIColor.black,
          ]
          attributedString.addAttributes(strokeEffect, range: range)
          
          // color the symbols
          attributedString.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: startIndex, length: 1))
          attributedString.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: index, length: 1))
          
          startIndex = -1
        }
      }
    }
    return attributedString
  }
  
  private func fixColors(attributedString: NSMutableAttributedString) -> NSMutableAttributedString {
    attributedString.enumerateAttribute(.foregroundColor, in:  NSRange(location: 0, length: attributedString.length)) { (value, range, _) in
      if let color = value as? UIColor, color.hexString == UIColor.systemGray.hexString {
        if let a = attributedString.string.slicing(from: range.location, length: range.length) {
          if a != "*" && a != "_" && a != "•" && a != "~" {
            attributedString.removeAttribute(.foregroundColor, range: range)
            attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: range)
          }
        }
      }
    }
    
    return attributedString
  }
  
}
