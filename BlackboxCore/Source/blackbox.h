#define _GNU_SOURCE
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <math.h>
#include <time.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>
#include <dirent.h>
#include <signal.h>
#include <ctype.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <openssl/hmac.h>
#include <openssl/evp.h>
#include <openssl/ec.h>
#include <openssl/crypto.h>
#include <openssl/err.h>
#include <openssl/sha.h>
#include <openssl/pem.h>
#include <openssl/bio.h>
#include <openssl/ssl.h>
#include <openssl/conf.h>
#include <openssl/x509.h>
#include <openssl/buffer.h>
#include <openssl/x509v3.h>
#include <openssl/opensslconf.h>
#include <openssl/ecdsa.h>
//#include <libntruencrypt/ntru_crypto_drbg.h>
//#include <libntruencrypt/ntru_crypto.h>
#include <arpa/inet.h>
#include <sys/wait.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <resolv.h>
#include <opus.h>
#include <jpeglib.h>
#include <ftw.h>
/*#include <gd.h>
#include <gdfontl.h>
#include <gdfontt.h>
#include <gdfonts.h>
#include <gdfontmb.h>
#include <gdfontg.h>
*/
void bb_init(void);
void bb_init_session(int session);
uint32_t bbtotp(uint8_t *key);
uint32_t bbhotp(uint8_t *key, size_t kl, uint64_t interval, int digits);
uint8_t *bbhmac(unsigned char *key, int kl, uint64_t interval);
uint32_t bbdt(uint8_t *digest);
uint32_t bbtotpcheck(uint8_t *key,uint32_t totpc);
int bb_encrypt_file_aes_gcm(const char * infile, const char * outfile, const void * key, const void * iv,char * tag);
int bb_decrypt_file_aes_gcm(const char * infile, const char * outfile, const void * key, const void * iv,char * tag);
int bb_encrypt_file_camellia_ofb(const char * infile, const char * outfile, const void * key, const void * iv);
int bb_decrypt_file_camellia_ofb(const char * infile, const char * outfile, const void * key, const void * iv);
int bb_encrypt_file_chacha20(const char * infile, const char * outfile, const void * key, const void * iv);
int bb_decrypt_file_chacha20(const char * infile, const char * outfile, const void * key, const void * iv);
int bb_encode_base64(unsigned char * source, int sourcelen,unsigned char * destination);
int bb_decode_base64(unsigned char * source, unsigned char * destination);
int bb_sha2_256(unsigned char * source, int sourcelen,unsigned char * destination);
int bb_sha2_512(unsigned char * source, int sourcelen,unsigned char * destination);
int bb_sha3_256(unsigned char * source, int sourcelen,unsigned char * destination);
int bb_sha3_512(unsigned char * source, int sourcelen,unsigned char * destination);
int bb_crypto_random_data(char * rd);
int bb_encrypt_file(const char * infile, const char * outfile, char *key);
int bb_decrypt_file(const char * infile, const char * outfile, char *key);
int bb_json_getvalue(char * n,char *json,char *destination,int maxlen);
char * bb_json_getvalue_fromarray(char * name,char *json,int nr);
int bb_json_remove_escapes(char * v);
int bb_json_removefield(char *json,char *fieldname);
int bb_json_escapestr(char *json,char *jsonescaped,int maxlen);
char * bb_str_replace(char const * const original,char const * const pattern, char const * const replacement);

