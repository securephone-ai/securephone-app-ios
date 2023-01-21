import Foundation


extension UILabel {

  var maxNumberOfLines: Int {
    /// An empty string's array
    var linesArray = [String]()
    
    guard let text = text, let font = font else { return 0 }
    
    let rect = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: frame.size.height)
    
    var attStr: NSMutableAttributedString!
    if attributedText != nil {
      attStr = NSMutableAttributedString(attributedString: attributedText!)
    } else {
      let myFont: CTFont = font as CTFont
      
      let attStr = NSMutableAttributedString(string: text)
      attStr.addAttribute(kCTFontAttributeName as NSAttributedString.Key, value: myFont, range: NSRange(location: 0, length: attStr.length))
    }
    
    let frameSetter: CTFramesetter = CTFramesetterCreateWithAttributedString(attStr as CFAttributedString)
    let path: CGMutablePath = CGMutablePath()
    path.addRect(CGRect(x: 0, y: 0, width: rect.size.width, height: 100000), transform: .identity)
    
    let frame: CTFrame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, nil)
    guard let lines = CTFrameGetLines(frame) as? [Any] else { return 0 }
    
    for line in lines {
      let lineRef = line as! CTLine
      let lineRange: CFRange = CTLineGetStringRange(lineRef)
      let range = NSRange(location: lineRange.location, length: lineRange.length)
      let lineString: String = (text as NSString).substring(with: range)
      linesArray.append(lineString)
    }
    
    return linesArray.count
  }
  
  // https://stackoverflow.com/a/14413484/1232289
  func getStringAt(line: Int) -> String? {
    
    /// An empty string's array
    var linesArray = [String]()
    
    guard let text = text, let font = font else { return nil }
    
    let rect = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: frame.size.height)
    
    var attStr: NSMutableAttributedString!
    if attributedText != nil {
      attStr = NSMutableAttributedString(attributedString: attributedText!)
    } else {
      let myFont: CTFont = font as CTFont
      
      let attStr = NSMutableAttributedString(string: text)
      attStr.addAttribute(kCTFontAttributeName as NSAttributedString.Key, value: myFont, range: NSRange(location: 0, length: attStr.length))
    }
    
    let frameSetter: CTFramesetter = CTFramesetterCreateWithAttributedString(attStr)
    let path: CGMutablePath = CGMutablePath()
    path.addRect(CGRect(x: 0, y: 0, width: rect.size.width, height: 100000), transform: .identity)
    
    let frame: CTFrame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, nil)
    guard let lines = CTFrameGetLines(frame) as? [Any] else { return nil }
    
    for line in lines {
      let lineRef = line as! CTLine
      let lineRange: CFRange = CTLineGetStringRange(lineRef)
      let range = NSRange(location: lineRange.location, length: lineRange.length)
      let lineString: String = (text as NSString).substring(with: range)
      linesArray.append(lineString)
    }
    
    return linesArray[line-1]
  }
  
}
