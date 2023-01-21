//
//  BlackboxCore.h
//  BlackboxCore
//
//

#import <Foundation/Foundation.h>

//! Project version number for BlackboxCore.
FOUNDATION_EXPORT double BlackboxCoreVersionNumber;

//! Project version string for BlackboxCore.
FOUNDATION_EXPORT const unsigned char BlackboxCoreVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <BlackboxCore/PublicHeader.h>

typedef void (*PushMsgCallback)(int);
typedef enum AutoDownload {
    WifiCellular,
    Wifi,
    Never,
} AutoDownload;

@interface BlackboxCore : NSObject

// MARK: - Utility functions
+ (BOOL)setHostname:(NSString * _Nonnull)hostname;
+ (BOOL)setInternalPushHostname:(NSString * _Nonnull)hostname;
+ (BOOL)encryptPwdConf:(NSString * _Nonnull)conf key:(NSString * _Nonnull)key;
+ (NSString * _Nullable)decryptPwdConf:(NSData* _Nonnull)encryptedPwdConf
                                   key:(NSString * _Nullable)key
                            tempFolder:(NSString * _Nonnull)tempFolder;
+ (NSString * _Nullable)getAccountNumber;
+ (NSString * _Nullable)signupDevice:(NSString * _Nonnull)mobilenumber
                                 otp:(NSString * _Nonnull)otp
                              smsotp:(NSString * _Nonnull)smsotp;

// MARK: - Account functions
+ (NSString * _Nullable)accountRegisterPresence:(NSString * _Nonnull)pwd
                                             os:(NSString * _Nonnull)os
                                         pushId:(NSString * _Nullable)pushId
                                     voipPushId:(NSString * _Nullable)voipPushId;
+ (NSString * _Nullable)accountUpdateProfileName:(NSString * _Nonnull)name;
+ (NSString * _Nullable)accountUpdateProfilePhoto:(NSString * _Nonnull)filePath;
+ (NSString * _Nullable)accountSetOnline:(BOOL)isOnline;
+ (NSString * _Nullable)accountUpdateStatusMessage:(NSString * _Nonnull)message;
+ (NSString * _Nullable)accountGetSettings;
+ (NSString * _Nullable)accountSetSettings:(NSString * _Nullable)calendar
                                  language:(NSString * _Nullable)language
                          onlineVisibility:(BOOL)onlineVisibility
                        autoDownloadPhotos:(AutoDownload)autoDownloadPhotos
                        autoDownloadAudios:(AutoDownload)autoDownloadAudios
                        autoDownloadVideos:(AutoDownload)autoDownloadVideos
                     autoDownloadDocuments:(AutoDownload)autoDownloadDocuments;
+ (NSString * _Nullable)accountGetChatsList;
+ (NSString * _Nullable)accountGetCallsHistory;
+ (NSString * _Nullable)accountGetContacts:(NSString * _Nullable)search
                                 contactId:(NSInteger)contactId
                                flagSearch:(NSInteger)flagSearch
                               limitSearch:(NSInteger)limitSearch;
+ (NSString * _Nullable)accountGetNewMessage;
+ (NSString * _Nullable)accountGetNewMessageBackground;
+ (NSString * _Nullable)accountDeleteVoiceCall:(NSString * _Nonnull)callId;



// MARK: - Contacts functions
+ (NSString * _Nullable)contactAdd:(NSString * _Nonnull)json;
+ (NSString * _Nullable)contactUpdate:(NSString * _Nonnull)json;
+ (NSString * _Nullable)contactDelete:(NSString * _Nonnull)contactId;
+ (NSString * _Nullable)contactGetPhotoFileName:(NSString * _Nonnull)contactNumber;
+ (NSString * _Nullable)contactGetStarredMessages:(NSString * _Nonnull)contactNumber;
+ (NSString * _Nullable)contactGetMessages:(NSString * _Nonnull)contactNumber
                                 msgIdFrom:(NSString * _Nullable)msgIdFrom
                                   msgIdTo:(NSString * _Nullable)msgIdTo
                                  dateFrom:(NSString * _Nullable)dateFrom
                                    dateTo:(NSString * _Nullable)dateTo
                                     limit:(NSInteger)limit;
+ (NSString * _Nullable)contactGetAutoDeleteTimer:(NSString * _Nonnull)contactNumber;
+ (NSString * _Nullable)contactSetAutoDeleteTimer:(NSString * _Nonnull)contactNumber
                                          seconds:(NSInteger)seconds;
