#import <Foundation/Foundation.h>
#import "blackbox.h"
#import "BlackboxCore.h"

NSInteger const AudioPacketSize = 1920;


@implementation NSString (formatter)

- (char *)toChar {
    return (char*)self.UTF8String;
}

- (BOOL)isEmpty {
    return self.length == 0;
}

+ (BOOL)isEmptyOrNull:(NSString *)string {
    return string == NULL || [string isEmpty];
}

@end

@implementation NSData (formatter)

- (BOOL)isEmpty {
    return self.length == 0;
}

+ (BOOL)isEmptyOrNull:(NSData*)data {
    return data == NULL || [data isEmpty];
}

@end

@interface BlackboxCore()

+ (NSString *)charToString:(char*)c;
+ (NSString *)chatGetMessages:(NSString *)contactNumber groupId:(NSString *)groupId msgIdFrom:(NSString *)msgIdFrom msgIdTo:(NSString *)msgIdTo
                     dateFrom:(NSString *)dateFrom dateTo:(NSString *)dateTo limit:(NSInteger)limit;
+ (NSString *)chatGetAutoDeleteTimer:(NSString *)contactNumber groupId:(NSString *)groupId;
+ (NSString *)chatSetAutoDeleteTimer:(NSString *)contactNumber groupId:(NSString *)groupId seconds:(NSInteger)seconds;
+ (NSString *)chatArchive:(NSString *)contactNumber groupId:(NSString *)groupId;
+ (NSString *)chatUnarchive:(NSString *)contactNumber groupId:(NSString *)groupId;
+ (NSString *)chatDelete:(NSString *)contactNumber groupId:(NSString *)groupId;

@end


@implementation BlackboxCore
NSString* pwdConf = NULL;

// MARK: - Utility functions

+ (BOOL)setHostname:(NSString *)hostname {
    if ([hostname isEmpty])
        return false;
    
    bb_set_hostname([hostname toChar]);
    return true;
}

+ (BOOL)setInternalPushHostname:(NSString *)hostname {
    if ([hostname isEmpty])
        return false;
    
    bb_set_interlapush_hostname([hostname toChar]);
    return true;
}



/// Encrypt the pwdConf and save the encrypted content to a file
/// @param conf pwdConf
/// @param key password used for encryption
+ (BOOL)encryptPwdConf:(NSString *)conf key:(NSString *)key {
    if ([conf isEmpty] || [key isEmpty])
        return false;
    
    // Get pwdConf Data
    NSData* pwdConfData = [conf dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger encryptedDataLen = pwdConfData.length + 64;
    unsigned char* encryptedPwdConf = malloc(encryptedDataLen);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    int result = bb_encrypt_pwdconf([conf toChar], [key toChar], encryptedPwdConf, [documentsDirectory toChar]);
    if (result <= 0)
        return FALSE;
    
    // Create file with this name
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"test/9154fed975b467fa8e56b1661cc1352fd1e726a34d8573449941b5a216124d44.enc"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // remove the old file
    if ([fileManager fileExistsAtPath:filePath])
        [fileManager removeItemAtPath:filePath error:NULL];
    
    // Save the new file
    NSData* encryptedData = [[NSData alloc] initWithBytes:encryptedPwdConf length:encryptedDataLen];
    [encryptedData writeToFile:filePath atomically:TRUE];
    
    return TRUE;
}


/// Decrypt the pwdConf file
/// @param encryptedPwdConf encrypted file bytes
/// @param key decryption key. Can be Null.
/// @param tempFolder temp Folder used by Blackbox.
+ (NSString *)decryptPwdConf:(NSData *)encryptedPwdConf key:(NSString *)key tempFolder:(NSString *)tempFolder {
    if ([encryptedPwdConf isEmpty] || [tempFolder isEmpty])
        return NULL;
    
    if (key == NULL)
        key = @"";
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"test/9154fed975b467fa8e56b1661cc1352fd1e726a34d8573449941b5a216124d44.enc"];
    NSData *data = [[NSData alloc] initWithContentsOfFile:filePath];
    
    char* pwdConfPlaceholder = malloc(2048);
    int bytesLenght = bb_decrypt_pwdconf((unsigned char*)[data bytes],
                                         (int)encryptedPwdConf.length,
                                         [key toChar],
                                         pwdConfPlaceholder,
                                         [tempFolder toChar]);
    
    if (bytesLenght <= 0)
        return NULL;
    
    pwdConf = [self charToString:pwdConfPlaceholder];
    return pwdConf;
}



/// Register with internal push notifications
/// @param mobileNumber the account number
/// @param callback callback called upon receiv ing new internal push notifications
+ (BOOL)registerInternalPushMessage:(NSString *)mobileNumber callback:(PushMsgCallback)callback {
    if (![self isPwdValid])
        return FALSE;
    
    if ([mobileNumber isEmpty])
        return false;
    
    bb_push_messages_client([mobileNumber toChar], callback);
    return TRUE;
}


/// Close internal push sockets
+ (void)closeInternalPush {
    bb_push_messages_client_close();
}