int bb_ecdhe_compute_secretkey_sender(char *peerkeypem,unsigned char *secretkey,char * ephemeralpublickey);
int bb_ecdhe_compute_secretkey_receiver(char *peerkeypem,unsigned char *secretkey,char * privatekeypem);
int bb_encrypt_buffer_aes_gcm(unsigned char * , int ,unsigned char * , int * ,const void * , const void * ,char * );
int bb_decrypt_buffer_aes_gcm(unsigned char * , int * ,unsigned char * , int ,const void * , const void * ,char * );
int bb_encrypt_buffer_camellia_ofb(unsigned char * buffer,int buffer_len,unsigned char * encrypted,int * encrypted_len,unsigned char *key,unsigned char *iv);
int bb_decrypt_buffer_camellia_ofb(unsigned char * buffer,int * buffer_len,unsigned char * encrypted,int encrypted_len,unsigned char *key,unsigned char *iv);
int bb_encrypt_buffer_aes_ofb(unsigned char * buffer,int buffer_len,unsigned char * encrypted,int * encrypted_len,unsigned char *key,unsigned char *iv);
int bb_decrypt_buffer_aes_ofb(unsigned char * buffer,int * buffer_len,unsigned char * encrypted,int encrypted_len,unsigned char *key,unsigned char *iv);
int bb_encrypt_buffer_chacha20(unsigned char * buffer,int buffer_len,unsigned char * encrypted,int * encrypted_len,unsigned char *key,unsigned char *iv);
int bb_decrypt_buffer_chacha20(unsigned char * buffer,int * buffer_len,unsigned char * encrypted,int encrypted_len,unsigned char *key,unsigned char *iv);
int bb_encrypt_buffer(unsigned char * buffer, int buffer_len,unsigned char * encrypted,int * encrypted_len, char *key);
int bb_encrypt_buffer_setkey(unsigned char * buffer, int buffer_len,unsigned char * encrypted,int * encrypted_len, char *key);
int bb_decrypt_buffer(unsigned char * buffer, int *buffer_len,unsigned char * encrypted,int encrypted_len, char *key);
int bb_symmetrickey_to_jsonkey(unsigned char * key, char *jsonkey);
int bb_encrypt_buffer_ec(unsigned char * buffer,int buffer_len,char * peerpublickeypem,char *encryptedjson);
char * bb_decrypt_buffer_ec(int *buffer_len,char * privatekeypem,char *encryptedjson);
int bb_sign_ec(unsigned char *hash,int hashlen,char * sign, int *signlen,char * privatekeypem);
int bb_verify_ec(unsigned char *hash,int hashlen,char * sign,char * publickeypem);
int bb_verify_ec_certificate(unsigned char *hash,int hashlen,char * sign,char * certificatepem);
uint32_t bb_ntru_randombytes(uint8_t *out, uint32_t num_bytes);
int bb_ntru_new_keyspair(unsigned char *publickeyb64,unsigned char *privatekeyb64);
int bb_encrypt_ntru(unsigned char *buffer,size_t buflen,unsigned char * encryptedb64,unsigned char *publickeyb64);
int bb_decrypt_ntru(unsigned char *buffer,size_t * buflen,unsigned char * encryptedb64,unsigned char *privatekeyb64);
char *bb_str_replace(const char *s, const char *strsearch,const char *strreplace) ;
void bb_hexdump(char *desc, void *addr, int len);
char bb_from_hex(char ch);
char bb_to_hex(char ch);
void bb_bin2hex(unsigned char *binary,int binlen,char * destination);
void bb_set_ca(const char* path);
char * bb_url_encode(char *str);
char * bb_url_decode(char *str);
void bb_strip_path(char * filename);
long bb_get_microtime(void);
char * bb_copy_file_to_cache(char *originfilename);
char * bb_cache_file_name(char * originfilename);
int bb_copy_file(char *originfilename,char *destinationfilename);
void bb_filetransfer_addbytes(char * filename,int bytes,int filesize);
void bb_filetransfer_broken(char * filename);
int bb_filetransfer_pending(char * filename);
void bb_filetransfer_dump(void);
void bb_filetransfer_init(void);
int bb_filetransfer_getstatus(char * filename);
void * bb_get_encryptedfile_async(void * threadargv);
char * bb_send_delete_nofification(char *recipient,char *msgid,char *pwdconf);
void bb_gen_msgref(char * msgref);
struct svtpbuffer{
    long microtime;
    unsigned int sq;
    unsigned char *dp;
    int dplen;
};
typedef struct bb_svtp{
    unsigned int sq;
    unsigned int sqseed;
    unsigned char key[64];
    unsigned char keyseed[32];
    struct sockaddr_in destination;
    int fdsocket;
    int portbinded;
    int portpunched;
    int statusvoicecall;
    int asyncrunning;
    int audioconference;
    char error[512];
    struct svtpbuffer svtpbuf[100];
    unsigned char ringbuf[97920];
    int ringbufptr;
    int ringbuflst;
    int ringbuflstmerge[10];
    pthread_t thread;
    OpusEncoder * opusencoder;
    OpusDecoder * opusdecoder;
} SVTP;
struct swtpbuffer{
    unsigned int sq;
    unsigned char datapacket[512];
};
typedef struct bb_swtp{
    unsigned int sq;
    unsigned int sqseed;
    unsigned char key[64];
    unsigned char keyseed[32];
    struct sockaddr_in destination;
    struct swtpbuffer buf[10];
    int fdsocket;
    int portbinded;
    int portpunched;
    int cnt;
    char error[512];
} SWTP;