+ (NSString * _Nullable)contactArchiveChat:(NSString * _Nullable)contactNumber;
+ (NSString * _Nullable)contactUnarchiveChat:(NSString * _Nullable)contactNumber;
+ (NSString * _Nullable)contactSendTextMessage:(NSString * _Nonnull)contactNumber
                                          body:(NSString * _Nonnull)body
                              replyToMessageId:(NSString * _Nullable)replyToMessageId
                                     replyBody:(NSString * _Nullable)replyBody;
+ (NSString * _Nullable)contactSendFileMessage:(NSString * _Nonnull)contactNumber
                                      filePath:(NSString * _Nonnull)filePath
                                          body:(NSString * _Nullable)body
                              replyToMessageId:(NSString * _Nullable)replyToMessageId
                                     replyBody:(NSString * _Nullable)replyBody;
+ (NSString * _Nullable)contactSendLocation:(NSString * _Nonnull)contactNumber
                                   latitude:(NSString * _Nonnull)latitude
                                  longitude:(NSString * _Nonnull)longitude
                           replyToMessageId:(NSString * _Nullable)replyToMessageId
                                  replyBody:(NSString * _Nullable)replyBody;
+ (NSString * _Nullable)contactSendTyping:(NSString * _Nonnull)contactNumber;
+ (NSString * _Nullable)contactClearChat:(NSString * _Nonnull)contactNumber;
+ (NSString * _Nullable)contactSetNotificationSound:(NSString * _Nonnull)registeredNumber
                                          soundName:(NSString * _Nonnull)soundName;



// MARK: - Group functions
+ (NSString * _Nullable)groupCreate:(NSString * _Nonnull)description;
+ (NSString * _Nullable)groupGetStarredMessages:(NSString * _Nonnull)groupId;
+ (NSString * _Nullable)groupGetMessages:(NSString * _Nonnull)groupId
                               msgIdFrom:(NSString * _Nullable)msgIdFrom
                                 msgIdTo:(NSString * _Nullable)msgIdTo
                                dateFrom:(NSString * _Nullable)dateFrom
                                  dateTo:(NSString * _Nullable)dateTo
                                   limit:(NSInteger)limit;
+ (NSString * _Nullable)groupGetAutoDeleteTimer:(NSString * _Nonnull)groupId;
+ (NSString * _Nullable)groupSetAutoDeleteTimer:(NSString * _Nonnull)groupId
                                        seconds:(NSInteger)seconds;
+ (NSString * _Nullable)groupArchiveChat:(NSString * _Nullable)groupId;
+ (NSString * _Nullable)groupUnarchiveChat:(NSString * _Nullable)groupId;
+ (NSString * _Nullable)groupClearChat:(NSString * _Nonnull)groupId;
+ (NSString * _Nullable)groupSetProfilePhoto:(NSString * _Nonnull)groupId
                                    filePath:(NSString * _Nonnull)filePath;
+ (NSString * _Nullable)groupGetMembers:(NSString * _Nonnull)groupId;
+ (NSString * _Nullable)groupAddContact:(NSString * _Nonnull)groupId
                          contactNumber:(NSString * _Nonnull)contactNumber;
+ (NSString * _Nullable)groupRemoveContact:(NSString * _Nonnull)groupId
                             contactNumber:(NSString * _Nonnull)contactNumber;
+ (NSString * _Nullable)groupSetDescription:(NSString * _Nonnull)groupId
                                description:(NSString * _Nonnull)description;
+ (NSString * _Nullable)groupChangeRole:(NSString * _Nonnull)groupId
                          contactNumber:(NSString * _Nonnull)contactNumber
                                   role:(NSString * _Nonnull)role;
+ (NSString * _Nullable)groupDestroy:(NSString * _Nonnull)groupId;
+ (NSString * _Nullable)groupGetMessageReadReceipts:(NSString * _Nonnull)messageId;
+ (NSString * _Nullable)groupSetExpiryDate:(NSString * _Nonnull)groupId
                                      date:(NSString * _Nonnull)date;
+ (NSString * _Nullable)groupSendTextMessage:(NSString * _Nonnull)groupId
                                        body:(NSString * _Nonnull)body
                            replyToMessageId:(NSString * _Nullable)replyToMessageId
                                   replyBody:(NSString * _Nullable)replyBody;
+ (NSString * _Nullable)groupSendFileMessage:(NSString * _Nonnull)groupId
                                    filePath:(NSString * _Nonnull)filePath
                                        body:(NSString * _Nullable)body
                            replyToMessageId:(NSString * _Nullable)replyToMessageId
                                   replyBody:(NSString * _Nullable)replyBody;