/// Get the registerd account number
+ (NSString *)getAccountNumber {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_get_registered_mobilenumber([pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Register a new device
/// @param mobilenumber mobile number to register
/// @param otp otp
/// @param smsotp smsotp
+ (NSString *)signupDevice:(NSString *)mobilenumber otp:(NSString *)otp smsotp:(NSString *)smsotp {
    if ([mobilenumber isEmpty] || [otp isEmpty] || [smsotp isEmpty])
        return NULL;
    
    
    char* result = bb_signup_newdevice([mobilenumber toChar], [otp toChar], [smsotp toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}


// MARK: - Account functions

/// Register the account presence
/// @param pwd the pwdConf
/// @param os device OS
/// @param pushId Apple push notification token. Can be Null
/// @param voipPushId apple VoipPush notification token. Can be null
+ (NSString *)accountRegisterPresence:(NSString *)pwd os:(NSString *)os pushId:(NSString *)pushId voipPushId:(NSString *)voipPushId {
    if ([pwd isEmpty] || [os isEmpty])
        return NULL;
    
    if (pushId == NULL)
        pushId = @"";
    
    if (voipPushId == NULL)
        voipPushId = @"";
    
    char* result = bb_register_presence([pwd toChar], [os toChar], [pushId toChar], [voipPushId toChar]);
    NSString *response = [self charToString:result];
    if ([response localizedCaseInsensitiveContainsString:@"\"answer\":\"OK\""]) {
        pwdConf = pwd;
    }
    free(result);
    return response;
}

/// Update the account profile name
/// @param name The new name to use
+ (NSString *)accountUpdateProfileName:(NSString *)name {
    if (![self isPwdValid])
        return NULL;
    
    if ([name isEmpty])
        return NULL;
    
    char* result = bb_update_profilename([name toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}


/// Update the account photo profile
/// @param filePath the path of the image to use
+ (NSString *)accountUpdateProfilePhoto:(NSString *)filePath {
    if (![self isPwdValid])
        return NULL;
    
    if ([filePath isEmpty])
        return NULL;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] == FALSE){
        NSLog(@"File doesn't exist");
        return NULL;
    }
    
    char* result = bb_update_photo_profile([filePath toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Set the account status to online or offline and notifiy the contacts
/// @param isOnline Flag to indicate if the account is online or offline
+ (NSString *)accountSetOnline:(BOOL)isOnline {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_set_onoffline([pwdConf toChar], isOnline ? "online" : "offline");
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Set the account status message
/// @param message the new message to use
+ (NSString *)accountUpdateStatusMessage:(NSString *)message {
    if (![self isPwdValid])
        return NULL;
    
    if ([message isEmpty])
        return NULL;
    
    char* result = bb_update_status([message toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get the account settings
+ (NSString *)accountGetSettings {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_get_configuration([pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Set Account Settings
/// @param calendar calendar: Islamic / Gregorian. If the value is Empty or Null it will be set to "Gregorian"
/// @param language language. If the value is Empty or Null it will be set to "Gregorian" it will be set to "eng"
/// @param onlineVisibility True send online notification to users. False to stay hidden
/// @param autoDownloadPhotos Auto Download photo network option
/// @param autoDownloadAudios Auto Download audio network option
/// @param autoDownloadVideos Auto Download video network option
/// @param autoDownloadDocuments Auto Download documents network option
+ (NSString *)accountSetSettings:(NSString *)calendar language:(NSString *)language onlineVisibility:(BOOL)onlineVisibility
              autoDownloadPhotos:(AutoDownload)autoDownloadPhotos autoDownloadAudios:(AutoDownload)autoDownloadAudios
              autoDownloadVideos:(AutoDownload)autoDownloadVideos autoDownloadDocuments:(AutoDownload)autoDownloadDocuments {
    
    if (![self isPwdValid])
        return NULL;
    
    if ([NSString isEmptyOrNull:calendar])
        calendar = @"gregorian";
    
    if ([NSString isEmptyOrNull:language])
        language = @"eng";
    
    char* result = bb_set_configuration([pwdConf toChar],
                                        [calendar toChar],
                                        [language toChar], onlineVisibility ? [@"Y" toChar] : [@"N" toChar],
                                        [(autoDownloadPhotos == WifiCellular ? @"0" : (autoDownloadPhotos == Wifi ? @"1" : @"2")) toChar],
                                        [(autoDownloadAudios == WifiCellular ? @"0" : (autoDownloadAudios == Wifi ? @"1" : @"2")) toChar],
                                        [(autoDownloadVideos == WifiCellular ? @"0" : (autoDownloadVideos == Wifi ? @"1" : @"2")) toChar],
                                        [(autoDownloadDocuments == WifiCellular ? @"0" : (autoDownloadDocuments == Wifi ? @"1" : @"2")) toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get account chats list
+ (NSString *)accountGetChatsList {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_get_list_chat([pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get the calls history
+ (NSString *)accountGetCallsHistory {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_last_voicecalls([pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Fetch the cotnacts from the server
/// @param search query search
/// @param contactId search by contact id
/// @param flagSearch flag
/// @param limitSearch limit number of returned elements
+ (NSString *)accountGetContacts:(NSString *)search contactId:(NSInteger)contactId flagSearch:(NSInteger)flagSearch limitSearch:(NSInteger)limitSearch {
    if (![self isPwdValid])
        return NULL;
    
    if (search == NULL)
        search = @"";
    
    char* result = bb_get_contacts([search toChar], (int)contactId, (int)flagSearch, (int)limitSearch, [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get a new message from the queue
+ (NSString *)accountGetNewMessage {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_get_newmsg_fileasync([pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get a new message from the queue. Used when the app is in background.
+ (NSString *)accountGetNewMessageBackground {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_get_newmsg_fileasync_background([pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

+ (NSString *)accountDeleteVoiceCall:(NSString *)callId {
    if (![self isPwdValid])
        return NULL;
    
    if ([callId isEmpty])
        return NULL;
    
    char* result = bb_delete_voicecalls([pwdConf toChar], [callId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}


// MARK: - Contacts functions

/// Add contact
/// @param json json string
+ (NSString *)contactAdd:(NSString *)json {
    if (![self isPwdValid])
        return NULL;
    
    if ([json isEmpty])
        return NULL;
    
    char* result = bb_add_contact([json toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Update contact
/// @param json json string
+ (NSString *)contactUpdate:(NSString *)json {
    if (![self isPwdValid])
        return NULL;
    
    if ([json isEmpty])
        return NULL;
    
    
    char* result = bb_update_contact([json toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Delete Contact
/// @param contactId the contact ID
+ (NSString *)contactDelete:(NSString *)contactId {
    if (![self isPwdValid])
        return NULL;
    
    if ([contactId isEmpty])
        return NULL;
    
    
    char* result = bb_delete_contact([contactId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get the copntact photo file name
/// @param contactNumber contact registered number used to identify the contact
+ (NSString *)contactGetPhotoFileName:(NSString *)contactNumber {
    if (![self isPwdValid]) return NULL;
    
    if ([contactNumber isEmpty])
        return NULL;
    
    char* result = bb_get_photoprofile_filename([contactNumber toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}


/// Get contact starred messages
/// @param contactNumber contact registerd number
+ (NSString *)contactGetStarredMessages:(NSString *)contactNumber {
    if (![self isPwdValid])
        return NULL;
    
    if ([contactNumber isEmpty])
        return NULL;
    
    char* result = bb_get_starredmsg([pwdConf toChar], "", [contactNumber toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}


/// Get contact messages
/// @param contactNumber contact number
/// @param msgIdFrom from id filter
/// @param msgIdTo to id filter
/// @param dateFrom from date filter
/// @param dateTo to date filter
/// @param limit limit returned messages
+ (NSString *)contactGetMessages:(NSString *)contactNumber msgIdFrom:(NSString *)msgIdFrom
                         msgIdTo:(NSString *)msgIdTo dateFrom:(NSString *)dateFrom dateTo:(NSString *)dateTo limit:(NSInteger)limit {
    return [self chatGetMessages:contactNumber groupId:@"" msgIdFrom:msgIdFrom msgIdTo:msgIdTo dateFrom:dateFrom dateTo:dateTo limit:limit];
}

/// Get contact chat auto delete timer
/// @param contactNumber contact registered number
+ (NSString *)contactGetAutoDeleteTimer:(NSString *)contactNumber {
    if ([contactNumber isEmpty]) {
        return NULL;
    }
    return [self chatGetAutoDeleteTimer:contactNumber groupId:NULL];
}

/// Set contact chat auto delete timer
/// @param contactNumber the contact registered number
/// @param seconds auto delete messages every specified seconds
+ (NSString *)contactSetAutoDeleteTimer:(NSString *)contactNumber seconds:(NSInteger)seconds {
    if ([contactNumber isEmpty]) {
        return NULL;
    }
    return [self chatSetAutoDeleteTimer:contactNumber groupId:NULL seconds:seconds];
}

/// Archive contact's chat
/// @param contactNumber contact registered number
+ (NSString *)contactArchiveChat:(NSString *)contactNumber {
    if ([NSString isEmptyOrNull:contactNumber])
        return NULL;
    
    return [self chatArchive:contactNumber groupId:NULL];
}

/// Unarchive contact's chat
/// @param contactNumber contact registered number
+ (NSString *)contactUnarchiveChat:(NSString *)contactNumber {
    if ([NSString isEmptyOrNull:contactNumber])
        return NULL;
    
    return [self chatUnarchive:contactNumber groupId:NULL];
}

/// Send a text message to a single contact
/// @param contactNumber the contact registered number
/// @param body the message body
/// @param replyToMessageId reply to message id
/// @param replyBody reply body
+ (NSString *)contactSendTextMessage:(NSString *)contactNumber
                                body:(NSString *)body
                    replyToMessageId:(NSString *)replyToMessageId
                           replyBody:(NSString *)replyBody {
    if (![self isPwdValid])
        return NULL;
    
    if (replyToMessageId == NULL)
        replyToMessageId = @"";
    
    if (replyBody == NULL)
        replyBody = @"";
    
    char* result = bb_send_txt_msg([contactNumber toChar], [body toChar], [pwdConf toChar], [replyToMessageId toChar], [replyBody toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Send a file message to a single contact
/// @param contactNumber the contact registered number
/// @param filePath the file path
/// @param body the message body
/// @param replyToMessageId reply to message id
/// @param replyBody reply body
+ (NSString *)contactSendFileMessage:(NSString *)contactNumber
                            filePath:(NSString *)filePath
                                body:(NSString *)body
                    replyToMessageId:(NSString *)replyToMessageId
                           replyBody:(NSString *)replyBody {
    if (![self isPwdValid])
        return NULL;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] == false)
        return NULL;
    
    if (body == NULL)
        body = @"";
    
    if (replyToMessageId == NULL)
        replyToMessageId = @"";
    
    if (replyBody == NULL)
        replyBody = @"";
    
    char* result = bb_send_file([filePath toChar], [contactNumber toChar], [body toChar], [pwdConf toChar], [replyToMessageId toChar], [replyBody toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Send the location to a single contact
/// @param contactNumber the contact registered number
/// @param latitude location latitude
/// @param longitude location longitude
/// @param replyToMessageId reply to message id
/// @param replyBody reply body
+ (NSString *)contactSendLocation:(NSString *)contactNumber
                         latitude:(NSString *)latitude
                        longitude:(NSString *)longitude
                 replyToMessageId:(NSString *)replyToMessageId
                        replyBody:(NSString *)replyBody {
    if (![self isPwdValid])
        return NULL;
    
    if ([latitude isEmpty])
        return NULL;
    
    if ([longitude isEmpty])
        return NULL;
    
    if (replyToMessageId == NULL)
        replyToMessageId = @"";
    
    if (replyBody == NULL)
        replyBody = @"";
    
    char* result = bb_send_location([contactNumber toChar], [latitude toChar], [longitude toChar], [pwdConf toChar], [replyToMessageId toChar], [replyBody toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Send typing to contact
/// @param contactNumber the contact registered numbrer
+ (NSString *)contactSendTyping:(NSString *)contactNumber {
    if (![self isPwdValid])
        return NULL;
    
    if ([contactNumber isEmpty])
        return NULL;
    
    char* result = bb_send_typing([contactNumber toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Delete a contact's chat
/// @param contactNumber the contact registered number
+ (NSString *)contactClearChat:(NSString *)contactNumber {
    return [self chatDelete:contactNumber groupId:NULL];
}

/// Set contact notification sound
/// @param registeredNumber contact registered number
/// @param soundName file name
+ (NSString *)contactSetNotificationSound:(NSString *)registeredNumber soundName:(NSString *)soundName {
    if (![self isPwdValid])
        return NULL;
    
    if ([registeredNumber isEmpty])
        return NULL;
    
    if ([soundName isEmpty])
        return NULL;

    char* result = bb_set_notifications([pwdConf toChar],
                                        "",
                                        [registeredNumber toChar],
                                        [soundName toChar],
                                        "Y",
                                        "Y",
                                        "Y",
                                        "0000-00-00 00:00:00");
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

// MARK: - Group functions
+ (NSString *)groupCreate:(NSString *)description {
    if (![self isPwdValid])
        return NULL;
    
    if ([description isEmpty])
        return NULL;
    
    char* result = bb_new_groupchat([description toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get group starred messages
/// @param groupId group identifier
+ (NSString *)groupGetStarredMessages:(NSString *)groupId {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty]) {
        return NULL;
    }
    
    char* result = bb_get_starredmsg([pwdConf toChar], [groupId toChar], "");
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get group messages
/// @param groupId contact number
/// @param msgIdFrom from id filter
/// @param msgIdTo to id filter
/// @param dateFrom from date filter
/// @param dateTo to date filter
/// @param limit limit returned messages
+ (NSString *)groupGetMessages:(NSString *)groupId msgIdFrom:(NSString *)msgIdFrom msgIdTo:(NSString *)msgIdTo dateFrom:(NSString *)dateFrom dateTo:(NSString *)dateTo limit:(NSInteger)limit {
    return [self chatGetMessages:@"" groupId:groupId msgIdFrom:msgIdFrom msgIdTo:msgIdTo dateFrom:dateFrom dateTo:dateTo limit:limit];
}

/// Get group chat auto delete timer
/// @param groupId group id
+ (NSString *)groupGetAutoDeleteTimer:(NSString *)groupId {
    if ([groupId isEmpty]) {
        return NULL;
    }
    return [self chatGetAutoDeleteTimer:NULL groupId:groupId];
}

/// Set group chat auto delete timer
/// @param groupId group id
/// @param seconds auto delete messages every specified seconds
+ (NSString *)groupSetAutoDeleteTimer:(NSString *)groupId seconds:(NSInteger)seconds {
    if ([groupId isEmpty]) {
        return NULL;
    }
    return [self chatSetAutoDeleteTimer:NULL groupId:groupId seconds:seconds];
}

/// Archive group's chat
/// @param groupId group id
+ (NSString *)groupArchiveChat:(NSString *)groupId {
    if ([NSString isEmptyOrNull:groupId])
        return NULL;
    
    return [self chatArchive:NULL groupId:groupId];
}

/// Unarchie groupìs chat
/// @param groupId group id
+ (NSString *)groupUnarchiveChat:(NSString *)groupId {
    if ([NSString isEmptyOrNull:groupId])
        return NULL;
    
    return [self chatUnarchive:NULL groupId:groupId];
}

/// Delete the group's chat
/// @param groupId group id
+ (NSString *)groupClearChat:(NSString *)groupId {
    return [self chatDelete:NULL groupId:groupId];
}

/// Set the group profile image
/// @param groupId groupid
/// @param filePath the image file path
+ (NSString *)groupSetProfilePhoto:(NSString *)groupId filePath:(NSString *)filePath {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty])
        return NULL;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] == false)
        return NULL;
    
    char* result = bb_update_photo_groupchat([filePath toChar], [groupId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get the group's members list
/// @param groupId group Id
+ (NSString *)groupGetMembers:(NSString *)groupId {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty])
        return NULL;
    
    char* result = bb_get_list_members_groupchat([groupId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Add a new Contact to the group
/// @param groupId group ID
/// @param contactNumber the contact registered number
+ (NSString *)groupAddContact:(NSString *)groupId contactNumber:(NSString *)contactNumber {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty])
        return NULL;
    
    if ([contactNumber isEmpty])
        return NULL;
    
    char* result = bb_add_member_groupchat([groupId toChar], [contactNumber toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

+ (NSData *)decryptFile:(NSString *)filename key:(NSString *)key {
    int size = 0;
    unsigned char * result = bb_decrypt_file_to_buffer([filename toChar], [key toChar], &size);
    NSData* data = [NSData dataWithBytes:result length:(NSUInteger)size];
    free(result);
    return data;
}

/// Remove a new Contact from the group
/// @param groupId group ID
/// @param contactNumber the contact registered number
+ (NSString *)groupRemoveContact:(NSString *)groupId contactNumber:(NSString *)contactNumber {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty])
        return NULL;
    
    if ([contactNumber isEmpty])
        return NULL;
    
    char* result = bb_revoke_member_groupchat([groupId toChar], [contactNumber toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Set the group description
/// @param groupId group id
/// @param description the new description
+ (NSString *)groupSetDescription:(NSString *)groupId description:(NSString *)description {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty])
        return NULL;
    
    if ([description isEmpty])
        return NULL;
    
    char* result = bb_change_groupchat([description toChar], [groupId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Change the role of a contact within the group (Admin/Creator only)
/// @param groupId the group id
/// @param contactNumber the contact registered number
/// @param role the new role
+ (NSString *)groupChangeRole:(NSString *)groupId contactNumber:(NSString *)contactNumber role:(NSString *)role {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty])
        return NULL;
    
    if ([contactNumber isEmpty])
        return NULL;
    
    if ([role isEmpty])
        return NULL;
    
    char* result = bb_change_role_member_groupchat([groupId toChar], [contactNumber toChar], [role toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Compeltely delete a group
/// @param groupId group id
+ (NSString *)groupDestroy:(NSString *)groupId {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty])
        return NULL;
    
    char* result = bb_delete_groupchat([groupId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}


/// Get the message read receipts
/// @param messageId message id
+ (NSString *)groupGetMessageReadReceipts:(NSString *)messageId {
    if (![self isPwdValid])
        return NULL;
    
    if ([messageId isEmpty])
        return NULL;
    
    char* result = bb_get_read_receipts_groupmsg([pwdConf toChar], [messageId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Set the group exiry date
/// @param groupId group id
/// @param date the expiry date string
+ (NSString *)groupSetExpiryDate:(NSString *)groupId date:(NSString *)date {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty])
        return NULL;
    
    if ([date isEmpty])
        return NULL;
    
    char* result = bb_setexpiringdate_groupchat([date toChar], [groupId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Send a text message to a single contact
/// @param groupId the group id
/// @param body the message body
/// @param replyToMessageId reply to message id
/// @param replyBody reply body
+ (NSString *)groupSendTextMessage:(NSString *)groupId body:(NSString *)body replyToMessageId:(NSString *)replyToMessageId replyBody:(NSString *)replyBody {
    if (![self isPwdValid])
        return NULL;
    
    if (replyToMessageId == NULL)
        replyToMessageId = @"";
    
    if (replyBody == NULL)
        replyBody = @"";
    
    char* result = bb_send_txt_msg_groupchat([groupId toChar], [body toChar], [pwdConf toChar], [replyToMessageId toChar], [replyBody toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Send a file message to a group chat
/// @param groupId groupid
/// @param filePath the file path
/// @param body the message body
/// @param replyToMessageId reply to message id
/// @param replyBody reply body
+ (NSString *)groupSendFileMessage:(NSString *)groupId filePath:(NSString *)filePath body:(NSString *)body replyToMessageId:(NSString *)replyToMessageId replyBody:(NSString *)replyBody {
    if (![self isPwdValid])
        return NULL;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] == false)
        return NULL;
    
    if (body == NULL)
        body = @"";
    
    if (replyToMessageId == NULL)
        replyToMessageId = @"";
    
    if (replyBody == NULL)
        replyBody = @"";
    
    char* result = bb_send_file_groupchat([filePath toChar], [groupId toChar], [body toChar], [pwdConf toChar], [replyToMessageId toChar], [replyBody toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Send the location to a group
/// @param groupId group id
/// @param latitude location latitude
/// @param longitude location longitude
/// @param replyToMessageId reply to message id
/// @param replyBody reply body
+ (NSString *)groupSendLocationMessage:(NSString *)groupId latitude:(NSString *)latitude longitude:(NSString *)longitude replyToMessageId:(NSString *)replyToMessageId replyBody:(NSString *)replyBody {
    if (![self isPwdValid])
        return NULL;
    
    if ([latitude isEmpty])
        return NULL;
    
    if ([longitude isEmpty])
        return NULL;
    
    if (replyToMessageId == NULL)
        replyToMessageId = @"";
    
    if (replyBody == NULL)
        replyBody = @"";
    
    char* result = bb_send_location_groupchat([groupId toChar], [latitude toChar], [longitude toChar], [pwdConf toChar], [replyToMessageId toChar], [replyBody toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Send typing to Group
/// @param groupId group id
+ (NSString *)groupSendTyping:(NSString *)groupId {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty])
        return NULL;
    
    char* result = bb_send_typing_groupchat([groupId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

+ (NSString *)groupSetNotificationSound:(NSString *)groupId soundName:(NSString *)soundName {
    if (![self isPwdValid])
        return NULL;
    
    if ([groupId isEmpty])
        return NULL;
    
    if ([soundName isEmpty])
        return NULL;
    
    char* result = bb_set_notifications([pwdConf toChar],
                                        [groupId toChar],
                                        "",
                                        [soundName toChar],
                                        "Y",
                                        "Y",
                                        "Y",
                                        "0000-00-00 00:00:00");
    NSString* response = [self charToString:result];
    free(result);
    return response;
}


// MARK: - Chat & Messages functions

/// Send message read receipt
/// @param msgId message id
/// @param contactNumber message sender
+ (NSString *)sendReadReceipt:(NSString *)msgId toContactNumber:(NSString *)contactNumber {
    if (![self isPwdValid])
        return NULL;
    
    if ([msgId isEmpty] || [contactNumber isEmpty])
        return NULL;
    
    char* result = bb_send_read_receipt([contactNumber toChar], msgId.intValue, [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Set starred message
/// @param msgId the message id
+ (NSString *)setStarredMessage:(NSString *)msgId {
    if (![self isPwdValid])
        return NULL;
    
    if ([msgId isEmpty])
        return NULL;
    
    char* result = bb_set_starredmsg([msgId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Unset starred message
/// @param msgId the message id
+ (NSString *)unsetStarredMessage:(NSString *)msgId {
    if (![self isPwdValid])
        return NULL;
    
    if ([msgId isEmpty])
        return NULL;
    
    char* result = bb_unset_starredmsg([msgId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Flag a message as Forwarded
/// @param msgId message Id
+ (NSString *)setForwardedMessage:(NSString *)msgId {
    if (![self isPwdValid])
        return NULL;
    
    if ([msgId isEmpty])
        return NULL;
    
    char* result = bb_set_forwardedmsg([msgId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Delete message
/// @param msgId message id
+ (NSString *)deleteMessage:(NSString *)msgId {
    if (![self isPwdValid])
        return NULL;
    
    if ([msgId isEmpty])
        return NULL;
    
    char* result = bb_delete_message([pwdConf toChar], [msgId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}


// MARK: - Call functions

/// Start a new voice call with a specific contact
/// @param contactNumber conract registered number
+ (NSString *)voiceCallStart:(NSString *)contactNumber {
    if (![self isPwdValid])
        return NULL;
    
    if ([contactNumber isEmpty])
        return NULL;

    char* result = bb_originate_voicecall([contactNumber toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Check if there is a new Incoming Voice Call
+ (NSString *)voiceCallCheckIncoming {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_info_voicecall([pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Answer incoming Voice Call
+ (NSString *)voiceCallAnswer {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_answer_voicecall([pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// End Voice Call
/// @param callId call id
+ (NSString *)voiceCallEnd:(NSString *)callId {
    if (![self isPwdValid])
        return NULL;
    
    if ([callId isEmpty])
        return NULL;
    
    char* result = bb_hangup_voicecall([pwdConf toChar], [callId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get the call status
/// @param callId call Id
+ (NSString *)voiceCallGetStatus:(NSString *)callId {
    if (![self isPwdValid])
        return NULL;
    
    if ([callId isEmpty])
        return NULL;
    
    char* result = bb_status_voicecall([pwdConf toChar], [callId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Start a new conference and add the specific contact to it
/// @param contactNumber the cotnact registered number
/// @param sessionId the contact session identifier
+ (NSString *)conferenceCallStart:(NSString *)contactNumber sessionId:(NSInteger)sessionId {
    if (![self isPwdValid])
        return NULL;
    
    if ([contactNumber isEmpty])
        return NULL;
    
    char* result = bb_originate_voicecall_id([contactNumber toChar], [pwdConf toChar], (int)sessionId);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Remove the contact from the conference call
/// @param callId contact call Id
/// @param sessionId contact session identifier
+ (NSString *)conferenceCallEnd:(NSString *)callId sessionId:(NSInteger)sessionId {
    if (![self isPwdValid])
        return NULL;
    
    if ([callId isEmpty])
        return NULL;
    
    char* result = bb_hangup_voicecall_id([pwdConf toChar], [callId toChar], (int)sessionId);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get Conference call status
/// @param callId call id
/// @param sessionId session
+ (NSString *)conferenceCallGetStatus:(NSString *)callId sessionId:(NSInteger)sessionId {
    if (![self isPwdValid])
        return NULL;
    
    if ([callId isEmpty])
        return NULL;
    
    char* result = bb_status_voicecall_id([pwdConf toChar], [callId toChar], (int)sessionId);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Set Audio Conference for a session
/// @param session the session
+ (void)conferenceCallSetSession:(NSInteger)session {
    bb_audio_set_audioconference((int)session);
}

/// Unset Audio Conference for a session
/// @param session session
+ (void)conferenceCallUnsetSession:(NSInteger)session {
    bb_audio_unset_audioconference((int)session);
}

/// Start a new Video Call with a specific contact
/// @param contactNumber conract registered number
+ (NSString *)videoCallStart:(NSString *)contactNumber {
    if (![self isPwdValid])
        return NULL;
    
    if ([contactNumber isEmpty])
        return NULL;
    
    char* result = bb_originate_videocall([contactNumber toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Check if there is a new Incoming Video Call
+ (NSString *)videoCallCheckIncoming {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_info_videocall([pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Answer incoming Video Call
/// @param audioOnly flag to indicate if the call only Audio or Audo+Video. Usually it has only audio when answered when phone is locked.
+ (NSString *)videoCallAnswer:(BOOL)audioOnly {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_answer_videocall([pwdConf toChar], audioOnly ? "Y" : "N");
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// End Video Call
/// @param callId video call id
+ (NSString *)videoCallEnd:(NSString *)callId {
    if (![self isPwdValid])
        return NULL;
    
    if ([callId isEmpty])
        return NULL;
    
    char* result = bb_hangup_videocall([pwdConf toChar], [callId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get the Video Call status
/// @param callId call Id
+ (NSString *)videoCallGetStatus:(NSString *)callId {
    if (![self isPwdValid])
        return NULL;
    
    if ([callId isEmpty])
        return NULL;
    
    char* result = bb_status_videocall([pwdConf toChar], [callId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// CONFIRM READY FOR VIDEO CALL
/// @param callId call Id
+ (NSString *)videoCallConfirm:(NSString *)callId {
    if (![self isPwdValid])
        return NULL;
    
    if ([callId isEmpty])
        return NULL;
    
    char* result = bb_confirm_videocall([pwdConf toChar], [callId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Send audio buffers to OneToOne call
/// @param audioBuffer audio buffer
+ (NSInteger)voiceCallSendAudio:(unsigned char *)audioBuffer {
    return (int)bb_audio_send(audioBuffer);
}

/// Receive audio pakcets from OneToOne call
/// @param errorBlock Error Codes:
/// -1 = Audio - Timed-out
/// -2 = Call - Hang-Up
+ (NSData * _Nullable)voiceCallGetAudio:(void(^ _Nullable)(NSInteger errorCode))errorBlock {
    if (![self isPwdValid])
        return NULL;
    NSMutableData *buffer = [NSMutableData dataWithLength:AudioPacketSize];
    int size = bb_audio_receive((unsigned char *)[buffer bytes]);
    if (size <= 0) {
        errorBlock(size);
        return NULL;
    }
    return buffer;
}

/// Receive audio pakcets from conference call.
/// @param errorBlock Error Codes:
/// -1 = Audio - Timed-out
/// -2 = Call - Hang-Up
+ (NSData *)conferenceGetAudioSession:(NSInteger)session errorBlock:(void (^)(NSInteger))errorBlock {
    if (![self isPwdValid])
        return NULL;
    
    NSMutableData *buffer = [NSMutableData dataWithLength:AudioPacketSize];
    int size = bb_audio_receive_session((int)session, (unsigned char *)[buffer bytes]);
    if (size <= 0) {
        errorBlock(size);
        return NULL;
    }
    return buffer;
}

/// Send audio buffers to Conference call
/// @param audioBuffer audio buffer
+ (NSInteger)conferenceCallSendAudio:(unsigned char *)audioBuffer sessionId:(NSInteger)sessionId {
    return bb_audio_send_session((int)sessionId, audioBuffer);
}

/// Send video frame
/// @param frame frame buffer
/// @param frameSize frame size
+ (NSInteger)videoCallSendFrame:(unsigned char * _Nonnull)frame frameSize:(NSInteger)frameSize {
    return bb_video_send(frame, (unsigned short)frameSize);
}

/// Get video call frame
+ (char *)videoCallGetFrame:(int *)frameLen {
    if (![self isPwdValid])
        return NULL;

    char* frameBuffer = bb_video_receive(frameLen);
    return frameLen > 0 ? frameBuffer : NULL;
}


// MARK: - General functions

/// Get profile info. Can be used for Account and Contacts
/// @param registeredNumber the account registered Number
+ (NSString *)getProfileInfo:(NSString *)registeredNumber {
    if (![self isPwdValid])
        return NULL;
    
    if ([registeredNumber isEmpty])
        return NULL;
    
    char* result = bb_get_profileinfo([registeredNumber toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get profile photo
/// @param name photo name
+ (NSString *)getPhoto:(NSString *)name {
    if (![self isPwdValid])
        return NULL;
    
    if ([name isEmpty])
        return NULL;
        
    char* result = bb_get_photo([name toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Retrieve chats notification sound
+ (NSString *)getNotificationsSound {
    if (![self isPwdValid])
        return NULL;
    
    char* result = bb_get_notifications([pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Set the network currently in use
/// @param type the network in use
+ (NSString *)setNetworkType:(NSString *)type {
    if (![self isPwdValid])
        return NULL;
    
    if ([type isEmpty])
        return NULL;
    
    char* result = bb_set_networktype([pwdConf toChar], [type toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Download the message File
/// @param msgId msg id
+ (NSString *)downloadMessageFileAsync:(NSString *)msgId {
    if (![self isPwdValid])
        return NULL;
    
    if ([msgId isEmpty])
        return NULL;
    
    char* result = bb_download_fileasync([pwdConf toChar], [msgId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

/// Get the file transfer progress of a file 0->100
/// @param fileName the file name to check
+ (int)getFileTransferProgress:(NSString * _Nonnull)fileName {
    return bb_filetransfer_getstatus([fileName toChar]);
}

/// Remove temporary files
+ (void)removeTemporaryFiles {
    bb_clean_tmp_files();
}

/// Remove all files
+ (void)wipeAllFiles {
    bb_wipe_all_files();
}

/// remove temporary pwdconf file
+ (void)removeTemporaryPwdConfFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    bb_clean_tmp_masterpwdfile([documentsDirectory toChar]);
}

// MARK: -

/// Convert char* to NSString*
/// @param c the char to convert
+ (NSString *)charToString:(char *)c {
    if (c == NULL)
        return @"";
    return [NSString stringWithUTF8String:c];
}

+ (BOOL)isPwdValid {
    return [NSString isEmptyOrNull:pwdConf] == false;
}


// MARK: - Private Functions

/// General function to get contacts and groups messages
+ (NSString *)chatGetMessages:(NSString *)contactNumber groupId:(NSString *)groupId msgIdFrom:(NSString *)msgIdFrom msgIdTo:(NSString *)msgIdTo dateFrom:(NSString *)dateFrom dateTo:(NSString *)dateTo limit:(NSInteger)limit {
    if (![self isPwdValid])
        return NULL;
    
    if (contactNumber == NULL) {
        contactNumber = @"";
    }
    if (groupId == NULL) {
        groupId = @"";
    }
    if (msgIdFrom == NULL) {
        msgIdFrom = @"";
    }
    if (msgIdTo == NULL) {
        msgIdTo = @"";
    }
    if (dateFrom == NULL) {
        dateFrom = @"";
    }
    if (dateTo == NULL) {
        dateTo = @"";
    }
    if (limit <= 0) {
        limit = 80;
    }
    
    char* result = bb_get_msgs_fileasync([pwdConf toChar],
                                         [contactNumber toChar],
                                         [msgIdFrom toChar],
                                         [msgIdTo toChar],
                                         [dateFrom toChar],
                                         [dateTo toChar],
                                         [groupId toChar],
                                         (int)limit);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}


/// General function to get auto delete timer of contacts and groups
/// @param contactNumber contact number
/// @param groupId group id
+ (NSString *)chatGetAutoDeleteTimer:(NSString *)contactNumber groupId:(NSString *)groupId {
    if (![self isPwdValid])
        return NULL;
    
    if (contactNumber == NULL)
        contactNumber = @"";

    if (groupId == NULL)
        groupId = @"";
    
    char* result = bb_autodelete_chat_getconf([pwdConf toChar], [contactNumber toChar], [groupId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
        
}

/// General function to set auto delete timer of contacts and groups
/// @param contactNumber contact number
/// @param groupId group id
+ (NSString *)chatSetAutoDeleteTimer:(NSString *)contactNumber groupId:(NSString *)groupId seconds:(NSInteger)seconds {
    if (![self isPwdValid])
        return NULL;
    
    if (contactNumber == NULL)
        contactNumber = @"";
    
    if (groupId == NULL)
        groupId = @"";
    
    char* result = bb_autodelete_chat([pwdConf toChar], [contactNumber toChar], [groupId toChar], (int)seconds);
    NSString* response = [self charToString:result];
    free(result);
    return response;
    
}

+ (NSString *)chatArchive:(NSString *)contactNumber groupId:(NSString *)groupId {
    if (![self isPwdValid])
        return NULL;
    if (contactNumber == NULL)
        contactNumber = @"";
    if (groupId == NULL)
        groupId = @"";
    char* result = bb_set_archivedchat([contactNumber toChar], [groupId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

+ (NSString *)chatUnarchive:(NSString *)contactNumber groupId:(NSString *)groupId {
    if (![self isPwdValid])
        return NULL;
    if (contactNumber == NULL)
        contactNumber = @"";
    if (groupId == NULL)
        groupId = @"";
    char* result = bb_unset_archivedchat([contactNumber toChar], [groupId toChar], [pwdConf toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}

+ (NSString *)chatDelete:(NSString *)contactNumber groupId:(NSString *)groupId {
    if (![self isPwdValid])
        return NULL;
    
    if (contactNumber == NULL)
        contactNumber = @"";
    
    if (groupId == NULL)
        groupId = @"";
    
    char* result = bb_delete_chat([pwdConf toChar], [contactNumber toChar], [groupId toChar]);
    NSString* response = [self charToString:result];
    free(result);
    return response;
}
@end