/*// FOR ASYNC DOWNLOAD
struct FileDownloadThread{
   char pwdconf[4096];
   char uniquefilename[1024];
   char keyfile[2048];
};
// STRUCTURE FOR FILE TRANSFER PROGRESS
struct bb_files_transfer{
 time_t tm;
 char filename[256];
 long bytesfilesize;
 long bytestransfer;
} FileTransfer[99];
int FileTransferSet=0;*/
//FUNCTION FOR SVTP PROTOCOL
int bb_svtp_init(SVTP * svtp,unsigned int sq,unsigned int sqseed,unsigned char *key,char *ipdestination,unsigned short int portdestination);
int bb_svtp_send_data(SVTP *svtp,unsigned char *datapacket,unsigned short int dplen);
int bb_svtp_read_data(SVTP *svtp,unsigned char *datapacket,unsigned short int dplen);
void bb_svtp_free(SVTP * svtp);
void bb_svtp_buffer_dump(struct svtpbuffer *svtpbuf);
void bb_svtp_push_datapacket_to_buffer(struct svtpbuffer *svtpbuf,unsigned int sq,unsigned char *datapacket,int lendp);
unsigned char * bb_svtp_pull_datapacket_to_buffer(struct svtpbuffer *svtpbuf,unsigned int sq,int *buflen);
//FUNCTION FOR SWTP PROTOCL (SHIELDE VIDEO TRANSPORT PROTOCOL)
int bb_swtp_read_data(SWTP *swtp,unsigned char *datapacket);
int bb_swtp_send_data(SWTP *swtp,unsigned char *datapacket);
int bb_swtp_init(SWTP * swtp,unsigned int sq,unsigned int sqseed,unsigned char *key,char *ipdestination,unsigned short int portdestination);
void bb_swtp_free(SWTP * swtp);
#ifndef UNUSED
# define UNUSED(x) ((void)(x))
#endif
//PUBLIC FUNCTIONS
char * bb_signup_newdevice(char *mobilenumber, char *otp, char *smsotp);
char * bb_register_presence(char *pwd,char *os,char *uniqueid,char *uniqueuidvoip);
char * bb_get_registered_mobilenumber(char *pwdconf);
char * bb_send_txt_msg(char *recipient,char *bodymsg,char *pwdconf,char *repliedto,char *repliedtotxt);
char * bb_send_read_receipt(char *recipient,int msgid,char *pwdconf);
char * bb_send_location(char *recipient,char *latitude,char *longitude,char *pwdconf,char *repliedto,char *repliedtotxt);
char * bb_send_file(char *filename,char * recipient,char *bodymsg,char *pwdconf,char *repliedto,char *repliedtotxt);