+ (NSString * _Nullable)groupSendLocationMessage:(NSString * _Nonnull)groupId
                                        latitude:(NSString * _Nonnull)latitude
                                       longitude:(NSString * _Nonnull)longitude
                                replyToMessageId:(NSString * _Nullable)replyToMessageId
                                       replyBody:(NSString * _Nullable)replyBody;
+ (NSString * _Nullable)groupSendTyping:(NSString * _Nonnull)groupId;
+ (NSString * _Nullable)groupSetNotificationSound:(NSString * _Nonnull)groupId
                                        soundName:(NSString * _Nonnull)soundName;

+ (NSData * _Nullable)decryptFile:(NSString * _Nonnull)filename
                                key:(NSString * _Nonnull)key;


// MARK: - Chat & Messages functions
+ (NSString * _Nullable)sendReadReceipt:(NSString * _Nonnull)msgId
                        toContactNumber:(NSString * _Nonnull)contactNumber;
+ (NSString * _Nullable)setStarredMessage:(NSString * _Nonnull)msgId;
+ (NSString * _Nullable)unsetStarredMessage:(NSString * _Nonnull)msgId;
+ (NSString * _Nullable)setForwardedMessage:(NSString * _Nonnull)msgId;
+ (NSString * _Nullable)deleteMessage:(NSString * _Nonnull)msgId;


// MARK: - Call functions
+ (NSString * _Nullable)voiceCallStart:(NSString * _Nonnull)contactNumber;
+ (NSString * _Nullable)voiceCallCheckIncoming;
+ (NSString * _Nullable)voiceCallAnswer;
+ (NSString * _Nullable)voiceCallEnd:(NSString * _Nonnull)callId;
+ (NSString * _Nullable)voiceCallGetStatus:(NSString * _Nonnull)callId;

+ (NSString * _Nullable)conferenceCallStart:(NSString * _Nonnull)contactNumber
                                  sessionId:(NSInteger)sessionId;
+ (NSString * _Nullable)conferenceCallEnd:(NSString * _Nonnull)callId
                                sessionId:(NSInteger)sessionId;
+ (NSString * _Nullable)conferenceCallGetStatus:(NSString * _Nonnull)callId
                                      sessionId:(NSInteger)sessionId;
+ (void)conferenceCallSetSession:(NSInteger)session;
+ (void)conferenceCallUnsetSession:(NSInteger)session;


+ (NSString * _Nullable)videoCallStart:(NSString * _Nonnull)contactNumber;
+ (NSString * _Nullable)videoCallCheckIncoming;
+ (NSString * _Nullable)videoCallAnswer:(BOOL)audioOnly;
+ (NSString * _Nullable)videoCallEnd:(NSString * _Nonnull)callId;
+ (NSString * _Nullable)videoCallGetStatus:(NSString * _Nonnull)callId;
+ (NSString * _Nullable)videoCallConfirm:(NSString * _Nonnull)callId;

+ (NSInteger)voiceCallSendAudio:(unsigned char * _Nonnull)audioBuffer;
+ (NSData * _Nullable)voiceCallGetAudio:(void(^ _Nullable)(NSInteger errorCode))errorBlock;

+ (NSData * _Nullable)conferenceGetAudioSession:(NSInteger)session
                                     errorBlock:(void(^ _Nullable)(NSInteger errorCode))errorBlock;
+ (NSInteger)conferenceCallSendAudio:(unsigned char * _Nonnull)audioBuffer
                           sessionId:(NSInteger)sessionId;

+ (NSInteger)videoCallSendFrame:(unsigned char * _Nonnull)frame
                      frameSize:(NSInteger)frameSize;
+ (char * _Nullable)videoCallGetFrame:(int * _Nonnull)frameLen;




// MARK: - General functions
+ (NSString * _Nullable)getPhoto:(NSString * _Nonnull)name;
+ (NSString * _Nullable)getProfileInfo:(NSString * _Nonnull)registeredNumber;
+ (NSString * _Nullable)getNotificationsSound;
+ (NSString * _Nullable)setNetworkType:(NSString * _Nonnull)type;
+ (NSString * _Nullable)downloadMessageFileAsync:(NSString * _Nonnull)msgId;

+ (int)getFileTransferProgress:(NSString * _Nonnull)fileName;
+ (void)removeTemporaryFiles;
+ (void)wipeAllFiles;
+ (void)removeTemporaryPwdConfFile;



+ (BOOL)registerInternalPushMessage:(NSString * _Nonnull)mobileNumber
                           callback:(PushMsgCallback _Nonnull)callback;
+ (void)closeInternalPush;

@end

