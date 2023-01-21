import UIKit

@IBDesignable
class PaddableUITextField: UITextField {

  public var TextPadding = UIEdgeInsets.zero
  
  // = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
  @IBInspectable public var bottomInset: CGFloat {
    get { return TextPadding.bottom }
    set { TextPadding.bottom = newValue }
  }
  @IBInspectable public var leftInset: CGFloat {
    get { return TextPadding.left }
    set { TextPadding.left = newValue }
  }
  @IBInspectable public var rightInset: CGFloat {
    get { return TextPadding.right }
    set { TextPadding.right = newValue }
  }
  @IBInspectable public var topInset: CGFloat {
    get { return TextPadding.top }
    set { TextPadding.top = newValue }
  }

  
  override open func textRect(forBounds bounds: CGRect) -> CGRect {
    return bounds.inset(by: TextPadding)
  }
  
  override open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
    return bounds.inset(by: TextPadding)
  }
  
  override open func editingRect(forBounds bounds: CGRect) -> CGRect {
    return bounds.inset(by: TextPadding)
  }
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
