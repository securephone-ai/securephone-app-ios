

import Foundation
import UIKit


extension NSAttributedString {
    // "\u{200F}" = RTL
    // "\u{200E}" = LTR
    func toRTL() -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: self)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.baseWritingDirection = .rightToLeft
        // *** Apply attribute to string ***
        attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range:  NSRange(location: 0, length: attributedString.length))
        
        return attributedString
    }
    
    func toLTR() -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: self)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.baseWritingDirection = .leftToRight
        // *** Apply attribute to string ***
        attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range:  NSRange(location: 0, length: attributedString.length))
        
        return attributedString
    }
    
    func adjustDirectionBasedOnSystemLanguage() -> NSAttributedString {
        if AppUtility.isArabic {
            return self.toRTL()
        } else {
            return self.toLTR()
        }
    }
    
    func height(withConstrainedWidth width: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = boundingRect(with: constraintRect,
                                       options: .usesLineFragmentOrigin,
                                       context: nil)
        
        return ceil(boundingBox.height)
    }
    
    func width(withConstrainedHeight height: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = boundingRect(with: constraintRect,
                                       options: .usesLineFragmentOrigin,
                                       context: nil)
        
        return ceil(boundingBox.width)
    }
    
    func size(withConstrainedWidth width: CGFloat) -> CGSize {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        return boundingRect(with: constraintRect,
                            options: .usesLineFragmentOrigin,
                            context: nil).size
    }
    
}