char * bb_update_photo_groupchat(char *filename,char * groupid,char *pwdconf);
char * bb_update_photo_profile(char *filename,char *pwdconf);
char * bb_get_newmsg(char *pwdconf);
char * bb_get_newmsg_fileasync(char *pwdconf);
char * bb_get_newmsg_fileasync_background(char *pwdconf);
char * bb_get_msgs(char *pwdconf,char * recipient,char *msgidfrom,char *msgidto,char *dtfrom,char *dtto,char *groupid,int limit);
char * bb_get_msgs_fileasync(char *pwdconf,char * recipient,char *msgidfrom,char *msgidto,char *dtfrom,char *dtto,char * groupid,int limit);
char * bb_get_msgs_fileasync_background(char *pwdconf,char * recipient,char *msgidfrom,char *msgidto,char *dtfrom,char *dtto,char *groupid,int limit);
char * bb_set_forwardedmsg(char *msgid,char *pwdconf);
char * bb_set_starredmsg(char *msgid,char *pwdconf);
char * bb_unset_starredmsg(char *msgid,char *pwdconf);
char * bb_get_starredmsg(char *pwdconf,char *groupid,char *recipient);
char * bb_unset_archivedchat(char *recipient,char *groupchatid,char *pwdconf);
char * bb_set_archivedchat(char *recipient,char *groupchatid,char *pwdconf);
char * bb_get_list_chat(char *pwdconf);
char * bb_add_contact(char * contactjson,char *pwdconf);
char * bb_update_contact(char *contactjson,char *pwdconf);
char * bb_delete_contact(char *contactjson,char *pwdconf);
char * bb_get_contacts(char *search,int contactid,int flagsearch,int limitsearch,char *pwdconf);
char * bb_new_groupchat(char *groupdescription,char *pwdconf);
char * bb_change_groupchat(char *groupdescription,char *groupid,char *pwdconf);
char * bb_setexpiringdate_groupchat(char *expiringdate,char *groupid,char *pwdconf);
char * bb_add_member_groupchat(char *groupid,char *phonenumber,char *pwdconf);
char * bb_revoke_member_groupchat(char *groupid,char *phonenumber,char *pwdconf);
char * bb_get_list_groupchat(char *pwdconf);
char * bb_get_list_members_groupchat(char *groupid,char *pwdconf);
char * bb_delete_groupchat(char *groupid,char *pwdconf);
char * bb_change_role_member_groupchat(char *groupid,char *phonenumber,char *role,char *pwdconf);
char * bb_send_txt_msg_groupchat(char * groupid,char *bodymsg,char *pwdconf,char *repliedto,char *repliedtotxt);
char * bb_send_file_groupchat(char *originfilename,char * groupid,char *bodymsg,char *pwdconf,char *repliedto,char *repliedtotxt);
char * bb_send_location_groupchat(char * groupid,char *latitude,char *longitude,char *pwdconf,char *repliedto,char *repliedtotxt);
char * bb_update_status(char *status,char *pwdconf);
char * bb_update_profilename(char *name,char *pwdconf);
char * bb_get_profileinfo(char *recipient,char *pwdconf);
char * bb_get_photo(char *filename,char *pwdconf);
char * bb_get_photoprofile_filename(char *contactnumber,char *pwdconf);
char * bb_originate_voicecall(char *recipient,char *pwdconf);
char * bb_originate_voicecall_id(char *recipient,char *pwdconf,int session);
char * bb_originate_videocall(char *recipient,char *pwdconf);
char * bb_confirm_videocall(char *pwdconf, char * callid);
char * bb_info_voicecall(char *pwdconf);
char * bb_info_videocall(char *pwdconf);
char * bb_answer_voicecall(char *pwdconf);
char * bb_answer_videocall(char *pwdconf,char * audioonly);
char * bb_answer_voicecall_id(char *pwdconf,char *callid,int session);
char * bb_hangup_voicecall(char *pwdconf,char *callid);
char * bb_hangup_voicecall_id(char *pwdconf,char *callid,int session);
char * bb_hangup_videocall(char *pwdconf,char *callid);
char * bb_status_voicecall(char *pwdconf,char *callid);
char * bb_status_videocall(char *pwdconf,char *callid);
char * bb_status_voicecall_id(char *pwdconf,char *callid,int session);
char * bb_last_voicecalls(char *pwdconf);
char * bb_delete_voicecalls(char * pwdconf,char *callid);
char * bb_delete_message(char * pwdconf,char *msgid);
char * bb_delete_chat(char * pwdconf,char *recipient,char *groupid);
char * bb_autodelete_chat(char * pwdconf,char *recipient,char *groupid, int seconds);
char * bb_autodelete_chat_getconf(char * pwdconf,char *recipient,char *groupid);
char * bb_set_onoffline(char *pwdconf,char *status);
char * bb_set_networktype(char *pwdconf,char *networktype);
char * bb_get_online_contacts(char *pwdconf);
char * bb_autodelete_message(char * pwdconf,char *msgid,char *seconds);
char * bb_send_typing(char *recipient,char *pwdconf);
char * bb_send_typing_groupchat(char * groupid,char *pwdconf);
char * bb_send_typing_membergroupchat(char *recipient,char * groupid,char *pwdconf);
int bb_audio_send(unsigned char *audiopacket);
int bb_audio_send_session(int session,unsigned char *audiopacket);
int bb_audio_receive(unsigned char *audiopacket);
int bb_audio_receive_session(int session,unsigned char *audiopacket); //PUBLIC FUNCTION
void *bb_audio_receive_session_async(void *param); //INTERNAL FUNCTION WORKING IN A THREAD
void bb_audio_set_audioconference(int session);
void bb_audio_unset_audioconference(int session);
int bb_audio_get_audioconference(int session);
int bb_video_send(unsigned char *videopacket,unsigned short int packetlen);
char * bb_video_receive(int *packetlen);
char * bb_set_notifications(char * pwdconf,char *groupchatid,char *contactnumber,char *soundname,char *vibration,char * priority,char *popup,char *dtmute);
char * bb_get_notifications(char * pwdconf);
char * bb_set_configuration(char * pwdconf,char *calendar,char *language,char *onlinevisibility,char *autodownloadphotos,char *autodownloadaudio,char *autodownloadvideos,char *autodownloaddocuments);
char * bb_get_configuration(char * pwdconf);
int bb_encrypt_configurationkeys(char *pwdconf,char *pwd);
int bb_decrypt_configurationkeys(char *pwdconfenc,char *pwdconf,char *pwd);
int bb_encrypt_pwdconf(char *pwdconf,char *key,unsigned char *pwdconfenc,char *tmpfolder);
int bb_decrypt_pwdconf(unsigned char *pwdconfenc,int pwdconfenclen,char *key,char *pwdconf,char *tmpfolder);

