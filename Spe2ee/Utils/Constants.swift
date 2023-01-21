import UIKit
import AVFoundation

enum Constants {
    
    // App name
    static let AppName = "Calc".localized()    
    
    // Colors
    static let LighGrayBackground = UIColor(named: "LighGrayBackground")!
    static let NavBarBackground = UIColor(named: "NavBarBackground")!
    static let NavBarBackgroundiPhoneX = UIColor(named: "NavBarBackgroundiPhoneX")!
    static let DividerBackground = UIColor(named: "DividerBackground")!
    static let ArchiveSwipeActionColor = UIColor(named: "ArchiveSwipeActionColor")!
    static let UnreadSwipeActionColor = UIColor(named: "UnreadSwipeActionColor")!
    static let ChatsListSelectedBackgroundColor = UIColor(named: "ChatsListSelectedBackgroundColor")!
    static let MessagesHeaderDateBackgroundColor = UIColor(named: "MessagesHeaderDateBackgroundColor")!
    static let OutgoingBubbleColor = UIColor(named: "OutgoingBubbleColor")!
    static let IncomingBubbleColor = UIColor(named: "IncomingBubbleColor")!
    static let SystemMessageBackgroundColor = UIColor(named: "SystemMessageBackgroundColor")!
    static let MessageContextMenuBackground = UIColor(named: "MessageContextMenuBackground")!
    static let OutgoingBubbleBlinkColor = UIColor(named: "OutgoingBubbleBlinkColor")!
    static let IncomingBubbleBlinkColor = UIColor(named: "IncomingBubbleBlinkColor")!
    static let AlertColorCopy = UIColor(named: "AlertColorCopy")!
    static let AlertColorForward = UIColor(named: "AlertColorForward")!
    static let AlertColorScreenshot = UIColor(named: "AlertColorScreenshot")!
    static let AppMainColorDark = UIColor(named: "AppMainColorDark")!
    static let AppMainColorLight = UIColor(named: "AppMainColorLight")!
    static let AppMainColorGreen = UIColor(named: "AppMainGreen")!
    static let UnreadMessageBannerBackgroundLight = UIColor(named: "UnreadMessageBannerBackgroundLight")!
    
    // Chat View Margins
    static let msgTextViewTopBottomMargin = 8
    static let msgTextVieTopPlusButtomMargin = msgTextViewTopBottomMargin*2
    
    // MARK: Sound
    static let Vibrate = kSystemSoundID_Vibrate
    
    // MARK: ViewControllers name
    static let Chat = "ChatViewController"
    
    // MARK: UITableView Identifiers
    static let MessageCell_ID = "MessageCell_ID"
    static let MessageCellText_ID = "MessageCellText_ID"
    static let MessageCellLocation_ID = "MessageCellLocation_ID"
    static let MessageCellDocument_ID = "MessageCellDocument_ID"
    static let MessageCellAudio_ID = "MessageCellAudio_ID"
    static let MessagesSectionHeader_ID = "MessagesSectionHeader_ID"
    static let MessageCellSystem_ID = "MessageCellSystem_ID"
    static let MessageCellSystemAutoDelete_ID = "MessageCellSystemAutoDelete_ID"
    static let MessageCellSystemTemporaryChat_ID = "MessageCellSystemTemporaryChat_ID"
    static let MessageCellAlertCopyForward_ID = "MessageCellAlertCopyForward_ID"
    static let MessageCellDeleted_ID = "MessageCellDeleted_ID"
    static let MessageInfoCell_ID = "MessageInfoCell_ID"
    static let UnreadMessagesBannerCell_ID = "UnreadMessagesBannerCell_ID"
    
    // Starred Messages
    static let StarredMessageCell_ID = "StarredMessageCell_ID"
    static let StarredMessageCellText_ID = "StarredMessageCellText_ID"
    static let StarredMessageCellLocation_ID = "StarredMessageCellLocation_ID"
    static let StarredMessageCellDocument_ID = "StarredMessageCellDocument_ID"
    static let StarredMessageCellAudio_ID = "StarredMessageCellAudio_ID"
    static let StarredMessagesSectionHeader_ID = "StarredMessagesSectionHeader_ID"
    static let StarredMessageCellSystem_ID = "StarredMessageCellSystem_ID"
    static let StarredMessageCellAlertCopyForward_ID = "StarredMessageCellAlertCopyForward_ID"
    static let StarredMessageInfoCell_ID = "StarredMessageInfoCell_ID"
    
    // GROUP INFO CELLS IS
    static let GroupInfoTemporaryCell_ID = "GroupInfoTemporaryCell_ID"
    static let GroupInfoDefaultCell_ID = "GroupInfoDefaultCell_ID"
    static let GroupInfoMemberCell_ID = "GroupInfoMemberCell_ID"
    static let ContactInfoActionCell_ID = "ContactInfoActionCell_ID"
    
    // Blackbox periodic check timer
    static let CheckNewMessagesTimer: Int = 10
    
}

enum ScreenSize
{
    static let SCREEN_WIDTH         = UIScreen.main.bounds.size.width
    static let SCREEN_HEIGHT        = UIScreen.main.bounds.size.height
    static let SCREEN_MAX_LENGTH    = max(ScreenSize.SCREEN_WIDTH, ScreenSize.SCREEN_HEIGHT)
    static let SCREEN_MIN_LENGTH    = min(ScreenSize.SCREEN_WIDTH, ScreenSize.SCREEN_HEIGHT)
}


enum DeviceType
{
    static let IS_IPHONE_4_OR_LESS  = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH < 568.0
    static let IS_IPHONE_5          = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 568.0
    static let IS_IPHONE_6_7        = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 667.0
    static let IS_IPHONE_6P_7P      = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 736.0
    static let IS_IPAD              = UIDevice.current.userInterfaceIdiom == .pad && ScreenSize.SCREEN_MAX_LENGTH == 1024.0
    static let IS_IPAD_PRO          = UIDevice.current.userInterfaceIdiom == .pad && ScreenSize.SCREEN_MAX_LENGTH == 1366.0
}