char * bb_send_systemalert(char *recipient,char *groupid,char *txt,char *pwdconf);
char * bb_get_read_receipts_groupmsg(char * pwdconf,char *msgid);
void bb_keystore_userpwd(char *keyuser,unsigned char * pwdconfenc,int pwdconfenclen,char *tmpfolder);
void bb_keyget_userpwd(char *keyuser,unsigned char * pwdconfenc,int pwdconfenclen,char *tmpfolder);
int bb_check_autodownload(char *filename,char *autodownloadphotos,char * autodownloadvideos,char * autodownloadaudios,char *autodownloaddocuments);
char * bb_download_fileasync(char *pwdconf,char *msgid);

//END PUBLIC FUNCTIONS
// INTERNAL FUNCTIONS
void bb_jpeg_swaprow(unsigned char *src, unsigned char *dest);
int bb_jpeg_resize(char *inFileName, char *outFileName);
char * bb_get_encryptedfile(char *filename,char *pwdconf);
char * bb_tls_sendmsg(char *hostname,int port,char *msg, int *lenreply);
char * bb_tls_sendfile(char *hostname,int port,char *msg, int *lenreply,char *filename);
char * bb_tls_getencryptedfile(char *hostname,int port,char *msg,char *filename);
int bb_verify_callback(int preverify, X509_STORE_CTX* x509_ctx);
void bb_print_cn_name(const char* label, X509_NAME* const name);
void bb_print_san_name(const char* label, X509* const cert);
char * bb_get_cert(char *sender,char *recipient,char *token,char *pwd);
char * bb_load_configuration(char *pwdconf,char * conf);
char * bb_send_request_server(char *requestjson,char * action,char *pwdconf);
char * bb_send_txt_msg_membergroupchat(char *recipient,char *bodymsg,char * groupid,char *pwdconf,char *repliedto,char *repliedtotxt,char *msgref);
char * bb_send_file_membergroupchat(char *originfilename,char * recipient,char *bodymsg,char * groupid,char *pwdconf,char *repliedto,char *repliedtotxt,char *msgref);
char * bb_send_location_membersgroupchat(char *recipient,char *latitude,char * longitude,char *pwdconf,char *groupid,char *repliedto,char *repliedtotxt,char *msgref);
char * bb_send_photo(char *filename,char *bodymsg,char *pwdconf);
int bb_ffmpeg(char *cmd);
int bb_watermark_jpeg(char *filename);
void bb_swtp_dump_buffer(struct swtpbuffer * sb);
void bb_swtp_push_buffer(struct swtpbuffer  * sb,unsigned char *datapacket, unsigned int sq);
unsigned int bb_swtp_pull_buffer(struct swtpbuffer  * sb,unsigned char *datapacket, unsigned int sq );


// TYPEDEF FOR PUSH MESSAGES
typedef void (*PushMsgCallback)(int);
void  bb_push_messages_client(char *mobilenumber,PushMsgCallback cb);
void bb_push_messages_client_close(void);
void pushmessagecallback(int i);

int bb_securedeletefile(char * nf);
void bb_sdel_init(int secure_random);
void bb_sdel_finnish(void);
int bb_sdel_overwrite(int mode, int fd, long start, unsigned long bufsize, unsigned long length, int zero);
int bb_sdel_unlink(char *filename, int directory, int truncate, int slow);
static int bb_delete_tmp_files(const char *fpath, const struct stat *sb,int tflag, struct FTW *ftwbuf);
void bb_clean_tmp_files(void);
void bb_clean_tmp_masterpwdfile(char *tmpfolder);
void bb_wipe_all_files(void);
static int bb_securedelete_all_files(const char *fpath, const struct stat *sb,int tflag, struct FTW *ftwbuf);
void bb_set_hostname(char *hostname);
void bb_set_interlapush_hostname(char *hostname);
unsigned char * bb_decrypt_file_to_buffer(char * filename,char *key,int *buffer_len);

//#define _GNU_SOURCE   //for ANDROID

