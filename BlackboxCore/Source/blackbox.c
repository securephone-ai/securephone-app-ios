#include "blackbox.h"
/** \mainpage blackbox.c is a library of functions making the encryption/decryption processes and low level communication with the servers keeping hidden the complexity to the developers of the user interface.\n
blackbox.c is written in portable C Ansi and it can be compiled for any modern operating system.(tested on iOs/Android/Linux\n
The public API are documented with samples in the document "Api Reference".
*/
//*******************************************************************************
//************* FILE SECURE DELETE DEFINITION
//*******************************************************************************
#define BLOCKSIZE    32769           /* must be mod 3 = 0, should be >= 16k */
#define RANDOM_DEVICE    "/dev/urandom"  /* mustexist */
#define DIR_SEPERATOR    '/'             /* '/' on unix, '\' on dos/win */
#define FLUSH        sync()          /* system call to flush the disk */
#define MAXINODEWIPE    4194304         /* 22 bits */
unsigned char write_modes[27][3] = {
    {"\x55\x55\x55"}, {"\xaa\xaa\xaa"}, {"\x92\x49\x24"}, {"\x49\x24\x92"},
    {"\x24\x92\x49"}, {"\x00\x00\x00"}, {"\x11\x11\x11"}, {"\x22\x22\x22"},
    {"\x33\x33\x33"}, {"\x44\x44\x44"}, {"\x55\x55\x55"}, {"\x66\x66\x66"},
    {"\x77\x77\x77"}, {"\x88\x88\x88"}, {"\x99\x99\x99"}, {"\xaa\xaa\xaa"},
    {"\xbb\xbb\xbb"}, {"\xcc\xcc\xcc"}, {"\xdd\xdd\xdd"}, {"\xee\xee\xee"},
    {"\xff\xff\xff"}, {"\x92\x49\x24"}, {"\x49\x24\x92"}, {"\x24\x92\x49"},
    {"\x6d\xb6\xdb"}, {"\xb6\xdb\x6d"}, {"\xdb\x6d\xb6"}
};
unsigned char std_array_ff[3] = "\xff\xff\xff";
unsigned char std_array_00[3] = "\x00\x00\x00";

FILE *devrandom = NULL;
int __internal_bb_sdel_init = 0;
//*******************************************************************************
//INTERNAL GLOBAL VARIABLES
char bbhostname[128]={"95.183.55.249"};
char bbpushhostname[128]={"95.183.55.249"};
int bbport=443;
char bbtoken[256]={""};
char CaLocation[512]={"tls-ca-chain.pem"};
int verbose=1;
unsigned char KeyPush[128];
int PushServerFd=0;
int StatusVoiceCall=0; //0=INACTIVE,1=RINGING,2=ACTIVE,3=HANGUP
int StatusVideoCall=0; //0=INACTIVE,1=RINGING,2=ACTIVE,3=HANGUP
// FOR ASYNC DOWNLOAD
struct FileDownloadThread{
   char pwdconf[4096];
   char uniquefilename[1024];
   char keyfile[2048];
};
// STRUCTURE FOR FILE TRANSFER PROGRESS
struct bb_files_transfer{
 time_t tm;
 char filename[512];
 long bytesfilesize;
 long bytestransfer;
} FileTransfer[99];
int FileTransferSet=0;
// STRUCTURE FOR VOICE/VIDEO CALL ONE-TO-ONE
SVTP SvtpRead,SvtpWrite;
SWTP SwtpRead,SwtpWrite;
// STRUCTURE FOR VOICE CALL AUDIOCONFERENCE
SVTP SvtpReadAC[10],SvtpWriteAC[10];
// DOCUMENT PATH
char DocumentPath[512]={""};
//******************************************************************************
/**
* FUNCTION TO GET MESSAGES, FILTERING THEM. CONFIGURATION DATA pwdconf IS MANDATORY.
* THE FILTER MAY BE:
* recipient,msgid (from,to),datetime (from,to)
* IF THE FROM IS > OF TO WE WILL MAKE THE SEARCH ORDERE FROM UPPER TO LOWER
* LIMIT = MAX NUMBER OF RECORDS TO FETCH
* FILES ARE DOWNLOADED IN SYNC TIME (ANOTHER FUNCTION IS AVAILABLE FOR ASYNC DONWLOAD)
*/
char * bb_get_msgs(char *pwdconf,char * recipient,char *msgidfrom,char *msgidto,char *dtfrom,char *dtto,char *groupid,int limit){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char sign[8192];
    char *reply;
    char token[256];
    char error[128];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen;
    char encpkb64[8192];
    char encpk[8192];
    int z;
    char *jr=NULL;
    char *tmsgencb64=NULL;
    char *tmsgenc=NULL;
    char *tmsg=NULL;
    char *njr=NULL;
    char *newreply=NULL;
    int len_tmsgencb64;
    int len_tmsgenc;
    int len_tmsg;
    int len_njr;
    char janswer[64];
    char jmessage[256];
    char jtoken[256];
    struct stat sb;
    error[0]=0;
    int c,jrlen;
    char msgtype[256];
    int lenmsgtype=0;
    char *replydownload=NULL;
    char filenamemsg[256];
    char localfilenamemsgenc[512];
    char localfilenamemsg[512];
    char keyfile[2048];
    char keyfileb64[2048];
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char originfilename[512];
    char jsonadd[3072];
    char *replyconf;
    char repliedtotxtrecipientb64[16384];
    char repliedtotxtrecipientenc[16384];
    char * repliedtotxtrecipient=NULL;
    char * replybuf=NULL;
    int zj;
    char dtdeleted[64];
    char *jsonbuf;
    
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }

   bb_json_getvalue("mobilenumber",conf,mobilenumber,64);
   if(strlen(mobilenumber)==0){
        strcpy(error,"4000 - mobilenumber not found in the configuration\n");
        goto CLEANUP;
   }
   //END LOADING CONFIGURATION
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"4005 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "4006 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"4007 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"4009 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+strlen(recipient)+strlen(msgidfrom)+strlen(msgidto)+strlen(dtfrom)+strlen(dtto)+strlen(groupid)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%s%s%s%d%u%s",mobilenumber,recipient,msgidfrom,msgidto,dtfrom,dtto,limit,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=buflen+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getmsg\",\"mobilenumber\":\"%s\",\"recipient\":\"%s\",\"msgidfrom\":\"%s\",\"msgidto\":\"%s\",\"dtfrom\":\"%s\",\"dtto\":\"%s\",\"groupid\":\"%s\",\"limit\":\"%d\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,recipient,msgidfrom,msgidto,dtfrom,dtto,groupid,limit,bbtoken,totp,hashb64,sign);
   if(verbose) printf("getmsg: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"4010 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
    //DECRYPT ANSWER
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   janswer[0]=0;
   jmessage[0]=0;
   jtoken[0]=0;
   bb_json_getvalue("answer",reply,janswer,63);
   bb_json_getvalue("message",reply,jmessage,255);
   bb_json_getvalue("token",reply,jtoken,255);
   if(strlen(jtoken)>0) strncpy(bbtoken,jtoken,255);
   newreply=malloc(lenreply*2);
   sprintf(newreply,"{\"answer\":\"%s\",\"message\":\"%s\",\"token\":\"%s\",\"messages\":[",janswer,jmessage,jtoken);
   c=0;
   while(1){
       jr=bb_json_getvalue_fromarray("messages",reply,c);
       if(jr==NULL)
         break;
       jrlen=strlen(jr);
       //DO NOT DECRYPT "received", "read","status","typing", "deleted","status""
       bb_json_getvalue("msgtype",jr,msgtype,255);
       memset(dtdeleted,0x0,64);
       bb_json_getvalue("dtdeleted",jr,dtdeleted,63);
       if(strcmp(msgtype,"received")==0 || strcmp(msgtype,"read")==0
       || strcmp(msgtype,"status")==0 || strcmp(msgtype,"typing")==0 || strcmp(msgtype,"deleted")==0
       || (strcmp(dtdeleted,"0000-00-00 00:00:00")!=0 && strlen(dtdeleted)>0)){
            if(c>0) strcat(newreply,",");
            strcat(newreply,jr);
            c++;
            memset(jr,0x0,jrlen);
            free(jr);
            continue;
       }
       //DECRYPT MESSAGEBODY
       len_tmsgencb64=jrlen;
       tmsgencb64=malloc(len_tmsgencb64);
       bb_json_getvalue("msgbody",jr,tmsgencb64,len_tmsgencb64);
       len_tmsgenc=jrlen;
       tmsgenc=malloc(len_tmsgenc);
       len_tmsgenc=bb_decode_base64(tmsgencb64,tmsgenc);
       tmsgenc[len_tmsgenc]=0;
       tmsg=bb_decrypt_buffer_ec(&len_tmsg,encpk,tmsgenc);
       if(tmsg==NULL){
          tmsg=malloc(64);
          strcpy(tmsg,"Error decrypting content");
       }
       else
          tmsg[len_tmsg]=0;
       //JSON ESCAPE
       char *tmsgbuf=NULL;
       int len_tmsgescaped;
       tmsgbuf=malloc(len_tmsg+64);
       strncpy(tmsgbuf,tmsg,len_tmsg+63);
       free(tmsg);
       tmsg=malloc(len_tmsg*2+64);
       len_tmsgescaped=bb_json_escapestr(tmsgbuf,tmsg,len_tmsg*2+64);
       free(tmsgbuf);
       //END JSON ESCAPE
       njr=bb_str_replace(jr,tmsgencb64,tmsg);
       len_njr=strlen(njr);
       replydownload=NULL;
       newtmsg=NULL;
       newreplydecrypted=NULL;
       //DECRYPT REPLIEDTOTXT IF SET
       memset(repliedtotxtrecipientb64,0x0,16384);
       memset(repliedtotxtrecipientenc,0x0,16384);
       bb_json_getvalue("repliedtotxt",jr,repliedtotxtrecipientb64,16383);
       if(strlen(repliedtotxtrecipientb64)>1){
          zj=bb_decode_base64(repliedtotxtrecipientb64,repliedtotxtrecipientenc);
          if(zj>0) repliedtotxtrecipientenc[zj]=0;
          repliedtotxtrecipient=bb_decrypt_buffer_ec(&zj,encpk,repliedtotxtrecipientenc);
          if(repliedtotxtrecipient==NULL){
            strcpy(error,"1910b - error decrypting replytotxt");
            goto CLEANUP;
          }
          if(zj>0) repliedtotxtrecipient[zj]=0;
          jsonbuf=malloc(zj+1024);
          bb_json_escapestr(repliedtotxtrecipient,jsonbuf,zj+1024);
          replybuf=bb_str_replace(njr,repliedtotxtrecipientb64,jsonbuf);
          free(jsonbuf);
          if(repliedtotxtrecipient!=NULL){
            memset(repliedtotxtrecipient,0x0,zj);
            free(repliedtotxtrecipient);
          }
          if(replybuf!=NULL){
              strncpy(njr,replybuf,(strlen(njr)-1));
              memset(replybuf,0x0,strlen(replybuf));
              free(replybuf);
          }
      }
      memset(repliedtotxtrecipientb64,0x0,16384);
      memset(repliedtotxtrecipientenc,0x0,16384);
      // END DECRYPTING REPLIEDTOTXT
      //FILE DOWNLOAD/DECRYPT IF MSGTYPE=file
      if(strcmp(msgtype,"file")==0){
           filenamemsg[0]=0;
           bb_json_getvalue("filename",njr,filenamemsg,255);
           if(strlen(filenamemsg)==0){
                strcpy(error,"Filename not found in the message, something is wrong");
                goto CLEANUP;
           }
           bb_strip_path(filenamemsg);
           replydownload=bb_get_encryptedfile(filenamemsg,pwdconf);
           bb_json_getvalue("answer",replydownload,answer,63);
           answer[0]=0;
           if(strcmp(answer,"KO")==0){
                bb_json_getvalue("message",replydownload,error,64);
                goto CLEANUP;
    
           }
           localfilenamemsgenc[0]=0;
           bb_json_getvalue("filename",replydownload,localfilenamemsgenc,511);
           if(strlen(localfilenamemsgenc)==0){
                strcpy(error,"Local filename not found in the answer, something is wrong");
                goto CLEANUP;
           }
           if(verbose) printf("localfilenamemsgenc: %s\n",localfilenamemsgenc);
           strcpy(localfilenamemsg,localfilenamemsgenc);
           j=strlen(localfilenamemsg);
           if(localfilenamemsg[j-1]=='c' && localfilenamemsg[j-2]=='n' && localfilenamemsg[j-3]=='e' && localfilenamemsg[j-4]=='.'){
                localfilenamemsg[j-4]=0;
           }
           else{
                strcpy(error,"Encrypted filename not .enc");
                goto CLEANUP;
           }
           sp=strstr(tmsg,"#####");
           if(sp==NULL){
                  strcpy(error,"15001 - Decryption key for filename has not been found");
                  goto CLEANUP;
           }
           strncpy(keyfileb64,sp+5,2047);
           j=bb_decode_base64(keyfileb64,keyfile);
           if(j<=0){
               strcpy(error,"Error decoding keyfileb64 (1)");
               goto CLEANUP;
           }
           keyfile[j]=0;
           originfilename[0]=0;
           bb_json_getvalue("originfilename",keyfile,originfilename,511);
           bb_strip_path(originfilename);
          
           // remove for decryption only in ram
           /*if(access(localfilenamemsg,F_OK|R_OK)==-1){
               if(!bb_decrypt_file(localfilenamemsgenc,localfilenamemsg,keyfile)){
                    strcpy(error,"Error decrypting");
                    goto CLEANUP;
               }
//               if(strstr(originfilename,".jpg")!=NULL || strstr(originfilename,".jpeg")!=NULL)
//                    bb_watermark_jpeg(localfilenamemsg);
           }*/

          //REPLACE MSGBODY
           newtmsg=malloc(strlen(tmsg)+64);
           strcpy(newtmsg,tmsg);
           sp=strstr(newtmsg,"#####");
           *sp=0;
           newreplydecrypted=bb_str_replace(njr,tmsg,newtmsg);
           if(verbose) printf("newreplydecrypted: %s\n",newreplydecrypted);
           njr=realloc(njr,strlen(newreplydecrypted)+4096);
           strcpy(njr,newreplydecrypted);
           j=strlen(njr);
           njr[j-1]=0;
           sprintf(jsonadd,",\"originfilename\":\"%s\",\"localfilename\":\"%s\",\"keyfile\":\"%s\"}",originfilename,localfilenamemsgenc,keyfileb64);
           strncat(njr,jsonadd,3072);
           len_njr=strlen(njr);
           if(verbose) printf("njr: %s\n",njr);
           if(replydownload!=NULL){
              token[0]=0;
              bb_json_getvalue("token",replydownload,token,255);
              if(strlen(token)>0) strncpy(bbtoken,token,255);
           }
       }
       //END FILE DOWNLOAD/DECRYPT

       if(c>0) strcat(newreply,",");
         strcat(newreply,njr);
       if(verbose) printf("njr: %s\n",njr);
       memset(jr,0x0,jrlen);
       free(jr);
       memset(tmsgencb64,0x0,len_tmsgencb64);
       free(tmsgencb64);
       memset(tmsgenc,0x0,len_tmsgenc);
       free(tmsgenc);
       memset(tmsg,0x0,len_tmsg);
       free(tmsg);
       memset(njr,0x0,len_njr);
       free(njr);
       if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
       if(replydownload!=NULL) free(replydownload);
       if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
       if(newtmsg!=NULL) free(newtmsg);
       if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
       if(newreplydecrypted!=NULL) free(newreplydecrypted);
       if(verbose) printf("loop\n");
       c++;
   }
   strcat(newreply,"]}");
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset (reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   x=0;
   return(newreply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO GET MESSAGES, FILTERING THEM. CONFIGURATION DATA pwdconf IS MANDATORY.\n
* THE FILTER MAY BE:\n
* recipient,msgid (from,to),datetime (from,to)\n
* IF THE FROM IS > OF TO WE WILL MAKE THE SEARCH ORDERE FROM UPPER TO LOWER\n
* LIMIT = MAX NUMBER OF RECORDS TO FETCH\n
* FILES ARE DOWNLOADED IN ASSYNC TIME (ANOTHER FUNCTION IS AVAILABLE FOR ASYNC DONWLOAD)\n
*/
char * bb_get_msgs_fileasync(char *pwdconf,char * recipient,char *msgidfrom,char *msgidto,char *dtfrom,char *dtto,char *groupid,int limit){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char sign[8192];
    char *reply;
    char token[256];
    char error[128];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen;
    char encpkb64[8192];
    char encpk[8192];
    int z;
    char *jr=NULL;
    char *tmsgencb64=NULL;
    char *tmsgenc=NULL;
    char *tmsg=NULL;
    char *njr=NULL;
    char *newreply=NULL;
    int len_tmsgencb64;
    int len_tmsgenc;
    int len_tmsg;
    int len_njr;
    char janswer[64];
    char jmessage[256];
    char jtoken[256];
    struct stat sb;
    error[0]=0;
    int c,jrlen;
    char msgtype[256];
    int lenmsgtype=0;
    char *replydownload=NULL;
    char filenamemsg[256];
    char localfilenamemsgenc[512];
    char localfilenamemsg[512];
    char keyfile[2048];
    char keyfileb64[2048];
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char originfilename[512];
    char jsonadd[1024];
    char *replyconf;
    struct FileDownloadThread fdt;
    pthread_t threads;
    int rc;
    char repliedtotxtrecipientb64[16384];
    char repliedtotxtrecipientenc[16384];
    char * repliedtotxtrecipient=NULL;
    char * replybuf=NULL;
    int zj;
    char dtdeleted[64];
    char *jsonbuf;
    char autodownloadphotos[16],autodownloadvideos[16],autodownloadaudios[16],autodownloaddocuments[16],autodownload[16];
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }

   bb_json_getvalue("mobilenumber",conf,mobilenumber,64);
   if(strlen(mobilenumber)==0){
        strcpy(error,"4000 - mobilenumber not found in the configuration\n");
        goto CLEANUP;
   }
   //END LOADING CONFIGURATION
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"4005 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "4006 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"4007 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"4009 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+strlen(recipient)+strlen(msgidfrom)+strlen(msgidto)+strlen(dtfrom)+strlen(dtto)+strlen(groupid)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%s%s%s%d%u%s",mobilenumber,recipient,msgidfrom,msgidto,dtfrom,dtto,limit,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=buflen+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getmsg\",\"mobilenumber\":\"%s\",\"recipient\":\"%s\",\"msgidfrom\":\"%s\",\"msgidto\":\"%s\",\"dtfrom\":\"%s\",\"dtto\":\"%s\",\"groupid\":\"%s\",\"limit\":\"%d\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,recipient,msgidfrom,msgidto,dtfrom,dtto,groupid,limit,bbtoken,totp,hashb64,sign);
   if(verbose) printf("getmsg: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"4010 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
    //GET AUTODOWNLOAD INFO
    memset(autodownloadphotos,0x0,16);
    memset(autodownloadvideos,0x0,16);
    memset(autodownloadaudios,0x0,16);
    memset(autodownloaddocuments,0x0,16);
    memset(autodownload,0x0,16);
    bb_json_getvalue("autodownloadphotos",reply,autodownloadphotos,15);
    bb_json_getvalue("autodownloadvideos",reply,autodownloadvideos,15);
    bb_json_getvalue("autodownloadaudios",reply,autodownloadaudios,15);
    bb_json_getvalue("autodownloaddocuments",reply,autodownloaddocuments,15);
    //DECRYPT ANSWER
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   janswer[0]=0;
   jmessage[0]=0;
   jtoken[0]=0;
   bb_json_getvalue("answer",reply,janswer,63);
   bb_json_getvalue("message",reply,jmessage,255);
   bb_json_getvalue("token",reply,jtoken,255);
   if(strlen(jtoken)>0) strncpy(bbtoken,jtoken,255);
   newreply=malloc(lenreply*2);
   sprintf(newreply,"{\"answer\":\"%s\",\"message\":\"%s\",\"token\":\"%s\",\"messages\":[",janswer,jmessage,jtoken);
   c=0;
   while(1){
       jr=bb_json_getvalue_fromarray("messages",reply,c);
       if(jr==NULL)
         break;
       jrlen=strlen(jr);
       //DO NOT DECRYPT "received", "read","status","typing"
       bb_json_getvalue("msgtype",jr,msgtype,255);
       memset(dtdeleted,0x0,64);
       bb_json_getvalue("dtdeleted",jr,dtdeleted,255);
       if(strcmp(msgtype,"received")==0 || strcmp(msgtype,"read")==0
       || strcmp(msgtype,"status")==0 || strcmp(msgtype,"typing")==0 || strcmp(msgtype,"deleted")==0
       || (strcmp(dtdeleted,"0000-00-00 00:00:00")!=0 && strlen(dtdeleted)>0)){
            if(c>0) strcat(newreply,",");
            strcat(newreply,jr);
            c++;
            memset(jr,0x0,jrlen);
            free(jr);
            continue;
       }
       //DECRYPT MSGBODY
       len_tmsgencb64=jrlen;
       tmsgencb64=malloc(len_tmsgencb64);
       bb_json_getvalue("msgbody",jr,tmsgencb64,len_tmsgencb64);
       len_tmsgenc=jrlen;
       tmsgenc=malloc(len_tmsgenc);
       len_tmsgenc=bb_decode_base64(tmsgencb64,tmsgenc);
       tmsgenc[len_tmsgenc]=0;
       tmsg=bb_decrypt_buffer_ec(&len_tmsg,encpk,tmsgenc);
       if(tmsg==NULL){
          tmsg=malloc(64);
          strcpy(tmsg,"Error decrypting content");
          len_tmsg=strlen(tmsg);
       }
       else
          tmsg[len_tmsg]=0;
       //JSON ESCAPE
       char *tmsgbuf=NULL;
       int len_tmsgescaped;
       tmsgbuf=malloc(len_tmsg+64);
       strncpy(tmsgbuf,tmsg,len_tmsg+63);
       free(tmsg);
       tmsg=malloc(len_tmsg*2+64);
       len_tmsgescaped=bb_json_escapestr(tmsgbuf,tmsg,len_tmsg*2+64);
       free(tmsgbuf);
       //END JSON ESCAPE
       njr=bb_str_replace(jr,tmsgencb64,tmsg);
       len_njr=strlen(njr);
       replydownload=NULL;
       newtmsg=NULL;
       newreplydecrypted=NULL;
       //DECRYPT REPLIEDTOTXT IF SET
       memset(repliedtotxtrecipientb64,0x0,16384);
       memset(repliedtotxtrecipientenc,0x0,16384);
       bb_json_getvalue("repliedtotxt",jr,repliedtotxtrecipientb64,16383);
       if(strlen(repliedtotxtrecipientb64)>1){
          zj=bb_decode_base64(repliedtotxtrecipientb64,repliedtotxtrecipientenc);
          if(zj>0) repliedtotxtrecipientenc[zj]=0;
          repliedtotxtrecipient=bb_decrypt_buffer_ec(&zj,encpk,repliedtotxtrecipientenc);
          if(repliedtotxtrecipient==NULL){
            strcpy(error,"1910b - error decrypting replytotxt");
            goto CLEANUP;
          }
          if(zj>0) repliedtotxtrecipient[zj]=0;
          //JSON ESCAPE
          jsonbuf=malloc(zj+1024);
          bb_json_escapestr(repliedtotxtrecipient,jsonbuf,zj+1023);
          replybuf=bb_str_replace(njr,repliedtotxtrecipientb64,jsonbuf);
          free(jsonbuf);
          if(repliedtotxtrecipient!=NULL){
            memset(repliedtotxtrecipient,0x0,zj);
            free(repliedtotxtrecipient);
          }
          if(replybuf!=NULL){
              strncpy(njr,replybuf,(strlen(njr)-1));
              memset(replybuf,0x0,strlen(replybuf));
              free(replybuf);
          }
       }
       memset(repliedtotxtrecipientb64,0x0,16384);
       memset(repliedtotxtrecipientenc,0x0,16384);
       // END DECRYPTING REPLIEDTOTXT
       //FILE DOWNLOAD/DECRYPT IF MSGTYPE=file
       if(strcmp(msgtype,"file")==0){
           localfilenamemsg[0]=0;
           bb_json_getvalue("filename",njr,localfilenamemsg,255);
           if(strlen(localfilenamemsg)==0){
                strcpy(error,"Filename not found in the message, something is wrong");
                goto CLEANUP;
           }
           bb_strip_path(localfilenamemsg);
           sp=strstr(tmsg,"#####");
           if(sp==NULL){
                  strcpy(error,"15002 - Decryption key for filename has not been found");
                  goto CLEANUP;
           }
           strncpy(keyfileb64,sp+5,2047);
           j=bb_decode_base64(keyfileb64,keyfile);
           if(j<=0){
               strcpy(error,"Error decoding keyfileb64 (1)");
               goto CLEANUP;
           }
           keyfile[j]=0;
           bb_json_getvalue("originfilename",keyfile,originfilename,511);
           bb_strip_path(originfilename);
           //REPLACE MSGBODY
           newtmsg=malloc(strlen(tmsg)+64);
           strcpy(newtmsg,tmsg);
           sp=strstr(newtmsg,"#####");
           *sp=0;
           newreplydecrypted=bb_str_replace(njr,tmsg,newtmsg);
           njr=realloc(njr,strlen(newreplydecrypted)+2048);
           strcpy(njr,newreplydecrypted);
           j=strlen(njr);
           njr[j-1]=0;
           if(bb_check_autodownload(originfilename,autodownloadphotos,autodownloadvideos,autodownloadaudios,autodownloaddocuments)==1)
               strcpy(autodownload,"Y");
           else
               strcpy(autodownload,"N");
           
           sprintf(jsonadd,",\"originfilename\":\"%s\",\"localfilename\":\"%s/Documents/test/%s\",\"autodownload\":\"%s\",\"keyfile\":\"%s\"}",originfilename,getenv("HOME"),localfilenamemsg,autodownload,keyfileb64);
           strncat(njr,jsonadd,1024);
           len_njr=strlen(njr);
           if(verbose) printf("njr: %s\n",njr);
           if(bb_check_autodownload(originfilename,autodownloadphotos,autodownloadvideos,autodownloadaudios,autodownloaddocuments)==1){
               //**************************************
               //ASYNC FILE DOWNLOAD
               strncpy(fdt.pwdconf,pwdconf,4095);
               strncpy(fdt.uniquefilename,localfilenamemsg,1023);
               strncpy(fdt.keyfile,keyfile,2047);
               rc=pthread_create(&threads,NULL,bb_get_encryptedfile_async,(void *)&fdt);
               if(rc){
                   fprintf(stderr,"ERROR; return code from pthread_create() is %d\n", rc);
               }
               // END ASYNC LAUNCH
               //***************************************
           }
           if(replydownload!=NULL){
              token[0]=0;
              bb_json_getvalue("token",replydownload,token,255);
              if(strlen(token)>0) strncpy(bbtoken,token,255);
           }
       }
       //END FILE MANAGEMENT (NO DOWNLOAD TILL NOW)

       if(c>0) strcat(newreply,",");
         strcat(newreply,njr);
       memset(jr,0x0,jrlen);
       free(jr);
       memset(tmsgencb64,0x0,len_tmsgencb64);
       free(tmsgencb64);
       memset(tmsgenc,0x0,len_tmsgenc);
       free(tmsgenc);
       memset(tmsg,0x0,len_tmsg);
       free(tmsg);
       memset(njr,0x0,len_njr);
       free(njr);
       if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
       if(replydownload!=NULL) free(replydownload);
       if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
       if(newtmsg!=NULL) free(newtmsg);
       if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
       if(newreplydecrypted!=NULL) free(newreplydecrypted);
       if(verbose) printf("loop\n");
       c++;
   }
   strcat(newreply,"]}");
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset (reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   x=0;
   return(newreply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO GET MESSAGES, FILTERING THEM. CONFIGURATION DATA pwdconf IS MANDATORY.\n
* THE FILTER MAY BE:\n
* recipient,msgid (from,to),datetime (from,to)\n
* IF THE FROM IS > OF TO WE WILL MAKE THE SEARCH ORDERE FROM UPPER TO LOWER\n
* LIMIT = MAX NUMBER OF RECORDS TO FETCH\n
* FILES ARE DOWNLOAD IN SYNC TIME (ANOTHER FUNCTION IS AVAILABLE FOR ASYNC DONWLOAD)\n
* THIS VERSION DO NOT UPDATE THE LAST SEEN STATUS OF THE USER\n
*/
char * bb_get_msgs_fileasync_background(char *pwdconf,char * recipient,char *msgidfrom,char *msgidto,char *dtfrom,char *dtto,char *groupid,int limit){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char sign[8192];
    char *reply;
    char token[256];
    char error[128];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen;
    char encpkb64[8192];
    char encpk[8192];
    int z;
    char *jr=NULL;
    char *tmsgencb64=NULL;
    char *tmsgenc=NULL;
    char *tmsg=NULL;
    char *njr=NULL;
    char *newreply=NULL;
    int len_tmsgencb64;
    int len_tmsgenc;
    int len_tmsg;
    int len_njr;
    char janswer[64];
    char jmessage[256];
    char jtoken[256];
    struct stat sb;
    error[0]=0;
    int c,jrlen;
    char msgtype[256];
    int lenmsgtype=0;
    char *replydownload=NULL;
    char filenamemsg[256];
    char localfilenamemsgenc[512];
    char localfilenamemsg[512];
    char keyfile[2048];
    char keyfileb64[2048];
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char originfilename[512];
    char jsonadd[1024];
    char *replyconf;
    struct FileDownloadThread fdt;
    pthread_t threads;
    int rc;
    char repliedtotxtrecipientb64[16384];
    char repliedtotxtrecipientenc[16384];
    char * repliedtotxtrecipient=NULL;
    char * replybuf=NULL;
    int zj;
    char dtdeleted[64];
    char *jsonbuf;
    char autodownloadphotos[16],autodownloadvideos[16],autodownloadaudios[16],autodownloaddocuments[16],autodownload[16];

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }

   bb_json_getvalue("mobilenumber",conf,mobilenumber,64);
   if(strlen(mobilenumber)==0){
        strcpy(error,"4000 - mobilenumber not found in the configuration\n");
        goto CLEANUP;
   }
   //END LOADING CONFIGURATION
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"4005 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "4006 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"4007 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"4009 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+strlen(recipient)+strlen(msgidfrom)+strlen(msgidto)+strlen(dtfrom)+strlen(dtto)+strlen(groupid)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%s%s%s%d%u%s",mobilenumber,recipient,msgidfrom,msgidto,dtfrom,dtto,limit,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=buflen+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getmsg\",\"mobilenumber\":\"%s\",\"recipient\":\"%s\",\"msgidfrom\":\"%s\",\"msgidto\":\"%s\",\"dtfrom\":\"%s\",\"dtto\":\"%s\",\"groupid\":\"%s\",\"limit\":\"%d\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\",\"background\":\"1\"}",mobilenumber,recipient,msgidfrom,msgidto,dtfrom,dtto,groupid,limit,bbtoken,totp,hashb64,sign);
   if(verbose) printf("getmsg: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"4010 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
    //GET AUTODOWNLOAD INFO
    memset(autodownloadphotos,0x0,16);
    memset(autodownloadvideos,0x0,16);
    memset(autodownloadaudios,0x0,16);
    memset(autodownloaddocuments,0x0,16);
    memset(autodownload,0x0,16);
    bb_json_getvalue("autodownloadphotos",reply,autodownloadphotos,15);
    bb_json_getvalue("autodownloadvideos",reply,autodownloadvideos,15);
    bb_json_getvalue("autodownloadaudios",reply,autodownloadaudios,15);
    bb_json_getvalue("autodownloaddocuments",reply,autodownloaddocuments,15);
    //DECRYPT ANSWER
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   janswer[0]=0;
   jmessage[0]=0;
   jtoken[0]=0;
   bb_json_getvalue("answer",reply,janswer,63);
   bb_json_getvalue("message",reply,jmessage,255);
   bb_json_getvalue("token",reply,jtoken,255);
   if(strlen(jtoken)>0) strncpy(bbtoken,jtoken,255);
   newreply=malloc(lenreply*2);
   sprintf(newreply,"{\"answer\":\"%s\",\"message\":\"%s\",\"token\":\"%s\",\"messages\":[",janswer,jmessage,jtoken);
   c=0;
   while(1){
       jr=bb_json_getvalue_fromarray("messages",reply,c);
       if(jr==NULL)
         break;
       jrlen=strlen(jr);
       //DO NOT DECRYPT "received", "read","status","typing"
       bb_json_getvalue("msgtype",jr,msgtype,255);
       memset(dtdeleted,0x0,64);
       bb_json_getvalue("dtdeleted",jr,dtdeleted,255);
       if(strcmp(msgtype,"received")==0 || strcmp(msgtype,"read")==0
       || strcmp(msgtype,"status")==0 || strcmp(msgtype,"typing")==0 || strcmp(msgtype,"deleted")==0
       || (strcmp(dtdeleted,"0000-00-00 00:00:00")!=0 && strlen(dtdeleted)>0)){
            if(c>0) strcat(newreply,",");
            strcat(newreply,jr);
            c++;
            memset(jr,0x0,jrlen);
            free(jr);
            continue;
       }
       //DECRYPT MSGBODY
       len_tmsgencb64=jrlen;
       tmsgencb64=malloc(len_tmsgencb64);
       bb_json_getvalue("msgbody",jr,tmsgencb64,len_tmsgencb64);
       len_tmsgenc=jrlen;
       tmsgenc=malloc(len_tmsgenc);
       len_tmsgenc=bb_decode_base64(tmsgencb64,tmsgenc);
       tmsgenc[len_tmsgenc]=0;
       tmsg=bb_decrypt_buffer_ec(&len_tmsg,encpk,tmsgenc);
       if(tmsg==NULL){
          tmsg=malloc(64);
          strcpy(tmsg,"Error decrypting content");
          len_tmsg=strlen(tmsg);
       }
       else
          tmsg[len_tmsg]=0;
       //JSON ESCAPE
       char *tmsgbuf=NULL;
       int len_tmsgescaped;
       tmsgbuf=malloc(len_tmsg+64);
       strncpy(tmsgbuf,tmsg,len_tmsg+63);
       free(tmsg);
       tmsg=malloc(len_tmsg*2+64);
       len_tmsgescaped=bb_json_escapestr(tmsgbuf,tmsg,len_tmsg*2+64);
       free(tmsgbuf);
       //END JSON ESCAPE
       njr=bb_str_replace(jr,tmsgencb64,tmsg);
       len_njr=strlen(njr);
       replydownload=NULL;
       newtmsg=NULL;
       newreplydecrypted=NULL;
       //DECRYPT REPLIEDTOTXT IF SET
       memset(repliedtotxtrecipientb64,0x0,16384);
       memset(repliedtotxtrecipientenc,0x0,16384);
       bb_json_getvalue("repliedtotxt",jr,repliedtotxtrecipientb64,16383);
       if(strlen(repliedtotxtrecipientb64)>0){
          zj=bb_decode_base64(repliedtotxtrecipientb64,repliedtotxtrecipientenc);
          if(zj>0) repliedtotxtrecipientenc[zj]=0;
          repliedtotxtrecipient=bb_decrypt_buffer_ec(&zj,encpk,repliedtotxtrecipientenc);
          if(repliedtotxtrecipient==NULL){
            strcpy(error,"1910b - error decrypting replytotxt");
            goto CLEANUP;
          }
          if(zj>0) repliedtotxtrecipient[zj]=0;
          jsonbuf=malloc(zj+1024);
          bb_json_escapestr(repliedtotxtrecipient,jsonbuf,zj+1023);
          replybuf=bb_str_replace(njr,repliedtotxtrecipientb64,jsonbuf);
          free(jsonbuf);
          if(repliedtotxtrecipient!=NULL){
            memset(repliedtotxtrecipient,0x0,zj);
            free(repliedtotxtrecipient);
          }
          if(replybuf!=NULL){
              strncpy(njr,replybuf,(strlen(njr)-1));
              memset(replybuf,0x0,strlen(replybuf));
              free(replybuf);
          }
       }
       memset(repliedtotxtrecipientb64,0x0,16384);
       memset(repliedtotxtrecipientenc,0x0,16384);
       // END DECRYPTING REPLIEDTOTXT
       //FILE DOWNLOAD/DECRYPT IF MSGTYPE=file
       if(strcmp(msgtype,"file")==0){
           localfilenamemsg[0]=0;
           bb_json_getvalue("filename",njr,localfilenamemsg,255);
           if(strlen(localfilenamemsg)==0){
                strcpy(error,"Filename not found in the message, something is wrong");
                goto CLEANUP;
           }
           bb_strip_path(localfilenamemsg);
           sp=strstr(tmsg,"#####");
           if(sp==NULL){
                  strcpy(error,"15002 - Decryption key for filename has not been found");
                  goto CLEANUP;
           }
           strncpy(keyfileb64,sp+5,2047);
           j=bb_decode_base64(keyfileb64,keyfile);
           if(j<=0){
               strcpy(error,"Error decoding keyfileb64 (1)");
               goto CLEANUP;
           }
           keyfile[j]=0;
           bb_json_getvalue("originfilename",keyfile,originfilename,511);
           bb_strip_path(originfilename);
           //REPLACE MSGBODY
           newtmsg=malloc(strlen(tmsg)+64);
           strcpy(newtmsg,tmsg);
           sp=strstr(newtmsg,"#####");
           *sp=0;
           newreplydecrypted=bb_str_replace(njr,tmsg,newtmsg);
           njr=realloc(njr,strlen(newreplydecrypted)+2048);
           strcpy(njr,newreplydecrypted);
           j=strlen(njr);
           njr[j-1]=0;
           if(bb_check_autodownload(originfilename,autodownloadphotos,autodownloadvideos,autodownloadaudios,autodownloaddocuments)==1)
               strcpy(autodownload,"Y");
           else
               strcpy(autodownload,"N");
           sprintf(jsonadd,",\"originfilename\":\"%s\",\"localfilename\":\"%s/Documents/test/%s\",\"autodownload\":\"%s\",\"keyfile\":\"%s\"}",originfilename,getenv("HOME"),localfilenamemsg,autodownload,keyfileb64);
           strncat(njr,jsonadd,1024);
           len_njr=strlen(njr);
           if(verbose) printf("njr: %s\n",njr);
           if(bb_check_autodownload(originfilename,autodownloadphotos,autodownloadvideos,autodownloadaudios,autodownloaddocuments)==1){
               //ASYNC FILE DOWNLOAD
               strncpy(fdt.pwdconf,pwdconf,4095);
               strncpy(fdt.uniquefilename,localfilenamemsg,1023);
               strncpy(fdt.keyfile,keyfile,2047);
               rc=pthread_create(&threads,NULL,bb_get_encryptedfile_async,(void *)&fdt);
               if(rc){
                   fprintf(stderr,"ERROR; return code from pthread_create() is %d\n", rc);
               }
               // END ASYNC LAUNCH
           }
           if(replydownload!=NULL){
              token[0]=0;
              bb_json_getvalue("token",replydownload,token,255);
              if(strlen(token)>0) strncpy(bbtoken,token,255);
           }
       }
       //END FILE MANAGEMENT (NO DOWNLOAD TILL NOW

       if(c>0) strcat(newreply,",");
         strcat(newreply,njr);
       memset(jr,0x0,jrlen);
       free(jr);
       memset(tmsgencb64,0x0,len_tmsgencb64);
       free(tmsgencb64);
       memset(tmsgenc,0x0,len_tmsgenc);
       free(tmsgenc);
       memset(tmsg,0x0,len_tmsg);
       free(tmsg);
       memset(njr,0x0,len_njr);
       free(njr);
       if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
       if(replydownload!=NULL) free(replydownload);
       if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
       if(newtmsg!=NULL) free(newtmsg);
       if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
       if(newreplydecrypted!=NULL) free(newreplydecrypted);
       if(verbose) printf("loop\n");
       c++;
   }
   strcat(newreply,"]}");
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset (reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   x=0;
   return(newreply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO DOWNLOAD A FILE WITHOUT CONSIDERING AUTODOWNLOAD SETTINGS\n
* TO BE USED WHEN THE USER DECIDE IN ANY CASE TO DOWNLOAD THE FILE\n
*/
char * bb_download_fileasync(char *pwdconf,char *msgid){
    char recipient[16];
    char msgidfrom[64];
    char msgidto[64];
    char dtfrom[64];
    char dtto[64];
    char groupid[64];
    int limit=1;
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char sign[8192];
    char *reply;
    char token[256];
    char error[128];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen;
    char encpkb64[8192];
    char encpk[8192];
    int z;
    char *jr=NULL;
    char *tmsgencb64=NULL;
    char *tmsgenc=NULL;
    char *tmsg=NULL;
    char *njr=NULL;
    char *newreply=NULL;
    int len_tmsgencb64;
    int len_tmsgenc;
    int len_tmsg;
    int len_njr;
    char janswer[64];
    char jmessage[256];
    char jtoken[256];
    struct stat sb;
    error[0]=0;
    int c,jrlen;
    char msgtype[256];
    int lenmsgtype=0;
    char *replydownload=NULL;
    char filenamemsg[256];
    char localfilenamemsgenc[512];
    char localfilenamemsg[512];
    char keyfile[2048];
    char keyfileb64[2048];
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char originfilename[512];
    char jsonadd[1024];
    char *replyconf;
    struct FileDownloadThread fdt;
    pthread_t threads;
    int rc;
    char repliedtotxtrecipientb64[16384];
    char repliedtotxtrecipientenc[16384];
    char * repliedtotxtrecipient=NULL;
    char * replybuf=NULL;
    int zj;
    char dtdeleted[64];
    char *jsonbuf;
    recipient[0]=0;
    strncpy(msgidfrom,msgid,64);
    strncpy(msgidto,msgid,64);
    dtfrom[0]=0;
    dtto[0]=0;
    groupid[0]=0;
    limit=1;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }

   bb_json_getvalue("mobilenumber",conf,mobilenumber,64);
   if(strlen(mobilenumber)==0){
        strcpy(error,"4000 - mobilenumber not found in the configuration\n");
        goto CLEANUP;
   }
   //END LOADING CONFIGURATION
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"4005 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "4006 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"4007 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"4009 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+strlen(recipient)+strlen(msgidfrom)+strlen(msgidto)+strlen(dtfrom)+strlen(dtto)+strlen(groupid)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%s%s%s%d%u%s",mobilenumber,recipient,msgidfrom,msgidto,dtfrom,dtto,limit,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=buflen+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getmsg\",\"mobilenumber\":\"%s\",\"recipient\":\"%s\",\"msgidfrom\":\"%s\",\"msgidto\":\"%s\",\"dtfrom\":\"%s\",\"dtto\":\"%s\",\"groupid\":\"%s\",\"limit\":\"%d\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,recipient,msgidfrom,msgidto,dtfrom,dtto,groupid,limit,bbtoken,totp,hashb64,sign);
   if(verbose) printf("getmsg: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"4010 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
    //DECRYPT ANSWER
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   janswer[0]=0;
   jmessage[0]=0;
   jtoken[0]=0;
   bb_json_getvalue("answer",reply,janswer,63);
   bb_json_getvalue("message",reply,jmessage,255);
   bb_json_getvalue("token",reply,jtoken,255);
   if(strlen(jtoken)>0) strncpy(bbtoken,jtoken,255);
   newreply=malloc(lenreply*2);
   sprintf(newreply,"{\"answer\":\"%s\",\"message\":\"%s\",\"token\":\"%s\",\"messages\":[",janswer,jmessage,jtoken);
   c=0;
   while(1){
       jr=bb_json_getvalue_fromarray("messages",reply,c);
       if(jr==NULL)
         break;
       jrlen=strlen(jr);
       //DO NOT DECRYPT "received", "read","status","typing"
       bb_json_getvalue("msgtype",jr,msgtype,255);
       memset(dtdeleted,0x0,64);
       bb_json_getvalue("dtdeleted",jr,dtdeleted,255);
       if(strcmp(msgtype,"received")==0 || strcmp(msgtype,"read")==0
       || strcmp(msgtype,"status")==0 || strcmp(msgtype,"typing")==0 || strcmp(msgtype,"deleted")==0
       || (strcmp(dtdeleted,"0000-00-00 00:00:00")!=0 && strlen(dtdeleted)>0)){
            if(c>0) strcat(newreply,",");
            strcat(newreply,jr);
            c++;
            memset(jr,0x0,jrlen);
            free(jr);
            continue;
       }
       //DECRYPT MSGBODY
       len_tmsgencb64=jrlen;
       tmsgencb64=malloc(len_tmsgencb64);
       bb_json_getvalue("msgbody",jr,tmsgencb64,len_tmsgencb64);
       len_tmsgenc=jrlen;
       tmsgenc=malloc(len_tmsgenc);
       len_tmsgenc=bb_decode_base64(tmsgencb64,tmsgenc);
       tmsgenc[len_tmsgenc]=0;
       tmsg=bb_decrypt_buffer_ec(&len_tmsg,encpk,tmsgenc);
       if(tmsg==NULL){
          tmsg=malloc(64);
          strcpy(tmsg,"Error decrypting content");
          len_tmsg=strlen(tmsg);
       }
       else
          tmsg[len_tmsg]=0;
       //JSON ESCAPE
       char *tmsgbuf=NULL;
       int len_tmsgescaped;
       tmsgbuf=malloc(len_tmsg+64);
       strncpy(tmsgbuf,tmsg,len_tmsg+63);
       free(tmsg);
       tmsg=malloc(len_tmsg*2+64);
       len_tmsgescaped=bb_json_escapestr(tmsgbuf,tmsg,len_tmsg*2+64);
       free(tmsgbuf);
       //END JSON ESCAPE
       njr=bb_str_replace(jr,tmsgencb64,tmsg);
       len_njr=strlen(njr);
       replydownload=NULL;
       newtmsg=NULL;
       newreplydecrypted=NULL;
       //DECRYPT REPLIEDTOTXT IF SET
       memset(repliedtotxtrecipientb64,0x0,16384);
       memset(repliedtotxtrecipientenc,0x0,16384);
       bb_json_getvalue("repliedtotxt",jr,repliedtotxtrecipientb64,16383);
       if(strlen(repliedtotxtrecipientb64)>1){
          zj=bb_decode_base64(repliedtotxtrecipientb64,repliedtotxtrecipientenc);
          if(zj>0) repliedtotxtrecipientenc[zj]=0;
          repliedtotxtrecipient=bb_decrypt_buffer_ec(&zj,encpk,repliedtotxtrecipientenc);
          if(repliedtotxtrecipient==NULL){
            strcpy(error,"1910b - error decrypting replytotxt");
            goto CLEANUP;
          }
          if(zj>0) repliedtotxtrecipient[zj]=0;
          //JSON ESCAPE
          jsonbuf=malloc(zj+1024);
          bb_json_escapestr(repliedtotxtrecipient,jsonbuf,zj+1023);
          replybuf=bb_str_replace(njr,repliedtotxtrecipientb64,jsonbuf);
          free(jsonbuf);
          if(repliedtotxtrecipient!=NULL){
            memset(repliedtotxtrecipient,0x0,zj);
            free(repliedtotxtrecipient);
          }
          if(replybuf!=NULL){
              strncpy(njr,replybuf,(strlen(njr)-1));
              memset(replybuf,0x0,strlen(replybuf));
              free(replybuf);
          }
       }
       memset(repliedtotxtrecipientb64,0x0,16384);
       memset(repliedtotxtrecipientenc,0x0,16384);
       // END DECRYPTING REPLIEDTOTXT
       //FILE DOWNLOAD/DECRYPT IF MSGTYPE=file
       if(strcmp(msgtype,"file")==0){
           localfilenamemsg[0]=0;
           bb_json_getvalue("filename",njr,localfilenamemsg,255);
           if(strlen(localfilenamemsg)==0){
                strcpy(error,"Filename not found in the message, something is wrong");
                goto CLEANUP;
           }
           bb_strip_path(localfilenamemsg);
           sp=strstr(tmsg,"#####");
           if(sp==NULL){
                  strcpy(error,"15002 - Decryption key for filename has not been found");
                  goto CLEANUP;
           }
           strncpy(keyfileb64,sp+5,2047);
           j=bb_decode_base64(keyfileb64,keyfile);
           if(j<=0){
               strcpy(error,"Error decoding keyfileb64 (1)");
               goto CLEANUP;
           }
           keyfile[j]=0;
           bb_json_getvalue("originfilename",keyfile,originfilename,511);
           bb_strip_path(originfilename);
           //REPLACE MSGBODY
           newtmsg=malloc(strlen(tmsg)+64);
           strcpy(newtmsg,tmsg);
           sp=strstr(newtmsg,"#####");
           *sp=0;
           newreplydecrypted=bb_str_replace(njr,tmsg,newtmsg);
           njr=realloc(njr,strlen(newreplydecrypted)+2048);
           strcpy(njr,newreplydecrypted);
           j=strlen(njr);
           njr[j-1]=0;
           sprintf(jsonadd,",\"originfilename\":\"%s\",\"localfilename\":\"%s/Documents/test/%s\",\"keyfile\":\"%s\"}",originfilename,getenv("HOME"),localfilenamemsg, keyfileb64);
           strncat(njr,jsonadd,1024);
           len_njr=strlen(njr);
           if(verbose) printf("njr: %s\n",njr);
           //**************************************
           //ASYNC FILE DOWNLOAD
           strncpy(fdt.pwdconf,pwdconf,4095);
           strncpy(fdt.uniquefilename,localfilenamemsg,1023);
           strncpy(fdt.keyfile,keyfile,2047);
           rc=pthread_create(&threads,NULL,bb_get_encryptedfile_async,(void *)&fdt);
           if(rc){
              fprintf(stderr,"ERROR; return code from pthread_create() is %d\n", rc);
           }
           // END ASYNC LAUNCH
           //***************************************
           if(replydownload!=NULL){
              token[0]=0;
              bb_json_getvalue("token",replydownload,token,255);
              if(strlen(token)>0) strncpy(bbtoken,token,255);
           }
       }
       //END FILE MANAGEMENT (NO DOWNLOAD TILL NOW)

       if(c>0) strcat(newreply,",");
         strcat(newreply,njr);
       memset(jr,0x0,jrlen);
       free(jr);
       memset(tmsgencb64,0x0,len_tmsgencb64);
       free(tmsgencb64);
       memset(tmsgenc,0x0,len_tmsgenc);
       free(tmsgenc);
       memset(tmsg,0x0,len_tmsg);
       free(tmsg);
       memset(njr,0x0,len_njr);
       free(njr);
       if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
       if(replydownload!=NULL) free(replydownload);
       if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
       if(newtmsg!=NULL) free(newtmsg);
       if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
       if(newreplydecrypted!=NULL) free(newreplydecrypted);
       if(verbose) printf("loop\n");
       c++;
   }
   strcat(newreply,"]}");
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset (reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   x=0;
   return(newreply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO GET STARRED MESSAGES
* GROUPID OR RECIPIENT CAN BE USED TO FILTER THE MESSAGES
*/
char * bb_get_starredmsg(char *pwdconf,char* groupid,char *recipient){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char sign[8192];
    char *reply;
    char token[256];
    char error[128];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen;
    char encpkb64[8192];
    char encpk[8192];
    int z;
    char *jr=NULL;
    char *tmsgencb64=NULL;
    char *tmsgenc=NULL;
    char *tmsg=NULL;
    char *njr=NULL;
    char *newreply=NULL;
    int len_tmsgencb64;
    int len_tmsgenc;
    int len_tmsg;
    int len_njr;
    char janswer[64];
    char jmessage[256];
    char jtoken[256];
    struct stat sb;
    error[0]=0;
    int c,jrlen;
    char msgtype[256];
    int lenmsgtype=0;
    char *replydownload=NULL;
    char filenamemsg[256];
    char localfilenamemsgenc[512];
    char localfilenamemsg[512];
    char keyfile[2048];
    char keyfileb64[2048];
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char originfilename[512];
    char jsonadd[1024];
    char *replyconf;
    struct FileDownloadThread fdt;
    pthread_t threads;
    int rc;
    char repliedtotxtrecipientb64[16384];
    char repliedtotxtrecipientenc[16384];
    char * repliedtotxtrecipient=NULL;
    char * replybuf=NULL;
    int zj;
    char dtdeleted[64];
    char *jsonbuf;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }

   bb_json_getvalue("mobilenumber",conf,mobilenumber,64);
   if(strlen(mobilenumber)==0){
        strcpy(error,"4000 - mobilenumber not found in the configuration\n");
        goto CLEANUP;
   }
   //END LOADING CONFIGURATION
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"4005 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "4006 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"4007 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"4009 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"getstarredmsg%s",mobilenumber);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=buflen+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getstarredmsg\",\"mobilenumber\":\"%s\",\"groupid\":\"%s\",\"recipient\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,groupid, recipient,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"4010 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
    //DECRYPT ANSWER
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   janswer[0]=0;
   jmessage[0]=0;
   jtoken[0]=0;
   bb_json_getvalue("answer",reply,janswer,63);
   bb_json_getvalue("message",reply,jmessage,255);
   bb_json_getvalue("token",reply,jtoken,255);
   if(strlen(jtoken)>0) strncpy(bbtoken,jtoken,255);
   newreply=malloc(lenreply*2);
   sprintf(newreply,"{\"answer\":\"%s\",\"message\":\"%s\",\"token\":\"%s\",\"messages\":[",janswer,jmessage,jtoken);
   c=0;
   while(1){
       jr=bb_json_getvalue_fromarray("messages",reply,c);
       if(jr==NULL)
         break;
       jrlen=strlen(jr);
       //DO NOT DECRYPT "received", "read","status","typing"
       bb_json_getvalue("msgtype",jr,msgtype,255);
       memset(dtdeleted,0x0,64);
       bb_json_getvalue("dtdeleted",jr,dtdeleted,255);
       if(strcmp(msgtype,"received")==0 || strcmp(msgtype,"read")==0
       || strcmp(msgtype,"status")==0 || strcmp(msgtype,"typing")==0 || strcmp(msgtype,"deleted")==0
       || (strcmp(dtdeleted,"0000-00-00 00:00:00")!=0 && strlen(dtdeleted)>0)){
            if(c>0) strcat(newreply,",");
            strcat(newreply,jr);
            c++;
            memset(jr,0x0,jrlen);
            free(jr);
            continue;
       }
       //DECRYPT MSGBODY
       len_tmsgencb64=jrlen;
       tmsgencb64=malloc(len_tmsgencb64);
       bb_json_getvalue("msgbody",jr,tmsgencb64,len_tmsgencb64);
       len_tmsgenc=jrlen;
       tmsgenc=malloc(len_tmsgenc);
       len_tmsgenc=bb_decode_base64(tmsgencb64,tmsgenc);
       tmsgenc[len_tmsgenc]=0;
       tmsg=bb_decrypt_buffer_ec(&len_tmsg,encpk,tmsgenc);
       if(tmsg==NULL){
          tmsg=malloc(64);
          strcpy(tmsg,"Error decrypting content");
          len_tmsg=strlen(tmsg);
       }
       else
          tmsg[len_tmsg]=0;
       //JSON ESCAPE
       char *tmsgbuf=NULL;
       int len_tmsgescaped;
       tmsgbuf=malloc(len_tmsg+64);
       strncpy(tmsgbuf,tmsg,len_tmsg+63);
       free(tmsg);
       tmsg=malloc(len_tmsg*2+64);
       len_tmsgescaped=bb_json_escapestr(tmsgbuf,tmsg,len_tmsg*2+64);
       free(tmsgbuf);
       //END JSON ESCAPE
       njr=bb_str_replace(jr,tmsgencb64,tmsg);
       len_njr=strlen(njr);
       replydownload=NULL;
       newtmsg=NULL;
       newreplydecrypted=NULL;
       //DECRYPT REPLIEDTOTXT IF SET
       memset(repliedtotxtrecipientb64,0x0,16384);
       memset(repliedtotxtrecipientenc,0x0,16384);
       bb_json_getvalue("repliedtotxt",jr,repliedtotxtrecipientb64,16383);
       if(strlen(repliedtotxtrecipientb64)>0){
          zj=bb_decode_base64(repliedtotxtrecipientb64,repliedtotxtrecipientenc);
          if(zj>0) repliedtotxtrecipientenc[zj]=0;
          repliedtotxtrecipient=bb_decrypt_buffer_ec(&zj,encpk,repliedtotxtrecipientenc);
          if(repliedtotxtrecipient==NULL){
            strcpy(error,"1910b - error decrypting replytotxt");
            goto CLEANUP;
          }
          if(zj>0) repliedtotxtrecipient[zj]=0;
          jsonbuf=malloc(zj+1023);
          bb_json_escapestr(repliedtotxtrecipient,jsonbuf,zj+1023);
          replybuf=bb_str_replace(njr,repliedtotxtrecipientb64,jsonbuf);
          free(jsonbuf);
          if(repliedtotxtrecipient!=NULL){
            memset(repliedtotxtrecipient,0x0,zj);
            free(repliedtotxtrecipient);
          }
          if(replybuf!=NULL){
              strncpy(njr,replybuf,(strlen(njr)-1));
              memset(replybuf,0x0,strlen(replybuf));
              free(replybuf);
          }
       }
       memset(repliedtotxtrecipientb64,0x0,16384);
       memset(repliedtotxtrecipientenc,0x0,16384);
       // END DECRYPTING REPLIEDTOTXT
       //FILE DOWNLOAD/DECRYPT IF MSGTYPE=file
       if(strcmp(msgtype,"file")==0){
           localfilenamemsg[0]=0;
           bb_json_getvalue("filename",njr,localfilenamemsg,255);
           if(strlen(localfilenamemsg)==0){
                strcpy(error,"Filename not found in the message, something is wrong");
                goto CLEANUP;
           }
           bb_strip_path(localfilenamemsg);
           sp=strstr(tmsg,"#####");
           if(sp==NULL){
                  strcpy(error,"15002 - Decryption key for filename has not been found");
                  goto CLEANUP;
           }
           strncpy(keyfileb64,sp+5,2047);
           j=bb_decode_base64(keyfileb64,keyfile);
           if(j<=0){
               strcpy(error,"Error decoding keyfileb64 (1)");
               goto CLEANUP;
           }
           keyfile[j]=0;
           //ASYNC FILE DOWNLOAD
           strncpy(fdt.pwdconf,pwdconf,4095);
           strncpy(fdt.uniquefilename,localfilenamemsg,1023);
           strncpy(fdt.keyfile,keyfile,2047);
           rc=pthread_create(&threads,NULL,bb_get_encryptedfile_async,(void *)&fdt);
           if(rc){
                  fprintf(stderr,"ERROR; return code from pthread_create() is %d\n", rc);
           }
           // END ASYNC LAUNCH
           sp=strstr(tmsg,"#####");
           if(sp==NULL){
                  strcpy(error,"15003 - Decryption key for filename has not been found");
                  goto CLEANUP;
           }
           strncpy(keyfileb64,sp+5,2047);
           j=bb_decode_base64(keyfileb64,keyfile);
           if(j<=0){
               strcpy(error,"Error decoding keyfileb64 (1)");
               goto CLEANUP;
           }
           keyfile[j]=0;
           bb_json_getvalue("originfilename",keyfile,originfilename,511);
           bb_strip_path(originfilename);
           //REPLACE MSGBODY
           newtmsg=malloc(strlen(tmsg)+64);
           strcpy(newtmsg,tmsg);
           sp=strstr(newtmsg,"#####");
           *sp=0;
           newreplydecrypted=bb_str_replace(njr,tmsg,newtmsg);
           njr=realloc(njr,strlen(newreplydecrypted)+2048);
           strcpy(njr,newreplydecrypted);
           j=strlen(njr);
           njr[j-1]=0;
           sprintf(jsonadd,",\"originfilename\":\"%s\",\"localfilename\":\"%s/Documents/test/%s\",\"keyfile\":\"%s\"}",originfilename,getenv("HOME"),localfilenamemsg, keyfileb64);
           strncat(njr,jsonadd,1024);
           len_njr=strlen(njr);
           if(verbose) printf("njr: %s\n",njr);
           if(replydownload!=NULL){
              token[0]=0;
              bb_json_getvalue("token",replydownload,token,255);
              if(strlen(token)>0) strncpy(bbtoken,token,255);
           }
       }
       //END FILE MANAGEMENT (NO DOWNLOAD TILL NOW

       if(c>0) strcat(newreply,",");
         strcat(newreply,njr);
       memset(jr,0x0,jrlen);
       free(jr);
       memset(tmsgencb64,0x0,len_tmsgencb64);
       free(tmsgencb64);
       memset(tmsgenc,0x0,len_tmsgenc);
       free(tmsgenc);
       memset(tmsg,0x0,len_tmsg);
       free(tmsg);
       memset(njr,0x0,len_njr);
       free(njr);
       if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
       if(replydownload!=NULL) free(replydownload);
       if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
       if(newtmsg!=NULL) free(newtmsg);
       if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
       if(newreplydecrypted!=NULL) free(newreplydecrypted);
       if(verbose) printf("loop\n");
       c++;
   }
   strcat(newreply,"]}");
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset (reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   x=0;
   return(newreply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO RECEIVE A NEW MESSAGE
*/
char * bb_get_newmsg(char *pwdconf){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char *replydownload=NULL;
    char filenamemsg[256];
    char localfilenamemsgenc[512];
    char localfilenamemsg[512];
    char keyfile[2048];
    char keyfileb64[2048];
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char originfilename[512];
    // increased space for adding keyfile field
    char jsonadd[3072];
    char *replyconf;
    char repliedtotxtrecipientb64[16384];
    char repliedtotxtrecipientenc[16384];
    char * repliedtotxtrecipient=NULL;
    char * replybuf=NULL;
    int zj,i;
    char dtdeleted[64];
    char *jsonbuf;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getnewmsg\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   memset(dtdeleted,0x0,64);
   bb_json_getvalue("dtdeleted",reply,dtdeleted,63);
   bb_json_getvalue("msgtype",reply,msgtype,255);
   if(strcmp(msgtype,"read")==0 || strcmp(msgtype,"received")==0
   || strcmp(msgtype,"status")==0 || strcmp(msgtype,"typing")==0  || strcmp(msgtype,"deleted")==0
   || (strcmp(dtdeleted,"0000-00-00 00:00:00")!=0 && strlen(dtdeleted)>0)){
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }else{
      //DECRYPT ANSWER
      //printf("lenreply: %d\n",lenreply);
      lenalltmsg=lenreply+8192;
      tmsgenc=malloc(lenalltmsg);
      tmsgencb64=malloc(lenalltmsg);
      //tmsg=malloc(lenalltmsg);
      bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
      z=bb_decode_base64(encpkb64,encpk);
      encpk[z]=0;
      bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
      z=bb_decode_base64(tmsgencb64,tmsgenc);
      tmsgenc[z]=0;
      lentmsg=0;
      tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
      if(tmsg==NULL){
          tmsg=malloc(64);
          strcpy(tmsg,"Error decrypting content");
          lentmsg=strlen(tmsg);
       }
       else
          tmsg[lentmsg]=0;
      //printf("lentmsg: %d lenalltmsg %d\n",lentmsg,lenalltmsg);
      //printf("tmsg %s\n",tmsg);
      if(lentmsg>0)
         tmsg[lentmsg]=0;
      //JSON ESCAPE
      char *tmsgbuf=NULL;
      int len_tmsgescaped;
      tmsgbuf=malloc(lentmsg+64);
      strncpy(tmsgbuf,tmsg,lentmsg+63);
      free(tmsg);
      tmsg=malloc(lentmsg*2+64);
      len_tmsgescaped=bb_json_escapestr(tmsgbuf,tmsg,lentmsg*2+64);
      free(tmsgbuf);
      //END JSON ESCAPE
      //DECRYPT REPLIEDTOTXT IF SET
      memset(repliedtotxtrecipientb64,0x0,16384);
      memset(repliedtotxtrecipientenc,0x0,16384);
      bb_json_getvalue("repliedtotxt",reply,repliedtotxtrecipientb64,16383);
      if(strlen(repliedtotxtrecipientb64)>0){
          zj=bb_decode_base64(repliedtotxtrecipientb64,repliedtotxtrecipientenc);
          if(zj>0) repliedtotxtrecipientenc[zj]=0;
          repliedtotxtrecipient=bb_decrypt_buffer_ec(&zj,encpk,repliedtotxtrecipientenc);
          if(repliedtotxtrecipient==NULL){
            strcpy(error,"1910a - error decrypting replytotxt");
            goto CLEANUP;
          }
          if(zj>0) repliedtotxtrecipient[zj]=0;
          jsonbuf=malloc(zj+1024);
          bb_json_escapestr(repliedtotxtrecipient,jsonbuf,zj+1023);
          replybuf=bb_str_replace(reply,repliedtotxtrecipientb64,jsonbuf);
          free(jsonbuf);
          if(verbose) printf("REPLIEDTOXT - replybuf: %s\n",replybuf);
          if(repliedtotxtrecipient!=NULL){
            memset(repliedtotxtrecipient,0x0,zj);
            free(repliedtotxtrecipient);
          }
          if(replybuf!=NULL){
              strncpy(reply,replybuf,(strlen(reply)-1));
              memset(replybuf,0x0,strlen(replybuf));
              free(replybuf);
          }
      }
      memset(repliedtotxtrecipientb64,0x0,16384);
      memset(repliedtotxtrecipientenc,0x0,16384);
      // END DECRYPTING REPLIEDTOTXT
      if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
      }
      else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
      }
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   //FILE DOWNLOAD FOR MSGTYPE=file

   if(strcmp(msgtype,"file")==0){
       filenamemsg[0]=0;
       bb_json_getvalue("filename",reply,filenamemsg,255);
       bb_strip_path(filenamemsg);
       if(strlen(filenamemsg)==0){
            strcpy(error,"Filename not found in the message, something is wrong");
            free(replydecrypted);
            goto CLEANUP;
       }
       replydownload=bb_get_encryptedfile(filenamemsg,pwdconf);
       bb_json_getvalue("answer",replydownload,answer,63);
       answer[0]=0;
       if(strcmp(answer,"KO")==0){
            bb_json_getvalue("message",replydownload,error,64);
            goto CLEANUP;
       }
       localfilenamemsgenc[0]=0;
       bb_json_getvalue("filename",replydownload,localfilenamemsgenc,511);
       if(strlen(localfilenamemsgenc)==0){
            strcpy(error,"Local filename not found in the answer, something is wrong");
            goto CLEANUP;
       }
       if(verbose) printf("localfilenamemsgenc: %s\n",localfilenamemsgenc);
       strcpy(localfilenamemsg,localfilenamemsgenc);
       j=strlen(localfilenamemsg);
       if(localfilenamemsg[j-1]=='c' && localfilenamemsg[j-2]=='n' && localfilenamemsg[j-3]=='e' && localfilenamemsg[j-4]=='.'){
          localfilenamemsg[j-4]=0;
       }
       else{
            strcpy(error,"Encrypted filename not .enc");
            goto CLEANUP;
       }
       if(verbose) printf("localfilenamemsg: %s\n",localfilenamemsg);
       sp=strstr(tmsg,"#####");
       if(sp==NULL){
            strcpy(error,"15004 - Decryption key for filename has not been found");
            goto CLEANUP;
       }
       strncpy(keyfileb64,sp+5,2047);
       if(verbose) printf("keyfileb64: %s\n",keyfileb64);
       j=bb_decode_base64(keyfileb64,keyfile);
       if(j<=0){
            strcpy(error,"Error decoding keyfileb64");
            goto CLEANUP;
       }
       keyfile[j]=0;
       originfilename[0]=0;
       bb_json_getvalue("originfilename",keyfile,originfilename,511);
       if(strlen(originfilename)==0){
            strcpy(error,"Origin file name has not been found");
            goto CLEANUP;
       }
       bb_strip_path(originfilename);
       //REPLACE MSGBODY
       newtmsg=malloc(strlen(tmsg)+64);
       strcpy(newtmsg,tmsg);
       sp=strstr(newtmsg,"#####");
       *sp=0;
       newreplydecrypted=bb_str_replace(replydecrypted,tmsg,newtmsg);
       if(verbose) printf("newreplydecrypted: %s\n",newreplydecrypted);
       replydecrypted=realloc(replydecrypted,strlen(newreplydecrypted)+4096);
       strcpy(replydecrypted,newreplydecrypted);
       j=strlen(replydecrypted);
       replydecrypted[j-1]=0;
       // replace file name with encrypted one
       sprintf(jsonadd,",\"originfilename\":\"%s\",\"localfilename\":\"%s\",\"keyfile\":\"%s\"}",originfilename,localfilenamemsgenc,keyfileb64);
       strncat(replydecrypted,jsonadd,3072);
        
       //UPDATE NEW TOKEN IN RAM
       token[0]=0;
       bb_json_getvalue("token",replydownload,token,255);
       if(strlen(token)>0) strncpy(bbtoken,token,255);
   }
   
   // CLEAN RAM VARIABLES
   if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
   if(replydownload!=NULL) free(replydownload);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(originfilename,0x0,512);
   memset(jsonadd,0x0,1024);
   
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(filenamemsg,0x0,256);
   memset(localfilenamemsgenc,0x0,512);
   memset(localfilenamemsg,0x0,512);
   memset(keyfile,0x0,2048);
   memset(keyfileb64,0x0,2048);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(replydecrypted);
    
   CLEANUP:
   if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
   if(replydownload!=NULL) free(replydownload);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(filenamemsg,0x0,256);
   memset(localfilenamemsgenc,0x0,512);
   memset(localfilenamemsg,0x0,512);
   memset(keyfile,0x0,2048);
   memset(keyfileb64,0x0,2048);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(originfilename,0x0,512);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO RECEIVE A NEW MESSAGE WITH FILE DOWNLOAD IN ASYNC
*/
char * bb_get_newmsg_fileasync(char *pwdconf){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char *replydownload=NULL;
    char filenamemsg[256];
    char localfilenamemsgenc[512];
    char localfilenamemsg[512];
    char keyfile[2048];
    char keyfileb64[2048];
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char originfilename[512];
    char jsonadd[1024];
    char *replyconf;
    struct FileDownloadThread fdt;
    pthread_t threads;
    int rc;
    char repliedtotxtrecipientb64[16384];
    char repliedtotxtrecipientenc[16384];
    char * repliedtotxtrecipient=NULL;
    char * replybuf=NULL;
    int zj;
    char * jsonbuf;
    char autodownloadphotos[16],autodownloadvideos[16],autodownloadaudios[16],autodownloaddocuments[16],autodownload[16];
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getnewmsg\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //GET AUTODOWNLOAD INFO
   memset(autodownloadphotos,0x0,16);
   memset(autodownloadvideos,0x0,16);
   memset(autodownloadaudios,0x0,16);
   memset(autodownloaddocuments,0x0,16);
    memset(autodownload,0x0,16);
   bb_json_getvalue("autodownloadphotos",reply,autodownloadphotos,15);
   bb_json_getvalue("autodownloadvideos",reply,autodownloadvideos,15);
   bb_json_getvalue("autodownloadaudios",reply,autodownloadaudios,15);
   bb_json_getvalue("autodownloaddocuments",reply,autodownloaddocuments,15);
   bb_json_getvalue("msgtype",reply,msgtype,255);
   if(strcmp(msgtype,"read")==0 || strcmp(msgtype,"received")==0
   || strcmp(msgtype,"status")==0 || strcmp(msgtype,"typing")==0 || strcmp(msgtype,"deleted")==0){
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }else{
      //DECRYPT ANSWER
      //printf("lenreply: %d\n",lenreply);
      lenalltmsg=lenreply+8192;
      tmsgenc=malloc(lenalltmsg);
      tmsgencb64=malloc(lenalltmsg);
      //tmsg=malloc(lenalltmsg);
      bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
      z=bb_decode_base64(encpkb64,encpk);
      encpk[z]=0;
      bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
      z=bb_decode_base64(tmsgencb64,tmsgenc);
      tmsgenc[z]=0;
      lentmsg=0;
      tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
      if(tmsg==NULL){
          tmsg=malloc(64);
          strcpy(tmsg,"Error decrypting content");
          lentmsg=strlen(tmsg);
       }
       else
          tmsg[lentmsg]=0;
      //printf("lentmsg: %d lenalltmsg %d\n",lentmsg,lenalltmsg);
      //printf("tmsg %s\n",tmsg);
      if(lentmsg>0)
         tmsg[lentmsg]=0;
      //JSON ESCAPE
      char *tmsgbuf=NULL;
      int len_tmsgescaped;
      tmsgbuf=malloc(lentmsg+64);
      strncpy(tmsgbuf,tmsg,lentmsg+63);
      free(tmsg);
      tmsg=malloc(lentmsg*2+64);
      len_tmsgescaped=bb_json_escapestr(tmsgbuf,tmsg,lentmsg*2+64);
      free(tmsgbuf);
       //END JSON ESCAPE
       
      //DECRYPT REPLIEDTOTXT IF SET
      memset(repliedtotxtrecipientb64,0x0,16384);
      memset(repliedtotxtrecipientenc,0x0,16384);
      bb_json_getvalue("repliedtotxt",reply,repliedtotxtrecipientb64,16383);
      if(strlen(repliedtotxtrecipientb64)>0){
          zj=bb_decode_base64(repliedtotxtrecipientb64,repliedtotxtrecipientenc);
          if(zj>0) repliedtotxtrecipientenc[zj]=0;
          repliedtotxtrecipient=bb_decrypt_buffer_ec(&zj,encpk,repliedtotxtrecipientenc);
          if(repliedtotxtrecipient==NULL){
            strcpy(error,"1910a - error decrypting replytotxt");
            goto CLEANUP;
          }
          if(zj>0) repliedtotxtrecipient[zj]=0;
          //JSON ESCAPE
          jsonbuf=malloc(zj+1024);
          bb_json_escapestr(repliedtotxtrecipient,jsonbuf,zj+1023);
          replybuf=bb_str_replace(reply,repliedtotxtrecipientb64,jsonbuf);
          free(jsonbuf);
          if(verbose) printf("REPLIEDTOXT - replybuf: %s\n",replybuf);
          if(repliedtotxtrecipient!=NULL){
            memset(repliedtotxtrecipient,0x0,zj);
            free(repliedtotxtrecipient);
          }
          if(replybuf!=NULL){
              strncpy(reply,replybuf,(strlen(reply)-1));
              memset(replybuf,0x0,strlen(replybuf));
              free(replybuf);
          }
      }
      memset(repliedtotxtrecipientb64,0x0,16384);
      memset(repliedtotxtrecipientenc,0x0,16384);
      if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
      }
      else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
      }
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   //FILE DOWNLOAD FOR MSGTYPE=file

   if(strcmp(msgtype,"file")==0){
           localfilenamemsg[0]=0;
           bb_json_getvalue("filename",reply,localfilenamemsg,255);
           if(strlen(localfilenamemsg)==0){
                strcpy(error,"Filename not found in the message, something is wrong");
                free(replydecrypted);
                goto CLEANUP;
           }
           bb_strip_path(localfilenamemsg);
           sp=strstr(tmsg,"#####");
           if(sp==NULL){
                  strcpy(error,"15005 - Decryption key for filename has not been found");
                  goto CLEANUP;
           }
           strncpy(keyfileb64,sp+5,2047);
           j=bb_decode_base64(keyfileb64,keyfile);
           if(j<=0){
               strcpy(error,"Error decoding keyfileb64 (1)");
               goto CLEANUP;
           }
           keyfile[j]=0;
                    
        //REPLACE MSGBODY
       originfilename[0]=0;
       bb_json_getvalue("originfilename",keyfile,originfilename,511);
       if(strlen(originfilename)==0){
            strcpy(error,"Origin file name has not been found");
            goto CLEANUP;
       }
       bb_strip_path(originfilename);
       newtmsg=malloc(strlen(tmsg)+64);
       strcpy(newtmsg,tmsg);
       sp=strstr(newtmsg,"#####");
       *sp=0;
       newreplydecrypted=bb_str_replace(replydecrypted,tmsg,newtmsg);
       if(verbose) printf("newreplydecrypted: %s\n",newreplydecrypted);
       replydecrypted=realloc(replydecrypted,strlen(newreplydecrypted)+2048);
       strcpy(replydecrypted,newreplydecrypted);
       free(newreplydecrypted);
       newreplydecrypted=NULL;
       j=strlen(replydecrypted);
       replydecrypted[j-1]=0;
       if(bb_check_autodownload(originfilename,autodownloadphotos,autodownloadvideos,autodownloadaudios,autodownloaddocuments)==1)
           strcpy(autodownload,"Y");
       else
           strcpy(autodownload,"N");
       sprintf(jsonadd,",\"originfilename\":\"%s\",\"localfilename\":\"%s/Documents/test/%s\",\"autodownload\":\"%s\",\"keyfile\":\"%s\"}",originfilename,getenv("HOME"),localfilenamemsg,autodownload, keyfileb64);
       strncat(replydecrypted,jsonadd,1024);
       if(bb_check_autodownload(originfilename,autodownloadphotos,autodownloadvideos,autodownloadaudios,autodownloaddocuments)==1){
           //*************************************
           //ASYNC FILE DOWNLOAD
           strncpy(fdt.pwdconf,pwdconf,4095);
           strncpy(fdt.uniquefilename,localfilenamemsg,1023);
           strncpy(fdt.keyfile,keyfile,2047);
           rc=pthread_create(&threads,NULL,bb_get_encryptedfile_async,(void *)&fdt);
           if(rc){
               fprintf(stderr,"ERROR; return code from pthread_create() is %d\n", rc);
           }
           // END ASYNC LAUNCH
           //**************************************
       }
   }
   
   // CLEAN RAM VARIABLES
   if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
   if(replydownload!=NULL) free(replydownload);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(originfilename,0x0,512);
   memset(jsonadd,0x0,1024);
   
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(filenamemsg,0x0,256);
   memset(localfilenamemsgenc,0x0,512);
   memset(localfilenamemsg,0x0,512);
   memset(keyfile,0x0,2048);
   memset(keyfileb64,0x0,2048);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   bb_json_removefield(replydecrypted,"autodownloadphotos");
   bb_json_removefield(replydecrypted,"autodownloadaudios");
   bb_json_removefield(replydecrypted,"autodownloadvideos");
   bb_json_removefield(replydecrypted,"autodownloaddocuments");
   return(replydecrypted);
    
   CLEANUP:
   if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
   if(replydownload!=NULL) free(replydownload);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(filenamemsg,0x0,256);
   memset(localfilenamemsgenc,0x0,512);
   memset(localfilenamemsg,0x0,512);
   memset(keyfile,0x0,2048);
   memset(keyfileb64,0x0,2048);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(originfilename,0x0,512);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   if(reply==NULL) reply=malloc(2048);
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO RECEIVE A NEW MESSAGE FLE DOWNLOAD IN ASYNC
*/
char * bb_get_newmsg_fileasync_background(char *pwdconf){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char *replydownload=NULL;
    char filenamemsg[256];
    char localfilenamemsgenc[512];
    char localfilenamemsg[512];
    char keyfile[2048];
    char keyfileb64[2048];
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char originfilename[512];
    char jsonadd[1024];
    char *replyconf;
    struct FileDownloadThread fdt;
    pthread_t threads;
    int rc;
    char repliedtotxtrecipientb64[16384];
    char repliedtotxtrecipientenc[16384];
    char * repliedtotxtrecipient=NULL;
    char * replybuf=NULL;
    int zj;
    char *jsonbuf;
    char autodownloadphotos[16],autodownloadvideos[16],autodownloadaudios[16],autodownloaddocuments[16],autodownload[16];
    

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getnewmsg\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\",\"background\":\"1\"}",mobilenumber,bbtoken,totp,hashb64,sign);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
    //GET AUTODOWNLOAD INFO
    memset(autodownloadphotos,0x0,16);
    memset(autodownloadvideos,0x0,16);
    memset(autodownloadaudios,0x0,16);
    memset(autodownloaddocuments,0x0,16);
    memset(autodownload,0x0,16);
    bb_json_getvalue("autodownloadphotos",reply,autodownloadphotos,15);
    bb_json_getvalue("autodownloadvideos",reply,autodownloadvideos,15);
    bb_json_getvalue("autodownloadaudios",reply,autodownloadaudios,15);
    bb_json_getvalue("autodownloaddocuments",reply,autodownloaddocuments,15);
   bb_json_getvalue("msgtype",reply,msgtype,255);
   if(strcmp(msgtype,"read")==0 || strcmp(msgtype,"received")==0
   || strcmp(msgtype,"status")==0 || strcmp(msgtype,"typing")==0 || strcmp(msgtype,"deleted")==0){
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }else{
      //DECRYPT ANSWER
      //printf("lenreply: %d\n",lenreply);
      lenalltmsg=lenreply+8192;
      tmsgenc=malloc(lenalltmsg);
      tmsgencb64=malloc(lenalltmsg);
      //tmsg=malloc(lenalltmsg);
      bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
      z=bb_decode_base64(encpkb64,encpk);
      encpk[z]=0;
      bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
      z=bb_decode_base64(tmsgencb64,tmsgenc);
      tmsgenc[z]=0;
      lentmsg=0;
      tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
      if(tmsg==NULL){
          tmsg=malloc(64);
          strcpy(tmsg,"Error decrypting content");
          lentmsg=strlen(tmsg);
       }
       else
          tmsg[lentmsg]=0;
      //printf("lentmsg: %d lenalltmsg %d\n",lentmsg,lenalltmsg);
      //printf("tmsg %s\n",tmsg);
      if(lentmsg>0)
         tmsg[lentmsg]=0;
      //JSON ESCAPE
      char *tmsgbuf=NULL;
      int len_tmsgescaped;
      tmsgbuf=malloc(lentmsg+64);
      strncpy(tmsgbuf,tmsg,lentmsg+63);
      free(tmsg);
      tmsg=malloc(lentmsg*2+64);
      len_tmsgescaped=bb_json_escapestr(tmsgbuf,tmsg,lentmsg*2+64);
      free(tmsgbuf);
       //END JSON ESCAPE
      //DECRYPT REPLIEDTOTXT IF SET
      memset(repliedtotxtrecipientb64,0x0,16384);
      memset(repliedtotxtrecipientenc,0x0,16384);
      bb_json_getvalue("repliedtotxt",reply,repliedtotxtrecipientb64,16383);
      if(strlen(repliedtotxtrecipientb64)>0){
          zj=bb_decode_base64(repliedtotxtrecipientb64,repliedtotxtrecipientenc);
          if(zj>0) repliedtotxtrecipientenc[zj]=0;
          repliedtotxtrecipient=bb_decrypt_buffer_ec(&zj,encpk,repliedtotxtrecipientenc);
          if(repliedtotxtrecipient==NULL){
            strcpy(error,"1910a - error decrypting replytotxt");
            goto CLEANUP;
          }
          if(zj>0) repliedtotxtrecipient[zj]=0;
          jsonbuf=malloc(zj+1024);
          bb_json_escapestr(repliedtotxtrecipient,jsonbuf,zj+1023);
          replybuf=bb_str_replace(reply,repliedtotxtrecipientb64,jsonbuf);
          free(jsonbuf);
          if(verbose) printf("REPLIEDTOXT - replybuf: %s\n",replybuf);
          if(repliedtotxtrecipient!=NULL){
            memset(repliedtotxtrecipient,0x0,zj);
            free(repliedtotxtrecipient);
          }
          if(replybuf!=NULL){
              strncpy(reply,replybuf,(strlen(reply)-1));
              memset(replybuf,0x0,strlen(replybuf));
              free(replybuf);
          }
      }
      memset(repliedtotxtrecipientb64,0x0,16384);
      memset(repliedtotxtrecipientenc,0x0,16384);
      if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
      }
      else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
      }
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   //FILE DOWNLOAD FOR MSGTYPE=file

   if(strcmp(msgtype,"file")==0){
           localfilenamemsg[0]=0;
           bb_json_getvalue("filename",reply,localfilenamemsg,255);
           if(strlen(localfilenamemsg)==0){
                strcpy(error,"Filename not found in the message, something is wrong");
                goto CLEANUP;
           }
           bb_strip_path(localfilenamemsg);
           sp=strstr(tmsg,"#####");
           if(sp==NULL){
                  strcpy(error,"15005 - Decryption key for filename has not been found");
                  goto CLEANUP;
           }
           strncpy(keyfileb64,sp+5,2047);
           j=bb_decode_base64(keyfileb64,keyfile);
           if(j<=0){
               strcpy(error,"Error decoding keyfileb64 (1)");
               goto CLEANUP;
           }
           keyfile[j]=0;

       //REPLACE MSGBODY
       originfilename[0]=0;
       bb_json_getvalue("originfilename",keyfile,originfilename,511);
       if(strlen(originfilename)==0){
            strcpy(error,"Origin file name has not been found");
            goto CLEANUP;
       }
       bb_strip_path(originfilename);
       newtmsg=malloc(strlen(tmsg)+64);
       strcpy(newtmsg,tmsg);
       sp=strstr(newtmsg,"#####");
       *sp=0;
       newreplydecrypted=bb_str_replace(replydecrypted,tmsg,newtmsg);
       if(verbose) printf("newreplydecrypted: %s\n",newreplydecrypted);
       replydecrypted=realloc(replydecrypted,strlen(newreplydecrypted)+2048);
       strcpy(replydecrypted,newreplydecrypted);
       free(newreplydecrypted);
       newreplydecrypted=NULL;
       j=strlen(replydecrypted);
       replydecrypted[j-1]=0;
       if(bb_check_autodownload(originfilename,autodownloadphotos,autodownloadvideos,autodownloadaudios,autodownloaddocuments)==1)
           strcpy(autodownload,"Y");
       else
           strcpy(autodownload,"N");
       sprintf(jsonadd,",\"originfilename\":\"%s\",\"localfilename\":\"%s/Documents/test/%s\",\"autodownload\":\"%s\",\"keyfile\":\"%s\"}",originfilename,getenv("HOME"),localfilenamemsg,autodownload, keyfileb64);
       strncat(replydecrypted,jsonadd,1024);
       if(bb_check_autodownload(originfilename,autodownloadphotos,autodownloadvideos,autodownloadaudios,autodownloaddocuments)==1){
          //ASYNC FILE DOWNLOAD
          strncpy(fdt.pwdconf,pwdconf,4095);
          strncpy(fdt.uniquefilename,localfilenamemsg,1023);
          strncpy(fdt.keyfile,keyfile,2047);
          rc=pthread_create(&threads,NULL,bb_get_encryptedfile_async,(void *)&fdt);
          if(rc){
                 fprintf(stderr,"ERROR; return code from pthread_create() is %d\n", rc);
          }
          // END ASYNC LAUNCH
       }
   }
   
   // CLEAN RAM VARIABLES
   if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
   if(replydownload!=NULL) free(replydownload);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(originfilename,0x0,512);
   memset(jsonadd,0x0,1024);
   
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(filenamemsg,0x0,256);
   memset(localfilenamemsgenc,0x0,512);
   memset(localfilenamemsg,0x0,512);
   memset(keyfile,0x0,2048);
   memset(keyfileb64,0x0,2048);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(replydecrypted);
    
   CLEANUP:
   if(replydownload!=NULL) memset(replydownload,0x0,strlen(replydownload));
   if(replydownload!=NULL) free(replydownload);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(filenamemsg,0x0,256);
   memset(localfilenamemsgenc,0x0,512);
   memset(localfilenamemsg,0x0,512);
   memset(keyfile,0x0,2048);
   memset(keyfileb64,0x0,2048);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(originfilename,0x0,512);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   if(reply==NULL) reply=malloc(2048);
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}

/**
* FUNCTION TO SEND A TEXT MESSAGE
*/
char * bb_send_txt_msg(char *recipient,char *bodymsg,char *pwdconf,char *repliedto,char *repliedtotxt){
    char *msg=NULL;
    char *crt=NULL;
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];

    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    char repliedtotxtenc[8192];
    char repliedtotxtencb64[16384];
    char repliedtotxtencb64r[16384];
    memset(repliedtotxtenc,0x0,8192);
    memset(repliedtotxtencb64,0x0,16384);
    memset(repliedtotxtencb64r,0x0,16384);
    if(strlen(bodymsg)==0){
        strcpy(error,"1600 - Message cannot be empty to be sent");
        goto CLEANUP;
    }
    if(strlen(bodymsg)>256000){
        strcpy(error,"1601 - Message text is too long (>256K)");
        goto CLEANUP;
    }
    if(strlen(recipient)==0){
        strcpy(error,"1603 - Recipient is missing");
        goto CLEANUP;
    }
    if(repliedto==NULL || strlen(repliedto)>32){
        strcpy(error,"1603a - Repliedto is wrong");
        goto CLEANUP;
    }
    if(repliedtotxt==NULL || strlen(repliedtotxt)>256){
        strcpy(error,"1603b - Repliedtotxt is wrong");
        goto CLEANUP;
    }

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1608 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1609 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1610 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1611 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1612 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"1613 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //ENCRYPT REPLIEDTOTXT IF PRESENT FOR RECIPIENT
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64r,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificate,repliedtotxtenc)){
        strcpy(error,"1613a - error encrypting the repliedtotxt by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64r);
   }
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"1613r - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //ENCRYPT REPLIEDTOTXT FOR SENDER
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificater,repliedtotxtenc)){
        strcpy(error,"1613b - error encrypting the repliedtotxt for recipient by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64);
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%s%s%u,%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken)+strlen(repliedtotxtencb64)+strlen(repliedtotxtencb64r)+strlen(repliedto);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"sendmsg\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"repliedto\":\"%s\",\"repliedtotxtsender\":\"%s\",\"repliedtotxtrecipient\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsgencb64,bodymsgencb64r,repliedto,repliedtotxtencb64,repliedtotxtencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   memset(repliedtotxtenc,0x0,512);
   memset(repliedtotxtencb64,0x0,1024);
   memset(repliedtotxtencb64r,0x0,1024);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(repliedtotxtenc,0x0,512);
   memset(repliedtotxtencb64,0x0,1024);
   memset(repliedtotxtencb64r,0x0,1024);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bx=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO SEND A TEXT TO A GROUP CHAT
*/
char * bb_send_txt_msg_groupchat(char * groupid,char *bodymsg,char *pwdconf,char *repliedto,char *repliedtotxt)
{
    char error[256];
    char answer[64];
    char recipient[64];
    char *reply=NULL;
    char *replymsg=NULL;
    char *member=NULL;
    char *replym=NULL;
    char *mymobile=NULL;
    char mynumber[256];
    char msgref[64];
    char autodelete[64];
    int x,i;
    if(strlen(groupid)==0){
        strcpy(error,"1602 - Group id is missing");
        goto CLEANUP;
    }
    if(strlen(bodymsg)==0){
        strcpy(error,"1600 - Message cannot be empty to be sent");
        goto CLEANUP;
    }
    if(strlen(bodymsg)>256000){
        strcpy(error,"1601 - Message text is too long (>256K)");
        goto CLEANUP;
    }
    if(strlen(pwdconf)==0){
        strcpy(error,"1600 - Configuration is missing");
        goto CLEANUP;
    }
    reply=bb_get_list_members_groupchat(groupid,pwdconf);
    if(reply==NULL){
         strcpy(error,"1620 - Error reading members list of the group");
        goto CLEANUP;
    }
    answer[0]=0;
    bb_json_getvalue("answer",reply,answer,63);
    if(strcmp(answer,"KO")==0){
      error[0]=0;
      bb_json_getvalue("message",reply,error,255);
      goto CLEANUP;
    }
    //LOOP TO SEND A MESSAGE FOR EACH MEMBER
    i=0;
    x=0;
    char lastmsgid[128];
    memset(lastmsgid,0x0,128);
    mymobile=bb_get_registered_mobilenumber(pwdconf);
    memset(mynumber,0x0,256);
    bb_json_getvalue("mobilenumber",mymobile,mynumber,255);
    bb_gen_msgref(msgref);
    memset(autodelete,0x0,64);
    while(1){
          member=bb_json_getvalue_fromarray("members",reply,i);
          if(member==NULL){
            break;
          }
          recipient[0]=0;
          bb_json_getvalue("mobilenumber",member,recipient,63);
          if(strlen(recipient)==0){
            x++;
            continue;
          }
          replymsg=bb_send_txt_msg_membergroupchat(recipient,bodymsg,groupid,pwdconf,repliedto,repliedtotxt,msgref);
          answer[0]=0;
          bb_json_getvalue("answer",replymsg,answer,63);
          if(strcmp(answer,"KO")==0){
              x++;
          }
          if(strcmp(mynumber,recipient)==0){
             lastmsgid[0]=0;
             bb_json_getvalue("msgid",replymsg,lastmsgid,127);
          }
          if(verbose) printf("replymsg:%s\n",replymsg);
          memset(autodelete,0x0,64);
          bb_json_getvalue("autodelete", replymsg, autodelete, 63);
          free(replymsg);
          free(member);
          i++;
    }
    if(verbose) printf("mynumber:%s\n",mynumber);
    //END LOOP
    free(mymobile);
    free(reply);
    reply=malloc(512);
    if(autodelete[0]!='0' && autodelete[0]!='1') strcpy(autodelete,"0");
    sprintf(reply,"{\"answer\":\"OK\",\"message\":\"Messages sent: %d failed: %d\",\"msgid\":\"%s\",\"msgref\":\"%s\",\"autodelete\":\"%s\"}",i,x,lastmsgid,msgref,autodelete);
    memset(error,0x0,256);
    memset(answer,0x0,64);
    memset(recipient,0x0,64);
    return(reply);
        
    CLEANUP:
    memset(error,0x0,256);
    memset(answer,0x0,64);
    memset(recipient,0x0,64);
    if(reply!=NULL){
       x=strlen(reply);
       memset(reply,0x0,x);
       free(reply);
    }
    reply=malloc(512);
    sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
    return(reply);
}

/**
* FUNCTION TO SEND A TYPING MSG TO A GROUP
*/
char * bb_send_typing_groupchat(char * groupid,char *pwdconf)
{
    char error[256];
    char answer[64];
    char recipient[64];
    char *reply=NULL;
    char *replymsg=NULL;
    char *member=NULL;
    char *replym=NULL;
    char *mymobile=NULL;
    char mynumber[256];
    int x,i;
    if(strlen(groupid)==0){
        strcpy(error,"1602 - Group id is missing");
        goto CLEANUP;
    }
    if(strlen(pwdconf)==0){
        strcpy(error,"1600 - Configuration is missing");
        goto CLEANUP;
    }
    reply=bb_get_list_members_groupchat(groupid,pwdconf);
    if(reply==NULL){
         strcpy(error,"1620 - Error reading members list of the group");
        goto CLEANUP;
    }
    answer[0]=0;
    bb_json_getvalue("answer",reply,answer,63);
    if(strcmp(answer,"KO")==0){
      error[0]=0;
      bb_json_getvalue("message",reply,error,255);
      goto CLEANUP;
    }
    //LOOP TO SEND A MESSAGE FOR EACH MEMBER
    i=0;
    x=0;
    char lastmsgid[128];
    memset(lastmsgid,0x0,128);
    mymobile=bb_get_registered_mobilenumber(pwdconf);
    memset(mynumber,0x0,256);
    bb_json_getvalue("mobilenumber",mymobile,mynumber,255);
    while(1){
          member=bb_json_getvalue_fromarray("members",reply,i);
          if(member==NULL){
            break;
          }
          recipient[0]=0;
          bb_json_getvalue("mobilenumber",member,recipient,63);
          if(strlen(recipient)==0){
            free(member);
            i++;
            continue;
          }
          if(strcmp(mynumber,recipient)==0){
           free(member);
           i++;
           continue;
          }
          replymsg=bb_send_typing_membergroupchat(recipient,groupid,pwdconf);
          answer[0]=0;
          bb_json_getvalue("answer",replymsg,answer,63);
          if(strcmp(answer,"KO")==0){
              x++;
          }
          lastmsgid[0]=0;
          bb_json_getvalue("msgid",replymsg,lastmsgid,127);
          if(verbose) printf("replymsg:%s\n",replymsg);
          free(replymsg);
          free(member);
          i++;
    }
    //if(verbose) printf("mynumber:%s\n",mynumber);
    //END LOOP
    free(mymobile);
    free(reply);
    reply=malloc(512);
    sprintf(reply,"{\"answer\":\"OK\",\"message\":\"Messages sent: %d failed: %d\",\"msgid\":\"%s\"}",i,x,lastmsgid);
    memset(error,0x0,256);
    memset(answer,0x0,64);
    memset(recipient,0x0,64);
    return(reply);
        
    CLEANUP:
    memset(error,0x0,256);
    memset(answer,0x0,64);
    memset(recipient,0x0,64);
    if(reply!=NULL){
       x=strlen(reply);
       memset(reply,0x0,x);
       free(reply);
    }
    reply=malloc(512);
    sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
    return(reply);

}
/**
* FUNCTION TO SEND A FILE TO A GROUP CHAT
*/
char * bb_send_file_groupchat(char *originfilename,char * groupid,char *bodymsg,char *pwdconf,char *repliedto,char *repliedtotxt)
{
    char error[512];
    char answer[64];
    char recipient[64];
    char *reply=NULL;
    char *replymsg=NULL;
    char *replyf=NULL;
    char *replym=NULL;
    char mobilenumber[128];
    char *member=NULL;
    char msgref[64];
    char autodelete[64];
    int x,i;
    memset(mobilenumber,0x0,128);
    if(strlen(groupid)==0){
        strcpy(error,"1602 - Group id is missing");
        goto CLEANUP;
    }
//    if(strlen(bodymsg)==0){
//        strcpy(error,"1600 - Message cannot be empty to be sent");
//        goto CLEANUP;
//    }
    if(strlen(bodymsg)>256000){
        strcpy(error,"1601 - Message text is too long (>256K)");
        goto CLEANUP;
    }
    if(strlen(pwdconf)==0){
        strcpy(error,"1600 - Configuration is missing");
        goto CLEANUP;
    }
    if(strlen(originfilename)==0 || strlen(originfilename)>255){
        strcpy(error,"2800 - file name is wrong");
        goto CLEANUP;
    }
    if(access(originfilename,F_OK )== -1){
       sprintf(error,"2801 - file name is not accessible or it does not exist [%s]",originfilename);
        goto CLEANUP;
    }
    replym=bb_get_registered_mobilenumber(pwdconf);
    if(replym!=NULL){
        bb_json_getvalue("mobilenumber",replym,mobilenumber,127);
        free(replym);
    }
    reply=bb_get_list_members_groupchat(groupid,pwdconf);
    if(reply==NULL){
         strcpy(error,"1620 - Error reading members list of the group");
        goto CLEANUP;
    }
    answer[0]=0;
    bb_json_getvalue("answer",reply,answer,63);
    if(strcmp(answer,"KO")==0){
      error[0]=0;
      bb_json_getvalue("message",reply,error,255);
      goto CLEANUP;
    }
    //LOOP TO SEND A MESSAGE FOR EACH MEMBER
    i=0;
    x=0;
    bb_gen_msgref(msgref);
    memset(autodelete,0x0,64);
    while(1){
          member=bb_json_getvalue_fromarray("members",reply,i);
          if(member==NULL){
            break;
          }
          recipient[0]=0;
          bb_json_getvalue("mobilenumber",member,recipient,63);
          if(strlen(recipient)==0){
            x++;
            continue;
          }
          replymsg=bb_send_file_membergroupchat(originfilename,recipient,bodymsg,groupid,pwdconf,repliedto,repliedtotxt,msgref);
          answer[0]=0;
          bb_json_getvalue("answer",replymsg,answer,63);
          if(strcmp(answer,"KO")==0){
              x++;
          }
          //printf("REPLYMSG GROUP FILE: %s\n",replymsg);
          if(strcmp(recipient,mobilenumber)==0 && replyf==NULL){
                      replyf=malloc(strlen(replymsg)+1);
                      strcpy(replyf,replymsg);
          }
          memset(autodelete,0x0,64);
          bb_json_getvalue("autodelete", replymsg, autodelete, 63);
          free(replymsg);
          free(member);
          i++;
    }
    //END LOOP
    free(reply);
    if(replyf!=NULL){
       memset(error,0x0,256);
       memset(answer,0x0,64);
       memset(recipient,0x0,64);
        reply=malloc(strlen(replyf)+512);
        strcpy(reply,replyf);
        free(replyf);
        int lr=strlen(reply);
        reply[lr-1]=0;
        strcat(reply,",\"autodelete\":\"");
        strcat(reply,autodelete);
        strcat(reply,"\"}");
        return(reply);
    }
    else{
       reply=malloc(1024);
       sprintf(reply,"{\"answer\":\"OK\",\"message\":\"Messages sent: %d failed: %d\",\"msgref\":\"%s\",\"autodelete\":\"%s\"}",i,x,msgref,autodelete);
       memset(error,0x0,256);
       memset(answer,0x0,64);
       memset(recipient,0x0,64);
       return(reply);
     }
        
    CLEANUP:
    memset(error,0x0,256);
    memset(answer,0x0,64);
    memset(recipient,0x0,64);
    if(reply!=NULL){
       x=strlen(reply);
       memset(reply,0x0,x);
       free(reply);
    }
    reply=malloc(512);
    sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
    return(reply);

}
/**
* FUNCTION TO SEND A LOCATION TO A GROUP
*/
char * bb_send_location_groupchat(char * groupid,char *latitude,char *longitude,char *pwdconf,char *repliedto,char *repliedtotxt)
{
    char error[512];
    char answer[64];
    char recipient[64];
    char *reply=NULL;
    char *replymsg=NULL;
    char *member=NULL;
    char msgref[64];
    char autodelete[64];
    int x,i;
    if(strlen(groupid)==0){
        strcpy(error,"1602a - Group id is missing");
        goto CLEANUP;
    }
    if(strlen(latitude)==0){
        strcpy(error,"1600a - Latitude cannot be empty");
        goto CLEANUP;
    }
    if(strlen(longitude)==0){
        strcpy(error,"1601a - Longitude cannot be empty)");
        goto CLEANUP;
    }
    if(strlen(pwdconf)==0){
        strcpy(error,"1600a - Configuration is missing");
        goto CLEANUP;
    }
    if(strlen(groupid)==0){
        strcpy(error,"1603a - Group id is missing");
        goto CLEANUP;
    }
    reply=bb_get_list_members_groupchat(groupid,pwdconf);
    if(reply==NULL){
         strcpy(error,"1604a - Error reading members list of the group");
        goto CLEANUP;
    }
    answer[0]=0;
    bb_json_getvalue("answer",reply,answer,63);
    if(strcmp(answer,"KO")==0){
      error[0]=0;
      bb_json_getvalue("message",reply,error,255);
      goto CLEANUP;
    }
    //LOOP TO SEND A MESSAGE FOR EACH MEMBER
    i=0;
    x=0;
    bb_gen_msgref(msgref);
    memset(autodelete,0x0,64);
    while(1){
          member=bb_json_getvalue_fromarray("members",reply,i);
          if(member==NULL){
            break;
          }
          recipient[0]=0;
          bb_json_getvalue("mobilenumber",member,recipient,63);
          if(strlen(recipient)==0){
            x++;
            continue;
          }
          replymsg=bb_send_location_membersgroupchat(recipient,latitude,longitude,pwdconf,groupid,repliedto,repliedtotxt,msgref);
          answer[0]=0;
          bb_json_getvalue("answer",replymsg,answer,63);
          if(strcmp(answer,"KO")==0){
              x++;
          }
          //printf("%s\n",replymsg);
          bb_json_getvalue("autodelete", replymsg, autodelete, 63);
          free(replymsg);
          free(member);
          i++;
    }
    //END LOOP
    free(reply);
    reply=malloc(512);
    sprintf(reply,"{\"answer\":\"OK\",\"message\":\"Messages sent: %d failed: %d\",\"msgref\":\"%s\",\"autodelete\":\"%s\"}",i,x,msgref,autodelete);
    //sprintf(reply,"{\"answer\":\"OK\",\"message\":\"Messages sent: %d failed: %d\",\"msgref\":\"%s\"}",i,x,msgref);
    memset(error,0x0,256);
    memset(answer,0x0,64);
    memset(recipient,0x0,64);
    return(reply);
        
    CLEANUP:
    memset(error,0x0,256);
    memset(answer,0x0,64);
    memset(recipient,0x0,64);
    if(reply!=NULL){
       x=strlen(reply);
       memset(reply,0x0,x);
       free(reply);
    }
    reply=malloc(512);
    sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
    return(reply);

}
/**
* FUNCTION TO SEND LOCATION TO A MEMBER OF A GROUP CHAT
*/
char * bb_send_location_membersgroupchat(char *recipient,char *latitude,char * longitude,char *pwdconf,char *groupid,char *repliedto,char *repliedtotxt,char *msgref){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    char repliedtotxtenc[8192];
    char repliedtotxtencb64[16384];
    char repliedtotxtencb64r[16384];
    char autodelete[64];
    memset(repliedtotxtenc,0x0,8192);
    memset(repliedtotxtencb64,0x0,16384);
    memset(repliedtotxtencb64r,0x0,16384);
    
   
    if(atof(latitude)>90 || atof(latitude)<-90){
        strcpy(error,"2700 - Latitude is wrong");
        goto CLEANUP;
    }
    if(atof(longitude)>180 || atof(longitude)<-180){
        strcpy(error,"2701 - Longitude is wrong");
        goto CLEANUP;
    }
    if(groupid==NULL || strlen(groupid)==0){
        strcpy(error,"2701ac - Groupid is wrong");
        goto CLEANUP;
    }
    if(repliedto==NULL || strlen(repliedto)>32){
        strcpy(error,"2701a - Repliedto is wrong");
        goto CLEANUP;
    }
    if(repliedtotxt==NULL || strlen(repliedtotxt)>256){
        strcpy(error,"2701b - Repliedtotxt is wrong");
        goto CLEANUP;
    }
    sprintf(bodymsg,"%.14f,%.14f",atof(latitude),atof(longitude));
    if(strlen(recipient)==0){
        strcpy(error,"2702 - Recipient is missing");
        goto CLEANUP;
    }

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2706 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2707 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2708 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2709 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2710 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"2711 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //ENCRYPT REPLIEDTOTXT IF PRESENT FOR RECIPIENT
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64r,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificate,repliedtotxtenc)){
        strcpy(error,"1613a - error encrypting the repliedtotxt by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64r);
   }
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"2712 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //ENCRYPT REPLIEDTOTXT FOR SENDER
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificater,repliedtotxtenc)){
        strcpy(error,"1613b - error encrypting the repliedtotxt for recipient by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64);
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"location%s%s%s%u,%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken)+strlen(repliedtotxtencb64)+strlen(repliedtotxtencb64r)+strlen(repliedto)+strlen(groupid)+strlen(msgref);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"sendlocationgroupchat\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"groupid\":\"%s\",\"repliedto\":\"%s\",\"repliedtotxtsender\":\"%s\",\"repliedtotxtrecipient\":\"%s\",\"msgref\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsgencb64,bodymsgencb64r,groupid,repliedto,repliedtotxtencb64,repliedtotxtencb64r,msgref,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   //if(reply!=NULL) memset(reply,0x0,lenreply);
   //if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   memset(repliedtotxtenc,0x0,8192);
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   memset(autodelete,0x0,64);
   bb_json_getvalue("autodelete", reply, autodelete, 64);
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"OK\",\"message\":\"Location has been sent\",\"autodelete\":\"%s\"}",autodelete);
   //sprintf(replysend,"{\"answer\":\"OK\",\"message\":\"Location has been sent\"}");
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(repliedtotxtenc,0x0,8192);
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO SEND A TEXT MESSAGE TO A MEMBER OF GROUP
*/
char * bb_send_txt_msg_membergroupchat(char *recipient,char *bodymsg,char * groupid,char *pwdconf,char *repliedto,char *repliedtotxt,char* msgref){
    char *msg=NULL;
    char *crt=NULL;
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    char lastmsgid[128];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    char repliedtotxtenc[8192];
    char repliedtotxtencb64[16384];
    char repliedtotxtencb64r[16384];
    memset(repliedtotxtenc,0x0,8192);
    memset(repliedtotxtencb64,0x0,16384);
    memset(repliedtotxtencb64r,0x0,16384);
    
    if(strlen(bodymsg)==0){
        strcpy(error,"1600 - Message cannot be empty to be sent");
        goto CLEANUP;
    }
    if(strlen(bodymsg)>256000){
        strcpy(error,"1601 - Message text is too long (>256K)");
        goto CLEANUP;
    }
    if(strlen(recipient)==0){
        strcpy(error,"1603 - Recipient is missing");
        goto CLEANUP;
    }
    if(strlen(groupid)==0){
        strcpy(error,"1602 - Group id is missing");
        goto CLEANUP;
    }
    if(repliedto==NULL || strlen(repliedto)>32){
        strcpy(error,"1603a - Repliedto is wrong");
        goto CLEANUP;
    }
    if(repliedtotxt==NULL || strlen(repliedtotxt)>256){
        strcpy(error,"1603b - Repliedtotxt is wrong");
        goto CLEANUP;
    }

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1608 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1609 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1610 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1611 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1612 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"1613 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   if(verbose) printf("bx64: %d\n",bx64);
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //ENCRYPT REPLIEDTOTXT IF PRESENT FOR RECIPIENT
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64r,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificate,repliedtotxtenc)){
        strcpy(error,"1613a - error encrypting the repliedtotxt by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64r);
   }
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"1613r - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //ENCRYPT REPLIEDTOTXT FOR SENDER
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificater,repliedtotxtenc)){
        strcpy(error,"1613b - error encrypting the repliedtotxt for recipient by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64);
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%u,%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken)+strlen(repliedtotxtencb64)+strlen(repliedtotxtencb64r)+strlen(repliedto)+strlen(msgref);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   //sprintf(msg,"{\"action\":\"sendmsggroupchat\",\"sender\":\"%s\",\"recipient\":\"%s\",\"groupid\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,groupid,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   sprintf(msg,"{\"action\":\"sendmsggroupchat\",\"sender\":\"%s\",\"recipient\":\"%s\",\"groupid\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"repliedto\":\"%s\",\"repliedtotxtsender\":\"%s\",\"repliedtotxtrecipient\":\"%s\",\"msgref\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,groupid,bodymsgencb64,bodymsgencb64r,repliedto,repliedtotxtencb64,repliedtotxtencb64r,msgref,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   //if(reply!=NULL) memset(reply,0x0,lenreply);
   //if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   //replysend=malloc(256);
   //sprintf(replysend,"{\"answer\":\"OK\",\"message\":\"Message has been sent\"}");
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bx=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO SEND THE LOCATION
*/
char * bb_send_location(char *recipient,char *latitude,char *longitude,char *pwdconf,char *repliedto,char *repliedtotxt){

    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    char autodelete[64];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    char repliedtotxtenc[8192];
    char repliedtotxtencb64[16384];
    char repliedtotxtencb64r[16384];
    char lastmsgid[128];
    memset(repliedtotxtenc,0x0,8192);
    memset(repliedtotxtencb64,0x0,16384);
    memset(repliedtotxtencb64r,0x0,16384);
    
   
    if(atof(latitude)>90 || atof(latitude)<-90){
        strcpy(error,"2700 - Latitude is wrong");
        goto CLEANUP;
    }
    if(atof(longitude)>180 || atof(longitude)<-180){
        strcpy(error,"2701 - Longitude is wrong");
        goto CLEANUP;
    }
    if(repliedto==NULL || strlen(repliedto)>32){
        strcpy(error,"2701a - Repliedto is wrong");
        goto CLEANUP;
    }
    if(repliedtotxt==NULL || strlen(repliedtotxt)>256){
        strcpy(error,"2701b - Repliedtotxt is wrong");
        goto CLEANUP;
    }

    sprintf(bodymsg,"%.14f,%.14f",atof(latitude),atof(longitude));
    if(strlen(recipient)==0){
        strcpy(error,"2702 - Recipient is missing");
        goto CLEANUP;
    }

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2706 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2707 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2708 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2709 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2710 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"2711 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //ENCRYPT REPLIEDTOTXT IF PRESENT FOR RECIPIENT
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64r,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificate,repliedtotxtenc)){
        strcpy(error,"1613a - error encrypting the repliedtotxt by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64r);
   }
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"2712 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //ENCRYPT REPLIEDTOTXT FOR SENDER
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificater,repliedtotxtenc)){
        strcpy(error,"1613b - error encrypting the repliedtotxt for recipient by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64);
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"location%s%s%s%u,%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken)+strlen(repliedtotxtencb64)+strlen(repliedtotxtencb64r)+strlen(repliedto);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"sendlocation\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"repliedto\":\"%s\",\"repliedtotxtsender\":\"%s\",\"repliedtotxtrecipient\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsgencb64,bodymsgencb64r,repliedto,repliedtotxtencb64,repliedtotxtencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   buf[0]=0;
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   memset(lastmsgid,0x0,128);
   bb_json_getvalue("msgid",reply,lastmsgid,127);
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   memset(autodelete,0x0,64);
   bb_json_getvalue("autodelete", reply, autodelete, 64);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   memset(repliedtotxtenc,0x0,8192);
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"OK\",\"message\":\"Location has been sent\",\"msgid\":\"%s\",\"autodelete\":\"%s\"}",lastmsgid,autodelete);
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(repliedtotxtenc,0x0,8192);
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}

/**
* FUNCTION TO SEND TYPING MESSAGE DURING A CHAT ONE-TO-ONE
*/
char * bb_send_typing(char *recipient,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    char repliedtotxtenc[8192];
    char repliedtotxtencb64[16384];
    char repliedtotxtencb64r[16384];
    char lastmsgid[128];
    char groupid[64]={""};
    memset(repliedtotxtenc,0x0,8192);
    memset(repliedtotxtencb64,0x0,16384);
    memset(repliedtotxtencb64r,0x0,16384);
    
   
    if(recipient==NULL || strlen(recipient)==0 || strlen(recipient)>64){
        strcpy(error,"5010 - Recipient  is wrong");
        goto CLEANUP;
    }
    if(groupid==NULL || strlen(groupid)>640){
        strcpy(error,"5010a - Groupid  is wrong");
        goto CLEANUP;
    }
    if(atol(groupid)==0) groupid[0]=0;

    strcpy(bodymsg,"keyboard typing...");
    if(strlen(recipient)==0){
        strcpy(error,"2702 - Recipient is missing");
        goto CLEANUP;
    }

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2706 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2707 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2708 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2709 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2710 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"2711 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"2712 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"location%s%s%s%u,%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken)+strlen(groupid);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"typing\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"groupid\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsg,bodymsg,groupid,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   buf[0]=0;
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   memset(lastmsgid,0x0,128);
   bb_json_getvalue("msgid",reply,lastmsgid,127);
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   memset(repliedtotxtenc,0x0,8192);
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"OK\",\"message\":\"Typing has been sent\",\"msgid\":\"%s\"}",lastmsgid);
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(repliedtotxtenc,0x0,8192);
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
*FUNCTION TO SEND NOTIFICATION FOR DELETED MSG IN A CHAT ONE-TO-ONE
*/
char * bb_send_delete_nofification(char *recipient,char *msgid,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    char repliedtotxtenc[8192];
    char repliedtotxtencb64[16384];
    char repliedtotxtencb64r[16384];
    char lastmsgid[128];
    char groupid[64]={""};
    memset(repliedtotxtenc,0x0,8192);
    memset(repliedtotxtencb64,0x0,16384);
    memset(repliedtotxtencb64r,0x0,16384);
    
   
    if(recipient==NULL || strlen(recipient)==0 || strlen(recipient)>64){
        strcpy(error,"5010 - Recipient  is wrong");
        goto CLEANUP;
    }
    if(groupid==NULL || strlen(groupid)>640){
        strcpy(error,"5010a - Groupid  is wrong");
        goto CLEANUP;
    }
    if(atol(groupid)==0) groupid[0]=0;

    strcpy(bodymsg,msgid);
    if(strlen(recipient)==0){
        strcpy(error,"2702 - Recipient is missing");
        goto CLEANUP;
    }

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2706 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2707 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2708 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2709 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2710 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"2711 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"2712 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"location%s%s%s%u,%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken)+strlen(groupid);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"deletedinfo\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"groupid\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsg,bodymsg,groupid,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   buf[0]=0;
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   memset(lastmsgid,0x0,128);
   bb_json_getvalue("msgid",reply,lastmsgid,127);
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   memset(repliedtotxtenc,0x0,8192);
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"OK\",\"message\":\"Deleted info has been sent\",\"msgid\":\"%s\"}",lastmsgid);
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(repliedtotxtenc,0x0,8192);
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO SEND TYPING MESSAGE DURING A GROUP CHAT
*/
char * bb_send_typing_membergroupchat(char *recipient,char *groupid,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    char repliedtotxtenc[8192];
    char repliedtotxtencb64[16384];
    char repliedtotxtencb64r[16384];
    char lastmsgid[128];
    memset(repliedtotxtenc,0x0,8192);
    memset(repliedtotxtencb64,0x0,16384);
    memset(repliedtotxtencb64r,0x0,16384);
    
   
    if(recipient==NULL || strlen(recipient)==0 || strlen(recipient)>64){
        strcpy(error,"5010 - Recipient  is wrong");
        goto CLEANUP;
    }
    if(groupid==NULL || strlen(groupid)>640){
        strcpy(error,"5010a - Groupid  is wrong");
        goto CLEANUP;
    }
    if(atol(groupid)==0) groupid[0]=0;

    strcpy(bodymsg,"keyboard typing...");
    if(strlen(recipient)==0){
        strcpy(error,"2702 - Recipient is missing");
        goto CLEANUP;
    }

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2706 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2707 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2708 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2709 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2710 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"2711 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"2712 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"location%s%s%s%u,%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken)+strlen(groupid);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"typing\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"groupid\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsg,bodymsg,groupid,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   buf[0]=0;
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   memset(lastmsgid,0x0,128);
   bb_json_getvalue("msgid",reply,lastmsgid,127);
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   memset(repliedtotxtenc,0x0,8192);
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"OK\",\"message\":\"Typing has been sent\",\"msgid\":\"%s\"}",lastmsgid);
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(repliedtotxtenc,0x0,8192);
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO GET LIST OF CHATS
*/
char * bb_get_list_chat(char *pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 char answer[64];
 char mobilenumber[64];
 char *replyconf=NULL;
 char conf[8192];
 char msgtype[64];
 int x,j;
 error[0]=0;
 int c=0;
 char * jr;
 char *tmsgenc=NULL;
 char *tmsgencb64=NULL;
 char *tmsg=NULL;
 char * njr;
 int jrlen=0;
 int len_tmsgencb64=0;
 int len_tmsgenc=0;
  int len_tmsg=0;
 int len_njr=0;
 int len_newreply;
 int z;
 char encpk[8192];
 char encpkb64[8192];
 char *newreply;
 char *sp;
 char *buf;
 char keyfileb64[2048];
 char keyfile[2048];
 char originfilename[256];
 if(strlen(pwdconf)==0){
       strcpy(error,"configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"getchatlist",63);
 sprintf(requestjson,"{\"action\":\"%s\"}",action);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"No reply from server, please try later");
       goto CLEANUP;
 }
 answer[0]=0;
 bb_json_getvalue("answer",reply,answer,63);
 if(strcmp(answer,"KO")==0){
    bb_json_getvalue("message",reply,error,127);
    goto CLEANUP;

 }
 //DECRYPT CONFIGURATION
 replyconf=bb_load_configuration(pwdconf,conf);
 bb_json_getvalue("answer",replyconf,answer,63);
 if(strcmp(answer,"OK")!=0){
    strcpy(error,"6780 - Error decrypting the configuration");
    goto CLEANUP;
 }
 free(replyconf);
 bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
 z=bb_decode_base64(encpkb64,encpk);
 encpk[z]=0;
 len_newreply=strlen(reply)+8192;
 newreply=malloc(len_newreply);
 memset(newreply,0x0, len_newreply);
 strcpy(newreply,"{\"answer\":\"OK\",\"message\":\"Chats list\",\"chats\":[");
 //DECRYPT MSG BODIES
 while(1){
       jr=bb_json_getvalue_fromarray("chats",reply,c);
       if(jr==NULL)
         break;
       //DO NOT DECRYPT "received", "read","status","typing"
       bb_json_getvalue("msgtype",jr,msgtype,255);
       if(strcmp(msgtype,"received")==0 || strcmp(msgtype,"read")==0
       || strcmp(msgtype,"status")==0 || strcmp(msgtype,"typing")==0 || strcmp(msgtype,"deleted")==0){
            if(c>0) strcat(newreply,",");
            strcat(newreply,jr);
            c++;
            memset(jr,0x0,jrlen);
            free(jr);
            continue;
       }
       //DECRYPT BODYMSG
       jrlen=strlen(jr);
       len_tmsgencb64=jrlen;
       tmsgencb64=malloc(len_tmsgencb64);
       bb_json_getvalue("msgbody",jr,tmsgencb64,len_tmsgencb64);
       len_tmsgenc=jrlen;
       tmsgenc=malloc(len_tmsgenc);
       len_tmsgenc=bb_decode_base64(tmsgencb64,tmsgenc);
       tmsgenc[len_tmsgenc]=0;
       tmsg=bb_decrypt_buffer_ec(&len_tmsg,encpk,tmsgenc);
       if(tmsg==NULL){
          tmsg=malloc(64);
          strcpy(tmsg,"Error decrypting content");
          len_tmsg=strlen(tmsg);
       }
       else
          tmsg[len_tmsg]=0;
       //JSON ESCAPE
       char *tmsgbuf=NULL;
       int len_tmsgescaped;
       tmsgbuf=malloc(len_tmsg+64);
       strncpy(tmsgbuf,tmsg,len_tmsg+63);
       free(tmsg);
       tmsg=malloc(len_tmsg*2+64);
       len_tmsgescaped=bb_json_escapestr(tmsgbuf,tmsg,len_tmsg*2+64);
       free(tmsgbuf);
       //END JSON ESCAPE
       
       //FOR MSGTYPE=FILE
       originfilename[0]=0;
       if(strcmp(msgtype,"file")==0){
           sp=strstr(tmsg,"#####");
           if(sp==NULL){
                  strcpy(error,"15006 - Decryption key for filename has not been found ");
                  strncat(error,tmsg,64);
                  goto CLEANUP;
           }
           strncpy(keyfileb64,sp+5,2047);
           if(verbose) printf("keyfileb64: %s\n",keyfileb64);
           j=bb_decode_base64(keyfileb64,keyfile);
           if(j<=0){
               strcpy(error,"Error decoding keyfileb64 (1)");
               goto CLEANUP;
           }
           keyfile[j]=0;
           if(verbose) printf("keyfile: %s\n",keyfile);
           originfilename[0]=0;
           bb_json_getvalue("originfilename",keyfile,originfilename,255);
           if(verbose) printf("originfilename: %s\n",originfilename);
           j=strlen(tmsg)-1;
           strncpy(tmsg,originfilename,j);
           
        }
       //END MSGTYPE=FILE
       njr=bb_str_replace(jr,tmsgencb64,tmsg);
       len_njr=strlen(njr);
       //ADD FIELD IN CASE OF FILE
       if(strcmp(msgtype,"file")==0){
          buf=malloc(len_njr+512+strlen(originfilename));
          memset(buf,0x0,len_njr+512);
          strncpy(buf,njr,len_njr);
          memset(njr,0x0,len_njr);
          free(njr);
          len_njr=strlen(buf);
          buf[len_njr-1]=0;
          strcat(buf,",\"originfilename\":\"");
          strcat(buf,originfilename);
          strcat(buf,"\"}");
          njr=malloc(strlen(buf)+256);
          strcpy(njr,buf);
          len_njr=strlen(njr);
          memset(buf,0x0,strlen(buf));
          free(buf);
       }
       memset(tmsgencb64,0x0,len_tmsgencb64);
       memset(tmsgenc,0x0,len_tmsgenc);
       memset(tmsg,0x0,len_tmsg);
       free(tmsgencb64);
       free(tmsgenc);
       free(tmsg);
       if(strlen(njr)<=strlen(jr)){
           if(c>0) strcat(newreply,",");
           strncat(newreply,njr,len_njr);
       }
       c++;
       free(jr);
       free(njr);
 }
 strcat(newreply,"]}");
 if(reply!=NULL){
  memset(reply,0x0,strlen(reply));
  free(reply);
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(newreply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 if(reply!=NULL){
  memset(reply,0x0,strlen(reply));
  free(reply);
 }
 return(replyerror);
}
/**
* SEND ALERT TO A RECIPIENT OR MEMBERS OF A GROUP CHAT
*/
char * bb_send_systemalert(char *recipient,char *groupid,char *txt,char *pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[8192];
 char action[64];
 char answer[64];
 char recipientl[64];
 error[0]=0;
 if(strlen(groupid)==0 && strlen(recipient)==0){
       strcpy(error,"Group id or recipient is mandatory");
       goto CLEANUP;
 }
 if(strlen(groupid)>32){
       strcpy(error,"Group id is too long");
       goto CLEANUP;
 }
 if(strlen(recipient)>32){
       strcpy(error,"Recipient id is too long");
       goto CLEANUP;
 }
 if(strlen(txt)>4192){
       strcpy(error,"txt field is too long");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       strcpy(error,"configuration is missing");
       goto CLEANUP;
 }
 //SEND SYSTEM ALERT TO SINGLE RECIPIENT
 if(strlen(recipient)>0 && strlen(groupid)==0){
     strncpy(action,"systemalert",63);
     sprintf(requestjson,"{\"action\":\"%s\",\"recipient\":\"%s\",\"groupid\":\"%s\",\"txt\":\"%s\"}",action,recipient,groupid,txt);
     reply=bb_send_request_server(requestjson,action,pwdconf);
     if(reply==NULL){
          strcpy(error,"No reply from server, please try later");
           goto CLEANUP;
     }
     memset(error,0x0,256);
     memset(action,0x0,64);
     memset(requestjson,0x0,2048);
     return(reply);
 }
 //SEND SYSTEM MESSAGE TO GROUP CHAT
 if(strlen(groupid)>0){
     char *gc;
     char *jr;
     int c;
     gc=bb_get_list_members_groupchat(groupid,pwdconf);
     answer[0]=0;
     bb_json_getvalue("answer",gc,answer,63);
     if(strcmp(answer,"KO")==0){
         bb_json_getvalue("message",gc,error,127);
         free(gc);
         goto CLEANUP;
     }
     //LOOP FOR EACH MEMBER OF THE GROUP
     c=0;
     while(1){
       jr=bb_json_getvalue_fromarray("members",gc,c);
       if(jr==NULL)
         break;
       recipientl[0]=0;
       bb_json_getvalue("mobilenumber",jr,recipientl,63);
       if(strlen(recipientl)>0){
           strncpy(action,"systemalert",63);
           sprintf(requestjson,"{\"action\":\"%s\",\"recipient\":\"%s\",\"groupid\":\"%s\",\"txt\":\"%s\"}",action,recipientl,groupid,txt);
           reply=bb_send_request_server(requestjson,action,pwdconf);
           if(reply==NULL){
                strcpy(error,"No reply from server, please try later");
                free(jr);
                free(gc);
                goto CLEANUP;
                
           }
           free(reply);
       }
       free(jr);
       c++;
     }
     free(gc);
     memset(error,0x0,256);
     memset(action,0x0,64);
     memset(requestjson,0x0,8192);
     reply=malloc(512);
     strncpy(reply,"{\"answer\":\"OK\",\"message\":\"System alert has been sent\"}",512);
     return(reply);
 }

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,8192);
 return(replyerror);
}
/**
* FUNCTION TO CREATE NEW GROUP CHAT,THE RESULT MUST BE FREE()\n
* RETURNS GROUPID IF SUCCESSFULLY
*/
char * bb_new_groupchat(char *groupdescription,char *pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(groupdescription)==0){
       strcpy(error,"Group description is missing");
       goto CLEANUP;
 }
 if(strlen(groupdescription)>256){
       strcpy(error,"Group description is too long");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       strcpy(error,"configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"newgroupchat",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"groupdescription\":\"%s\"}",action,groupdescription);
 
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO CHANGE GROUP CHAT DESCTIPTION,THE RESULT MUST BE FREE()\n
* RETURN GROUPID IF SUCCESSFULLY
*/
char * bb_change_groupchat(char *groupdescription,char *groupid,char *pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(groupdescription)==0){
       sprintf(error,"%s","Group description is missing");
       goto CLEANUP;
 }
 if(strlen(groupdescription)>256){
       sprintf(error,"%s","Group description is too long");
       goto CLEANUP;
 }
 if(strlen(groupid)==0){
       sprintf(error,"%s","Group id is missing");
       goto CLEANUP;
 }
 if(strlen(groupid)>16){
       sprintf(error,"%s","Group id is too long");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"changegroupchat",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"groupdescription\":\"%s\",\"groupid\":\"%s\"}",action,groupdescription,groupid);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO SET EXPIRING DATE OF A GROUP CHAT THE  RESULT MUST BE FREE()
*/
char * bb_setexpiringdate_groupchat(char *expiringdate,char *groupid,char *pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(expiringdate)==0){
       sprintf(error,"%s","Expiring date is missing");
       goto CLEANUP;
 }
 if(strlen(expiringdate)>19){
       sprintf(error,"%s","Expiring date is too long");
       goto CLEANUP;
 }
  if(strlen(expiringdate)!=19){
       sprintf(error,"%s","Expiring date must be 19 char in sql date/time format (YYYY-MM-DD HH:MM:SS)");
       goto CLEANUP;
 }
 if(strlen(groupid)==0){
       sprintf(error,"%s","Group id is missing");
       goto CLEANUP;
 }
 if(strlen(groupid)>16){
       sprintf(error,"%s","Group id is too long");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"setexpiringdategroupchat",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"groupexpiringdate\":\"%s\",\"groupid\":\"%s\"}",action,expiringdate,groupid);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}

/**
* FUNCTION TO ADD MEMBER TO A GROUP ,THE RESULT MUST BE FREE()
*/
char * bb_add_member_groupchat(char *groupid,char *phonenumber,char *pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(phonenumber)==0){
       sprintf(error,"%s","Phone number is missing");
       goto CLEANUP;
 }
 if(strlen(phonenumber)>256){
       sprintf(error,"%s","Phone number is too long");
       goto CLEANUP;
 }
 if(strlen(groupid)==0){
       sprintf(error,"%s","Group id is missing");
       goto CLEANUP;
 }
 if(strlen(groupid)>16){
       sprintf(error,"%s","Group id is too long");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"addmembergroupchat",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"groupid\":\"%s\",\"role\":\"normal\",\"phonenumber\":\"%s\"}",action,groupid,phonenumber);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO REVOKE MEMBER FROM A GROUP ,THE RESULT MUST BE FREE()
*/
char * bb_revoke_member_groupchat(char *groupid,char *phonenumber,char *pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 char mobilenumber[64];
 int x;
 error[0]=0;
 if(strlen(phonenumber)==0){
       sprintf(error,"%s","Phone number is missing");
       goto CLEANUP;
 }
 if(strlen(phonenumber)>256){
       sprintf(error,"%s","Phone number is too long");
       goto CLEANUP;
 }
 if(strlen(groupid)==0){
       sprintf(error,"%s","Group id is missing");
       goto CLEANUP;
 }
 if(strlen(groupid)>16){
       sprintf(error,"%s","Group id is too long");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","configuration is missing");
       goto CLEANUP;
 }
 x=bb_json_getvalue("mobilenumber",pwdconf,mobilenumber,63);
 mobilenumber[x]=0;
 if(strcmp(mobilenumber,phonenumber)==0){
       sprintf(error,"%s","you cannot cancel your number, you should delete the group");
       goto CLEANUP;
 }
 strncpy(action,"revokemembergroupchat",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"groupid\":\"%s\",\"phonenumber\":\"%s\"}",action,groupid,phonenumber);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO CHANGE ROLE OF A MEMBER OF THE GROUP ,THE RESULT MUST BE FREE()
*/
char * bb_change_role_member_groupchat(char *groupid,char *phonenumber,char *role,char *pwdconf){

 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(phonenumber)==0){
       sprintf(error,"%s","Phone number is missing");
       goto CLEANUP;
 }
 if(strlen(phonenumber)>256){
       sprintf(error,"%s","Phone number is too long");
       goto CLEANUP;
 }
 if(strlen(groupid)==0){
       sprintf(error,"%s","Group id is missing");
       goto CLEANUP;
 }
 if(strlen(groupid)>16){
       sprintf(error,"%s","Group id is too long");
       goto CLEANUP;
 }
 if(strlen(role)==0){
       sprintf(error,"%s","Role is missing");
       goto CLEANUP;
 }
 if(strcmp(role,"administrator")!=0 && strcmp(role,"normal")!=0){
       sprintf(error,"%s","Role is wrong.(administrator/normal)");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"changerolemembergroupchat",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"groupid\":\"%s\",\"role\":\"%s\",\"phonenumber\":\"%s\"}",action,groupid,role,phonenumber);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO GET LIST OF OWN GROUPS,THE RESULT MUST BE FREE()
*/
char * bb_get_list_groupchat(char *pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 char mobilenumber[64];
 int x;
 error[0]=0;
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"getlistgroupchat",63);
 sprintf(requestjson,"{\"action\":\"%s\"}",action);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO DELETE A GROUP CHAT ,THE RESULT MUST BE FREE()
*/
char * bb_delete_groupchat(char *groupid,char *pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 char mobilenumber[64];
 int x;
 error[0]=0;
 if(strlen(groupid)==0){
       sprintf(error,"%s","Group id is missing");
       goto CLEANUP;
 }
 if(strlen(groupid)>16){
       sprintf(error,"%s","Group id is too long");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"deletegroupchat",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"groupid\":\"%s\"}",action,groupid);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO GET MEMBERS LIST OF A GROUP CHAT, THE RESULT MUST BE FREE()
*/
char * bb_get_list_members_groupchat(char *groupid,char *pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 char mobilenumber[64];
 int x;
 error[0]=0;
 if(strlen(groupid)==0){
       sprintf(error,"%s","Group id is missing");
       goto CLEANUP;
 }
 if(strlen(groupid)>16){
       sprintf(error,"%s","Group id is too long");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"listmembersgroupchat",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"groupid\":\"%s\"}",action,groupid);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}

/**
* FUNCTION TO SEND REQUEST TO SERVER,THE RESULT MUST BE FREE()
*/
char * bb_send_request_server(char *requestjson,char * action,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    char filename[512];
    char recipient[64];
    char *replyconf;
    if(strlen(requestjson)==0){
        strcpy(error,"3703 - requestjson field cannot be empty\n");
        goto CLEANUP;
    }
    // SET SERVER ACCOUNT
    strcpy(recipient,"0000001");
    sprintf(bodymsg,"%s",requestjson);
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"3707 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "3708 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"3709 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"3710 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"3711- error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
           bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"3812 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"3813 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%u%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"%s\",\"sender\":\"%s\",\"recipient\":\"0000001\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",action,sender,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO ADD A CONTACT, THE RESULT MUS BE FREE()
*/
char * bb_add_contact(char *contactjson,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[8192];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    char filename[512];
    char recipient[64];
    char *replyconf;
    char idassigned[128];
    if(strlen(contactjson)==0){
        strcpy(error,"3703 - contactjson field cannot be empty\n");
        goto CLEANUP;
    }
    // SET SERVER ACCOUNT
    strcpy(recipient,"0000001");
    strncpy(bodymsg,contactjson,8191);
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"3707 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "3708 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"3709 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"3710 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"3711- error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
           bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"3812 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"3813 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%u%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"addcontact\",\"sender\":\"%s\",\"recipient\":\"0000001\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   bb_json_getvalue("id",reply,idassigned,127);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO UPDATE A CONTACT, THE RESULT MUST BE FREE()
*/
char * bb_update_contact(char *contactjson,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[8192];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    char filename[512];
    char recipient[64];
    char *replyconf;
    if(strlen(contactjson)==0){
        strcpy(error,"3703 - contactjson field cannot be empty\n");
        goto CLEANUP;
        
    }
    if(strlen(contactjson)>8191){
        strcpy(error,"3704 - contactjson field is too long\n");
        goto CLEANUP;
    }
    // SET SERVER ACCOUNT
    strcpy(recipient,"0000001");
    strncpy(bodymsg,contactjson,8191);
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"3707 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "3708 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"3709 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"3710 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"3711- error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
           bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"3812 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"3813 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%u%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"updatecontact\",\"sender\":\"%s\",\"recipient\":\"0000001\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO DELETE A CONTACT, THE RESULT MUS BE FREE()
*/
char * bb_delete_contact(char *contactid,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    char filename[512];
    char recipient[64];
    char *replyconf;
    if(strlen(contactid)==0){
        strcpy(error,"3801 - contactid field cannot be empty\n");
        goto CLEANUP;
    }
    // SET SERVER ACCOUNT
    strcpy(recipient,"0000001");
    sprintf(bodymsg,"{\"contactid\":\"%s\"}",contactid);
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"3802 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "3803 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"3804 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"3805 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"3806- error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
           bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"3807 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"3809 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%u%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"deletecontact\",\"sender\":\"%s\",\"recipient\":\"0000001\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(256);
   strcpy(replysend,"{\"answer\":\"OK\",\"message\":\"Contact has been deleted\"}");
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO SEARCH/GET CONTACT, THE RESULT MUST BE FREE()
*/
char * bb_get_contacts(char *search,int contactid,int flagsearch,int limitsearch,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    char filename[512];
    char recipient[64];
    char *replyconf;
    // SET SERVER ACCOUNT
    strcpy(recipient,"0000001");
    sprintf(bodymsg,"{\"search\":\"%s\",\"contactid\":\"%d\",\"flagsearch\":\"%d\",\"limitsearch\":\"%d\"}",search,contactid,flagsearch,limitsearch);
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"3802 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "3803 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"3804 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"3805 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"3806- error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
           bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"3807 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"3809 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%u%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getcontacts\",\"sender\":\"%s\",\"recipient\":\"0000001\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}

/**
* FUNCTION TO UPDATE PHOTO OF GROUP CHAT\n
* SENDING AN ECNRYPTED PHOTO TO SYSTEM USER
*/
char * bb_update_photo_groupchat(char *filename,char * groupid,char *pwdconf)
{
    char *reply=NULL;
    char bodymsg[512];
    char buf[128];
    char error[512];
    int x;
    memset(error,0x0,512);
    if(strlen(filename)<5 || strlen(filename)>511){
         strcpy(error,"11200 - File name is wrong");
         goto CLEANUP;
    }
    if(atol(groupid)==0){
         strcpy(error,"11201 - Group id is missing or is wrong");
         goto CLEANUP;
    }
    if(strlen(pwdconf)==0){
         strcpy(error,"11202 - configuration is  wrong");
         goto CLEANUP;
    }
    if(access(filename,F_OK|R_OK)==-1){
         strcpy(error,"11203 - File name is not readable");
         goto CLEANUP;
    }
    x=strlen(filename);
    memset(buf,0x0,128);
    strcpy(buf,&filename[x-4]);
    if(strcmp(buf,".jpg")!=0 && strcmp(buf,"jpeg")!=0){
         sprintf(error,"11204 - File name must .jpg or .jpeg %s",buf);
         goto CLEANUP;
    }
    sprintf(bodymsg,"{\"action\":\"updategroupphoto\",\"groupid\":\"%ld\"}",atol(groupid));
    reply=bb_send_photo(filename,bodymsg,pwdconf);
    if(reply!=NULL)
       return(reply);
    else{
        strcpy(error,"11204 - Error uploading the photo");
        goto CLEANUP;
    }
    CLEANUP:
    memset(bodymsg,0x0,512);
    reply=malloc(512);
    sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
    memset(error,0x0,64);
    return(reply);
}
/**
* FUNCTION TO UPDATE PHOTO OF THE PROFILE
* SENDING AN ECNRYPTED PHOTO TO SYSTEM USER
*/
char * bb_update_photo_profile(char *filename,char *pwdconf)
{
    char *reply=NULL;
    char bodymsg[512];
    char buf[128];
    char error[512];
    int x;
    memset(error,0x0,512);
    if(strlen(filename)<5 || strlen(filename)>511){
         strcpy(error,"11200 - File name is wrong");
         goto CLEANUP;
    }
    if(strlen(pwdconf)==0){
         strcpy(error,"11201 - configuration is  wrong");
         goto CLEANUP;
    }
    if(access(filename,F_OK|R_OK)==-1){
         strcpy(error,"11202 - File name is not readable");
         goto CLEANUP;
    }
    x=strlen(filename);
    memset(buf,0x0,128);
    strcpy(buf,&filename[x-4]);
    if(strcmp(buf,".jpg")!=0 && strcmp(buf,"jpeg")!=0){
         sprintf(error,"11203 - File name must .jpg or .jpeg %s",buf);
         goto CLEANUP;
    }
    strcpy(bodymsg,"{\"action\":\"updateprofilephoto\"}");
    reply=bb_send_photo(filename,bodymsg,pwdconf);
    if(reply!=NULL)
       return(reply);
    else{
        strcpy(error,"11204 - Error uploading the photo");
        goto CLEANUP;
    }
    CLEANUP:
    memset(bodymsg,0x0,512);
    reply=malloc(512);
    sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
    memset(error,0x0,64);
    return(reply);
}
/**
* FUNCTION TO SEND A FILE
* RETURN AN ANSWER THAT MUST BE FREE()
*/
char * bb_send_file(char *originfilename,char * recipient,char *bodymsg,char *pwdconf,char *repliedto,char *repliedtotxt){
    char *msg=NULL;
    char *crt=NULL;
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend=NULL;
    char *cachefilename=NULL;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[512];
    char filenamenopath[512];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char filenameenc[512];
    char filepwd[1024];
    char filepwdb64[2048];
    int filesize;
    char *ss=NULL;
    char *newbodymsg=NULL;
    int len_newbodymsg=0;
    char *replyconf;
    char serverfilename[256];
    char serverfilenamepath[512];
    char bufx[512];
    int j;
    char serverfilenamepathenc[512];
    char cachefilenameenc[512];
    char repliedtotxtenc[8192];
    char repliedtotxtencb64[16384];
    char repliedtotxtencb64r[16384];
    memset(repliedtotxtenc,0x0,8192);
    memset(repliedtotxtencb64,0x0,16384);
    memset(repliedtotxtencb64r,0x0,16384);

    if(strlen(originfilename)==0 || strlen(originfilename)>255){
        strcpy(error,"2800 - file name is wrong");
        goto CLEANUP;
    }
    if(access(originfilename,F_OK )== -1){
       sprintf(error,"2801 - file name is not accessible or it does not exist [%s]",originfilename);
        goto CLEANUP;
    }
    if(strlen(recipient)==0){
        strcpy(error,"2802 - Recipient is missing");
        goto CLEANUP;
    }
    if(repliedto==NULL || strlen(repliedto)>32){
        strcpy(error,"2802a - Repliedto is wrong");
        goto CLEANUP;
    }
    if(repliedtotxt==NULL || strlen(repliedtotxt)>256){
        strcpy(error,"2802b - Repliedtotxt is wrong");
        goto CLEANUP;
    }
    //MAKE COPY IN THE LOCAL CACHE OF THE ORIGINAL FILE
    cachefilename=bb_copy_file_to_cache(originfilename);
    if(cachefilename==NULL){
     sprintf(error,"2802a - impossibile to copy the original file name [%s] to local cache",originfilename);
     goto CLEANUP;
    }
    if(verbose) printf("#### cachefilename: %s\n",cachefilename);

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   //END LOADING CONFIGURATION
   //ENCRYPT FILE TO SEND, GET HASH AND SIZE
   //   strncpy(filenamenopath,originfilename,511);
   //   bb_strip_path(filenamenopath);
   //   sprintf(filenameenc,"%s/%s.enc",getenv("TMPDIR"),filenamenopath);
   sprintf(filenameenc,"%s.enc",cachefilename);
//   if(!bb_encrypt_file(originfilename,filenameenc,filepwd)){
   if(!bb_encrypt_file(cachefilename,filenameenc,filepwd)){
       strcpy(error,"2825 - error encrypting file\n");
       goto CLEANUP;
   }
   if(verbose) printf("filenameenc: %s\n",filenameenc);
   if(!bb_encode_base64(filepwd,strlen(filepwd),filepwdb64)){
       strcpy(error,"2826 - error encoding file pwd\n");
       goto CLEANUP;
   }
   stat(filenameenc, &sb);
   filesize=sb.st_size;
   //if(verbose) printf("File pwd: %s\n",filepwd);
   // END FILE ENCRYPTION
   // CREATE NEW  BODYMSG
   len_newbodymsg=strlen(bodymsg)+strlen(filepwdb64)+64;
   newbodymsg=malloc(len_newbodymsg);
   if(newbodymsg==NULL){
       strcpy(error,"2827 - error allocating var space\n");
       goto CLEANUP;
   }
   sprintf(newbodymsg,"%s#####%s",bodymsg,filepwdb64);
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2806 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2807 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2808 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2809 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2810 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(newbodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(newbodymsg,strlen(newbodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"2811 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //ENCRYPT REPLIEDTOTXT IF PRESENT FOR RECIPIENT
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64r,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificate,repliedtotxtenc)){
        strcpy(error,"1613a - error encrypting the repliedtotxt by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64r);
   }
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(newbodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(newbodymsg,strlen(newbodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"2712 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //ENCRYPT REPLIEDTOTXT FOR SENDER
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificater,repliedtotxtenc)){
        strcpy(error,"1613b - error encrypting the repliedtotxt for recipient by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64);
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(newbodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"sendfile%s%s%s%u,%s",sender,recipient,newbodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken)+strlen(repliedto)+strlen(repliedtotxtencb64)+strlen(repliedtotxtencb64r);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"sendfile\",\"sender\":\"%s\",\"recipient\":\"%s\",\"filesize\":\"%d\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"repliedto\":\"%s\",\"repliedtotxtsender\":\"%s\",\"repliedtotxtrecipient\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,filesize,bodymsgencb64,bodymsgencb64r,repliedto,repliedtotxtencb64,repliedtotxtencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendfile(bbhostname,bbport,msg,&lenreply,filenameenc);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   //printf("######## %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   //COPY THE CACHEFILENAME TO FILENAME ASSIGNED FROM SERVER
   serverfilename[0]=0;
   bb_json_getvalue("filename",reply,serverfilename,255);

   if(strlen(serverfilename)>0 && strlen(cachefilename)>0)
   {
         sprintf(serverfilenamepath,"%s/Documents/test/%s",getenv("HOME"),serverfilename);
         rename(cachefilename,serverfilenamepath);
         sprintf(serverfilenamepathenc,"%s/Documents/test/%s.enc",getenv("HOME"),serverfilename);
         sprintf(cachefilenameenc,"%s.enc",cachefilename);
         rename(cachefilenameenc,serverfilenamepathenc);
         
   }
   replysend=malloc(strlen(reply)+512);
   sprintf(bufx,",\"localfilename\":\"%s\"}",serverfilenamepath);
   j=strlen(reply);
   strncpy(replysend,reply,j-1);
   replysend[j-1]=0;
   strncat(replysend,bufx,511);
   
   //CLEAN UP FOR EXIT
   if(cachefilename!=NULL) free(cachefilename);
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   if(newbodymsg!=NULL) free(newbodymsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   memset(filenameenc,0x0,512);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   return(replysend);
    
   CLEANUP:
   if(cachefilename!=NULL) free(cachefilename);
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(newbodymsg!=NULL) free(newbodymsg);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(filenameenc,0x0,512);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}

/**
* FUNCTION TO SEND A FILE\n
* RETURN AN ANSWER THAT MUST BE FREE()
*/
char * bb_send_photo(char *originfilename,char *bodymsg,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend=NULL;
    char *cachefilename=NULL;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    char recipient[64];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[512];
    char filenamenopath[512];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char filenameenc[512];
    char filepwd[1024];
    char filepwdb64[2048];
    int filesize;
    char *ss=NULL;
    char *newbodymsg=NULL;
    int len_newbodymsg=0;
    char *replyconf;
    char serverfilename[256];
    char serverfilenamepath[512];
    char bufx[512];
    int j,ii;
    char serverfilenamepathenc[512];
    char cachefilenameenc[512];
    char repliedtotxtenc[8192];
    char repliedtotxtencb64[16384];
    char repliedtotxtencb64r[16384];
    memset(repliedtotxtenc,0x0,8192);
    memset(repliedtotxtencb64,0x0,16384);
    memset(repliedtotxtencb64r,0x0,16384);

    if(strlen(originfilename)==0 || strlen(originfilename)>255){
        strcpy(error,"2800 - file name is wrong");
        goto CLEANUP;
    }
    if(access(originfilename,F_OK )== -1){
       sprintf(error,"2801 - file name is not accessible or it does not exist [%s]",originfilename);
        goto CLEANUP;
    }
    strcpy(recipient,"0000001");
    //MAKE COPY IN THE LOCAL CACHE OF THE ORIGINAL FILE
    cachefilename=bb_copy_file_to_cache(originfilename);
    if(cachefilename==NULL){
     sprintf(error,"2802a - impossibile to copy the original file name [%s] to local cache",originfilename);
     goto CLEANUP;
    }
    if(verbose) printf("#### cachefilename: %s\n",cachefilename);

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   //END LOADING CONFIGURATION
   //ENCRYPT FILE TO SEND, GET HASH AND SIZE
   //   strncpy(filenamenopath,originfilename,511);
   //   bb_strip_path(filenamenopath);
   //   sprintf(filenameenc,"%s/%s.enc",getenv("TMPDIR"),filenamenopath);
   sprintf(filenameenc,"%s.enc",cachefilename);
//   if(!bb_encrypt_file(originfilename,filenameenc,filepwd)){
   if(!bb_encrypt_file(cachefilename,filenameenc,filepwd)){
       strcpy(error,"2825 - error encrypting file\n");
       goto CLEANUP;
   }
   if(verbose) printf("filenameenc: %s\n",filenameenc);
   if(!bb_encode_base64(filepwd,strlen(filepwd),filepwdb64)){
       strcpy(error,"2826 - error encoding file pwd\n");
       goto CLEANUP;
   }
   stat(filenameenc, &sb);
   filesize=sb.st_size;
   //if(verbose) printf("File pwd: %s\n",filepwd);
   // END FILE ENCRYPTION
   // CREATE NEW  BODYMSG
   len_newbodymsg=strlen(bodymsg)+strlen(filepwdb64)+64;
   newbodymsg=malloc(len_newbodymsg);
   if(newbodymsg==NULL){
       strcpy(error,"2827 - error allocating var space\n");
       goto CLEANUP;
   }
   ii=strlen(bodymsg);
   bodymsg[ii-1]=0;
   sprintf(newbodymsg,"%s,\"filepwd\":\"%s\"}",bodymsg,filepwdb64);
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2806 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2807 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2808 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2809 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2810 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(newbodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(newbodymsg,strlen(newbodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"2811 - error encrypting the message by EC");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(newbodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(newbodymsg,strlen(newbodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"2712 - error encrypting the message by EC");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(newbodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"sendphoto%s%s%s%u,%s",sender,recipient,newbodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"sendphoto\",\"sender\":\"%s\",\"recipient\":\"%s\",\"filesize\":\"%d\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,filesize,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendfile(bbhostname,bbport,msg,&lenreply,filenameenc);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   //printf("######## %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   //COPY THE CACHEFILENAME TO FILENAME ASSIGNED FROM SERVER
   serverfilename[0]=0;
   bb_json_getvalue("filename",reply,serverfilename,255);

   if(strlen(serverfilename)>0 && strlen(cachefilename)>0)
   {
         sprintf(serverfilenamepath,"%s/Documents/test/%s",getenv("HOME"),serverfilename);
         rename(cachefilename,serverfilenamepath);
         sprintf(serverfilenamepathenc,"%s/Documents/test/%s.enc",getenv("HOME"),serverfilename);
         sprintf(cachefilenameenc,"%s.enc",cachefilename);
         rename(cachefilenameenc,serverfilenamepathenc);
         
   }
   replysend=malloc(strlen(reply)+512);
   sprintf(bufx,",\"localfilename\":\"%s\"}",serverfilenamepath);
   j=strlen(reply);
   strncpy(replysend,reply,j-1);
   replysend[j-1]=0;
   strncat(replysend,bufx,511);
   
   //CLEAN UP FOR EXIT
   if(cachefilename!=NULL) free(cachefilename);
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   memset(filenameenc,0x0,512);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   return(replysend);
    
   CLEANUP:
   if(cachefilename!=NULL) free(cachefilename);
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(filenameenc,0x0,512);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO SEND A FILE TO A GROUP ID
* RETURN AN ANSWER THAT MUST BE FREE()
*/
char * bb_send_file_membergroupchat(char *originfilename,char * recipient,char *bodymsg,char * groupid,char *pwdconf,char *repliedto,char *repliedtotxt,char *msgref){
    char *msg=NULL;
    char *crt=NULL;
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[512];
    char filenamenopath[512];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char filenameenc[512];
    char filepwd[1024];
    char filepwdb64[2048];
    int filesize;
    char *ss=NULL;
    char *newbodymsg=NULL;
    int len_newbodymsg=0;
    char *replyconf;
    char * cachefilename=NULL;
    char serverfilenamepathenc[512];
    char cachefilenameenc[512];
    char serverfilename[256];
    char serverfilenamepath[512];
    char bufx[512];
    int j;
    char repliedtotxtenc[8192];
    char repliedtotxtencb64[16384];
    char repliedtotxtencb64r[16384];
    memset(repliedtotxtenc,0x0,8192);
    memset(repliedtotxtencb64,0x0,16384);
    memset(repliedtotxtencb64r,0x0,16384);
    
    if(strlen(originfilename)==0 || strlen(originfilename)>255){
        strcpy(error,"2800 - file name is wrong");
        goto CLEANUP;
    }
    if(access(originfilename,F_OK )== -1){
       sprintf(error,"2801 - file name is not accessible or it does not exist [%s]",originfilename);
        goto CLEANUP;
    }
    if(strlen(recipient)==0){
        strcpy(error,"2802 - Recipient is missing");
        goto CLEANUP;
    }
    if(strlen(groupid)==0){
        strcpy(error,"2803 - Group id is missing");
        goto CLEANUP;
    }
    if(strlen(groupid)>63){
        strcpy(error,"2804 - Group id is too long");
        goto CLEANUP;
    }
    if(strlen(bodymsg)>256000){
        strcpy(error,"2804 - Text message is too long");
        goto CLEANUP;
    }
    if(repliedto==NULL || strlen(repliedto)>32){
        strcpy(error,"2804a - Repliedto is wrong");
        goto CLEANUP;
    }
    if(repliedtotxt==NULL || strlen(repliedtotxt)>256){
        strcpy(error,"2804b - Repliedtotxt is wrong");
        goto CLEANUP;
    }
    //MAKE COPY IN THE LOCAL CACHE OF THE ORIGINAL FILE
    cachefilename=bb_copy_file_to_cache(originfilename);
    if(cachefilename==NULL){
     sprintf(error,"2802a - impossibile to copy the original file name [%s] to local cache",originfilename);
     goto CLEANUP;
    }
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   //END LOADING CONFIGURATION
   //ENCRYPT FILE TO SEND, GET HASH AND SIZE
   //   strncpy(filenamenopath,originfilename,511);
   //   bb_strip_path(filenamenopath);
   //   sprintf(filenameenc,"%s/%s.enc",getenv("TMPDIR"),filenamenopath);
   sprintf(filenameenc,"%s.enc",originfilename);
   if(!bb_encrypt_file(cachefilename,filenameenc,filepwd)){
       strcpy(error,"2825 - error encrypting file\n");
       goto CLEANUP;
   }
   if(!bb_encode_base64(filepwd,strlen(filepwd),filepwdb64)){
       strcpy(error,"2826 - error encoding file pwd\n");
       goto CLEANUP;
   }
   stat(filenameenc, &sb);
   filesize=sb.st_size;
   //if(verbose) printf("File pwd: %s\n",filepwd);
   // END FILE ENCRYPTION
   // CREATE NEW  BODYMSG
   len_newbodymsg=strlen(bodymsg)+strlen(filepwdb64)+64;
   newbodymsg=malloc(len_newbodymsg);
   if(newbodymsg==NULL){
       strcpy(error,"2827 - error allocating var space\n");
       goto CLEANUP;
   }
   sprintf(newbodymsg,"%s#####%s",bodymsg,filepwdb64);
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2806 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2807 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2808 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2809 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2810 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(newbodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(newbodymsg,strlen(newbodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"2811 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //ENCRYPT REPLIEDTOTXT IF PRESENT FOR RECIPIENT
   memset(repliedtotxtencb64,0x0,16384);
   memset(repliedtotxtencb64r,0x0,16384);
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64r,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificate,repliedtotxtenc)){
        strcpy(error,"1613a - error encrypting the repliedtotxt by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64r);
   }
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(newbodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(newbodymsg,strlen(newbodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"2712 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //ENCRYPT REPLIEDTOTXT FOR SENDER
   if(strlen(repliedtotxt)>0){
      memset(repliedtotxtenc,0x0,8192);
      memset(repliedtotxtencb64,0x0,16384);
      if(!bb_encrypt_buffer_ec(repliedtotxt,strlen(repliedtotxt),encryptioncertificater,repliedtotxtenc)){
        strcpy(error,"1613b - error encrypting the repliedtotxt for recipient by EC\n");
        goto CLEANUP;
      }
      bb_encode_base64(repliedtotxtenc,strlen(repliedtotxtenc),repliedtotxtencb64);
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(newbodymsg)+strlen(bbtoken)+strlen(groupid)+8192;
   buf=malloc(buflen);
   sprintf(buf,"sendfile%s%s%s%u,%s",sender,recipient,newbodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken)+strlen(repliedto)+strlen(repliedtotxtencb64)+strlen(repliedtotxtencb64r)+strlen(groupid)+strlen(msgref);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"sendfile\",\"sender\":\"%s\",\"recipient\":\"%s\",\"groupid\":\"%s\",\"filesize\":\"%d\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"repliedto\":\"%s\",\"repliedtotxtsender\":\"%s\",\"repliedtotxtrecipient\":\"%s\",\"msgref\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,groupid,filesize,bodymsgencb64,bodymsgencb64r,repliedto,repliedtotxtencb64,repliedtotxtencb64r,msgref,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendfile(bbhostname,bbport,msg,&lenreply,filenameenc);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   //COPY THE CACHEFILENAME TO FILENAME ASSIGNED FROM SERVER
   serverfilename[0]=0;
   bb_json_getvalue("filename",reply,serverfilename,255);
   if(strlen(serverfilename)>0 && strlen(cachefilename)>0)
   {
         sprintf(serverfilenamepath,"%s/Documents/test/%s",getenv("HOME"),serverfilename);
         rename(cachefilename,serverfilenamepath);
         sprintf(serverfilenamepathenc,"%s/Documents/test/%s.enc",getenv("HOME"),serverfilename);
         sprintf(cachefilenameenc,"%s.enc",cachefilename);
         rename(cachefilenameenc,serverfilenamepathenc);

   }
   replysend=malloc(strlen(reply)+512);
   sprintf(bufx,",\"localfilename\":\"%s\"}",serverfilenamepath);
   j=strlen(reply);
   strncpy(replysend,reply,j-1);
   replysend[j-1]=0;
   strncat(replysend,bufx,511);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   if(newbodymsg!=NULL) free(newbodymsg);
   if(cachefilename!=NULL) free(cachefilename);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   memset(filenameenc,0x0,512);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   if(cachefilename!=NULL) free(cachefilename);
   if(newbodymsg!=NULL) free(newbodymsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(filenameenc,0x0,512);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO GET AN ENCRYPTED FILE BY UNIQUE NAME\n
* THE FILE MUST BE INSIDE A MESSAGE BELONGING TO THE USER AS RECIPIENT OR SENDER \n
* THE FUNCTION RETURNS AN ANSWER IN JSON FORMAT THAT MUST BE FREE()
*/
char * bb_get_encryptedfile(char *uniquefilename,char *pwdconf){
    char *msg=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,buflen;
    char error[512];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char filenameenc[512];
    char filepwd[1024];
    char filepwdb64[2048];
    char *ss=NULL;
    char *newbodymsg=NULL;
    int len_newbodymsg=0;
    if(strlen(uniquefilename)==0 || strlen(uniquefilename)>255){
        strcpy(error,"2900 - unique file name is wrong");
        goto CLEANUP;
    }
    bb_strip_path(uniquefilename);
    if(strlen(pwdconf)==0){
        strcpy(error,"2901 - pwd configuration is mandatory");
        goto CLEANUP;
    }
    char *replyconf;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // CREATE NEW  BODYMSG
   len_newbodymsg=strlen(uniquefilename)+64;
   newbodymsg=malloc(len_newbodymsg);
   if(newbodymsg==NULL){
       strcpy(error,"2827 - error allocating var space\n");
       goto CLEANUP;
   }
   sprintf(newbodymsg,"%s",uniquefilename);
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2806 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2807 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2808 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2809 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2810 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(uniquefilename)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"getencryptedfile%s%s%u%s",sender,uniquefilename,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(uniquefilename)+strlen(uniquefilename)+strlen(sender)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getencryptedfile\",\"sender\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,uniquefilename,uniquefilename,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_getencryptedfile(bbhostname,bbport,msg,uniquefilename);
   if(verbose) printf("reply from bb_tls_getencryptedfile: %s\n",reply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   filenameenc[0]=0;
   bb_json_getvalue("filename",reply,filenameenc,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(error,0x0,64);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   replysend=malloc(256);
   sprintf(replysend,"{\"answer\":\"OK\",\"message\":\"File download completed.\",\"filename\":\"%s\"}",filenameenc);
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(filenameenc,0x0,512);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO GET AN ENCRYPTED FILE BY UNIQUE NAME IN A THREAD\n
* THE FILE MUST BE INSIDE A MESSAGE BELONGING TO THE USER AS RECIPIENT OR SENDER
*/
void * bb_get_encryptedfile_async(void * threadargv){
    char *msg=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char localfilename[512];
    char *reply=NULL;
    char token[256];
    char answer[64];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,buflen;
    char error[512];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char filenameenc[512];
    char filepwd[1024];
    char filepwdb64[2048];
    char *ss=NULL;
    char *newbodymsg=NULL;
    int len_newbodymsg=0;
    char pwdconf[4096];
    char uniquefilename[1024];
    char keyfile[2048];
    int j,i;
    struct FileDownloadThread *fileparam;
    char originfilename[512];
    
    fileparam=(struct FileDownloadThread *) threadargv;
    if(strlen(fileparam->pwdconf)==0){
       strcpy(error,"2898 - pwdconf is empty");
        goto CLEANUP;
    }
    if(strlen(fileparam->uniquefilename)==0){
       strcpy(error,"2899 - uniquefilename is empty");
        goto CLEANUP;
    }
    if(strlen(fileparam->keyfile)==0){
       strcpy(error,"2897 - keyfile is empty");
        goto CLEANUP;
    }
    strncpy(pwdconf,fileparam->pwdconf,4095);
    strncpy(uniquefilename,fileparam->uniquefilename,1023);
    strncpy(keyfile,fileparam->keyfile,2047);
    if(strlen(uniquefilename)==0 || strlen(uniquefilename)>255){
        strcpy(error,"2900 - unique file name is wrong");
        goto CLEANUP;
    }
    bb_strip_path(uniquefilename);
    if(strlen(pwdconf)==0){
        strcpy(error,"2901 - pwd configuration is mandatory");
        goto CLEANUP;
    }
    char *replyconf;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // CREATE NEW  BODYMSG
   len_newbodymsg=strlen(uniquefilename)+64;
   newbodymsg=malloc(len_newbodymsg);
   if(newbodymsg==NULL){
       strcpy(error,"2827 - error allocating var space\n");
       goto CLEANUP;
   }
   sprintf(newbodymsg,"%s",uniquefilename);
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2806 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2807 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2808 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2809 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2810 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(uniquefilename)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"getencryptedfile%s%s%u%s",sender,uniquefilename,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(uniquefilename)+strlen(uniquefilename)+strlen(sender)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getencryptedfile\",\"sender\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,uniquefilename,uniquefilename,bbtoken,totp,hashb64,sign);
   lenreply=0;
   if(verbose) printf("Thread msg: %s\n",msg);
   reply=bb_tls_getencryptedfile(bbhostname,bbport,msg,uniquefilename);
   if(verbose) printf("reply from bb_tls_getencryptedfile: %s\n",reply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   filenameenc[0]=0;
   bb_json_getvalue("filename",reply,filenameenc,255);
   //DECRYPT FILE IF NOT PRESENT ALREADY
   strncpy(localfilename,filenameenc,511);
   j=strlen(localfilename);
   if(localfilename[j-1]=='c' && localfilename[j-2]=='n' && localfilename[j-3]=='e' && localfilename[j-4]=='.'){
      localfilename[j-4]=0;
   }
   else{
     strcpy(error,"Thread error Encrypted filename not .enc");
     goto CLEANUP;
   }

    /* removed for decyrption in ram only
    if(access(localfilename,F_OK|R_OK)==-1){
      if(!bb_decrypt_file(filenameenc,localfilename,keyfile)){
         strcpy(error,"THREAD Error decrypting FILE");
         goto CLEANUP;
      }
      originfilename[0]=0;
      bb_json_getvalue("originfilename",keyfile,originfilename,511);
      bb_strip_path(originfilename);
      i=strlen(originfilename);
   }*/
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(newbodymsg!=NULL) free(newbodymsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(error,0x0,64);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   pthread_exit((void *) 1);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(newbodymsg!=NULL) free(newbodymsg);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(filenameenc,0x0,512);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   fprintf(stderr,"InThread error: %s\n",error);
   memset(error,0x0,64);
   pthread_exit((void *) 0);
}
/**
* FUNCTION TO GET AN ENCRYPTED PHOTO BY UNIQUE NAME\n
* THE FILE MUST BE FROM A GROUP/PROFILE ACCESSIBLE TO THE USER \n
* THE FUNCTION RETURNS AN ANSWER IN JSON FORMAT THAT MUST BE FREE()
*/
char * bb_get_photo(char *uniquefilename,char *pwdconf){
    char *msg=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,buflen;
    char error[512];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char filenameenc[512];
    char localfilename[512];
    char localfilenametmp[512];
    char localfilenamejpg[512];
    char filepwd[2048];
    char filepwdb64[2048];
    char *ss=NULL;
    char *newbodymsg=NULL;
    int len_newbodymsg=0;
    if(strlen(uniquefilename)==0 || strlen(uniquefilename)>255){
        strcpy(error,"2900 - unique file name is wrong");
        goto CLEANUP;
    }
    bb_strip_path(uniquefilename);
    if(strlen(pwdconf)==0){
        strcpy(error,"2901 - pwd configuration is mandatory");
        goto CLEANUP;
    }
    char *replyconf;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // CREATE NEW  BODYMSG
   len_newbodymsg=strlen(uniquefilename)+64;
   newbodymsg=malloc(len_newbodymsg);
   if(newbodymsg==NULL){
       strcpy(error,"2827 - error allocating var space\n");
       goto CLEANUP;
   }
   sprintf(newbodymsg,"%s",uniquefilename);
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2806 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2807 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2808 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2809 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2810 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(uniquefilename)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"getencryptedphoto%s%s%u%s",sender,uniquefilename,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(uniquefilename)+strlen(uniquefilename)+strlen(sender)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getencryptedphoto\",\"sender\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,uniquefilename,uniquefilename,bbtoken,totp,hashb64,sign);
   lenreply=0;
   if(verbose) printf("Msg: %s\n",msg);
   reply=bb_tls_getencryptedfile(bbhostname,bbport,msg,uniquefilename);
   if(verbose) printf("\nreply from bb_tls_getencryptedfile: %s\n",reply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   filenameenc[0]=0;
   bb_json_getvalue("filename",reply,filenameenc,255);
   filepwdb64[0]=0;
   bb_json_getvalue("filepwd",reply,filepwdb64,2047);
   bb_decode_base64(filepwdb64,filepwd);
   memset(localfilename,0x0,512);
   strncpy(localfilename,filenameenc,507);
   localfilename[strlen(localfilename)-4]=0;
   if(access(localfilename,F_OK|R_OK)==0){
     strcpy(localfilenamejpg,localfilename);
     strcat(localfilenamejpg,".jpg");
     bb_copy_file(localfilename,localfilenamejpg);
   }
   strcpy(localfilenametmp,localfilename);
   strcat(localfilename,".jpg");
   bb_decode_base64(filepwdb64,filepwd);
   if(verbose) printf("Decrypt file: %s\n",filepwd);
   /* removed decryption for only ram decyrption change
   if(access(localfilename,F_OK|R_OK)==-1){
         if(!bb_decrypt_file(filenameenc,localfilename,filepwd)){
              strcpy(error,"Error decrypting file ");
              goto CLEANUP;
         }
       bb_copy_file(localfilename,localfilenametmp);
   }
   */
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(newbodymsg!=NULL) free(newbodymsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   replysend=malloc(8192);
   sprintf(replysend,"{\"answer\":\"OK\",\"message\":\"File download completed.\",\"filename\":\"%s\",\"localfilename\":\"%s\",\"keyfile\":\"%s\"}",filenameenc,filenameenc,filepwdb64);
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(newbodymsg!=NULL) free(newbodymsg);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(filenameenc,0x0,512);
   memset(filepwd,0x0,512);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}

/**
* FUNCTION TO DELETE A CONTACT, THE RESULT MUS BE FREE()
*/
char * bb_get_photoprofile_filename(char *contactnumber,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    char filename[512];
    char recipient[64];
    char *replyconf;
    if(strlen(contactnumber)==0){
        strcpy(error,"13801 - contactnumber field cannot be empty\n");
        goto CLEANUP;
    }
    // SET SERVER ACCOUNT
    strcpy(recipient,"0000001");
    sprintf(bodymsg,"{\"contactnumber\":\"%s\"}",contactnumber);
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"13802 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "13803 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"13804 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"13805 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"13806- error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
           bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"13807 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"13809 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"%s%s%s%u%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getphotoprofilefilename\",\"sender\":\"%s\",\"recipient\":\"0000001\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}

/*
* FUNCTION TO UPDATE STATUS OF THE USER
*/
char * bb_update_status(char *status,char *pwdconf){

    char *msg=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    if(strlen(status)==0){
        strcpy(error,"2750 - Status cannot be empty");
        goto CLEANUP;
    }
    if(strlen(status)>64){
        strcpy(error,"2751 - Status is too long (>64)");
        goto CLEANUP;
    }
    sprintf(bodymsg,"%s",status);
    
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2754 - session token is not present, you must register first");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2755 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2756 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2757 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2758 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(sender)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"status%s%s%s%u,%s",sender,sender,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsg)+strlen(bodymsg)+strlen(sender)+strlen(sender)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"sendstatus\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,sender,bodymsg,bodymsg,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(256);
   strcpy(replysend,"{\"answer\":\"OK\",\"message\":\"Status has been updated\"}");
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO UPDATE PROFILE NAME OF THE USER
*/
char * bb_update_profilename(char *name,char *pwdconf){

    char *msg=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    if(strlen(name)==0){
        strcpy(error,"2750 - Status cannot be empty");
        goto CLEANUP;
    }
    if(strlen(name)>128){
        strcpy(error,"2751 - Name is too long (>64)");
        goto CLEANUP;
    }
    sprintf(bodymsg,"%s",name);
    
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2754 - session token is not present, you must register first");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2755 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2756 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2757 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2758 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(sender)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"profilename%s%s%s%u,%s",sender,sender,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsg)+strlen(bodymsg)+strlen(sender)+strlen(sender)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"sendprofilename\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,sender,bodymsg,bodymsg,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(256);
   strcpy(replysend,"{\"answer\":\"OK\",\"message\":\"Profile name has been updated\"}");
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO GET PROFILE INFO OF THE USER
*/
char * bb_get_profileinfo(char * recipientr,char *pwdconf){

    char *msg=NULL;
    char bodymsg[512];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char recipient[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    strcpy(bodymsg,"getprofileinfo");
    if(strlen(recipientr)>63){
       strcpy(error, "2765 - recipient is wrong");
       goto CLEANUP;
    }
    strncpy(recipient,recipientr,64);

    
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }

     
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"2754 - session token is not present, you must register first");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   if(strlen(recipient)==0){
       strncpy(recipient,sender,64);
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "2755 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"2756 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"2757 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"2758 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(sender)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"profileinfo%s%s%s%u,%s",sender,sender,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsg)+strlen(bodymsg)+strlen(sender)+strlen(sender)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"getprofileinfo\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsg,bodymsg,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO SEND A READ RECEIPT
* ERROR MUST HAVE ALLOCATED SPACE FOR 128 chars
*/
char * bb_send_read_receipt(char * recipient,int msgid,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char bodymsg[512];
    char *replyconf;
    if(msgid<=0){
        strcpy(error,"3600 - Message id is missing or not valid");
        goto CLEANUP;
    }
    sprintf(bodymsg,"%d",msgid);

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"3608 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "3609 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"3610 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"3611 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"3612 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"3613 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"3613r - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"readreceipt%s%s%u%s",sender,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"readreceipt\",\"sender\":\"%s\",\"recipient\":\"%s\",\"msgid\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsg,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   replysend=malloc(256);
   strcpy(replysend,"{\"answer\":\"OK\",\"message\":\"Read receipt has been sent\"}");
   return(replysend);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}

/**
* FUNCTION TO REGISTER PRESENCE
*/
char * bb_register_presence(char *pwdconf,char *os,char *uniqueid,char *uniqueidvoip){
    char mobilenumber[256];
    char msg[16384];
    FILE *fp;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char pwdreg[256];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char buf[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    int lensign=0,lenreply=0;
    char error[256];
    char *replyreg=NULL;
    uint32_t totp=0;
    int x,conflen,hashlen;
    char fn[512];
    char answer[64];
    struct stat sb;
    unsigned char keypush[256];
    char keypushb64[512];
    char *replyconf;
    if(strlen(pwdconf)==0){
        strcpy(error,"3201 - pwdconf for the configuration is missing");
        goto CLEANUP;
    }
    if(strlen(os)==0){
        strcpy(error,"3202 - Operating system is wrong");
        goto CLEANUP;
    }
    if(strlen(uniqueid)==0){
        strcpy(error,"3203 - Uniqueid is missing");
        goto CLEANUP;
    }
    if(strlen(uniqueidvoip)==0){
        strcpy(error,"3203a - Uniqueidvoip is missing");
        goto CLEANUP;
    }

    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }

   bb_json_getvalue("mobilenumber",conf,mobilenumber,64);
   if(strlen(mobilenumber)==0){
        strcpy(error,"3200 - mobilenumber not found in the configuration\n");
        goto CLEANUP;
   }
   // BUILD THE REGISTRATION MESSAGE
   pwdreg[0]=0;
   bb_json_getvalue("pwd",conf,pwdreg,256);
   if(strlen(pwdreg)==0){
       strcpy(error,"3207 - pwd not found in the configuration\n");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error,"3208 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"3209 - totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"3210 - authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"3211 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   authpk[x]=0;
   if(verbose) printf("Private key: %s\n",authpk);
   // HASH CALCULATION
   sprintf(buf,"register%s%s%u%sopush265%s%s",mobilenumber,pwdreg,totp,os,uniqueid,uniqueidvoip);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   // KEYS GENERATION FOR PUSH SERVERS
   memset(keypush,0x0,256);
   memset(keypushb64,0x0,512);
   bb_crypto_random_data(keypush);
   bb_crypto_random_data(&keypush[64]);
   bb_encode_base64(keypush,96,keypushb64);
   memset(KeyPush,0x0,128);
   memcpy(KeyPush,keypush,96);
   // END KEY GENERATION FOR PUSH SERVER
   sprintf(msg,"{\"action\":\"register\",\"mobilenumber\":\"%s\",\"pwd\":\"%s\",\"totp\":\"%u\",\"operatingsystem\":\"%s\",\"voicecodec\":\"ilbc\",\"videocodec\":\"h264\",\"uniqueid\":\"%s\",\"uniqueidvoip\":\"%s\",\"hash\":\"%s\",\"signature\":\"%s\",\"keypush\":\"%s\"}",mobilenumber,pwdreg,totp,os,uniqueid,uniqueidvoip,hashb64,sign,keypushb64);
   if(verbose) printf("%s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
    }
    lenreply=strlen(reply);
    if(verbose) printf("Register_Presence reply: %s\n lenreply %d\n",reply,lenreply);
    bb_json_getvalue("answer",reply,buf,63);
    if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
    }
    token[0]=0;
    bb_json_getvalue("token",reply,token,255);
    if(strlen(token)>0) strncpy(bbtoken,token,255);
    
    memset(msg,0x0,16384);
    memset(hash,0x0,512);
    memset(hashb64,0x0,1024);
    memset(pwdreg,0x0,256);
    memset(totpseed,0x0,256);
    memset(authpk,0x0,8192);
    memset(authpkb64,0x0,8192);
    memset(buf,0x0,8192);
    memset(sign,0x0,8192);
    memset(token,0x0,256);
    memset(error,0x0,256);
    memset(mobilenumber,0x0,256);
    //if(reply!=NULL) memset(reply,0x0,lenreply);
    if(reply!=NULL) free(reply);
    totp=0;
    conflen=0;
    hashlen=0;
    x=0;
    lensign=0;
    lenreply=0;
    
    replyreg=malloc(512);
    strcpy(replyreg,"{\"answer\":\"OK\",\"message\":\"Registration done\"}");
    return(replyreg);

    CLEANUP:
    memset(msg,0x0,16384);
    memset(conf,0x0,8192);
    memset(hash,0x0,512);
    memset(hashb64,0x0,1024);
    memset(pwdreg,0x0,256);
    memset(totpseed,0x0,256);
    memset(authpk,0x0,8192);
    memset(authpkb64,0x0,8192);
    memset(buf,0x0,8192);
    memset(sign,0x0,8192);
    memset(token,0x0,256);
    memset(mobilenumber,0x0,256);
    if(reply!=NULL) memset(reply,0x0,lenreply);
    if(reply!=NULL) free(reply);
    totp=0;
    conflen=0;
    hashlen=0;
    x=0;
    lensign=0;
    lenreply=0;
    replyreg=malloc(512);
    sprintf(replyreg,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
    memset(error,0x0,128);
    return(replyreg);
}
/**
* FUNCTION TO GET THE REGISTERED MOBILE NUMBER
*/
char * bb_get_registered_mobilenumber(char *pwdconf){

    char mobilenumber[256];
    char conf[8192];
    char error[256];
    char answer[64];
    char *replyconf=NULL;
    char *reply=NULL;
    if(strlen(pwdconf)==0){
        strcpy(error,"3301 - pwdconf for the configuration is missing");
        goto CLEANUP;
    }
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    memset(replyconf,0x0,strlen(replyconf));
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   bb_json_getvalue("mobilenumber",conf,mobilenumber,64);
   if(strlen(mobilenumber)==0){
        strcpy(error,"3300 - mobilenumber not found in the configuration\n");
        goto CLEANUP;
   }
   reply=malloc(1024);
   sprintf(reply,"{\"answer\":\"OK\",\"message\":\"Registered mobile number:\",\"mobilenumber\":\"%s\"}",mobilenumber);
   memset(error,0x0,256);
   memset(conf,0x0,8192);
   memset(answer,0x0,64);
   memset(mobilenumber,0x0,256);
   return(reply);

   CLEANUP:
   reply=malloc(1024);
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,256);
   memset(conf,0x0,8192);
   memset(answer,0x0,64);
   memset(mobilenumber,0x0,256);
   return(reply);
}
/**
* FUNCTION TO SIGNUP
*/
char * bb_signup_newdevice(char *mobilenumber, char *otp, char *smsotp){
char msg[2048];
char *reply=NULL;
int lenreply=64000;
char pwd[2048];
char pwdb64[4096];
char buf[64];
char error[256];
char * enc=NULL;
char * encb64=NULL;
int enclen=0,enclenb64,x;
FILE *fp;
char filename[512];
    struct stat sb;
    
if(strlen(mobilenumber)>64){
    strcpy(error,"2400 - mobile number is too long");
    goto CLEANUP;
}
if(strlen(mobilenumber)==0){
    strcpy(error,"2401 - mobile number is missing");
    goto CLEANUP;
}
if(strlen(otp)>64){
    strcpy(error,"2402 - otp is too long");
    goto CLEANUP;
}
if(strlen(otp)==0){
    strcpy(error,"2403 - otp code is missing");
    goto CLEANUP;
}
if(strlen(smsotp)>64){
    strcpy(error,"2404 - smsotp is too long");
    goto CLEANUP;
}
sprintf(msg,"{\"action\":\"signup\",\"mobilenumber\":\"%s\",\"otp\":\"%s\",\"smsotp\":\"%s\"}",mobilenumber,otp,smsotp);
if(verbose) printf("Sending: %s\n",msg);
lenreply=0;
reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
if(reply==NULL){
    strcpy(error,"2405 - error sending tls message");
    goto CLEANUP;
}
lenreply=strlen(reply);
if(verbose) printf("Reply: %s\n",reply);
bb_json_getvalue("answer",reply,buf,63);
if(strcmp(buf,"KO")==0){
    bb_json_getvalue("message",reply,error,127);
    goto CLEANUP;
}
//** STORE THE CONFIGURATION IN AN ENCRYPTED FILE
x=strlen(reply);
enc=malloc(x+64);
if(!bb_encrypt_buffer(reply,x,enc,&enclen,pwd)){
    free(enc);
    strcpy(error,"2406 - error encrypting the configuration");
    goto CLEANUP;
}
enclenb64=x*2;
encb64=malloc(enclenb64);
bb_encode_base64(enc,enclen,encb64);
sprintf(filename,"%s/Documents/test",getenv("HOME"));
if (stat(filename, &sb) != 0)
        mkdir(filename, S_IRWXU | S_IRWXG);
sprintf(filename,"%s/Documents/test/c4955380679ef409832fb2de2f8878638833ba2cb3b7d2285db586b2295e6735.enc",getenv("HOME"));
fp=fopen(filename,"w");
fprintf(fp,"%s",encb64);
fclose(fp);
chmod(filename, S_IWUSR|S_IRUSR);
bb_encode_base64(pwd,strlen(pwd),pwdb64);
sprintf(reply,"{\"answer\":\"OK\",\"message\":\"Signup completed\",\"pwdconf\":\"%s\"}",pwdb64);
memset(pwd,0x0,2048);
memset(pwdb64,0x0,4096);
memset(msg,0x0,1024);
memset(buf,0x0,64);
memset(error,0x0,128);
memset(buf,0x0,64);
if(enc!=NULL){
   memset(enc,0x0,enclen);
   free(enc);
}
if(encb64!=NULL){
   memset(encb64,0x0,enclenb64);
   free(encb64);
}
x=0;
lenreply=0;
enclen=0;
enclenb64=0;
return(reply);

CLEANUP:
sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
memset(pwd,0x0,2048);
memset(pwdb64,0x0,4096);
memset(msg,0x0,1024);
memset(buf,0x0,64);
memset(error,0x0,128);
memset(buf,0x0,64);
if(enc!=NULL){
   memset(enc,0x0,enclen);
   free(enc);
}
if(encb64!=NULL){
   memset(encb64,0x0,enclenb64);
   free(encb64);
}
x=0;
lenreply=0;
enclen=0;
enclenb64=0;
return(reply);
}

/**
* FUNCTION TO SEND MESSAGE TO SERVER
*/
char * bb_tls_sendmsg(char *hostname,int port,char *msg,int *lenreply){
    //*** PUBLIC KEY OF SERVER CERTIFICATE TO PIN IN DER FORMAT ENCODED IN BASE64 (CHANGE IT FOR PRODUCTION)
    //char publickey[]={"MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQB7fK8s7x0VqZJyUShQb1NMdtg3rKJeVdmfOZJLjybhpibBaFDcuvTFp2UnwewSGjfMSMsLtV8NEz3c9gVhpYv7+UBBQH38cekWPqQAHpnMLHemm8/4jgPRcb5Rapcapewr15XHEiMGILS5hcBkGr2cShrAjSNi5SJF0UzwlYUE7VSIrU="};
    //char publickey[]={"MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQARlcZydlINPt/n0SNA+5bA6u/23yLUogaKS6DgMsL90AN3DQnvhdQCROdiOn829ZNjG79HbS89rzWTElN4lBMBMwBu9n5QcWnFwDGJT2RVDpEcjwO+on1+9+aV5T73OuQR/ljtEEBwO9YulgnqamaUDGysRKwtCalsYWl3n0anmVFhb0="};
    
    char publickey[]={"MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQBaIUVfHX1HzP5mpqE+XWbSeu8sT62XnfEby1mxilpt+nosCIDaeWSP34PhuAD+lzw7ypVGOnTBMC5SDeaDWevPOUBSSFzL+2S2a2UVy0fV9jzMaXfOQh0iuKNsHDk1scWGsWfLaZg1DgZfTLOKw1kg0SGGNf1As9kxH2CaZFPFMGUKAg="};

    //******************************************************************************************************
    SSL_CTX *ctx;
    char error[256];
    unsigned long ssl_err = 0;
    int server;
    SSL *ssl;
    int bytes,lenpk,ret;
    long res = 1;
    struct hostent *host;
    struct sockaddr_in addr;
    unsigned char *buff1 = NULL;
    unsigned char tempb64[16384];
    X509* cert = NULL;
    const SSL_METHOD* method =SSLv23_method();
    int mr=16384;
    int ptr=0;
    int c=0;
    size_t nb;
    char *reply=NULL;
    // CREATE CONTEXT OPENSSL
    ctx = SSL_CTX_new(method);
    ssl_err = ERR_get_error();
    if(ctx==NULL){
        const char* const str = ERR_reason_error_string(ssl_err);
        sprintf(error,"2001 - Error creating CTX structure [%s]",str);
        goto CLEANUP;
    }
    SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, bb_verify_callback);
    SSL_CTX_set_verify_depth(ctx, 5);
    //CONFIGURE TLS 1.2 AND UPPER ONLY
    const long flags = SSL_OP_ALL | SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3 | SSL_OP_NO_COMPRESSION |SSL_OP_NO_TLSv1|SSL_OP_NO_TLSv1_1;
    long old_opts = SSL_CTX_set_options(ctx, flags);
    UNUSED(old_opts);
/*    //LOAD TRUSTED CA ONLY FROM FILE
    res = SSL_CTX_load_verify_locations(ctx, (const char*)CaLocation, NULL);
    
    
    ssl_err = ERR_get_error();
    if(res!=1)
    {
            const char* const str  = ERR_reason_error_string(ssl_err);
            sprintf(error,"2002 - Error creating CTX structure (tls-ca-chain not found [%s]",str);
            goto CLEANUP;
    }
    //END LOAD TRUSTED CA FROM FILE
    */
    //LOAD TRUSTED CA FROM VARIABLE
    X509 *BB_CAcert;
    char zCert[8192];
    BIO *bbmem;
    strncpy(zCert,"-----BEGIN CERTIFICATE-----\n"
    "MIIDJDCCAoagAwIBAgIBAjAKBggqhkjOPQQDBDBUMQswCQYDVQQGEwJYWDERMA8G\n"
    "A1UECgwIWFhYWFhYWFgxHDAaBgNVBAsME1hYWFhYWFhYIE5ldHdvcmsgQ0ExFDAS\n"
    "BgNVBAMMC1hYWFhYWFhYIENBMB4XDTIwMDcyMzExMDE0N1oXDTMwMDcyMzExMDE0\n"
    "N1owVDELMAkGA1UEBhMCWFgxETAPBgNVBAoMCFhYWFhYWFhYMRgwFgYDVQQLDA9Y\n"
    "WFhYWFhYWCBUTFMgQ0ExGDAWBgNVBAMMD1hYWFhYWFhYIFRMUyBDQTCBmzAQBgcq\n"
    "hkjOPQIBBgUrgQQAIwOBhgAEAfM9O3mAr8vfnm9nM7hGwSOctHTqsTG4kx4p9OBk\n"
    "hXnqc9I8zLgEqyIah+4kxx9Zj3R3W86lK9GgkRmmNG+bVwX8AdNYCoL83dwwndUI\n"
    "aSQ2G/4zGoDA//E3Da032ho0+mwwzZRanIMw49FRYzU3twXyxLQ4abrVjAl1wxCP\n"
    "fg2Wohs4o4IBBDCCAQAwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8C\n"
    "AQAwHQYDVR0OBBYEFFLs9uEaIJkc0+m60PBsr5EAIZXHMB8GA1UdIwQYMBaAFBRF\n"
    "ka3kfCxc6O6fcSu1xYiuTwZEMD8GCCsGAQUFBwEBBDMwMTAvBggrBgEFBQcwAoYj\n"
    "aHR0cHM6Ly9rcnlwdG90ZWwuYWUvbmV0d29yay1jYS5jZXIwNAYDVR0fBC0wKzAp\n"
    "oCegJYYjaHR0cHM6Ly9rcnlwdG90ZWwuYWUvbmV0d29yay1jYS5jcmwwIwYDVR0g\n"
    "BBwwGjALBgkrBgEEAQABBwgwCwYJKwYBBAEAAQcJMAoGCCqGSM49BAMEA4GLADCB\n"
    "hwJCAfZyuYLE1Sxw53bAeDWAqYqFIJ5ThYBUyBs1rgZqDJjxl4JUAH6LWEmpQVnY\n"
    "1yuRevCDbUzQgA7mrFjDkxyqwVb0AkF9qEjWxgDbhtO9MrAJNNQZs7a/Es+g1R7p\n"
    "6A9Bh78Q+OBnvPZtdaOY75enpzDlBMHkwU1NaBHIEnVh5OBfr1WLnQ==\n"
    "-----END CERTIFICATE-----\n"
    "-----BEGIN CERTIFICATE-----\n"
    "MIIDFDCCAnWgAwIBAgIBAjAKBggqhkjOPQQDBDBOMQswCQYDVQQGEwJYWDERMA8G\n"
    "A1UECgwIWFhYWFhYWFgxETAPBgNVBAsMCFhYWFhYWFhYMRkwFwYDVQQDDBBYWFhY\n"
    "WFhYWCBSb290IENBMB4XDTIwMDcyMzExMDEwNFoXDTMwMTIzMTIzNTk1OVowVDEL\n"
    "MAkGA1UEBhMCWFgxETAPBgNVBAoMCFhYWFhYWFhYMRwwGgYDVQQLDBNYWFhYWFhY\n"
    "WCBOZXR3b3JrIENBMRQwEgYDVQQDDAtYWFhYWFhYWCBDQTCBmzAQBgcqhkjOPQIB\n"
    "BgUrgQQAIwOBhgAEAZ7pcxqkX6lMKJ5oYGMoRWOoTtY1CatNi/4O3u5Tp9+hCfP9\n"
    "XxpvxEThWRdva/i9duxEMnGdVFrZw4QCZHoBV0evAeelTFDyk2DW31EjYvOyX88a\n"
    "9mz1KBFlHyEu6KJLrWRIAPXpM100eQbB2NHJ1BkNYVBcD0NnX8yvC5SzgW//ArHr\n"
    "o4H6MIH3MA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW\n"
    "BBQURZGt5HwsXOjun3ErtcWIrk8GRDAfBgNVHSMEGDAWgBSpZtRanMPVVYTMWvyR\n"
    "vQ9u0+4d3jA8BggrBgEFBQcBAQQwMC4wLAYIKwYBBQUHMAKGIGh0dHBzOi8va3J5\n"
    "cHRvdGVsLmFlL3Jvb3QtY2EuY2VyMDEGA1UdHwQqMCgwJqAkoCKGIGh0dHBzOi8v\n"
    "a3J5cHRvdGVsLmFlL3Jvb3QtY2EuY3JsMCMGA1UdIAQcMBowCwYJKwYBBAEAAQcI\n"
    "MAsGCSsGAQQBAAEHCTAKBggqhkjOPQQDBAOBjAAwgYgCQgGh1zN6g0CsRcD+6Et+\n"
    "n5Nko2Wt441cyiELUJc+lLCCcMNNBxTjmJnLc1bp/9phCAoeXdgBfLTk4imw2+Sm\n"
    "f0rkgAJCAOcSEvhzbbsDHZBgcob65unrio/NIyw7TYIIKuVx2ug6vBrpHWS6/iq7\n"
    "i13K+dI1LopPzj99Th2hhGZX2E9jdmav\n"
    "-----END CERTIFICATE-----\n"
    "-----BEGIN CERTIFICATE-----\n"
    "MIICdjCCAdegAwIBAgIBATAKBggqhkjOPQQDBDBOMQswCQYDVQQGEwJYWDERMA8G\n"
    "A1UECgwIWFhYWFhYWFgxETAPBgNVBAsMCFhYWFhYWFhYMRkwFwYDVQQDDBBYWFhY\n"
    "WFhYWCBSb290IENBMB4XDTIwMDcyMzExMDAyMloXDTMwMTIzMTIzNTk1OVowTjEL\n"
    "MAkGA1UEBhMCWFgxETAPBgNVBAoMCFhYWFhYWFhYMREwDwYDVQQLDAhYWFhYWFhY\n"
    "WDEZMBcGA1UEAwwQWFhYWFhYWFggUm9vdCBDQTCBmzAQBgcqhkjOPQIBBgUrgQQA\n"
    "IwOBhgAEASEGXhmR+2snzkXUz+KsOdIypo+hU8WNM5BJQSe5PyJr53xhh36lOdYC\n"
    "l9kIB4QbhPjo66v2LjV2FzlUreQ2i2TpAGLVFHiiYBAMb1W83xiBcvczk19VfflC\n"
    "hEA2IxhbAqftcNQGFL3luATvQihdd4YjNRtolWDS73KzKq1IEsdx+Ji5o2MwYTAO\n"
    "BgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUqWbUWpzD\n"
    "1VWEzFr8kb0PbtPuHd4wHwYDVR0jBBgwFoAUqWbUWpzD1VWEzFr8kb0PbtPuHd4w\n"
    "CgYIKoZIzj0EAwQDgYwAMIGIAkIB6JabuM5icMe2wlLTm7affMUi7lawa/XxUgGh\n"
    "fx7GbaTFcvDtC7nUswtFlWmUGJroSQoCqd+g+0qZZgPIyE5COWYCQgDfRp/zEUYU\n"
    "yUqDs8xajRkoSj00ZcSsTq6S5SGrI1NgVaqBkHjKcwG3K9sNPjpyS9Xsx2nrwYCU\n"
    "ShTmVLfHtnLgcA==\n"
    "-----END CERTIFICATE-----\n",8192);

    bbmem = BIO_new(BIO_s_mem());
    BIO_puts(bbmem, zCert);
    while (BB_CAcert = PEM_read_bio_X509(bbmem, NULL, 0, NULL)) {
         X509_STORE_add_cert(SSL_CTX_get_cert_store(ctx), BB_CAcert);
         X509_free(BB_CAcert);
    }
    BIO_free(bbmem);
    //END TRUSTED CA LOAD FROM VARIABLE

    
    // OPEN SOCKET CONNECTION
    if ( (host = gethostbyname(hostname)) == NULL )
    {
        const char* const str = ERR_reason_error_string(ssl_err);
        sprintf(error,"2002 - hostname is wrong [%s][%s]",hostname,str);
        goto CLEANUP;
    }
    server = socket(PF_INET, SOCK_STREAM, 0);
    bzero(&addr, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = *(long*)(host->h_addr);
    if ( connect(server, (struct sockaddr*)&addr, sizeof(addr)) != 0 )
    {
        sprintf(error,"2003 - error connecting to server [%s] errno: %d",hostname,errno);
        close(server);
        goto CLEANUP;
    }
    ssl = SSL_new(ctx);
    SSL_set_fd(ssl, server);    /* attach the socket descriptor */
    if ( SSL_connect(ssl) == -1 ){   /* perform the connection */
        sprintf(error,"2004 - error connecting TLS to server [%s]",hostname);
        close(server);
        goto CLEANUP;
    }
    //CERTIFICATE PINNING
    cert = SSL_get_peer_certificate(ssl);
    if(cert==NULL){
        sprintf(error,"2009 - error getting certificate from server [%s]",hostname);
        close(server);
        goto CLEANUP;
    }
    lenpk = i2d_X509_PUBKEY(X509_get_X509_PUBKEY(cert), NULL);
    if(lenpk>8192){
        strcpy(error,"2010 - certificate is too loong");
        close(server);
        goto CLEANUP;
    }
    unsigned char* temp = NULL;
    buff1= temp = OPENSSL_malloc(lenpk);
    lenpk= i2d_X509_PUBKEY(X509_get_X509_PUBKEY(cert),&temp);
    bb_encode_base64(buff1,lenpk,tempb64);
    OPENSSL_free(buff1);
    if(verbose) printf("blackbox-client.c - public key length from server: %d\n",lenpk);
    if(verbose) printf("blackbox-client.c - public key  from server: %s\n",tempb64);
    if(verbose) printf("blackbox-client.c - public key hard coded: %s\n",publickey);
    if(strcmp(tempb64,publickey)!=0){
        if(verbose) printf("blackbox-client.c - public key is not matching\n");
        sprintf(error,"2011 - Public key is not matching the hard coded %s",hostname);
        close(server);
        goto CLEANUP;
    }
    //*** END CERTIFICATE PINNING
    if(verbose) printf("bb_tls_sendmsg() -  - sending msg: %s\n",msg);
    //*** SEND MSG
    ret=SSL_write(ssl,msg, strlen(msg));
    if(ret<=0){
        strcpy(error,"2012 - Error sending message ");
        close(server);
        goto CLEANUP;
    }
    //*** READ REPLY
    nb=(size_t)(mr+64);
    reply=(char *)malloc(nb);
    if(reply==NULL){
        strcpy(error,"2033 - Error allocating space for reply ");
        close(server);
        goto CLEANUP;
    }
    bytes = SSL_read(ssl, reply,mr);
    if(bytes<=0){
        strcpy(error,"2013m - Error reading  message ");
        close(server);
        goto CLEANUP;
    }
    reply[bytes]=0;
    c=1;
    ptr=bytes;
    while(SSL_has_pending(ssl) || bytes==16384){
       nb=(size_t)(mr*(c+1))+(16384);
       reply=realloc(reply,nb);
       if(reply==NULL){
        strcpy(error,"2034 - Error re-allocating space for reply ");
        close(server);
        goto CLEANUP;
       }
       if(verbose) printf("bb_tls_sendmsg() - New space allocated: %d\n",nb);
       bytes = SSL_read(ssl, &reply[ptr], mr);
       if(bytes<=0)
          break;
       ptr=ptr+bytes;
       reply[ptr]=0;
       c++;
       if(c>=9999) break;
    }
    if (verbose) printf("bb_tls_sendmsg() - REPLY:%s\n",reply);
    SSL_free(ssl);
    close(server);
        
    // CLEAN RETURN
    if(NULL != ctx) SSL_CTX_free(ctx);
    if(cert!=NULL) X509_free(cert);
    return(reply);

    CLEANUP:
    if(NULL != ctx) SSL_CTX_free(ctx);
    X509_free(cert);
    if(reply==NULL) reply=malloc(1024);
    sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
    return(reply);
}
/**
* FUNCTION TO SEND FILE TO SERVER
*/
char * bb_tls_sendfile(char *hostname,int port,char *msg,int *lenreply,char *filename){
    //*** PUBLIC KEY OF SERVER CERTIFICATE TO PIN IN DER FORMAT ENCODED IN BASE64 (CHANGE IT FOR PRODUCTION)
    //char publickey[]={"MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQB7fK8s7x0VqZJyUShQb1NMdtg3rKJeVdmfOZJLjybhpibBaFDcuvTFp2UnwewSGjfMSMsLtV8NEz3c9gVhpYv7+UBBQH38cekWPqQAHpnMLHemm8/4jgPRcb5Rapcapewr15XHEiMGILS5hcBkGr2cShrAjSNi5SJF0UzwlYUE7VSIrU="};
    //char publickey[]={"MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQARlcZydlINPt/n0SNA+5bA6u/23yLUogaKS6DgMsL90AN3DQnvhdQCROdiOn829ZNjG79HbS89rzWTElN4lBMBMwBu9n5QcWnFwDGJT2RVDpEcjwO+on1+9+aV5T73OuQR/ljtEEBwO9YulgnqamaUDGysRKwtCalsYWl3n0anmVFhb0="};
    char publickey[]={"MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQBaIUVfHX1HzP5mpqE+XWbSeu8sT62XnfEby1mxilpt+nosCIDaeWSP34PhuAD+lzw7ypVGOnTBMC5SDeaDWevPOUBSSFzL+2S2a2UVy0fV9jzMaXfOQh0iuKNsHDk1scWGsWfLaZg1DgZfTLOKw1kg0SGGNf1As9kxH2CaZFPFMGUKAg="};

    //******************************************************************************************************
    SSL_CTX *ctx;
    char error[256];
    char answer[64];
    char token[256];
    char serverfilename[512];
    char autodelete[64];
    unsigned long ssl_err = 0;
    int server;
    SSL *ssl;
    int bytes,lenpk,ret;
    long res = 1;
    struct hostent *host;
    struct sockaddr_in addr;
    unsigned char *buff1 = NULL;
    unsigned char tempb64[16384];
    X509* cert = NULL;
    const SSL_METHOD* method =SSLv23_method();
    int mr=16384;
    int ptr=0;
    int c=0;
    size_t nb;
    char *reply=NULL;
    char lastmsgid[128];
    int filesize;
    struct stat fs;
    // CREATE CONTEXT OPENSSL
    ctx = SSL_CTX_new(method);
    ssl_err = ERR_get_error();
    if(ctx==NULL){
        const char* const str = ERR_reason_error_string(ssl_err);
        sprintf(error,"2001 - Error creating CTX structure [%s]",str);
        goto CLEANUP;
    }
    SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, bb_verify_callback);
    SSL_CTX_set_verify_depth(ctx, 5);
    //CONFIGURE TLS 1.2 AND UPPER ONLY
    const long flags = SSL_OP_ALL | SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3 | SSL_OP_NO_COMPRESSION |SSL_OP_NO_TLSv1|SSL_OP_NO_TLSv1_1;
    long old_opts = SSL_CTX_set_options(ctx, flags);
    UNUSED(old_opts);
    /*
    //LOAD TRUSTED CA ONLY
    res = SSL_CTX_load_verify_locations(ctx, (const char*)CaLocation, NULL);
    ssl_err = ERR_get_error();
    if(res!=1)
    {
            const char* const str  = ERR_reason_error_string(ssl_err);
            sprintf(error,"2002 - Error creating CTX structure [%s]",str);
            goto CLEANUP;
    }
    */
    //LOAD TRUSTED CA FROM VARIABLE
    X509 *BB_CAcert;
    char zCert[8192];
    BIO *bbmem;
    strncpy(zCert,"-----BEGIN CERTIFICATE-----\n"
    "MIIDJDCCAoagAwIBAgIBAjAKBggqhkjOPQQDBDBUMQswCQYDVQQGEwJYWDERMA8G\n"
    "A1UECgwIWFhYWFhYWFgxHDAaBgNVBAsME1hYWFhYWFhYIE5ldHdvcmsgQ0ExFDAS\n"
    "BgNVBAMMC1hYWFhYWFhYIENBMB4XDTIwMDcyMzExMDE0N1oXDTMwMDcyMzExMDE0\n"
    "N1owVDELMAkGA1UEBhMCWFgxETAPBgNVBAoMCFhYWFhYWFhYMRgwFgYDVQQLDA9Y\n"
    "WFhYWFhYWCBUTFMgQ0ExGDAWBgNVBAMMD1hYWFhYWFhYIFRMUyBDQTCBmzAQBgcq\n"
    "hkjOPQIBBgUrgQQAIwOBhgAEAfM9O3mAr8vfnm9nM7hGwSOctHTqsTG4kx4p9OBk\n"
    "hXnqc9I8zLgEqyIah+4kxx9Zj3R3W86lK9GgkRmmNG+bVwX8AdNYCoL83dwwndUI\n"
    "aSQ2G/4zGoDA//E3Da032ho0+mwwzZRanIMw49FRYzU3twXyxLQ4abrVjAl1wxCP\n"
    "fg2Wohs4o4IBBDCCAQAwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8C\n"
    "AQAwHQYDVR0OBBYEFFLs9uEaIJkc0+m60PBsr5EAIZXHMB8GA1UdIwQYMBaAFBRF\n"
    "ka3kfCxc6O6fcSu1xYiuTwZEMD8GCCsGAQUFBwEBBDMwMTAvBggrBgEFBQcwAoYj\n"
    "aHR0cHM6Ly9rcnlwdG90ZWwuYWUvbmV0d29yay1jYS5jZXIwNAYDVR0fBC0wKzAp\n"
    "oCegJYYjaHR0cHM6Ly9rcnlwdG90ZWwuYWUvbmV0d29yay1jYS5jcmwwIwYDVR0g\n"
    "BBwwGjALBgkrBgEEAQABBwgwCwYJKwYBBAEAAQcJMAoGCCqGSM49BAMEA4GLADCB\n"
    "hwJCAfZyuYLE1Sxw53bAeDWAqYqFIJ5ThYBUyBs1rgZqDJjxl4JUAH6LWEmpQVnY\n"
    "1yuRevCDbUzQgA7mrFjDkxyqwVb0AkF9qEjWxgDbhtO9MrAJNNQZs7a/Es+g1R7p\n"
    "6A9Bh78Q+OBnvPZtdaOY75enpzDlBMHkwU1NaBHIEnVh5OBfr1WLnQ==\n"
    "-----END CERTIFICATE-----\n"
    "-----BEGIN CERTIFICATE-----\n"
    "MIIDFDCCAnWgAwIBAgIBAjAKBggqhkjOPQQDBDBOMQswCQYDVQQGEwJYWDERMA8G\n"
    "A1UECgwIWFhYWFhYWFgxETAPBgNVBAsMCFhYWFhYWFhYMRkwFwYDVQQDDBBYWFhY\n"
    "WFhYWCBSb290IENBMB4XDTIwMDcyMzExMDEwNFoXDTMwMTIzMTIzNTk1OVowVDEL\n"
    "MAkGA1UEBhMCWFgxETAPBgNVBAoMCFhYWFhYWFhYMRwwGgYDVQQLDBNYWFhYWFhY\n"
    "WCBOZXR3b3JrIENBMRQwEgYDVQQDDAtYWFhYWFhYWCBDQTCBmzAQBgcqhkjOPQIB\n"
    "BgUrgQQAIwOBhgAEAZ7pcxqkX6lMKJ5oYGMoRWOoTtY1CatNi/4O3u5Tp9+hCfP9\n"
    "XxpvxEThWRdva/i9duxEMnGdVFrZw4QCZHoBV0evAeelTFDyk2DW31EjYvOyX88a\n"
    "9mz1KBFlHyEu6KJLrWRIAPXpM100eQbB2NHJ1BkNYVBcD0NnX8yvC5SzgW//ArHr\n"
    "o4H6MIH3MA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW\n"
    "BBQURZGt5HwsXOjun3ErtcWIrk8GRDAfBgNVHSMEGDAWgBSpZtRanMPVVYTMWvyR\n"
    "vQ9u0+4d3jA8BggrBgEFBQcBAQQwMC4wLAYIKwYBBQUHMAKGIGh0dHBzOi8va3J5\n"
    "cHRvdGVsLmFlL3Jvb3QtY2EuY2VyMDEGA1UdHwQqMCgwJqAkoCKGIGh0dHBzOi8v\n"
    "a3J5cHRvdGVsLmFlL3Jvb3QtY2EuY3JsMCMGA1UdIAQcMBowCwYJKwYBBAEAAQcI\n"
    "MAsGCSsGAQQBAAEHCTAKBggqhkjOPQQDBAOBjAAwgYgCQgGh1zN6g0CsRcD+6Et+\n"
    "n5Nko2Wt441cyiELUJc+lLCCcMNNBxTjmJnLc1bp/9phCAoeXdgBfLTk4imw2+Sm\n"
    "f0rkgAJCAOcSEvhzbbsDHZBgcob65unrio/NIyw7TYIIKuVx2ug6vBrpHWS6/iq7\n"
    "i13K+dI1LopPzj99Th2hhGZX2E9jdmav\n"
    "-----END CERTIFICATE-----\n"
    "-----BEGIN CERTIFICATE-----\n"
    "MIICdjCCAdegAwIBAgIBATAKBggqhkjOPQQDBDBOMQswCQYDVQQGEwJYWDERMA8G\n"
    "A1UECgwIWFhYWFhYWFgxETAPBgNVBAsMCFhYWFhYWFhYMRkwFwYDVQQDDBBYWFhY\n"
    "WFhYWCBSb290IENBMB4XDTIwMDcyMzExMDAyMloXDTMwMTIzMTIzNTk1OVowTjEL\n"
    "MAkGA1UEBhMCWFgxETAPBgNVBAoMCFhYWFhYWFhYMREwDwYDVQQLDAhYWFhYWFhY\n"
    "WDEZMBcGA1UEAwwQWFhYWFhYWFggUm9vdCBDQTCBmzAQBgcqhkjOPQIBBgUrgQQA\n"
    "IwOBhgAEASEGXhmR+2snzkXUz+KsOdIypo+hU8WNM5BJQSe5PyJr53xhh36lOdYC\n"
    "l9kIB4QbhPjo66v2LjV2FzlUreQ2i2TpAGLVFHiiYBAMb1W83xiBcvczk19VfflC\n"
    "hEA2IxhbAqftcNQGFL3luATvQihdd4YjNRtolWDS73KzKq1IEsdx+Ji5o2MwYTAO\n"
    "BgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUqWbUWpzD\n"
    "1VWEzFr8kb0PbtPuHd4wHwYDVR0jBBgwFoAUqWbUWpzD1VWEzFr8kb0PbtPuHd4w\n"
    "CgYIKoZIzj0EAwQDgYwAMIGIAkIB6JabuM5icMe2wlLTm7affMUi7lawa/XxUgGh\n"
    "fx7GbaTFcvDtC7nUswtFlWmUGJroSQoCqd+g+0qZZgPIyE5COWYCQgDfRp/zEUYU\n"
    "yUqDs8xajRkoSj00ZcSsTq6S5SGrI1NgVaqBkHjKcwG3K9sNPjpyS9Xsx2nrwYCU\n"
    "ShTmVLfHtnLgcA==\n"
    "-----END CERTIFICATE-----\n",8192);

    bbmem = BIO_new(BIO_s_mem());
    BIO_puts(bbmem, zCert);
    while (BB_CAcert = PEM_read_bio_X509(bbmem, NULL, 0, NULL)) {
         X509_STORE_add_cert(SSL_CTX_get_cert_store(ctx), BB_CAcert);
         X509_free(BB_CAcert);
    }
    BIO_free(bbmem);
    //END TRUSTED CA LOAD FROM VARIABLE
    
    // OPEN SOCKET CONNECTION
    if ( (host = gethostbyname(hostname)) == NULL )
    {
        const char* const str = ERR_reason_error_string(ssl_err);
        sprintf(error,"2002 - hostname is wrong [%s][%s]",hostname,str);
        goto CLEANUP;
    }
    server = socket(PF_INET, SOCK_STREAM, 0);
    bzero(&addr, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = *(long*)(host->h_addr);
    if ( connect(server, (struct sockaddr*)&addr, sizeof(addr)) != 0 )
    {
        sprintf(error,"2003 - error connecting to server [%s]",hostname);
        close(server);
        goto CLEANUP;
    }
    ssl = SSL_new(ctx);
    SSL_set_fd(ssl, server);    /* attach the socket descriptor */
    if ( SSL_connect(ssl) == -1 ){   /* perform the connection */
        sprintf(error,"2004 - error connecting TLS to server [%s]",hostname);
        close(server);
        goto CLEANUP;
    }
    //CERTIFICATE PINNING
    cert = SSL_get_peer_certificate(ssl);
    if(cert==NULL){
        sprintf(error,"2009 - error getting certificate from server [%s]",hostname);
        close(server);
        goto CLEANUP;
    }
    lenpk = i2d_X509_PUBKEY(X509_get_X509_PUBKEY(cert), NULL);
    if(lenpk>8192){
        strcpy(error,"2010 - certificate is too loong");
        close(server);
        goto CLEANUP;
    }
    unsigned char* temp = NULL;
    buff1= temp = OPENSSL_malloc(lenpk);
    lenpk= i2d_X509_PUBKEY(X509_get_X509_PUBKEY(cert),&temp);
    bb_encode_base64(buff1,lenpk,tempb64);
    OPENSSL_free(buff1);
    //if(verbose) printf("blackbox-client.c - public key length from server: %d\n",lenpk);
    //if(verbose) printf("blackbox-client.c - public key  from server: %s\n",tempb64);
    //if(verbose) printf("blackbox-client.c - public key hard coded: %s\n",publickey);
    if(strcmp(tempb64,publickey)!=0){
        if(verbose) printf("blackbox-client.c - public key is not matching\n");
        sprintf(error,"2011 - Public key is not matching the hard coded %s",hostname);
        close(server);
        goto CLEANUP;
    }
    //*** END CERTIFICATE PINNING
    if(verbose) printf("bb_tls_sendfile() -  - sending msg: %s\n",msg);
    //*** SEND MSG
    ret=SSL_write(ssl,msg, strlen(msg));
    if(ret<=0){
        strcpy(error,"2012 - Error sending message ");
        close(server);
        goto CLEANUP;
    }
    //*** READ REPLY
    nb=(size_t)(mr+64);
    reply=(char *)malloc(nb);
    if(reply==NULL){
        strcpy(error,"2033 - Error allocating space for reply ");
        close(server);
        goto CLEANUP;
    }
    bytes = SSL_read(ssl, reply,mr);
    if(bytes<=0){
        strcpy(error,"2013f - Error reading  message ");
        close(server);
        goto CLEANUP;
    }
    reply[bytes]=0;
    c=1;
    ptr=bytes;
    if (verbose) printf("bb_tls_sendfile() - REPLY:%s\n",reply);
    //FILE TRANSFER IF APPLICABLE
    answer[0]=0;
    serverfilename[0]=0;
    bb_json_getvalue("answer",reply,answer,63);
    bb_json_getvalue("filename",reply,serverfilename,127);
    memset(lastmsgid,0x0,128);
    bb_json_getvalue("msgid",reply,lastmsgid,127);
    memset(autodelete,0x0,64);
    bb_json_getvalue("autodelete",reply,autodelete,63);
    
  if(strcmp(answer,"OK")==0){
         token[0]=0;
         bb_json_getvalue("token",reply,token,255);
         if(strlen(token)>0) strncpy(bbtoken,token,255);
         //GET FILE SIZE
         stat(filename,&fs);
         filesize=fs.st_size;
         //UPLOAD SECTION
         if(verbose) printf("File Upload starting: %s\n",filename);
         int fnd,br,fbs;
         char fs[16385];
         fbs=0;
         fnd=open(filename,O_RDONLY);
         if(fnd==-1){
           sprintf(error,"Error opening file %s",filename);
           goto CLEANUP;
         }
         while(1){
             br=read(fnd,fs,16384);
             if(br<=0)
              break;
             ret=SSL_write(ssl,fs, br);
             if(ret!=br){
                strcpy(error,"2500 - Connection broken during file transfer");
                close(fnd);
                bb_filetransfer_broken(filename);
                goto CLEANUP;
             }
             fbs=fbs+br;
             if(verbose) printf("File Upload sending %d bytes, total sent: %d\n",br,fbs);
             bb_filetransfer_addbytes(filename,br,filesize);
         //bb_filetransfer_dump();
         }
         close(fnd);
         //END UPLOAD
         if(verbose) printf("blackbox.c: - File upload %s completed, bytes sent: %d\n",filename,fbs);
         sprintf(reply,"{\"answer\":\"OK\",\"message\":\"File upload %s completed, bytes sent: %d\",\"token\":\"%s\",\"filename\":\"%s\",\"msgid\":\"%s\",\"autodelete\":\"%s\"}",filename,fbs,token,serverfilename,lastmsgid,autodelete);
         memset(fs,0x0,16385);
    }
    SSL_free(ssl);
    close(server);
        
    // CLEAN RETURN
    if(NULL != ctx) SSL_CTX_free(ctx);
    if(cert!=NULL) X509_free(cert);
    return(reply);

    CLEANUP:
    if(NULL != ctx) SSL_CTX_free(ctx);
    X509_free(cert);
    if(reply==NULL) reply=malloc(1024);
    sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
    return(reply);
}

/***
* FUNCTION TO GET ENCRYPTED FILE FROM THE SERVER
*/
char * bb_tls_getencryptedfile(char *hostname,int port,char *msg,char *filename){
    //*** PUBLIC KEY OF SERVER CERTIFICATE TO PIN IN DER FORMAT ENCODED IN BASE64 (CHANGE IT FOR PRODUCTION)
    //char publickey[]={"MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQB7fK8s7x0VqZJyUShQb1NMdtg3rKJeVdmfOZJLjybhpibBaFDcuvTFp2UnwewSGjfMSMsLtV8NEz3c9gVhpYv7+UBBQH38cekWPqQAHpnMLHemm8/4jgPRcb5Rapcapewr15XHEiMGILS5hcBkGr2cShrAjSNi5SJF0UzwlYUE7VSIrU="};
    //char publickey[]={"MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQARlcZydlINPt/n0SNA+5bA6u/23yLUogaKS6DgMsL90AN3DQnvhdQCROdiOn829ZNjG79HbS89rzWTElN4lBMBMwBu9n5QcWnFwDGJT2RVDpEcjwO+on1+9+aV5T73OuQR/ljtEEBwO9YulgnqamaUDGysRKwtCalsYWl3n0anmVFhb0="};
    char publickey[]={"MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQBaIUVfHX1HzP5mpqE+XWbSeu8sT62XnfEby1mxilpt+nosCIDaeWSP34PhuAD+lzw7ypVGOnTBMC5SDeaDWevPOUBSSFzL+2S2a2UVy0fV9jzMaXfOQh0iuKNsHDk1scWGsWfLaZg1DgZfTLOKw1kg0SGGNf1As9kxH2CaZFPFMGUKAg="};

    //******************************************************************************************************
    SSL_CTX *ctx;
    char error[256];
    char answer[64];
    char filesizetxt[512];
    char filepwd[2048];
    int filesize;
    unsigned long ssl_err = 0;
    int server;
    SSL *ssl;
    int bytes,lenpk,ret;
    long res = 1;
    struct hostent *host;
    struct sockaddr_in addr;
    unsigned char *buff1 = NULL;
    unsigned char tempb64[16384];
    X509* cert = NULL;
    const SSL_METHOD* method =SSLv23_method();
    int mr=16384;
    int ptr=0;
    int c=0;
    size_t nb;
    char *reply=NULL;
    int fnd,br,fbs;
    char fs[16385];
    char fnc[512];
    char fncd[512];
    char fncdw[512];
    struct stat sb,sbe,sbd;
    //CHECK IF PRESENT IN THE CACHE
    sprintf(fnc,"%s/Documents",getenv("HOME"));
    if (stat(fnc, &sb) != 0)
         mkdir(fnc, S_IRWXU | S_IRWXG);
    sprintf(fnc,"%s/Documents/test/%s.enc",getenv("HOME"),filename);
    sprintf(fncd,"%s/Documents/test/%s",getenv("HOME"),filename);
    sprintf(fncdw,"%s/Documents/test/%s.download",getenv("HOME"),filename);
    if(access(fnc,F_OK| R_OK)==0 && access(fncd,F_OK| R_OK)==0){
          stat(fnc, &sbe);
          stat(fncd,&sbd);
          if(sbe.st_size==sbd.st_size){
             reply=malloc(512);
             sprintf(reply,"{\"answer\":\"OK\",\"message\":\"File present in the cache\",\"filename\":\"%s\",\"localfilename\":\"%s\"}",fnc,fncd);
             return(reply);
          }
    }
    // CREATE CONTEXT OPENSSL
    ctx = SSL_CTX_new(method);
    ssl_err = ERR_get_error();
    if(ctx==NULL){
        const char* const str = ERR_reason_error_string(ssl_err);
        sprintf(error,"4001 - Error creating CTX structure [%s]",str);
        goto CLEANUP;
    }
    SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, bb_verify_callback);
    SSL_CTX_set_verify_depth(ctx, 5);
    //CONFIGURE TLS 1.2 AND UPPER ONLY
    const long flags = SSL_OP_ALL | SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3 | SSL_OP_NO_COMPRESSION |SSL_OP_NO_TLSv1|SSL_OP_NO_TLSv1_1;
    long old_opts = SSL_CTX_set_options(ctx, flags);
    UNUSED(old_opts);
    /*
    //LOAD TRUSTED CA ONLY
    res = SSL_CTX_load_verify_locations(ctx, (const char*)CaLocation, NULL);
    ssl_err = ERR_get_error();
    if(res!=1)
    {
            const char* const str  = ERR_reason_error_string(ssl_err);
            sprintf(error,"4002 - Error creating CTX structure [%s]",str);
            goto CLEANUP;
    }*/
    //LOAD TRUSTED CA FROM VARIABLE
    X509 *BB_CAcert;
    char zCert[8192];
    BIO *bbmem;
    strncpy(zCert,"-----BEGIN CERTIFICATE-----\n"
    "MIIDJDCCAoagAwIBAgIBAjAKBggqhkjOPQQDBDBUMQswCQYDVQQGEwJYWDERMA8G\n"
    "A1UECgwIWFhYWFhYWFgxHDAaBgNVBAsME1hYWFhYWFhYIE5ldHdvcmsgQ0ExFDAS\n"
    "BgNVBAMMC1hYWFhYWFhYIENBMB4XDTIwMDcyMzExMDE0N1oXDTMwMDcyMzExMDE0\n"
    "N1owVDELMAkGA1UEBhMCWFgxETAPBgNVBAoMCFhYWFhYWFhYMRgwFgYDVQQLDA9Y\n"
    "WFhYWFhYWCBUTFMgQ0ExGDAWBgNVBAMMD1hYWFhYWFhYIFRMUyBDQTCBmzAQBgcq\n"
    "hkjOPQIBBgUrgQQAIwOBhgAEAfM9O3mAr8vfnm9nM7hGwSOctHTqsTG4kx4p9OBk\n"
    "hXnqc9I8zLgEqyIah+4kxx9Zj3R3W86lK9GgkRmmNG+bVwX8AdNYCoL83dwwndUI\n"
    "aSQ2G/4zGoDA//E3Da032ho0+mwwzZRanIMw49FRYzU3twXyxLQ4abrVjAl1wxCP\n"
    "fg2Wohs4o4IBBDCCAQAwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8C\n"
    "AQAwHQYDVR0OBBYEFFLs9uEaIJkc0+m60PBsr5EAIZXHMB8GA1UdIwQYMBaAFBRF\n"
    "ka3kfCxc6O6fcSu1xYiuTwZEMD8GCCsGAQUFBwEBBDMwMTAvBggrBgEFBQcwAoYj\n"
    "aHR0cHM6Ly9rcnlwdG90ZWwuYWUvbmV0d29yay1jYS5jZXIwNAYDVR0fBC0wKzAp\n"
    "oCegJYYjaHR0cHM6Ly9rcnlwdG90ZWwuYWUvbmV0d29yay1jYS5jcmwwIwYDVR0g\n"
    "BBwwGjALBgkrBgEEAQABBwgwCwYJKwYBBAEAAQcJMAoGCCqGSM49BAMEA4GLADCB\n"
    "hwJCAfZyuYLE1Sxw53bAeDWAqYqFIJ5ThYBUyBs1rgZqDJjxl4JUAH6LWEmpQVnY\n"
    "1yuRevCDbUzQgA7mrFjDkxyqwVb0AkF9qEjWxgDbhtO9MrAJNNQZs7a/Es+g1R7p\n"
    "6A9Bh78Q+OBnvPZtdaOY75enpzDlBMHkwU1NaBHIEnVh5OBfr1WLnQ==\n"
    "-----END CERTIFICATE-----\n"
    "-----BEGIN CERTIFICATE-----\n"
    "MIIDFDCCAnWgAwIBAgIBAjAKBggqhkjOPQQDBDBOMQswCQYDVQQGEwJYWDERMA8G\n"
    "A1UECgwIWFhYWFhYWFgxETAPBgNVBAsMCFhYWFhYWFhYMRkwFwYDVQQDDBBYWFhY\n"
    "WFhYWCBSb290IENBMB4XDTIwMDcyMzExMDEwNFoXDTMwMTIzMTIzNTk1OVowVDEL\n"
    "MAkGA1UEBhMCWFgxETAPBgNVBAoMCFhYWFhYWFhYMRwwGgYDVQQLDBNYWFhYWFhY\n"
    "WCBOZXR3b3JrIENBMRQwEgYDVQQDDAtYWFhYWFhYWCBDQTCBmzAQBgcqhkjOPQIB\n"
    "BgUrgQQAIwOBhgAEAZ7pcxqkX6lMKJ5oYGMoRWOoTtY1CatNi/4O3u5Tp9+hCfP9\n"
    "XxpvxEThWRdva/i9duxEMnGdVFrZw4QCZHoBV0evAeelTFDyk2DW31EjYvOyX88a\n"
    "9mz1KBFlHyEu6KJLrWRIAPXpM100eQbB2NHJ1BkNYVBcD0NnX8yvC5SzgW//ArHr\n"
    "o4H6MIH3MA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW\n"
    "BBQURZGt5HwsXOjun3ErtcWIrk8GRDAfBgNVHSMEGDAWgBSpZtRanMPVVYTMWvyR\n"
    "vQ9u0+4d3jA8BggrBgEFBQcBAQQwMC4wLAYIKwYBBQUHMAKGIGh0dHBzOi8va3J5\n"
    "cHRvdGVsLmFlL3Jvb3QtY2EuY2VyMDEGA1UdHwQqMCgwJqAkoCKGIGh0dHBzOi8v\n"
    "a3J5cHRvdGVsLmFlL3Jvb3QtY2EuY3JsMCMGA1UdIAQcMBowCwYJKwYBBAEAAQcI\n"
    "MAsGCSsGAQQBAAEHCTAKBggqhkjOPQQDBAOBjAAwgYgCQgGh1zN6g0CsRcD+6Et+\n"
    "n5Nko2Wt441cyiELUJc+lLCCcMNNBxTjmJnLc1bp/9phCAoeXdgBfLTk4imw2+Sm\n"
    "f0rkgAJCAOcSEvhzbbsDHZBgcob65unrio/NIyw7TYIIKuVx2ug6vBrpHWS6/iq7\n"
    "i13K+dI1LopPzj99Th2hhGZX2E9jdmav\n"
    "-----END CERTIFICATE-----\n"
    "-----BEGIN CERTIFICATE-----\n"
    "MIICdjCCAdegAwIBAgIBATAKBggqhkjOPQQDBDBOMQswCQYDVQQGEwJYWDERMA8G\n"
    "A1UECgwIWFhYWFhYWFgxETAPBgNVBAsMCFhYWFhYWFhYMRkwFwYDVQQDDBBYWFhY\n"
    "WFhYWCBSb290IENBMB4XDTIwMDcyMzExMDAyMloXDTMwMTIzMTIzNTk1OVowTjEL\n"
    "MAkGA1UEBhMCWFgxETAPBgNVBAoMCFhYWFhYWFhYMREwDwYDVQQLDAhYWFhYWFhY\n"
    "WDEZMBcGA1UEAwwQWFhYWFhYWFggUm9vdCBDQTCBmzAQBgcqhkjOPQIBBgUrgQQA\n"
    "IwOBhgAEASEGXhmR+2snzkXUz+KsOdIypo+hU8WNM5BJQSe5PyJr53xhh36lOdYC\n"
    "l9kIB4QbhPjo66v2LjV2FzlUreQ2i2TpAGLVFHiiYBAMb1W83xiBcvczk19VfflC\n"
    "hEA2IxhbAqftcNQGFL3luATvQihdd4YjNRtolWDS73KzKq1IEsdx+Ji5o2MwYTAO\n"
    "BgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUqWbUWpzD\n"
    "1VWEzFr8kb0PbtPuHd4wHwYDVR0jBBgwFoAUqWbUWpzD1VWEzFr8kb0PbtPuHd4w\n"
    "CgYIKoZIzj0EAwQDgYwAMIGIAkIB6JabuM5icMe2wlLTm7affMUi7lawa/XxUgGh\n"
    "fx7GbaTFcvDtC7nUswtFlWmUGJroSQoCqd+g+0qZZgPIyE5COWYCQgDfRp/zEUYU\n"
    "yUqDs8xajRkoSj00ZcSsTq6S5SGrI1NgVaqBkHjKcwG3K9sNPjpyS9Xsx2nrwYCU\n"
    "ShTmVLfHtnLgcA==\n"
    "-----END CERTIFICATE-----\n",8192);

    bbmem = BIO_new(BIO_s_mem());
    BIO_puts(bbmem, zCert);
    while (BB_CAcert = PEM_read_bio_X509(bbmem, NULL, 0, NULL)) {
         X509_STORE_add_cert(SSL_CTX_get_cert_store(ctx), BB_CAcert);
         X509_free(BB_CAcert);
    }
    BIO_free(bbmem);
    //END TRUSTED CA LOAD FROM VARIABLE
    // CHECK FOR OTHER DOWNLOAD PENDING
    if(bb_filetransfer_pending(filename)==1){
        strcpy(error,"4003a -Download same file name is running");
        goto CLEANUP;
    }
    
    // OPEN SOCKET CONNECTION
    if ( (host = gethostbyname(hostname)) == NULL )
    {
        const char* const str = ERR_reason_error_string(ssl_err);
        sprintf(error,"4003 - hostname is wrong [%s][%s]",hostname,str);
        goto CLEANUP;
    }
    server = socket(PF_INET, SOCK_STREAM, 0);
    bzero(&addr, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = *(long*)(host->h_addr);
    if ( connect(server, (struct sockaddr*)&addr, sizeof(addr)) != 0 )
    {
        sprintf(error,"4004 - error connecting to server [%s]",hostname);
        close(server);
        goto CLEANUP;
    }
    ssl = SSL_new(ctx);
    SSL_set_fd(ssl, server);    /* attach the socket descriptor */
    if ( SSL_connect(ssl) == -1 ){   /* perform the connection */
        sprintf(error,"4005 - error connecting TLS to server [%s]",hostname);
        close(server);
        goto CLEANUP;
    }
    //CERTIFICATE PINNING
    cert = SSL_get_peer_certificate(ssl);
    if(cert==NULL){
        sprintf(error,"4006 - error getting certificate from server [%s]",hostname);
        close(server);
        goto CLEANUP;
    }
    lenpk = i2d_X509_PUBKEY(X509_get_X509_PUBKEY(cert), NULL);
    if(lenpk>8192){
        strcpy(error,"4007 - certificate is too loong");
        close(server);
        goto CLEANUP;
    }
    unsigned char* temp = NULL;
    buff1= temp = OPENSSL_malloc(lenpk);
    lenpk= i2d_X509_PUBKEY(X509_get_X509_PUBKEY(cert),&temp);
    bb_encode_base64(buff1,lenpk,tempb64);
    OPENSSL_free(buff1);
    //if(verbose) printf("blackbox-client.c - public key length from server: %d\n",lenpk);
    //if(verbose) printf("blackbox-client.c - public key  from server: %s\n",tempb64);
    //if(verbose) printf("blackbox-client.c - public key hard coded: %s\n",publickey);
    if(strcmp(tempb64,publickey)!=0){
        if(verbose) printf("blackbox-client.c - public key is not matching\n");
        sprintf(error,"4008 - Public key is not matching the hard coded %s",hostname);
        close(server);
        goto CLEANUP;
    }
    //*** END CERTIFICATE PINNING
    if(verbose) printf("bb_tls_getencryptedfile() -  - sending msg: %s\n",msg);
    //*** SEND MSG
    ret=SSL_write(ssl,msg, strlen(msg));
    if(ret<=0){
        strcpy(error,"4009 - Error sending message ");
        close(server);
        goto CLEANUP;
    }
    //*** READ REPLY
    nb=(size_t)(mr+64);
    reply=(char *)malloc(nb);
    if(reply==NULL){
        strcpy(error,"4010 - Error allocating space for reply ");
        close(server);
        goto CLEANUP;
    }
    bytes = SSL_read(ssl, reply,mr);
    if(bytes<=0){
        strcpy(error,"4011 - Error reading  message ");
        close(server);
        goto CLEANUP;
    }
    reply[bytes]=0;
    c=1;
    ptr=bytes;
    if (verbose) printf("###### bb_tls_getencryptedfile() - REPLY:%s\n",reply);
    //FILE TRANSFER IF APPLICABLE
    bb_json_getvalue("answer",reply,answer,63);
    filesizetxt[0]=0;
    bb_json_getvalue("filesize",reply,filesizetxt,256);
    filepwd[0]=0;
    bb_json_getvalue("filepwd",reply,filepwd,2047);
    filesize=atoi(filesizetxt);
    //CHECK IF FILE IS ALREADY IN CACHE
    if(access(fnc,F_OK| R_OK)==0 && strcmp(answer,"OK")==0){
        stat(fnc, &sbe);
        if(sbe.st_size==filesize)
           goto JUMPDOWNLOAD;
    }
    //END CACHE MANAGEMENT
    if(strcmp(answer,"OK")==0){
         fbs=0;
         if(verbose) printf("Downloading file in %s\n",fnc);
         unlink(fnc);
         unlink(fncdw);
         fnd=open(fncdw,O_WRONLY | O_CREAT |S_IRUSR |S_IWUSR,0600);
         if(fnd==-1){
           sprintf(error,"Error opening file %s",fnc);
           goto CLEANUP;
         }
         time_t timestart;
         timestart=time(NULL);
         while(1){
             br=SSL_read(ssl,fs, 16384);
             if(br==-1){
                strcpy(error,"4012 - Connection broken during file transfer");
                close(fnd);
                unlink(fnc);
                unlink(fncdw);
                bb_filetransfer_broken(fnc);
                goto CLEANUP;
             }
             if(br==0){
               if(verbose) printf("blackbox.c: getencryptedfile: waiting 1 seconds to read socket\n");
               sleep(1);
               if(time(NULL)-timestart>15){
                strcpy(error,"4013 - Connection timeout during file transfer");
                close(fnd);
                unlink(fnc);
                unlink(fncdw);
                bb_filetransfer_broken(fnc);
                goto CLEANUP;
               }
               continue;
             }
             timestart=time(NULL);
             write(fnd,fs,br);
             fbs=fbs+br;
             if(verbose) printf("File Download  %d bytes, total received: %d\n",br,fbs);
             bb_filetransfer_addbytes(fnc,br,filesize);
             if(fbs>=filesize) break;
             //sleep(5);
         }
         close(fnd);
         rename(fncdw,fnc);
         JUMPDOWNLOAD:
         chmod(fnc,S_IRUSR|S_IWUSR);
         if(verbose) printf("blackbox.c: - File download %s completed, bytes sent: %d\n",filename,fbs);
         sprintf(reply,"{\"answer\":\"OK\",\"message\":\"File download %s completed, bytes received: %d\",\"filename\":\"%s\",\"filepwd\":\"%s\"}",filename,fbs,fnc,filepwd);
         memset(fs,0x0,16385);
    }
    SSL_free(ssl);
    close(server);
        
    // CLEAN RETURN
    if(NULL != ctx) SSL_CTX_free(ctx);
    if(cert!=NULL) X509_free(cert);
    return(reply);

    CLEANUP:
    if(NULL != ctx) SSL_CTX_free(ctx);
    X509_free(cert);
    if(reply==NULL) reply=malloc(1024);
    sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
    return(reply);
}
/**
* FUNCTION TO VERIFY THE CERTIFICATE PRESENTED FROM THE SERVER
*/
int bb_verify_callback(int preverify, X509_STORE_CTX* x509_ctx)
{
    /* For error codes, see http://www.openssl.org/docs/apps/verify.html  */
    
    int depth = X509_STORE_CTX_get_error_depth(x509_ctx);
    int err = X509_STORE_CTX_get_error(x509_ctx);
    
    X509* cert = X509_STORE_CTX_get_current_cert(x509_ctx);
    X509_NAME* iname = cert ? X509_get_issuer_name(cert) : NULL;
    X509_NAME* sname = cert ? X509_get_subject_name(cert) : NULL;
    
  //  if(verbose) fprintf(stdout, "verify_callback (depth=%d)(preverify=%d)\n", depth, preverify);
    
    /* Issuer is the authority we trust that warrants nothing useful */
    //if(verbose) bb_print_cn_name("blackbox-client.c - Issuer (cn)", iname);
    
    /* Subject is who the certificate is issued to by the authority  */
    //if(verbose) bb_print_cn_name("blackbox-client.c - Subject (cn)", sname);
    
//    if(depth == 0) {
//        if(verbose) bb_print_san_name("blackbox-client.c - Subject (san)", cert);
//    }
    
    if(preverify == 0)
    {
        if(err == X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY)
            fprintf(stderr, "  Error = X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY\n");
        else if(err == X509_V_ERR_CERT_UNTRUSTED)
            fprintf(stderr, "  Error = X509_V_ERR_CERT_UNTRUSTED\n");
        else if(err == X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN)
            fprintf(stderr, "  Error = X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN\n");
        else if(err == X509_V_ERR_CERT_NOT_YET_VALID)
            fprintf(stderr, "  Error = X509_V_ERR_CERT_NOT_YET_VALID\n");
        else if(err == X509_V_ERR_CERT_HAS_EXPIRED)
            fprintf(stderr, "  Error = X509_V_ERR_CERT_HAS_EXPIRED\n");
        else if(err == X509_V_OK)
            fprintf(stderr, "  Error = X509_V_OK\n");
        else
            fprintf(stderr, "  Error = %d\n", err);
        return(0);
    }
    return 1;
}
/**
* FUNCTION TO PRINT CN NAME OF A CERTIFICATE
*/
void bb_print_cn_name(const char* label, X509_NAME* const name)
{
    int idx = -1, success = 0;
    unsigned char *utf8 = NULL;
    
    do
    {
        if(!name) break; /* failed */
        
        idx = X509_NAME_get_index_by_NID(name, NID_commonName, -1);
        if(!(idx > -1))  break; /* failed */
        
        X509_NAME_ENTRY* entry = X509_NAME_get_entry(name, idx);
        if(!entry) break; /* failed */
        
        ASN1_STRING* data = X509_NAME_ENTRY_get_data(entry);
        if(!data) break; /* failed */
        
        int length = ASN1_STRING_to_UTF8(&utf8, data);
        if(!utf8 || !(length > 0))  break; /* failed */
        
        fprintf(stdout, "  %s: %s\n", label, utf8);
        success = 1;
        
    } while (0);
    
    if(utf8)
        OPENSSL_free(utf8);
    
    if(!success)
        fprintf(stdout, "  %s: <not available>\n", label);
}

/**
* FUNCTION TO PRINT SAN NAME OF A CERTIFICATE
*/
void bb_print_san_name(const char* label, X509* const cert)
{
    int success = 0;
    GENERAL_NAMES* names = NULL;
    unsigned char* utf8 = NULL;
    
    do
    {
        if(!cert) break; /* failed */
        
        names = X509_get_ext_d2i(cert, NID_subject_alt_name, 0, 0 );
        if(!names) break;
        
        int i = 0, count = sk_GENERAL_NAME_num(names);
        if(!count) break; /* failed */
        
        for( i = 0; i < count; ++i )
        {
            GENERAL_NAME* entry = sk_GENERAL_NAME_value(names, i);
            if(!entry) continue;
            
            if(GEN_DNS == entry->type)
            {
                int len1 = 0, len2 = -1;
                
                len1 = ASN1_STRING_to_UTF8(&utf8, entry->d.dNSName);
                if(utf8) {
                    len2 = (int)strlen((const char*)utf8);
                }
                
                if(len1 != len2) {
                    fprintf(stderr, "  Strlen and ASN1_STRING size do not match (embedded null?): %d vs %d\n", len2, len1);
                }
                
                /* If there's a problem with string lengths, then     */
                /* we skip the candidate and move on to the next.     */
                /* Another policy would be to fails since it probably */
                /* indicates the client is under attack.              */
                if(utf8 && len1 && len2 && (len1 == len2)) {
                    fprintf(stdout, "  %s: %s\n", label, utf8);
                    success = 1;
                }
                
                if(utf8) {
                    OPENSSL_free(utf8), utf8 = NULL;
                }
            }
            else
            {
                fprintf(stderr, "2002 - Unknown GENERAL_NAME type: %d\n", entry->type);
            }
        }

    } while (0);
    
    if(names)
        GENERAL_NAMES_free(names);
    
    if(utf8)
        OPENSSL_free(utf8);
    
    if(!success)
        fprintf(stdout, "  %s: <not available>\n", label);
    
}
/**
* FUNCTION TO GET CERTIFICATES OF THE RECIPIENT
*/
char * bb_get_cert(char *sender,char *recipient,char *token,char *pwd){
    char msg[4096];
    char error[128];
    char *reply=NULL;
    char *encrypted=NULL;
    char *encryptedb64=NULL;
    char buf[256];
    int lenreply,taglen;
    int encryptedlen;
    int elen,eb64len;
    char tagaes[512];
    char oldtagaes[512];
    char newpwd[2048];
    char *pwdres=NULL;
    char ltoken[512];
    char hashrecipient[512];
    char hashrecipientb64[1024];
    char buffer[1024];
    //NEW VARS
    char fname[1024];
    FILE *fp;
    struct stat sb;

    if(strlen(sender)==0){
        strcpy(error,"1650 - Sender cannot be empty");
        goto CLEANUP;
    }
    if(strlen(sender)>=63){
        strcpy(error,"1651 - Sender is too long");
        goto CLEANUP;
    }
    if(strlen(recipient)==0){
        strcpy(error,"1652 - Recipient cannot be empty");
        goto CLEANUP;
    }
    if(strlen(recipient)>=63){
        strcpy(error,"1653 - Recipient is too long");
        goto CLEANUP;
    }
    if(strlen(token)==0){
        strcpy(error,"1654 - Token cannot be empty");
        goto CLEANUP;
    }
    if(strlen(token)>=255){
        strcpy(error,"1655 - Token is too long");
        goto CLEANUP;
    }
    sprintf(fname,"%s/Documents/test/cache",getenv("HOME"));
    //printf(fname);
    //exit(0);
    if (stat(fname, &sb) != 0)
    {
        if(verbose) printf("mkdir %s\n",fname);
        mkdir(fname, S_IRWXU | S_IRWXG);
    }
    // compute hash of the recipient
    if(strlen(recipient)<256) {
        sprintf(buffer,"%s 287Sjdshw23893489sds-23:278237833sdjnhdsuy3DHJA",recipient);
        int x=strlen(buffer);
        int hashlen=bb_sha2_512(buffer,x,hashrecipient);
        //bb_encode_base64(hashrecipient,hashlen,hashrecipientb64);
        bb_bin2hex(hashrecipient,hashlen,hashrecipientb64);
    }else {
        strncpy(hashrecipientb64,recipient,255);
        hashrecipientb64[256]=0;
    }
    sprintf(fname,"%s/Documents/test/cache/%s.enccrt",getenv("HOME"),hashrecipientb64);
    // LOAD CERTIFICATE FROM DISK
    if(access(fname,F_OK)>=0){
        fp=fopen(fname,"r");
        reply=malloc(16384);
        encryptedb64=malloc(16384);
        encrypted=malloc(16384);
        encryptedb64[0]=0;
        fgets(encryptedb64,16383,fp);
        eb64len=strlen(encryptedb64);
        fclose(fp);
        if(strstr(encryptedb64,"###")!=NULL){
          strncpy(tagaes,strstr(encryptedb64,"###")+3,511);
          taglen=strlen(tagaes);
          encryptedb64[eb64len-taglen-3]=0;
        }
        elen=bb_decode_base64(encryptedb64,encrypted);
        bb_json_getvalue("tagaes",pwd,oldtagaes,511);
        pwdres=bb_str_replace(pwd,oldtagaes,tagaes);
        if(!bb_decrypt_buffer(reply,&lenreply,encrypted,elen,pwdres)){
            if(verbose) printf("Error decrypting Local cache\n");
        }
        else{
            reply[lenreply]=0;
            if(verbose) printf("\n\n########## Local cache: %s\n\n\n",reply);
            goto CACHELOADED;
        }
    }
    // SEND GETCERT REQUEST
    sprintf(msg,"{\"action\":\"getcert\",\"mobilenumber\":\"%s\",\"recipient\":\"%s\",\"token\":\"%s\"}",sender,recipient,token);
    lenreply=0;
    reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
    if(reply==NULL){
            if(verbose) printf("reply: %s\n",reply);
            strcpy(reply,"{\"answer\":\"KO\",\"message\":\"error sending TLS message\"}");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,63);
        goto CLEANUP;
   }
   ltoken[0]=0;
   bb_json_getvalue("token",reply,ltoken,254);
   if(strlen(ltoken)>0) strncpy(bbtoken,ltoken,255);
   // SAVE TO CACHE THE CERTIFICATE
   sprintf(fname,"%s/Documents/test/cache/%s.enccrt",getenv("HOME"),hashrecipientb64);
   elen=strlen(reply)+2048;
   encrypted=malloc(elen);
   encryptedlen=0;
   strncpy(newpwd,pwd,2047);
   if(!bb_encrypt_buffer_setkey(reply,strlen(reply),encrypted,&encryptedlen,newpwd)){
         strcpy(error,"1900 - error encrypting the cache");
         goto CLEANUP;
   }
   eb64len=elen*2;
   encryptedb64=malloc(eb64len);
   bb_encode_base64(encrypted,encryptedlen,encryptedb64);
   fp=fopen(fname,"w");
   
   tagaes[0]=0;
   bb_json_getvalue("tagaes",newpwd,tagaes,511);
   fprintf(fp,"%s###%s",encryptedb64,tagaes);
   fclose(fp);
   
   
   //CLEANUP VARS AND RETURN
   CACHELOADED:
   memset(error,0x0,128);
   memset(msg,0x0,4096);
   memset(buf,0x0,256);
   memset(fname,0x0,1024);
   memset(newpwd,0x0,2048);
   memset(oldtagaes,0x0,512);
   memset(tagaes,0x0,512);
   lenreply=0;
   if(encrypted!=NULL) memset(encrypted,0x0,elen);
   if(encryptedb64!=NULL) memset(encryptedb64,0x0,eb64len);
   if(encrypted!=NULL) free(encrypted);
   if(encryptedb64!=NULL) free(encryptedb64);
   if(pwdres!=NULL) memset(pwdres,0x0,strlen(pwdres));
   if(pwdres!=NULL) free(pwdres);
   elen=0;
   eb64len=0;
   return(reply);

   CLEANUP:
   if(reply==NULL) reply=malloc(128);
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   memset(msg,0x0,4096);
   memset(buf,0x0,256);
   memset(fname,0x0,1024);
   memset(newpwd,0x0,2048);
   memset(oldtagaes,0x0,512);
   memset(tagaes,0x0,512);
   lenreply=0;
   if(encrypted!=NULL) memset(encrypted,0x0,elen);
   if(encryptedb64!=NULL) memset(encryptedb64,0x0,eb64len);
   if(encrypted!=NULL) free(encrypted);
   if(encryptedb64!=NULL) free(encryptedb64);
   if(pwdres!=NULL) memset(pwdres,0x0,512);
   if(pwdres!=NULL) free(pwdres);
   elen=0;
   eb64len=0;
   return(reply);
}
/**
* FUNCTION TO LOAD AND DECRYPT CONFIGURATION FROM DISK
*/
char * bb_load_configuration(char *pwdconf,char * conf){
     char filename[512];
     char confb64[8192];
     char confenc[8192];
     char error[256];
     char *answer;
     FILE *fp;
     int x;
     int conflen;
     struct stat sb;

     sprintf(filename,"%s/Documents",getenv("HOME"));
     if (stat(filename, &sb) != 0)
         mkdir(filename, S_IRWXU | S_IRWXG);
     sprintf(filename,"%s/Documents/test/c4955380679ef409832fb2de2f8878638833ba2cb3b7d2285db586b2295e6735.enc",getenv("HOME"));
     fp=fopen(filename,"r");
     if(fp==NULL){
         strcpy(error,"3800 - configuration file is missing\n");
         goto CLEANUP;
     }
     fgets(confb64,8191,fp);
     fclose(fp);
     x=bb_decode_base64(confb64,confenc);
      if(x<=0){
        strcpy(error,"3801 - error decoding from base64 the configuration\n");
        goto CLEANUP;
    }
    confenc[x]=0;
    if(bb_decrypt_buffer(conf,&conflen,confenc,x,pwdconf)==0){
       strcpy(error,"3802 - error decrypting the configuration\n");
       goto CLEANUP;
   }
   conf[conflen]=0;
   answer=malloc(512);
   strcpy(answer,"{\"answer\":\"OK\",\"message\":\"configuration loaded\"}");
   memset(confb64,0x0,8192);
   memset(confenc,0x0,8192);
   memset(filename,0x0,512);
   memset(error,0x0,256);
   memset(&sb,0x0,sizeof(sb));
   x=0;
   conflen=0;
   return(answer);
   
   CLEANUP:
   answer=malloc(512);
   sprintf(answer,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(confb64,0x0,8192);
   memset(confenc,0x0,8192);
   memset(filename,0x0,512);
   memset(error,0x0,256);
   memset(&sb,0x0,sizeof(sb));
   x=0;
   conflen=0;
   return(answer);
   
}
/**
* FUNCTION TO ORIGINATE VOICE CALL
*/
char * bb_originate_voicecall(char *recipient,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[4096];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    unsigned char rd[128];
    unsigned char keyvoice[128];
    unsigned char keyvoiceb64[256];
    unsigned int sq,sqseed;
    char serveripaddress[128];
    char portread[64];
    char portwrite[64];
    char dummypacket[1024];
    ssize_t bytesent;
    int i;
    memset(keyvoice,0x0,128);
    memset(keyvoiceb64,0x0,256);
    // GENERATE KEY, SQ AND SQSEED FOR VOICE SESSION
    memset(rd,0x0,128);
    if(bb_crypto_random_data(rd)==0){
          strcpy(error,"16010 - Error generating true random data");
          goto CLEANUP;
     }
     memcpy(keyvoice,&rd[0],64);
     if(!bb_encode_base64(keyvoice,64,keyvoiceb64)){
        strcpy(error,"16011 - Error encoding in base64 keyvoice");
        goto CLEANUP;
     }
     if(bb_crypto_random_data(rd)==0){
          strcpy(error,"16012 - Error generating true random data");
          goto CLEANUP;
     }
     memset(&sq,0x0,4);
     memset(&sqseed,0x0,4);
     memcpy(&sq,&rd,2);
     memcpy(&sqseed,&rd[4],2);
     sprintf(bodymsg,"%s##%u###%u",keyvoiceb64,sq,sqseed);
    // END GENERATION KEY AND IV
    if(strlen(recipient)==0){
        strcpy(error,"16003 - Recipient is missing");
        goto CLEANUP;
    }
    if(strlen(recipient)>63){
       strcpy(error,"16004 - Recipient is too long");
       goto CLEANUP;
    }
    if(strlen(pwdconf)==0){
       strcpy(error,"16005 - configuration is missing");
       goto CLEANUP;
    }
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"16008 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1609 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1610 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1611 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1612 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"1613 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"1613r - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"voicecall%s%s%s%u,%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"voicecall\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   // SVTP INIT
   serveripaddress[0]=0;
   portread[0]=0;
   portwrite[0]=0;
   bb_json_getvalue("serveripaddress",reply,serveripaddress,127);
   bb_json_getvalue("portread",reply,portread,63);
   bb_json_getvalue("portwrite",reply,portwrite,63);
   if(verbose) printf("Call Setup on server ip: %s PortRead: %d PortWrite: %d\n",serveripaddress,atoi(portread),atoi(portwrite));
   //if(bb_svtp_init(&SvtpRead,sq,sqseed,keyvoice,"0.0.0.0",atoi(portread))==0){
   if(bb_svtp_init(&SvtpRead,sq,sqseed,keyvoice,serveripaddress,atoi(portread))==0){
      strcpy(error,SvtpRead.error);
      goto CLEANUP;
   }
   if(bb_svtp_init(&SvtpWrite,sq,sqseed,keyvoice,serveripaddress,atoi(portwrite))==0){
      strcpy(error,SvtpWrite.error);
      goto CLEANUP;
    }
   //** SEND A DUMMY AUDIOPACKET TO OPEN THE NAT FOR READING UDP PACKET
/*   if(SvtpRead.portbinded==0){
         if(bind(SvtpRead.fdsocket, (const struct sockaddr *)&SvtpRead.destination, sizeof(SvtpRead.destination))==-1){
             strcpy(SvtpRead.error,"5804 - Error binding socket - bb_svtp.c [");
             strncat(SvtpRead.error,strerror(errno),64);
             strcat(SvtpRead.error,"]");
             strcpy(error, SvtpRead.error);
             goto CLEANUP;
         }
         SvtpRead.portbinded=1;
   }*/
   /*
   bb_crypto_random_data(dummypacket);
   for(i=1;i<14;i++) memcpy(&dummypacket[i*64],&dummypacket[0],64);
   for(i=0;i<=5;i++){
       bytesent=sendto(SvtpRead.fdsocket,dummypacket,320,0,(struct sockaddr *)&SvtpRead.destination,sizeof(SvtpRead.destination));
       if(bytesent==-1){
         strcpy(error,"16310 - Error sending data packet to open NAT");
         goto CLEANUP;
       }
       usleep(10000);
   }*/
   // END SVTP INIT
   StatusVoiceCall=1;
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   bb_json_removefield(reply,"serveripaddress");
   bb_json_removefield(reply,"portread");
   bb_json_removefield(reply,"portwrite");
   bb_json_removefield(reply,"token");
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bx=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO ORIGINATE VOICE CALL
*/
char * bb_originate_voicecall_id(char *recipient,char *pwdconf,int session){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[4096];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    unsigned char rd[128];
    unsigned char keyvoice[128];
    unsigned char keyvoiceb64[256];
    unsigned int sq,sqseed;
    char serveripaddress[128];
    char portread[64];
    char portwrite[64];
    char dummypacket[1024];
    ssize_t bytesent;
    int i;
    memset(keyvoice,0x0,128);
    memset(keyvoiceb64,0x0,256);
    if(session<0 || session>9){
          strcpy(error,"16010a - session is wrong or missing");
          goto CLEANUP;
    }
    // GENERATE KEY, SQ AND SQSEED FOR VOICE SESSION
    memset(rd,0x0,128);
    if(bb_crypto_random_data(rd)==0){
          strcpy(error,"16010 - Error generating true random data");
          goto CLEANUP;
     }
     memcpy(keyvoice,&rd[0],64);
     if(!bb_encode_base64(keyvoice,64,keyvoiceb64)){
        strcpy(error,"16011 - Error encoding in base64 keyvoice");
        goto CLEANUP;
     }
     if(bb_crypto_random_data(rd)==0){
          strcpy(error,"16012 - Error generating true random data");
          goto CLEANUP;
     }
     memset(&sq,0x0,4);
     memset(&sqseed,0x0,4);
     memcpy(&sq,&rd,2);
     memcpy(&sqseed,&rd[4],2);
     sprintf(bodymsg,"%s##%u###%u",keyvoiceb64,sq,sqseed);
    // END GENERATION KEY AND IV
    if(strlen(recipient)==0){
        strcpy(error,"16003 - Recipient is missing");
        goto CLEANUP;
    }
    if(strlen(recipient)>63){
       strcpy(error,"16004 - Recipient is too long");
       goto CLEANUP;
    }
    if(strlen(pwdconf)==0){
       strcpy(error,"16005 - configuration is missing");
       goto CLEANUP;
    }
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"16008 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1609 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1610 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1611 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1612 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"1613 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"1613r - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"voicecall%s%s%s%u,%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"voicecall\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   // SVTP INIT
   serveripaddress[0]=0;
   portread[0]=0;
   portwrite[0]=0;
   bb_json_getvalue("serveripaddress",reply,serveripaddress,127);
   bb_json_getvalue("portread",reply,portread,63);
   bb_json_getvalue("portwrite",reply,portwrite,63);
   if(verbose) printf("Call Setup on server ip: %s PortRead: %d PortWrite: %d\n",serveripaddress,atoi(portread),atoi(portwrite));
   //if(bb_svtp_init(&SvtpRead,sq,sqseed,keyvoice,"0.0.0.0",atoi(portread))==0){
   if(bb_svtp_init(&SvtpReadAC[session],sq,sqseed,keyvoice,serveripaddress,atoi(portread))==0){
      strcpy(error,SvtpReadAC[session].error);
      goto CLEANUP;
   }
   if(bb_svtp_init(&SvtpWriteAC[session],sq,sqseed,keyvoice,serveripaddress,atoi(portwrite))==0){
      strcpy(error,SvtpWriteAC[session].error);
      goto CLEANUP;
    }
   //** SEND A DUMMY AUDIOPACKET TO OPEN THE NAT FOR READING UDP PACKET
/*   if(SvtpRead.portbinded==0){
         if(bind(SvtpRead.fdsocket, (const struct sockaddr *)&SvtpRead.destination, sizeof(SvtpRead.destination))==-1){
             strcpy(SvtpRead.error,"5804 - Error binding socket - bb_svtp.c [");
             strncat(SvtpRead.error,strerror(errno),64);
             strcat(SvtpRead.error,"]");
             strcpy(error, SvtpRead.error);
             goto CLEANUP;
         }
         SvtpRead.portbinded=1;
   }*/
   /*
   bb_crypto_random_data(dummypacket);
   for(i=1;i<14;i++) memcpy(&dummypacket[i*64],&dummypacket[0],64);
   for(i=0;i<=5;i++){
       bytesent=sendto(SvtpRead.fdsocket,dummypacket,320,0,(struct sockaddr *)&SvtpRead.destination,sizeof(SvtpRead.destination));
       if(bytesent==-1){
         strcpy(error,"16310 - Error sending data packet to open NAT");
         goto CLEANUP;
       }
       usleep(10000);
   }*/
   // END SVTP INIT
   SvtpReadAC[session].statusvoicecall=1;
   SvtpWriteAC[session].statusvoicecall=1;
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   bb_json_removefield(reply,"serveripaddress");
   bb_json_removefield(reply,"portread");
   bb_json_removefield(reply,"portwrite");
   bb_json_removefield(reply,"token");
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bx=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO ORIGINATE VIDEO CALL
*/
char * bb_originate_videocall(char *recipient,char *pwdconf){
    char *msg=NULL;
    char *crt=NULL;
    char bodymsg[4096];
    char *bodymsgenc=NULL;
    char *bodymsgencb64=NULL;
    char *bodymsgencr=NULL;
    char *bodymsgencb64r=NULL;
    char *buf=NULL;
    char *replysend;
    int x,conflen;
    char conf[8192];
    char sender[64];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char sign[8192];
    char *reply=NULL;
    char token[256];
    char answer[64];
    char encryptioncertificateb64[8192];
    char encryptioncertificate[8192];
    char encryptioncertificateb64r[8192];
    char encryptioncertificater[8192];
    int lensign=0,lenreply=0;
    uint32_t totp=0;
    int hashlen,cx,bx,bx64,buflen;
    int bxr,bx64r,cxr;
    char error[256];
    error[0]=0;
    FILE *fp;
    struct stat sb;
    char *replyconf;
    unsigned char rd[128];
    unsigned char keyvoice[128];
    unsigned char keyvoiceb64[256];
    unsigned int sq,sqseed;
    char serveripaddress[128];
    char portread[64];
    char portwrite[64];
    char dummypacket[1024];
    ssize_t bytesent;
    int i;
    memset(keyvoice,0x0,128);
    memset(keyvoiceb64,0x0,256);
    // GENERATE KEY, SQ AND SQSEED FOR VIDEO SESSION
    memset(rd,0x0,128);
    if(bb_crypto_random_data(rd)==0){
          strcpy(error,"16010 - Error generating true random data");
          goto CLEANUP;
     }
     memcpy(keyvoice,&rd[0],64);
     if(!bb_encode_base64(keyvoice,64,keyvoiceb64)){
        strcpy(error,"16011 - Error encoding in base64 keyvoice");
        goto CLEANUP;
     }
     if(bb_crypto_random_data(rd)==0){
          strcpy(error,"16012 - Error generating true random data");
          goto CLEANUP;
     }
     memset(&sq,0x0,4);
     memset(&sqseed,0x0,4);
     memcpy(&sq,&rd,2);
     memcpy(&sqseed,&rd[4],2);
     sprintf(bodymsg,"%s##%u###%u",keyvoiceb64,sq,sqseed);
    // END GENERATION KEY AND IV
    if(strlen(recipient)==0){
        strcpy(error,"16003 - Recipient is missing");
        goto CLEANUP;
    }
    if(strlen(recipient)>63){
       strcpy(error,"16004 - Recipient is too long");
       goto CLEANUP;
    }
    if(strlen(pwdconf)==0){
       strcpy(error,"16005 - configuration is missing");
       goto CLEANUP;
    }
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"16008 - session token is not present, you must register first\n");
       goto CLEANUP;
   }
   sender[0]=0;
   bb_json_getvalue("mobilenumber",conf,sender,63);
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1609 - totpseed not found in the configuration\n");
       goto CLEANUP;
   }
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1610 - blackbox-client.c: totp error\n");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1611 - blackbox-client.c: authentication private key not found in the configuration\n");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1612 - error decoding authentication private key\n");
        goto CLEANUP;
   }
   // GET PEER CERTIFICATE FOR ENCRYPTION OF THE BODYMSG
   crt=bb_get_cert(sender,recipient,bbtoken,pwdconf);
   bb_json_getvalue("answer",crt,answer,10);
   if(strcmp(answer,"KO")==0){
        bb_json_getvalue("message",crt,error,127);
        goto CLEANUP;
   }
   bb_json_getvalue("encryptioncertificate",crt,encryptioncertificateb64,8191);
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   //ENCRYPT BODY MESSAGE FOR RECIPIENT
   cx=bb_decode_base64(encryptioncertificateb64,encryptioncertificate);
   bx=strlen(bodymsg)*2+8192;
   bodymsgenc=malloc(bx);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificate,bodymsgenc)){
        strcpy(error,"1613 - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64=bx*2;
   bodymsgencb64=malloc(bx64);
   bb_encode_base64(bodymsgenc,strlen(bodymsgenc),bodymsgencb64);
   //***************************************
   // ENCRYPT BODY MESSAGE FOR SENDER
   bb_json_getvalue("encryptioncert",conf,encryptioncertificateb64r,8191);
   cxr=bb_decode_base64(encryptioncertificateb64r,encryptioncertificater);
   bxr=strlen(bodymsg)*2+8192;
   bodymsgencr=malloc(bxr);
   if(!bb_encrypt_buffer_ec(bodymsg,strlen(bodymsg),encryptioncertificater,bodymsgencr)){
        strcpy(error,"1613r - error encrypting the message by EC\n");
        goto CLEANUP;
   }
   bx64r=bxr*2;
   bodymsgencb64r=malloc(bx64r);
   bb_encode_base64(bodymsgencr,strlen(bodymsgencr),bodymsgencb64r);
   //*************************************
   // HASH CALCULATION
   buflen=strlen(sender)+strlen(recipient)+strlen(bodymsg)+strlen(bbtoken)+8192;
   buf=malloc(buflen);
   sprintf(buf,"videocall%s%s%s%u,%s",sender,recipient,bodymsg,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(bodymsgencb64)+strlen(bodymsgencb64r)+strlen(sender)+strlen(recipient)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msg=malloc(x+8192);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"videocall\",\"sender\":\"%s\",\"recipient\":\"%s\",\"bodymsgrecipient\":\"%s\",\"bodymsgsender\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",sender,recipient,bodymsgencb64,bodymsgencb64r,bbtoken,totp,hashb64,sign);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   
   // SVTP INIT (VOICE)
   serveripaddress[0]=0;
   portread[0]=0;
   portwrite[0]=0;
   bb_json_getvalue("serveripaddress",reply,serveripaddress,127);
   bb_json_getvalue("portread",reply,portread,63);
   bb_json_getvalue("portwrite",reply,portwrite,63);
   if(verbose) printf("Call Setup on server ip: %s PortRead: %d PortWrite: %d\n",serveripaddress,atoi(portread),atoi(portwrite));
   if(bb_svtp_init(&SvtpRead,sq,sqseed,keyvoice,serveripaddress,atoi(portread))==0){
      strcpy(error,SvtpRead.error);
      goto CLEANUP;
   }
   if(bb_svtp_init(&SvtpWrite,sq,sqseed,keyvoice,serveripaddress,atoi(portwrite))==0){
      strcpy(error,SvtpWrite.error);
      goto CLEANUP;
    }
   // END SVTP INIT
   // SWTP INIT (VIDEO)
   serveripaddress[0]=0;
   portread[0]=0;
   portwrite[0]=0;
   bb_json_getvalue("serveripaddress",reply,serveripaddress,127);
   bb_json_getvalue("vportread",reply,portread,63);
   bb_json_getvalue("vportwrite",reply,portwrite,63);
   if(verbose) printf("Video Setup on server ip: %s PortRead: %d PortWrite: %d\n",serveripaddress,atoi(portread),atoi(portwrite));
   if(bb_swtp_init(&SwtpRead,sq,sqseed,keyvoice,serveripaddress,atoi(portread))==0){
      strcpy(error,SwtpRead.error);
      goto CLEANUP;
   }
   if(bb_swtp_init(&SwtpWrite,sq,sqseed,keyvoice,serveripaddress,atoi(portwrite))==0){
      strcpy(error,SwtpWrite.error);
      goto CLEANUP;
    }
   // END SWTP INIT
   
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   memset(error,0x0,64);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bxr=0;
   bx64r=0;
   bb_json_removefield(reply,"serveripaddress");
   bb_json_removefield(reply,"portread");
   bb_json_removefield(reply,"portwrite");
   bb_json_removefield(reply,"vportread");
   bb_json_removefield(reply,"vportwrite");
   bb_json_removefield(reply,"token");
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,x+4096);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset(buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(crt!=NULL) memset(crt,0x0,strlen(crt));
   if(crt!=NULL) free(crt);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   if(bodymsgenc!=NULL) memset(bodymsgenc,0x0,bx);
   if(bodymsgenc!=NULL) free(bodymsgenc);
   if(bodymsgencb64!=NULL) memset(bodymsgencb64,0x0,bx64);
   if(bodymsgencb64!=NULL) free(bodymsgencb64);
   if(bodymsgencr!=NULL) memset(bodymsgencr,0x0,bxr);
   if(bodymsgencr!=NULL) free(bodymsgencr);
   if(bodymsgencb64r!=NULL) memset(bodymsgencb64r,0x0,bx64r);
   if(bodymsgencb64r!=NULL) free(bodymsgencb64r);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(answer,0x0,64);
   memset(encryptioncertificate,0x0,8192);
   memset(encryptioncertificateb64,0x0,8192);
   x=0;
   lensign=0;
   lenreply=0;
   totp=0;
   conflen=0;
   hashlen=0;
   cx=0;
   bx=0;
   bx64=0;
   bx=0;
   bx64r=0;
   replysend=malloc(512);
   sprintf(replysend,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,64);
   return(replysend);
}
/**
* FUNCTION TO GET INFO ABOUT AN INCOMING CALL
*/
char * bb_info_voicecall(char *pwdconf){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[512];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"voicecallinfo\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //DECRYPT ANSWER
   lenalltmsg=lenreply+8192;
   tmsgenc=malloc(lenalltmsg);
   tmsgencb64=malloc(lenalltmsg);
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
   z=bb_decode_base64(tmsgencb64,tmsgenc);
   tmsgenc[z]=0;
   lentmsg=0;
   tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
   if(tmsg==NULL){
      tmsg=malloc(64);
      strcpy(tmsg,"Error decrypting content");
   }
   else
      tmsg[lentmsg]=0;
   if(lentmsg>0)
      tmsg[lentmsg]=0;
   if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
   }
   else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);

   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(replydecrypted);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}

/**
* FUNCTION TO GET INFO ABOUT AN INCOMING VIDEO CALL
*/
char * bb_info_videocall(char *pwdconf){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[512];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"videocallinfo%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"videocallinfo\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //DECRYPT ANSWER
   lenalltmsg=lenreply+8192;
   tmsgenc=malloc(lenalltmsg);
   tmsgencb64=malloc(lenalltmsg);
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
   z=bb_decode_base64(tmsgencb64,tmsgenc);
   tmsgenc[z]=0;
   lentmsg=0;
   tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
   if(tmsg==NULL){
      tmsg=malloc(64);
      strcpy(tmsg,"Error decrypting content");
   }
   else
      tmsg[lentmsg]=0;
   if(lentmsg>0)
      tmsg[lentmsg]=0;
   if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
   }
   else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);

   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(replydecrypted);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO GET VOICE CALL LIST
*/
char * bb_last_voicecalls(char *pwdconf){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[512];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"lastvoicecalls%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"lastvoicecalls\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);

   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}


/**
* FUNCTION TO ANSWER AN INCOMING CALL
*/
char * bb_answer_voicecall(char *pwdconf){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    unsigned char keyvoice[128];
    unsigned char keyvoiceb64[256];
    char sq[64];
    char sqseed[64];
    char serveripaddress[128];
    char portread[64];
    char portwrite[64];
    char dummypacket[1024];
    ssize_t bytesent;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"voicecallanswer\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //DECRYPT ANSWER
   lenalltmsg=lenreply+8192;
   tmsgenc=malloc(lenalltmsg);
   tmsgencb64=malloc(lenalltmsg);
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
   z=bb_decode_base64(tmsgencb64,tmsgenc);
   tmsgenc[z]=0;
   lentmsg=0;
   tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
   if(tmsg==NULL){
      tmsg=malloc(64);
      strcpy(tmsg,"Error decrypting content");
   }
   else
      tmsg[lentmsg]=0;
   if(lentmsg>0)
      tmsg[lentmsg]=0;
   if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
   }
   else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   // SVTP INIT
   serveripaddress[0]=0;
   portread[0]=0;
   portwrite[0]=0;
   bb_json_getvalue("serveripaddress",reply,serveripaddress,127);
   bb_json_getvalue("calledudpportinput",reply,portread,63);
   bb_json_getvalue("calledudpportoutput",reply,portwrite,63);
   char *strp, *strpp;
   int kl;
   strp=strstr(tmsg,"##");
   if(strp==NULL){
        strcpy(error,"12700 - I cannot find the session key");
        goto CLEANUP;
   }
   kl=strp-&tmsg[0];
   if(kl>255) kl=255;
   strncpy(keyvoiceb64,tmsg,kl);
   keyvoiceb64[kl]=0;
   bb_decode_base64(keyvoiceb64,keyvoice);
   strpp=strstr(tmsg,"###");
   if(strpp==NULL){
        strcpy(error,"12701 - I cannot find the sequenxe number");
        goto CLEANUP;
   }
   kl=strpp-strp-2;
   strncpy(sq,strp+2,kl);
   sq[kl]=0;
   strncpy(sqseed,strpp+3,63);
   if(verbose) printf("Call Answering on server ip: %s PortRead: %d PortWrite: %d\n",serveripaddress,atoi(portread),atoi(portwrite));
   if(verbose) printf("keyvoice: %s sq: %u sqseed %u\n",keyvoiceb64,atoi(sq),atoi(sqseed));
   //if(bb_svtp_init(&SvtpRead,atoi(sq),atoi(sqseed),keyvoice,"0.0.0.0",atoi(portread))==0){
   if(bb_svtp_init(&SvtpRead,atoi(sq),atoi(sqseed),keyvoice,serveripaddress,atoi(portread))==0){
      strcpy(error,SvtpRead.error);
      goto CLEANUP;
   }
   if(bb_svtp_init(&SvtpWrite,atoi(sq),atoi(sqseed),keyvoice,serveripaddress,atoi(portwrite))==0){
      strcpy(error,SvtpWrite.error);
      goto CLEANUP;
    }
   //** SEND RANDOM DATA UDP PACKET  TO OPEN THE NAT
   bb_crypto_random_data(dummypacket);
   for(i=1;i<14;i++) memcpy(&dummypacket[i*64],&dummypacket[0],64);
   for(i=0;i<=5;i++){
       bytesent=sendto(SvtpRead.fdsocket,dummypacket,320,0,(struct sockaddr *)&SvtpRead.destination,sizeof(SvtpRead.destination));
       if(bytesent==-1){
         strcpy(error,"16310 - Error sending data packet to open NAT");
         goto CLEANUP;
       }
       usleep(10000);
   }
   StatusVoiceCall=2;
   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   bb_json_removefield(replydecrypted,"serveripaddress");
   bb_json_removefield(replydecrypted,"callerudpportinput");
   bb_json_removefield(replydecrypted,"callerudpportoutput");
   bb_json_removefield(replydecrypted,"calledudpportinput");
   bb_json_removefield(replydecrypted,"calledudpportoutput");
   bb_json_removefield(replydecrypted,"calleripaddress");
   bb_json_removefield(replydecrypted,"calledipaddress");
   bb_json_removefield(replydecrypted,"msgbody");
   bb_json_removefield(replydecrypted,"token");
   bb_json_removefield(replydecrypted,"uidrecipient");
   
   return(replydecrypted);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO ANSWER AN INCOMING CALL BY CALLID
*/
char * bb_answer_voicecall_id(char *pwdconf,char *callid,int session){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    unsigned char keyvoice[128];
    unsigned char keyvoiceb64[256];
    char sq[64];
    char sqseed[64];
    char serveripaddress[128];
    char portread[64];
    char portwrite[64];
    char dummypacket[1024];
    ssize_t bytesent;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
    if(strlen(callid)==0 || strlen(callid)>64){
       strcpy(error,"1904 - callid is wrong or missing");
       goto CLEANUP;
    }
    if(session<0 || session>9){
       strcpy(error,"1904a - session is wrong or missing");
       goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"voicecallanswer%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"voicecallanswer\",\"mobilenumber\":\"%s\",\"callid\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\"}",mobilenumber,callid,bbtoken,totp,hashb64,sign);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //DECRYPT ANSWER
   lenalltmsg=lenreply+8192;
   tmsgenc=malloc(lenalltmsg);
   tmsgencb64=malloc(lenalltmsg);
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
   z=bb_decode_base64(tmsgencb64,tmsgenc);
   tmsgenc[z]=0;
   lentmsg=0;
   tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
   if(tmsg==NULL){
      tmsg=malloc(64);
      strcpy(tmsg,"Error decrypting content");
   }
   else
      tmsg[lentmsg]=0;
   if(lentmsg>0)
      tmsg[lentmsg]=0;
   if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
   }
   else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   // SVTP INIT
   serveripaddress[0]=0;
   portread[0]=0;
   portwrite[0]=0;
   bb_json_getvalue("serveripaddress",reply,serveripaddress,127);
   bb_json_getvalue("calledudpportinput",reply,portread,63);
   bb_json_getvalue("calledudpportoutput",reply,portwrite,63);
   char *strp, *strpp;
   int kl;
   strp=strstr(tmsg,"##");
   if(strp==NULL){
        strcpy(error,"12700 - I cannot find the session key");
        goto CLEANUP;
   }
   kl=strp-&tmsg[0];
   if(kl>255) kl=255;
   strncpy(keyvoiceb64,tmsg,kl);
   keyvoiceb64[kl]=0;
   bb_decode_base64(keyvoiceb64,keyvoice);
   strpp=strstr(tmsg,"###");
   if(strpp==NULL){
        strcpy(error,"12701 - I cannot find the sequenxe number");
        goto CLEANUP;
   }
   kl=strpp-strp-2;
   strncpy(sq,strp+2,kl);
   sq[kl]=0;
   strncpy(sqseed,strpp+3,63);
   if(verbose) printf("Call Answering on server ip: %s PortRead: %d PortWrite: %d\n",serveripaddress,atoi(portread),atoi(portwrite));
   if(verbose) printf("keyvoice: %s sq: %u sqseed %u\n",keyvoiceb64,atoi(sq),atoi(sqseed));
   //if(bb_svtp_init(&SvtpRead,atoi(sq),atoi(sqseed),keyvoice,"0.0.0.0",atoi(portread))==0){
   if(bb_svtp_init(&SvtpReadAC[session],atoi(sq),atoi(sqseed),keyvoice,serveripaddress,atoi(portread))==0){
      strcpy(error,SvtpRead.error);
      goto CLEANUP;
   }
   if(bb_svtp_init(&SvtpWriteAC[session],atoi(sq),atoi(sqseed),keyvoice,serveripaddress,atoi(portwrite))==0){
      strcpy(error,SvtpWrite.error);
      goto CLEANUP;
    }
   //** SEND RANDOM DATA UDP PACKET  TO OPEN THE NAT
   bb_crypto_random_data(dummypacket);
   for(i=1;i<14;i++) memcpy(&dummypacket[i*64],&dummypacket[0],64);
   for(i=0;i<=5;i++){
       bytesent=sendto(SvtpReadAC[session].fdsocket,dummypacket,320,0,(struct sockaddr *)&SvtpReadAC[session].destination,sizeof(SvtpReadAC[session].destination));
       if(bytesent==-1){
         strcpy(error,"16310 - Error sending data packet to open NAT");
         goto CLEANUP;
       }
       usleep(10000);
   }
   SvtpReadAC[session].statusvoicecall=2;
   SvtpWriteAC[session].statusvoicecall=2;
   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   bb_json_removefield(replydecrypted,"serveripaddress");
   bb_json_removefield(replydecrypted,"callerudpportinput");
   bb_json_removefield(replydecrypted,"callerudpportoutput");
   bb_json_removefield(replydecrypted,"calledudpportinput");
   bb_json_removefield(replydecrypted,"calledudpportoutput");
   bb_json_removefield(replydecrypted,"calleripaddress");
   bb_json_removefield(replydecrypted,"calledipaddress");
   bb_json_removefield(replydecrypted,"msgbody");
   bb_json_removefield(replydecrypted,"token");
   bb_json_removefield(replydecrypted,"uidrecipient");
   
   return(replydecrypted);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO ANSWER AN INCOMING VIDEO CALL
*/
char * bb_answer_videocall(char *pwdconf,char * audioonly){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    unsigned char keyvoice[128];
    unsigned char keyvoiceb64[256];
    char sq[64];
    char sqseed[64];
    char serveripaddress[128];
    char portread[64];
    char portwrite[64];
    char vportread[64];
    char vportwrite[64];
    char dummypacket[1024];
    ssize_t bytesent;
    // CHECK AUDIO ONLY
    if(strcmp(audioonly,"Y")!=0 && strcmp(audioonly,"N")!=0){
       strcpy(error,"18920 - audio only field is wrong");
       goto CLEANUP;
    }
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"videocallanswer\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\",\"audioonly\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign,audioonly);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //DECRYPT ANSWER
   lenalltmsg=lenreply+8192;
   tmsgenc=malloc(lenalltmsg);
   tmsgencb64=malloc(lenalltmsg);
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
   z=bb_decode_base64(tmsgencb64,tmsgenc);
   tmsgenc[z]=0;
   lentmsg=0;
   tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
   if(tmsg==NULL){
      tmsg=malloc(64);
      strcpy(tmsg,"Error decrypting content");
   }
   else
      tmsg[lentmsg]=0;
   if(lentmsg>0)
      tmsg[lentmsg]=0;
   if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
   }
   else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   //StatusVoiceCall=2;
   //StatusVideoCall=2;
   // SVTP/SWTP INIT
   serveripaddress[0]=0;
   portread[0]=0;
   portwrite[0]=0;
   vportread[0]=0;
   vportwrite[0]=0;
   bb_json_getvalue("serveripaddress",reply,serveripaddress,127);
   bb_json_getvalue("calledudpportinput",reply,portread,63);
   bb_json_getvalue("calledudpportoutput",reply,portwrite,63);
   bb_json_getvalue("vcalledudpportinput",reply,vportread,63);
   bb_json_getvalue("vcalledudpportoutput",reply,vportwrite,63);
   char *strp, *strpp;
   int kl;
   strp=strstr(tmsg,"##");
   if(strp==NULL){
        strcpy(error,"12700 - I cannot find the session key");
        goto CLEANUP;
   }
   kl=strp-&tmsg[0];
   if(kl>255) kl=255;
   strncpy(keyvoiceb64,tmsg,kl);
   keyvoiceb64[kl]=0;
   bb_decode_base64(keyvoiceb64,keyvoice);
   strpp=strstr(tmsg,"###");
   if(strpp==NULL){
        strcpy(error,"12701 - I cannot find the sequence number");
        goto CLEANUP;
   }
   kl=strpp-strp-2;
   strncpy(sq,strp+2,kl);
   sq[kl]=0;
   strncpy(sqseed,strpp+3,63);
   if(verbose) printf("Voice Answering on server ip: %s PortRead: %d PortWrite: %d\n",serveripaddress,atoi(portread),atoi(portwrite));
   if(verbose) printf("Voice Answering on server ip: %s PortRead: %d PortWrite: %d\n",serveripaddress,atoi(vportread),atoi(vportwrite));
   if(verbose) printf("keyvoice: %s sq: %u sqseed %u\n",keyvoiceb64,atoi(sq),atoi(sqseed));
    printf("StatusVoicecall: %d\n StatusVideoCall: %d",StatusVoiceCall,StatusVideoCall);
    //INIT AUDIO STRUCTURE IF NOT ALREADY DONE
    if(StatusVoiceCall!=2){
        if(bb_svtp_init(&SvtpRead,atoi(sq),atoi(sqseed),keyvoice,serveripaddress,atoi(portread))==0){
            strcpy(error,SvtpRead.error);
            goto CLEANUP;
        }
        if(bb_svtp_init(&SvtpWrite,atoi(sq),atoi(sqseed),keyvoice,serveripaddress,atoi(portwrite))==0){
            strcpy(error,SvtpWrite.error);
            goto CLEANUP;
        }
        //** SEND RANDOM DATA UDP PACKET  TO OPEN THE NAT for VOICE
        bb_crypto_random_data(dummypacket);
        for(i=1;i<14;i++) memcpy(&dummypacket[i*64],&dummypacket[0],64);
        for(i=0;i<5;i++){
            bytesent=sendto(SvtpRead.fdsocket,dummypacket,320,0,(struct sockaddr *)&SvtpRead.destination,sizeof(SvtpRead.destination));
            if(bytesent==-1){
              strcpy(error,"16310 - Error sending data packet to open NAT");
              goto CLEANUP;
            }
            usleep(10000);
        }
        if(bb_swtp_init(&SwtpRead,atoi(sq),atoi(sqseed),keyvoice,serveripaddress,atoi(vportread))==0){
            strcpy(error,SwtpRead.error);
            goto CLEANUP;
        }
        if(bb_swtp_init(&SwtpWrite,atoi(sq),atoi(sqseed),keyvoice,serveripaddress,atoi(vportwrite))==0){
            strcpy(error,SwtpWrite.error);
            goto CLEANUP;
        }
       //** SEND RANDOM DATA UDP PACKET  TO OPEN THE NAT for VIDEO
       for(i=0;i<5;i++){
           bytesent=sendto(SwtpRead.fdsocket,dummypacket,320,0,(struct sockaddr *)&SwtpRead.destination,sizeof(SwtpRead.destination));
           if(bytesent==-1){
             strcpy(error,"16310a - Error sending data packet to open NAT");
             goto CLEANUP;
           }
           usleep(10000);
       }
        StatusVideoCall=2;
        StatusVoiceCall=2;
    }
   
   
   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(reply!=NULL) memset(reply,0x0,lenreply);
   if(reply!=NULL) free(reply);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   bb_json_removefield(replydecrypted,"serveripaddress");
   bb_json_removefield(replydecrypted,"callerudpportinput");
   bb_json_removefield(replydecrypted,"callerudpportoutput");
   bb_json_removefield(replydecrypted,"calledudpportinput");
   bb_json_removefield(replydecrypted,"calledudpportoutput");
   bb_json_removefield(replydecrypted,"vcallerudpportinput");
   bb_json_removefield(replydecrypted,"vcallerudpportoutput");
   bb_json_removefield(replydecrypted,"vcalledudpportinput");
   bb_json_removefield(replydecrypted,"vcalledudpportoutput");
   bb_json_removefield(replydecrypted,"calleripaddress");
   bb_json_removefield(replydecrypted,"calledipaddress");
   bb_json_removefield(replydecrypted,"msgbody");
   bb_json_removefield(replydecrypted,"token");
   bb_json_removefield(replydecrypted,"uidrecipient");
   return(replydecrypted);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}

/**
* FUNCTION TO HANGUP A CALL
*/
char * bb_hangup_voicecall(char *pwdconf, char * callid){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"voicecallhangup\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\",\"callid\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign,callid);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //DECRYPT ANSWER
/*   lenalltmsg=lenreply+8192;
   tmsgenc=malloc(lenalltmsg);
   tmsgencb64=malloc(lenalltmsg);
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
   z=bb_decode_base64(tmsgencb64,tmsgenc);
   tmsgenc[z]=0;
   lentmsg=0;
   tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
   if(tmsg==NULL){
      tmsg=malloc(64);
      strcpy(tmsg,"Error decrypting content");
   }
   else
      tmsg[lentmsg]=0;
   if(lentmsg>0)
      tmsg[lentmsg]=0;
   if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
   }
   else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }*/
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   StatusVoiceCall=3;
   StatusVideoCall=3;

   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO CONFIRM READY FOR VIDEO CALL
*/
char * bb_confirm_videocall(char *pwdconf, char * callid){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"videocallready\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\",\"callid\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign,callid);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //DECRYPT ANSWER
/*   lenalltmsg=lenreply+8192;
   tmsgenc=malloc(lenalltmsg);
   tmsgencb64=malloc(lenalltmsg);
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
   z=bb_decode_base64(tmsgencb64,tmsgenc);
   tmsgenc[z]=0;
   lentmsg=0;
   tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
   if(tmsg==NULL){
      tmsg=malloc(64);
      strcpy(tmsg,"Error decrypting content");
   }
   else
      tmsg[lentmsg]=0;
   if(lentmsg>0)
      tmsg[lentmsg]=0;
   if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
   }
   else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }*/
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);

   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/*
* FUNCTION TO HANGUP A CALL FOR A SESSION ID
*/
char * bb_hangup_voicecall_id(char *pwdconf, char * callid,int session){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   if(session<0 || session>9){
       strcpy(error,"1905a - session is wrong or missing");
       goto CLEANUP;

   }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"voicecallhangup\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\",\"callid\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign,callid);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //DECRYPT ANSWER
/*   lenalltmsg=lenreply+8192;
   tmsgenc=malloc(lenalltmsg);
   tmsgencb64=malloc(lenalltmsg);
   bb_json_getvalue("encryptionprivatekey",conf,encpkb64,8191);
   z=bb_decode_base64(encpkb64,encpk);
   encpk[z]=0;
   bb_json_getvalue("msgbody",reply,tmsgencb64,lenalltmsg-1);
   z=bb_decode_base64(tmsgencb64,tmsgenc);
   tmsgenc[z]=0;
   lentmsg=0;
   tmsg=bb_decrypt_buffer_ec(&lentmsg,encpk,tmsgenc);
   if(tmsg==NULL){
      tmsg=malloc(64);
      strcpy(tmsg,"Error decrypting content");
   }
   else
      tmsg[lentmsg]=0;
   if(lentmsg>0)
      tmsg[lentmsg]=0;
   if(reply!=NULL){
        replydecrypted=bb_str_replace(reply,tmsgencb64,tmsg);
   }
   else{
        replydecrypted=malloc(strlen(reply)+4096);
        strcpy(replydecrypted,reply);
   }*/
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   //UPDATE STATUS VOICE CALL
   SvtpReadAC[session].statusvoicecall=3;
   SvtpWriteAC[session].statusvoicecall=3;

   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO HANGUP A VIDEO CALL
*/
char * bb_hangup_videocall(char *pwdconf, char * callid){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"videocallhangup%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"videocallhangup\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\",\"callid\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign,callid);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   StatusVoiceCall=3;
   StatusVideoCall=3;

   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
FUNCTION TO GET STATUS OF A CALL
*/
char * bb_status_voicecall(char *pwdconf, char * callid){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    char status[64];
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"voicecallstatus\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\",\"callid\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign,callid);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   //UPDATE VOICECALL STATUS
   bb_json_getvalue("status",reply,status,63);
   if(strcmp(status,"hangup")==0){
       StatusVoiceCall=3;
       StatusVideoCall=3;
   }
   if(strcmp(status,"answered")==0 || strcmp(status,"answeredA")==0 || strcmp(status,"active")==0)
       StatusVoiceCall=2;
   if(strcmp(status,"ringing")==0)
       StatusVoiceCall=1;
   if(strcmp(status,"setup")==0)
       StatusVoiceCall=1;
   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO GET STATUS OF A CALL
*/
char * bb_status_voicecall_id(char *pwdconf, char * callid,int session){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    char status[64];
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   if(session<0 || session>9){
       strcpy(error,"1905a - session is wrong");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"voicecallstatus\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\",\"callid\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign,callid);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   //UPDATE VOICECALL STATUS
   bb_json_getvalue("status",reply,status,63);
   if(strcmp(status,"hangup")==0){
       SvtpReadAC[session].statusvoicecall=3;
       SvtpWriteAC[session].statusvoicecall=3;
   }
   if(strcmp(status,"answered")==0 || strcmp(status,"answeredA")==0 || strcmp(status,"active")==0){
       SvtpReadAC[session].statusvoicecall=2;
       SvtpWriteAC[session].statusvoicecall=2;
   }
   if(strcmp(status,"ringing")==0){
       SvtpReadAC[session].statusvoicecall=1;
       SvtpWriteAC[session].statusvoicecall=1;
   }
   if(strcmp(status,"setup")==0){
       SvtpReadAC[session].statusvoicecall=1;
       SvtpWriteAC[session].statusvoicecall=1;
   }
   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO GET STATUS OF A VIDEO CALL
*/
char * bb_status_videocall(char *pwdconf, char * callid){
    char mobilenumber[256];
    FILE *fp;
    int x,conflen,buflen,z;
    char conf[8192];
    char hash[512];
    char hashb64[1024];
    char totpseed[256];
    char authpkb64[8192];
    char authpk[8192];
    char encpkb64[8192];
    char encpk[8192];
    char *buf=NULL;
    char *msg=NULL;
    char *tmsg=NULL;
    char *tmsgenc=NULL;
    char *tmsgencb64=NULL;
    char sign[8192];
    char *reply=NULL;
    char *replydecrypted=NULL;
    char token[256];
    char error[128];
    char msgtype[256];
    int lensign=0,lenreply=0,lentmsg=0,lentmsgenc=0,lenalltmsg=0;
    uint32_t totp=0;
    int hashlen;
    int msglen;
    error[0]=0;
    struct stat sb;
    char answer[64];
    char *sp;
    int j;
    char *newreplydecrypted=NULL;
    char *newtmsg=NULL;
    char jsonadd[1024];
    char *replyconf;
    char * replybuf=NULL;
    int zj,i;
    char status[256];
    //DECRYPT CONFIGURATION
    replyconf=bb_load_configuration(pwdconf,conf);
    bb_json_getvalue("answer",replyconf,answer,63);
    free(replyconf);
    if(strcmp(answer,"OK")!=0){
        bb_json_getvalue("message",answer,error,128);
        goto CLEANUP;
    }
   // BUILD THE MESSAGE in JSON
   if(strlen(bbtoken)==0){
       strcpy(error,"1905 - session token is not present, you must register first");
       goto CLEANUP;
   }
   totpseed[0]=0;
   bb_json_getvalue("totpseed",conf,totpseed,256);
   if(strlen(totpseed)==0){
       strcpy(error, "1906 - totpseed not found in the configuration");
       goto CLEANUP;
   }
   mobilenumber[0]=0;
   bb_json_getvalue("mobilenumber",conf,mobilenumber,63);
   totp=0;
   totp=bbtotp(totpseed);
   if(totp==0){
       strcpy(error,"1907 - blackbox-client.c: totp error");
       goto CLEANUP;
   }
   authpkb64[0]=0;
   bb_json_getvalue("authenticationprivatekey",conf,authpkb64,8191);
   if(strlen(authpkb64)==0){
       strcpy(error,"1908 - blackbox-client.c: authentication private key not found in the configuration");
       goto CLEANUP;
   }
   x=bb_decode_base64(authpkb64,authpk);
   if(x==0){
        strcpy(error,"1909 - error decoding authentication private key");
        goto CLEANUP;
   }
   if(verbose) printf("blackbox-client.c: Private key: %s\n",authpk);
   // HASH CALCULATION
   buflen=strlen(mobilenumber)+strlen(bbtoken)+8192;
   if(verbose) printf("buflen %d\n",buflen);
   buf=malloc(buflen);
   sprintf(buf,"sendmsg%s%u%s",mobilenumber,totp,bbtoken);
   x=strlen(buf);
   hashlen=bb_sha2_512(buf,x,hash);
   bb_encode_base64(hash,hashlen,hashb64);
   if(verbose) printf("blackbox-client.c: hash %s\n",hashb64);
   // SIGN USING EC KEY
   bb_sign_ec(hashb64,strlen(hashb64),sign,&lensign,authpk);
   x=strlen(mobilenumber)+strlen(hashb64)+strlen(sign)+strlen(bbtoken);
   msglen=x+8192;
   msg=malloc(msglen);
   // SEND MESSAGE TO SERVER
   sprintf(msg,"{\"action\":\"videocallstatus\",\"mobilenumber\":\"%s\",\"token\":\"%s\",\"totp\":\"%u\",\"hash\":\"%s\",\"signature\":\"%s\",\"callid\":\"%s\"}",mobilenumber,bbtoken,totp,hashb64,sign,callid);
   if(verbose) printf("MSG TO SERVER: %s\n",msg);
   lenreply=0;
   reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
   if(reply==NULL){
            strcpy(error,"1910 - error sending TLS message");
            goto CLEANUP;
   }
   lenreply=strlen(reply);
   if(verbose) printf("reply: %s\n",reply);
   bb_json_getvalue("answer",reply,buf,63);
   if(strcmp(buf,"KO")==0){
        bb_json_getvalue("message",reply,error,127);
        goto CLEANUP;
   }
   //UPDATE NEW TOKEN IN RAM
   token[0]=0;
   bb_json_getvalue("token",reply,token,255);
   if(strlen(token)>0) strncpy(bbtoken,token,255);
   memset(status,0x0,256);
   bb_json_getvalue("status",reply,status,255);
   if(strcmp(status,"hangup")==0){
       StatusVoiceCall=3;
       StatusVideoCall=3;
   }
   if(strcmp(status,"answered")==0 || strcmp(status,"answeredA")==0 || strcmp(status,"active")==0){
       StatusVoiceCall=2;
       StatusVideoCall=2;
   }
   if(strcmp(status,"ringing")==0){
       StatusVoiceCall=1;
       StatusVideoCall=1;
       
   }
   if(strcmp(status,"setup")==0){
       StatusVoiceCall=1;
       StatusVideoCall=1;
   }
   // CLEAN RAM VARIABLES
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL) memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg-1);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(error,0x0,128);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   return(reply);
    
   CLEANUP:
   if(msg!=NULL) memset(msg,0x0,msglen);
   if(msg!=NULL) free(msg);
   if(buf!=NULL)memset (buf,0x0,buflen);
   if(buf!=NULL) free(buf);
   if(tmsgencb64!=NULL) memset(tmsgencb64,0x0,lenalltmsg-1);
   if(tmsgencb64!=NULL) free(tmsgencb64);
   if(tmsgenc!=NULL) memset(tmsgenc,0x0,lenalltmsg);
   if(tmsgenc!=NULL) free(tmsgenc);
   if(tmsg!=NULL) memset(tmsg,0x0,lentmsg);
   if(tmsg!=NULL) free(tmsg);
   memset(conf,0x0,8192);
   memset(hash,0x0,512);
   memset(hashb64,0x0,1024);
   memset(totpseed,0x0,256);
   memset(authpk,0x0,8192);
   memset(authpkb64,0x0,8192);
   memset(sign,0x0,8192);
   memset(token,0x0,256);
   memset(mobilenumber,0x0,256);
   memset(encpkb64,0x0,8192);
   memset(encpk,0x0,8192);
   memset(answer,0x0,64);
   if(newreplydecrypted!=NULL) memset(newreplydecrypted,0x0,strlen(newreplydecrypted));
   if(newreplydecrypted!=NULL) free(newreplydecrypted);
   if(newtmsg!=NULL) memset(newtmsg,0x0,strlen(newtmsg));
   if(newtmsg!=NULL) free(newtmsg);
   memset(jsonadd,0x0,1024);
   j=0;
   sp=NULL;
   totp=0;
   conflen=0;
   hashlen=0;
   lensign=0;
   lenreply=0;
   buflen=0;
   lentmsg=0;
   lentmsgenc=0;
   lenalltmsg=0;
   x=0;
   sprintf(reply,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
   memset(error,0x0,128);
   return(reply);
}
/**
* FUNCTION TO SEND AN AUDIO DATA PACKET IN PCM FORMAT 16 BIT MONO CHANNEL LITTLE ENDIAN - FRAME OF 20 MS A 48KHZ SAMPLE\n
* AUDIOPACKET MUST BE 1920 BYTES (20 ms audio at 48khz 16 bit)\n
* RETURN 0 IN CASE OF ERROR OR 1 FOR OK
*/
int bb_audio_send(unsigned char *audiopacket){

    if(!bb_svtp_send_data(&SvtpWrite,audiopacket,1920)){
            fprintf(stderr,"%s\n",SvtpWrite.error);
            return(0);
    }
    return(1);
}
/**
* FUNCTION TO SEND AN AUDIO DATA PACKET IN PCM FORMAT 16 BIT MONO CHANNEL LITTLE ENDIAN - FRAME OF 30 MS A 48KHZ SAMPLE\n
* AUDIOPACKET MUST BE 1920 BYTES (20 ms audio at 48khz 16 bit)\n
* RETURN 0 IN CASE OF ERROR OR 1 FOR OK
*/
int bb_audio_send_session(int session,unsigned char *audiopacket){
    int i,x,lst,j;
    short int merged,tomerge;
    unsigned char mergedaudio[1922];
    unsigned char ringbuf[1922];
    if(session<0 || session>9){
         fprintf(stderr,"Session is wrong (0-9 are the possible values");
         return(0);
    }
    // SEND AUDIO WHEN NO AUDIOCONFERENCE IS ACTIVE
    if(SvtpWriteAC[session].audioconference==0){
        if(!bb_svtp_send_data(&SvtpWriteAC[session],audiopacket,1920)){
            fprintf(stderr,"%s\n",SvtpWriteAC[session].error);
            return(0);
        }
    }
    //SEND MERGED AUDIO WHEN AUDIOCONFERENCE IS ACTIVE
    if(SvtpReadAC[session].audioconference==1){
        //printf("Merging for session: %d\n",session);
        for(j=0;j<=9;j++){
           if(SvtpReadAC[j].audioconference==0 || SvtpReadAC[j].statusvoicecall!=2) continue;
           memset(mergedaudio,0x0,1920);
           memcpy(ringbuf,audiopacket,1920);
           for(i=0;i<=9;i++){
               if(i==j) continue;
               if(SvtpReadAC[i].audioconference==0 || SvtpReadAC[i].statusvoicecall!=2) continue;
               lst=SvtpReadAC[i].ringbuflst;
               if(SvtpWriteAC[j].ringbuflstmerge[i]==lst)
                   continue;
               if(SvtpWriteAC[j].ringbuflstmerge[i]<(lst-1920) && (lst-1920)>0){
                   //printf("Write Lst was: %d changed to: %d\n",lst,SvtpWriteAC[session].ringbuflstmerge[i]+1920);
                   lst=SvtpWriteAC[j].ringbuflstmerge[i]+1920;
               }
               SvtpWriteAC[j].ringbuflstmerge[i]=lst;
               for(x=0;x<1920;x=x+2){
                   memcpy(&merged,&ringbuf[x],2);
                   memcpy(&tomerge,&SvtpReadAC[i].ringbuf[lst+x],2);
                   if((merged+tomerge)>32768){
                       merged=32767;
                       break;
                   }
                   if((merged+tomerge)<-32768){
                       merged=-32767;
                       break;
                   }
                   if(merged!=32767 && merged!=(-32767)){
                       merged=merged+tomerge;
                   }
                   memcpy(&mergedaudio[x],&merged,2);
               }
               memcpy(ringbuf,mergedaudio,1920);
           }
           // SEND MERGED AUDIO
           if(!bb_svtp_send_data(&SvtpWriteAC[j],ringbuf,1920)){
               fprintf(stderr,"%s\n",SvtpWriteAC[j].error);
               return(0);
           }
        }
    }
    return(1);
}


/**
* FUNCTION TO SET AUDIO CONFERENCE FOR A SESSION
*/
void bb_audio_set_audioconference(int session){
     if(session<0 || session>9){
         fprintf(stderr,"Session is wrong (0-9 are the possible values");
         return;
    }
    SvtpWriteAC[session].audioconference=1;
    SvtpReadAC[session].audioconference=1;
    return;
}
/**
* FUNCTION TO UNSET AUDIO CONFERENCE FOR A SESSION
*/
void bb_audio_unset_audioconference(int session){
     if(session<0 || session>9){
         fprintf(stderr,"Session is wrong (0-9 are the possible values");
         return;
    }
    SvtpWriteAC[session].audioconference=0;
    SvtpReadAC[session].audioconference=0;
    return;
}
/**
* FUNCTION TO GET AUDIO CONFERENCE FOR A SESSION
*/
int bb_audio_get_audioconference(int session){
     if(session<0 || session>9){
         fprintf(stderr,"Session is wrong (0-9 are the possible values");
         return(-1);
    }
    return(SvtpWriteAC[session].audioconference);
}

/**
* FUNCTION TO RECEIVE AN AUDIO DATA PACKET IN PCM FORMAT 16 BIT MONO CHANNEL LITTLE ENDIAN - FRAME OF 20 MS A 48KHZ SAMPLE\n
* AUDIOPACKET MUST BE ALLOCATED FOR 1920 BYTES (20 ms audio at 48khz 16 bit)\n
* RETURN -1 FOR TIMEOUT OF 45 SECONDS, -2 FOR HANGUP, or length OF AUDIOPACKET RECEIVED
*/
int bb_audio_receive(unsigned char *audiopacket){
      int x;
      time_t st,tt;
      st=time(NULL);
      memset(audiopacket,0x0,1920);
      while(1){
           tt=time(NULL);
           if(tt-st>=45) return(-1);
           x=bb_svtp_read_data(&SvtpRead,audiopacket,1920);
           if(x<=0){
               //fprintf(stderr,"Error: %s\n",SvtpRead.error);
               if(tt-st>=45) return(-1);
               if(StatusVoiceCall==3){
                   StatusVoiceCall=0;
                   return(-2);
               }
               continue;
           }
           if(x>0) return(x);
           st=time(NULL);
      }
}
/**
* FUNCTION TO RECEIVE AN AUDIO DATA PACKET IN PCM FORMAT 16 BIT MONO CHANNEL LITTLE ENDIAN - FRAME OF 20 MS A 48KHZ SAMPLE\n
* AUDIOPACKET MUST BE ALLOCATED FOR 320 BYTES (20 ms audio at 48khz 16 bit)\n
* RETURN -1 FOR TIMEOUT OF 45 SECONDS, -2 FOR HANGUP, or length OF AUDIOPACKET RECEIVED\n
*/
int bb_audio_receive_session(int session,unsigned char *audiopacket){
      int x,ptr,rc,i,lst,flagnewaudio,flagmerged;
      time_t st,tt;
      short int merged,tomerge;
      unsigned char mergedaudio[2048];
      unsigned char ringbuf[2048];
      st=time(NULL);
      memset(audiopacket,0x0,1920);
      usleep(20000);
      flagnewaudio=0;
      if(session<0 || session>9) return(-3);
      // RUN THREAD FOR READING
      if(SvtpReadAC[session].asyncrunning==0 && strlen(SvtpReadAC[session].error)==0){
           int *arg = malloc(sizeof(*arg));
           *arg = session;
           rc=pthread_create(&SvtpReadAC[session].thread,NULL,bb_audio_receive_session_async,arg);
           if(rc)
                  fprintf(stderr,"ERROR; return code from pthread_create() is %d\n", rc);
           else
               SvtpReadAC[session].asyncrunning=1;
          //return(0);

      }
      while(1){
           tt=time(NULL);
           if(tt-st>=45) return(-1);
           //TIME OUT FROM ASYNC THREAD
           if(SvtpReadAC[session].asyncrunning==0 && strcmp(SvtpReadAC[session].error,"Timeout reached")==0){
               return(-1);
           }
           //HANGUP
           if(SvtpReadAC[session].asyncrunning==0 && strlen(SvtpReadAC[session].error)==0){
                return(-2);
           }
           for(i=0;i<=9;i++){
                  if(SvtpReadAC[i].audioconference==0)
                     continue;
                  if(SvtpReadAC[i].ringbufptr>=1920)
                     lst=SvtpReadAC[i].ringbufptr-1920;
                  if(SvtpReadAC[i].ringbufptr==0 && SvtpReadAC[i].ringbuflst!=-1)
                      lst=96000;
                  if(SvtpReadAC[i].ringbufptr==0 && SvtpReadAC[i].ringbuflst==-1)
                      continue;
                  if(SvtpReadAC[i].ringbuflst<(lst-1920) && (lst-1920)>0) //correction to last packet to read
                      lst=SvtpReadAC[i].ringbuflst+1920;
                  if(SvtpReadAC[i].ringbuflst==lst)
                      continue;
                  SvtpReadAC[i].ringbuflst=lst;
                  flagnewaudio=1;
                  //printf("session: %d lst: %d\n",i,lst);
                  memset(mergedaudio,0x0,1920);
                  memcpy(ringbuf,&SvtpReadAC[i].ringbuf[lst],1920);
                  for(x=0;x<1920;x=x+2){
                       memcpy(&merged,&audiopacket[x],2);
                       memcpy(&tomerge,&ringbuf[x],2);
                       if((merged+tomerge)>32768){
                         merged=32767;
                       }
                       if((merged+tomerge)<-32768){
                         merged=-32767;
                       }
                       if(merged!=32767 && merged!=-32767) merged=merged+tomerge;
                       memcpy(&mergedaudio[x],&merged,2);
                  }
                  // SEND MERGED AUDIO
                  memcpy(audiopacket,mergedaudio,1920);

           }
           if(flagnewaudio==0){
               //printf("**** Sleep 5 ms\n");
               usleep(50);
              continue;
           }
          //printf("Returning from audio session %d/%d lst: %d/%d\n",0,1,SvtpReadAC[0].ringbuflst,SvtpReadAC[1].ringbuflst);
          return(1920);
      }
}

/**
* ASYNCRONOUS FUNCTION TO RECEIVE AUDIO FROM SVTP PROTOCOL AND STORE IN A "RING" BUFFER FOR SYNC FETCHING
*/
void * bb_audio_receive_session_async(void *param){
      int x;
      time_t st,tt,session;
      unsigned char audiopacket[2048];
      st=time(NULL);
      session=*((int *) param);
      free(param);
      if(session<0 || session>9){
         strcpy(SvtpReadAC[session].error,"Session is wrong (0-9 are the possible values");
         pthread_exit((void *) -3);
      }
      //printf("Thread running on session: %d\n",session);
      SvtpReadAC[session].asyncrunning=1;
      while(1){
           tt=time(NULL);
           if(tt-st>=45){
                strcpy(SvtpReadAC[session].error,"Timeout reached");
                SvtpReadAC[session].asyncrunning=0;
                pthread_exit((void *) -1);
           }
           memset(audiopacket,0x0,1920);
           x=bb_svtp_read_data(&SvtpReadAC[session],audiopacket,1920);
          //printf("bb_svtp_read_data x: %d\n",x);
           if(x<=0){
               fprintf(stderr,"Error: %s %d\n",SvtpReadAC[session].error,x);
               if(tt-st>=45){
                  strcpy(SvtpReadAC[session].error,"Timeout reached");
                  SvtpReadAC[session].asyncrunning=0;
                  pthread_exit((void *) -1);
               }
               if(SvtpReadAC[session].statusvoicecall==3){
                  SvtpReadAC[session].error[0]=0;
                  SvtpReadAC[session].asyncrunning=0;
                  pthread_exit((void *) -2);
               }
               continue;
           }
           // WRITE IN RING BUFFER
           memcpy(&SvtpReadAC[session].ringbuf[SvtpReadAC[session].ringbufptr],audiopacket,1920);
           if(SvtpReadAC[session].ringbufptr==96000)
               SvtpReadAC[session].ringbufptr=0;
           else
               SvtpReadAC[session].ringbufptr=SvtpReadAC[session].ringbufptr+1920;
               //printf("THREAD Ringbufptr: %d\n",SvtpReadAC[session].ringbufptr);
           st=time(NULL);
      }
}

/**
* FUNCTION TO SEND A PACKET IN CHUNKS OF 494 BYTES  of VIDEO STREAM\n
* RETURN 0 IN CASE OF ERROR OR 1 FOR OK
*/
int bb_video_send(unsigned char *videopacket,unsigned short int packetlen){
    unsigned char buf[512];
    int x,i,sl;
    unsigned short int rsd;
    
    if(packetlen<=0)
       return(0);
    if(packetlen<=492 && packetlen>0){
       memset(buf,0x0,512);
       memcpy(buf,&packetlen,2);
       memcpy(&buf[2],videopacket,packetlen);
       if(!bb_swtp_send_data(&SwtpWrite,buf)){
           fprintf(stderr,"%s\n",SwtpWrite.error);
           return(0);
       }
       return(1);
    }
    if(packetlen>492){
       x=packetlen/492;
       if(packetlen%492>0)
         x++;
       for(i=0;i<x;i++){
          memset(buf,0x0,512);
          rsd=packetlen-(492*(i));
          memcpy(buf,&rsd,2);
          if(packetlen-(i*492)>=492)
               sl=492;
           else
               sl=packetlen-(i*492);
          memcpy(&buf[2],&videopacket[i*492],sl);
          if(!bb_swtp_send_data(&SwtpWrite,buf)){
              fprintf(stderr,"%s\n",SwtpWrite.error);
              return(0);
          }
          //usleep(1000);
       }
       return(1);
    }
    return(0);
}
/**
* FUNCTION TO RECEIVE A VIDEO  PACKET  of any length (VIDEOPACKET must be freed with free(videopacket);\n
* RETURN -1 FOR TIMEOUT OF 45 SECONDS, -2 FOR HANGUP, or length OF VIDEOPACKET RECEIVED
*/
char * bb_video_receive(int *dplen){
      int x;
      time_t st,tt,ptr,am;
      unsigned short int rsd,nextrsd;
      char buf[512];
      unsigned char *videopacket=NULL;
      ptr=0;
      am=0;
      st=time(NULL);
      nextrsd=0;
      while(1){
           tt=time(NULL);
           if(tt-st>=45){
              *dplen=-1;
              if(am>0) free(videopacket);
              //printf("Exit from video receiving for timeout\n");
              return(NULL);
           }
           if(StatusVideoCall==3){
                   StatusVideoCall=0;
                   *dplen=-2;
                   if(am>0) free(videopacket);
                   return(NULL);
           }
           memset(buf,0x0,512);
           x=bb_swtp_read_data(&SwtpRead,buf);
           if(x==-3){
             //printf("Packet buffered\n");
             continue;
           }
           if(x==-4){
             //printf("Old Video Packet, dropped\n");
             continue;
           }
           if(x<0){  //OTHER KIND OF ERRORS
               //if(strstr(SwtpRead.error,"Resource temporarily unavailable")==NULL)
               if(strlen(SwtpRead.error)>0) fprintf(stderr,"Error: %s\n",SwtpRead.error);
               if(tt-st>=45){
                   if(am>0) free(videopacket);
                   printf("Exit from video receiving for timeout\n");
                   *dplen=-1;
                   return(NULL);
               }
               continue;
           }
           if(x==0){   //0 DATA ARRIVED
               if(tt-st>=45){
                  if(am>0) free(videopacket);
                  printf("Exit from video receiving for timeout\n");
                  *dplen=-1;
                  return(NULL);
               }
               else{
                   //printf("No data packet arrived\n");
                  continue;
               }
           }
           if(x>0){  //DATA ARRIVED
                SwtpRead.cnt++;
                memcpy(&rsd,buf,2); //GET BYTES OF THE PACKET
                //printf("data rsd: %d ptr: %d\n",rsd,ptr);
                //SIMULATION PACKET LOST
/*                if(SwtpRead.cnt==500){
                        printf("packet lost for simulation, dropping whole videopacket\n");
                        printf("data rsd: %d nextrsd: %d ptr: %d\n",rsd,nextrsd,ptr);
                        ptr=0;
                        rsd=0;
                        nextrsd=0;
                        if(am>0) free(videopacket);
                        am=0;
                        continue;
                }*/
                //END SIMULATION PACKET LOST
                if(am==0){
                    videopacket=malloc(rsd+2048);
                    am=1;
                    if(rsd<=492) nextrsd=0;
                    if(rsd>492) nextrsd=rsd-492;
                }else{
                    if (nextrsd!=0 && nextrsd!=rsd){  // PACKET LOST
                        printf("packet lost, dropping whole videopacket\n");
                        printf("data rsd: %d nextrsd: %d ptr: %d\n",rsd,nextrsd,ptr);
                        ptr=0;
                        rsd=0;
                        nextrsd=0;
                        free(videopacket);
                        am=0;
                        // 1) RETURN NULL PACKET
                        //*dplen=0;
                        //return(NULL);
                        // 2) RETURN PARTIAL PACKET
                        //*dplen=(ptr);
                        //return(videopacket);
                        // 3) CONTINUE TO NEXT PACKET
                        continue;
                    }
                }
                if(rsd<=492 && ptr==0){
                   memcpy(videopacket,&buf[2],rsd);
                   *dplen=rsd;
                   return(videopacket);
                }
                if(rsd>492){
                 memcpy(&videopacket[ptr],&buf[2],492);
                 ptr=ptr+492;
                 nextrsd=rsd-492;
                }
                if(rsd<=492 && ptr>0){
                   memcpy(&videopacket[ptr],&buf[2],rsd);
                   *dplen=(ptr+rsd);
                   return(videopacket);
                }
           }
           st=time(NULL);
      }
}


/**
* FUNCTION TO COPY A FILE TO THE LOCAL CACHE
*/
char * bb_copy_file_to_cache(char *originfilename){
    FILE *fp,*fd;
    char destinationfilename[512];
    char buffer[128];
    char hash[128];
    char suffix[32];
    char *buf;
    char *filename;
    struct stat sb;
    int s,r,i,x;
    if(strlen(originfilename)>511){
        fprintf(stderr,"20000 - origin file name is too long (bb_copy_file_to_cache)");
        return(NULL);
    }
    //SET FILE NAMES
    x=strlen(originfilename);
    memset(suffix,0x0,32);
    memset(destinationfilename,0x0,512);
    if(originfilename[x-5]=='.') strncpy(suffix,&originfilename[x-5],5);
    if(originfilename[x-4]=='.') strncpy(suffix,&originfilename[x-4],4);
    if(strcmp(suffix,".mov")==0) strcpy(suffix,".mp4");
    memset(hash,0x0,128);
    bb_sha3_256(originfilename, strlen(originfilename),hash);
    bb_bin2hex(hash,32,buffer);
    sprintf(destinationfilename,"%s/Documents/test",getenv("HOME"));
    if (stat(destinationfilename, &sb) != 0) mkdir(destinationfilename, S_IRWXU | S_IRWXG);
    sprintf(destinationfilename,"%s/Documents/test/%s",getenv("HOME"),buffer);
    if(strlen(suffix)==4)
        strncat(destinationfilename,suffix,4);
    if(strlen(suffix)==5)
        strncat(destinationfilename,suffix,5);
    memset(suffix,0x0,32);
    
    // RESIZE jpg or jpeg files
    i=strlen(originfilename);
    if((originfilename[i-1]=='g' && originfilename[i-2]=='p' && originfilename[i-3]=='j' && originfilename[i-4]=='.') ||
       (originfilename[i-1]=='g' && originfilename[i-2]=='e' && originfilename[i-3]=='p' && originfilename[i-4]=='j'  && originfilename[i-5]=='.')){
       bb_jpeg_resize(originfilename,destinationfilename);
       filename=malloc(512);
       strcpy(filename,destinationfilename);
       return(filename);
    }
       
    /*
    //** RESIZE .MOV AND CONVERT TO MP4
    i=strlen(originfilename);
    if((originfilename[i-1]=='v' && originfilename[i-2]=='o' && originfilename[i-3]=='m' && originfilename[i-4]=='.')){
       char ffmpegcmd[2048];
       sprintf(ffmpegcmd,"ffmpeg -hide_banner -loglevel panic -nostdin -y -i %s -vf scale=480:-2 -fs 100000000 %s",originfilename,destinationfilename);
       bb_ffmpeg(ffmpegcmd);
       memset(ffmpegcmd,0x0,2048);
       filename=malloc(512);
       strcpy(filename,destinationfilename);
       return(filename);
    }
    /*/
    //** COPY FILE IF NOT JPG/JPEG
    fp=fopen(originfilename,"rb");
    if(fp==NULL){
        fprintf(stderr,"20001 - error openin origin file name (bb_copy_file_to_cache)");
        return(NULL);
    }
    fd=fopen(destinationfilename,"wb");
    if(fd==NULL){
        fclose(fp);
        fprintf(stderr,"20002 - error opening destination file (bb_copy_file_to_cache)");
        return(NULL);
    }
    buf=malloc(1280001);
    if(buf==NULL){
        fclose(fp);
        fclose(fd);
        fprintf(stderr,"20003 - error allocating buffer (bb_copy_file_to_cache)");
        return(NULL);
    }
    while(!feof(fp)){
        s=fread(buf,1,1280000,fp);
        if(s<=0)
            break;
        r=fwrite(buf,1,s,fd);
        if(r!=s){
            fclose(fp);
            fclose(fd);
            fprintf(stderr,"20004 - error writing to destination file (bb_copy_file_to_cache)");
            memset(buf,0x0,1280000);
            free(buf);
            return(NULL);
        }
    }
    memset(buf,0x0,1280000);
    free(buf);
    fclose(fd);
    fclose(fp);
    filename=malloc(512);
    strcpy(filename,destinationfilename);
    return(filename);
}
/**
* FUNCTION TO COPY A FILE
*/
int  bb_copy_file(char *originfilename,char *destinationfilename){
    FILE *fp,*fd;
    char buffer[128];
    char *buf;
    struct stat sb;
    int s,r,i,x;
    if(strlen(originfilename)>511){
        fprintf(stderr,"20100 - origin file name is too long (bb_copy_file.c)");
        return(-1);
    }
    //** COPY FILES
    fp=fopen(originfilename,"rb");
    if(fp==NULL){
        fprintf(stderr,"20101 - error openin origin file name (bb_copy_file.c)");
        return(-1);
    }
    fd=fopen(destinationfilename,"wb");
    if(fd==NULL){
        fclose(fp);
        fprintf(stderr,"20102 - error opening destination file (bb_copy_file.c)");
        return(-1);
    }
    buf=malloc(1280001);
    if(buf==NULL){
        fclose(fp);
        fclose(fd);
        fprintf(stderr,"20103 - error allocating buffer (bb_copy_file.c)");
        return(-1);
    }
    while(!feof(fp)){
        s=fread(buf,1,1280000,fp);
        if(s<=0)
            break;
        r=fwrite(buf,1,s,fd);
        if(r!=s){
            fclose(fp);
            fclose(fd);
            fprintf(stderr,"20104 - error writing to destination file (bb_copy_file.c)");
            memset(buf,0x0,1280000);
            free(buf);
            return(-1);
        }
    }
    memset(buf,0x0,1280000);
    free(buf);
    fclose(fd);
    fclose(fp);
    return(1);
}
/**
* FUNCTION TO GET THE CACHE FILE NAME OF AN UPLOADING/UPLOADED FILE\n
* RESULT MUST FREE() IF NOT NULL
*/
char * bb_cache_file_name(char * originfilename){
    char h[128];
    char hash[256];
    char *d;
    int x,i;
    char suffix[32];
    if(strlen(originfilename)>256)
      return(NULL);
    d=malloc(512);
    memset(d,0x0,512);
    memset(h,0x0,128);
    memset(hash,0x0,256);
    memset(suffix,0x0,32);
    bb_sha3_256(originfilename, strlen(originfilename),h);
    bb_bin2hex(h,32,hash);
    x=strlen(originfilename);
    if(originfilename[x-5]=='.') strncpy(suffix,&originfilename[x-5],5);
    if(originfilename[x-4]=='.') strncpy(suffix,&originfilename[x-4],4);
    sprintf(d,"%s/Documents/test/%s%s",getenv("HOME"),hash,suffix);
    memset(suffix,0x0,32);
    memset(h,0x0,128);
    memset(hash,0x0,256);
    return(d);
}
/**
* FUNCTION TO GET % OF TRANSFER
*/
int bb_filetransfer_getstatus(char * filename){
 int i;
 long r;
 long bs=0;
 long bt=0;
 if(FileTransferSet==0) bb_filetransfer_init();
 i=strlen(filename);
 if(filename[i-1]=='c' && filename[i-2]=='n' && filename[i-3]=='e' && filename[i-4]=='.')
    filename[i-4]=0;
 for(i=0;i<99;i++){
    if(strcmp(filename,FileTransfer[i].filename)==0){
          bs=FileTransfer[i].bytesfilesize;
          bt=FileTransfer[i].bytestransfer;
    }
 }
 if(bt==-100) return(-100);
 if(bs>0){
   if(bt==0)
     return(0);
   if(bt>=bs)
    return(100);
   r=100*bt/bs;
   return(r);
 }
char *buf=bb_cache_file_name(filename);
i=strlen(buf);
if(buf[i-1]=='c' && buf[i-2]=='n' && buf[i-3]=='e' && buf[i-4]=='.')
    buf[i-4]=0;
for(i=0;i<99;i++){
    if(strcmp(buf,FileTransfer[i].filename)==0){
          bs=FileTransfer[i].bytesfilesize;
          bt=FileTransfer[i].bytestransfer;
    }
}
if(bt==-100) return(-100);
free(buf);
 if(bs>0){
   if(bt==0)
     return(0);
   if(bt>=bs)
    return(100);
   r=100*bt/bs;
   return(r);
 }
 return(-1);
}
/**
* FUNCTION TO UPDATE THE BYTE TRANSFER
*/
void bb_filetransfer_addbytes(char * filename,int bytes,int filesize){
  int i,freeslot,older;
  time_t t;
  time_t t_older;
  struct stat fs;
  t=time(NULL);
  char buf[512];
  if(strlen(filename)>511)
    return;
  memset(buf,0x0,512);
  strncpy(buf,filename,511);
  freeslot=-1;
  older=-1;
  t_older=2147483647;
  // INIT
  if(FileTransferSet==0) bb_filetransfer_init();
  // CUT .enc if present
  i=strlen(buf);
  if(buf[i-1]=='c' && buf[i-2]=='n' && buf[i-3]=='e' && buf[i-4]=='.')
     buf[i-4]=0;
  // CLEAN SLOT COMPLETE FROM >180 SECONDS
  for(i=0;i<99;i++){
     if(t-FileTransfer[i].tm>180){
        FileTransfer[i].tm=0;
        memset(FileTransfer[i].filename,0x0,512);
        FileTransfer[i].bytesfilesize=0;
        FileTransfer[i].bytestransfer=0;
     }
  }
  for(i=0;i<99;i++){
      if(FileTransfer[i].tm==0 && freeslot==-1)
         freeslot=i;
      if(strcmp(buf,FileTransfer[i].filename)==0 && FileTransfer[i].bytesfilesize>FileTransfer[i].bytestransfer){
         FileTransfer[i].bytestransfer=FileTransfer[i].bytestransfer+bytes;
         FileTransfer[i].tm=t;
         return;
      }
      if(FileTransfer[i].tm<t_older && FileTransfer[i].tm!=0 && FileTransfer[i].bytesfilesize<=FileTransfer[i].bytestransfer){
       older=i;
       t_older=FileTransfer[i].tm;
      }
  }
  if(freeslot!=-1){
     strncpy(FileTransfer[freeslot].filename,buf,511);
     FileTransfer[freeslot].bytesfilesize=filesize;
     FileTransfer[freeslot].bytestransfer=bytes;
     FileTransfer[freeslot].tm=t;
     return;
  }
  if(older!=-1){
      strncpy(FileTransfer[older].filename,buf,511);
      FileTransfer[older].bytesfilesize=filesize;
      FileTransfer[older].bytestransfer=bytes;
      FileTransfer[older].tm=t;
      return;
  }
  fprintf(stderr,"2010 - something is wrong (bb_filetransfer_addbytes)");
  return;
}
/**
* FUNCTION TO UPDATE THE BYTE TRANSFER
*/
void bb_filetransfer_broken(char * filename){
  int i,freeslot,older;
  time_t t;
  time_t t_older;
  struct stat fs;
  char buf[512];
  t=time(NULL);
  if(strlen(filename)>511)
    return;
  memset(buf,0x0,512);
  strncpy(buf,filename,511);
  // CUT .enc if present
  i=strlen(buf);
  if(buf[i-1]=='c' && buf[i-2]=='n' && buf[i-3]=='e' && buf[i-4]=='.')
     buf[i-4]=0;
  for(i=0;i<99;i++){
      if(strcmp(buf,FileTransfer[i].filename)==0){
         FileTransfer[i].bytestransfer=-100;
         FileTransfer[i].tm=t;
         return;
      }
  }
  return;
}
/**
* FUNCTION TO UPDATE THE BYTE TRANSFER
*/
int bb_filetransfer_pending(char * filename){
  int i,freeslot,older;
  struct stat fs;
  time_t t;
  char buf[512];
  char fn[512];
  t=time(NULL);
  if(strlen(filename)>511)
    return(-1);
  memset(buf,0x0,512);
  strncpy(buf,filename,511);
  i=strlen(buf);
  if(buf[i-1]=='c' && buf[i-2]=='n' && buf[i-3]=='e' && buf[i-4]=='.')
     buf[i-4]=0;
  for(i=0;i<99;i++){
      strncpy(fn,FileTransfer[i].filename,511);
      bb_strip_path(fn);
    //if(strstr(FileTransfer[i].filename,buf)!=NULL && FileTransfer[i].bytesfilesize>FileTransfer[i].bytestransfer){
      if(strcmp(fn,buf)==0 && FileTransfer[i].bytesfilesize>FileTransfer[i].bytestransfer){
         return(1);
      }
  }
  return(0);
}

/**
* INIT FUNCTION OF BLACKBOX CLIENT
*/
void bb_filetransfer_init(void){
 int i;
 for(i=0;i<99;i++){
    FileTransfer[i].tm=0;
    memset(FileTransfer[i].filename,0x0,256);
    FileTransfer[i].bytesfilesize=0;
    FileTransfer[i].bytestransfer=0;
    
 }
 FileTransferSet=1;
 return;
}
/**
* FUNCTION TO DUMP THE STRUCTURE IN RAM USED FOR FILE TRANSFER
*/
void bb_filetransfer_dump(void){
 int i;
 for(i=0;i<99;i++){
  if(strlen(FileTransfer[i].filename)>0)
   printf("[%d] Filename: %s size:%ld transferred %ld time:%ld\n",i,FileTransfer[i].filename,FileTransfer[i].bytesfilesize,FileTransfer[i].bytestransfer,FileTransfer[i].tm);
   
 }
 return;
}
/**
* FUNCTION TO SET "FORWARDED" FLAG FOR A MSGID
* RETURNED STRING MUST BE FREE
*/
char * bb_set_forwardedmsg(char *msgid,char *pwdconf){
 char error[256];
 char *replyerror=NULL;
 char *reply=NULL;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(msgid)==0){
       sprintf(error,"%s","5800 - msgid is missing");
       goto CLEANUP;
 }
 if(atol(msgid)<=0){
       sprintf(error,"%s","5801 - msgid is wrong");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","5802 - configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"setforwardedmsg",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"msgid\":\"%s\"}",action,msgid);
 
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","5803 - No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 if(reply!=NULL){
   memset(reply,0x0,strlen(reply));
   free(reply);
 }
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO UNSET "STARRED" FLAG FOR A MSGID\n
* RETURNED STRING MUST BE FREE
*/
char * bb_unset_starredmsg(char *msgid,char *pwdconf){
 char error[256];
 char *replyerror=NULL;
 char *reply=NULL;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(msgid)==0){
       sprintf(error,"%s","5820 - msgid is missing");
       goto CLEANUP;
 }
 if(atol(msgid)<=0){
       sprintf(error,"%s","5821 - msgid is wrong");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","5822 - configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"unsetstarredmsg",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"msgid\":\"%s\"}",action,msgid);
 
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"5803 - No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 if(reply!=NULL){
   memset(reply,0x0,strlen(reply));
   free(reply);
 }
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO SET "STARRED" FLAG FOR A MSGID\n
* RETURNED STRING MUST BE FREE
*/
char * bb_set_starredmsg(char *msgid,char *pwdconf){
 char error[256];
 char *replyerror=NULL;
 char *reply=NULL;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(msgid)==0){
       sprintf(error,"%s","5820 - msgid is missing");
       goto CLEANUP;
 }
 if(atol(msgid)<=0){
       sprintf(error,"%s","5821 - msgid is wrong");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","5822 - configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"setstarredmsg",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"msgid\":\"%s\"}",action,msgid);
 
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","5803 - No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 if(reply!=NULL){
   memset(reply,0x0,strlen(reply));
   free(reply);
 }
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO SET "ARCHIVED" FOR CHAT ONE-TO-ONE OR GROUP CHAT
* RETURNED STRING MUST BE FREE
*/
char * bb_set_archivedchat(char *recipient,char *groupchatid,char *pwdconf){
 char error[256];
 char *replyerror=NULL;
 char *reply=NULL;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(recipient)==0 && strlen(groupchatid)==0){
       sprintf(error,"%s","9820 - recipient or groupchat are missing");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       sprintf(error,"%s","9821 - configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"setarchivedchat",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"recipient\":\"%s\",\"groupchatid\":\"%s\"}",action,recipient,groupchatid);
 
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       sprintf(error,"%s","9822 - No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 if(reply!=NULL){
   memset(reply,0x0,strlen(reply));
   free(reply);
 }
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO UNSET "ARCHIVED" FOR CHAT ONE-TO-ONE OR GROUP CHAT\n
* RETURNED STRING MUST BE FREE
*/
char * bb_unset_archivedchat(char *recipient,char *groupchatid,char *pwdconf){
 char error[256];
 char *replyerror=NULL;
 char *reply=NULL;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(recipient)==0 && strlen(groupchatid)==0){
       strcpy(error,"9824 - recipient or groupchat are missing");
       goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       strcpy(error,"9825 - configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"unsetarchivedchat",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"recipient\":\"%s\",\"groupchatid\":\"%s\"}",action,recipient,groupchatid);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"9826 - No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 if(reply!=NULL){
   memset(reply,0x0,strlen(reply));
   free(reply);
 }
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO RESIZE A JPEG FILE
*/
int bb_jpeg_resize(char *inFileName, char *outFileName) {
  float factor;
  struct stat sb;
  struct jpeg_decompress_struct in;
  struct jpeg_error_mgr jInErr;
  struct jpeg_compress_struct out;
  struct jpeg_error_mgr jOutErr;
  JSAMPROW inRowPointer[1];
  FILE *inFile;
  int cx;
  stat(inFileName, &sb);
  factor=1.0f;
  if(sb.st_size>1000000) factor=0.5f;
  if(sb.st_size>500000 && sb.st_size<=1000000) factor=0.7f;
  if(sb.st_size>250000 && sb.st_size<=500000) factor=0.8f;
  if(sb.st_size<250000){
     cx=bb_copy_file(inFileName,outFileName);
     return(cx);
  }
  inFile = fopen(inFileName, "rb");
  if (!inFile) {
    fprintf(stderr,"25002 - Error opening jpeg file %s\n!", inFileName);
    return -1;
  }
  in.err = jpeg_std_error(&jInErr);
  jpeg_create_decompress(&in);
  jpeg_stdio_src(&in, inFile);
  jpeg_read_header(&in, TRUE);
  jpeg_start_decompress(&in);
  JSAMPROW outRowPointer[1];
  FILE *outFile = fopen(outFileName, "wb");
  if (!outFile) {
    fprintf(stderr,"25001- Error opening file %s\n", outFileName);
    return -1;
  }
  out.err = jpeg_std_error( &jOutErr);
  jpeg_create_compress(&out);
  jpeg_stdio_dest(&out, outFile);
  int width = in.output_width;
  int height = in.output_height;
  int bytesPerPixel = in.num_components;
  int destWidth = (int) (width * factor);
  int destHeight = (int) (height * factor);
  out.image_width = destWidth;
  out.image_height = destHeight;
  out.input_components = bytesPerPixel;
  out.in_color_space = JCS_RGB;
  jpeg_set_defaults(&out);
  jpeg_start_compress(&out, TRUE);
  // Process RGB data.
  int outRowStride = destWidth * bytesPerPixel;
  int inRowStride = width * bytesPerPixel;
  outRowPointer[0] = (unsigned char *) malloc(outRowStride);
  inRowPointer[0] = (unsigned char *) malloc(inRowStride);
  JSAMPROW baseInRowPointer[1];
  baseInRowPointer[0] = (unsigned char *) malloc(inRowStride);
  unsigned char bUpLeft, bUpRight, bDownLeft, bDownRight;
  unsigned char gUpLeft, gUpRight, gDownLeft, gDownRight;
  unsigned char rUpLeft, rUpRight, rDownLeft, rDownRight;
  unsigned char b, g, r;
  float fX, fY;
  int iX, iY;
  int i, j;
  int currentBaseLocation = -1;
  int count = 0;
  // Process the first line.
  jpeg_read_scanlines(&in, inRowPointer, 1);
  for (j = 0; j < destWidth; j++) {
    fX = ((float) j) / factor;
    iX = (int) fX;
    bUpLeft = inRowPointer[0][iX * 3 + 0];
    bUpRight = inRowPointer[0][(iX + 1) * 3 + 0];
    gUpLeft = inRowPointer[0][iX * 3 + 1];
    gUpRight = inRowPointer[0][(iX + 1) * 3 + 1];
    rUpLeft = inRowPointer[0][iX * 3 + 2];
    rUpRight = inRowPointer[0][(iX + 1) * 3 + 2];
    b = bUpLeft * (iX + 1 - fX) + bUpRight * (fX - iX);
    g = gUpLeft * (iX + 1 - fX) + gUpRight * (fX - iX);
    r = rUpLeft * (iX + 1 - fX) + rUpRight * (fX - iX);
    outRowPointer[0][j * 3 + 0] = b;
    outRowPointer[0][j * 3 + 1] = g;
    outRowPointer[0][j * 3 + 2] = r;
  }
  jpeg_write_scanlines(&out, outRowPointer, 1);
  currentBaseLocation = 0;
  // Process the other lines between the first and last.
  for (i = 1; i < destHeight - 1; i++) {
    fY = ((float) i) / factor;
    iY = (int) fY;
    if (iY == currentBaseLocation) {
      in.output_scanline = iY;
      bb_jpeg_swaprow(inRowPointer[0], baseInRowPointer[0]);
      jpeg_read_scanlines(&in, baseInRowPointer, 1);
    } else {
      in.output_scanline = iY - 1;
      jpeg_read_scanlines(&in, inRowPointer, 1);
      jpeg_read_scanlines(&in, baseInRowPointer, 1);
    }
    currentBaseLocation = iY + 1;
    for (j = 0; j < destWidth; j++) {
      fX = ((float) j) / factor;
      iX = (int) fX;
      bUpLeft = inRowPointer[0][iX * 3 + 0];
      bUpRight = inRowPointer[0][(iX + 1) * 3 + 0];
      bDownLeft = baseInRowPointer[0][iX * 3 + 0];
      bDownRight = baseInRowPointer[0][(iX + 1) * 3 + 0];
      gUpLeft = inRowPointer[0][iX * 3 + 1];
      gUpRight = inRowPointer[0][(iX + 1) * 3 + 1];
      gDownLeft = baseInRowPointer[0][iX * 3 + 1];
      gDownRight = baseInRowPointer[0][(iX + 1) * 3 + 1];
      rUpLeft = inRowPointer[0][iX * 3 + 2];
      rUpRight = inRowPointer[0][(iX + 1) * 3 + 2];
      rDownLeft = baseInRowPointer[0][iX * 3 + 2];
      rDownRight = baseInRowPointer[0][(iX + 1) * 3 + 2];
      b = bUpLeft * (iX + 1 - fX) * (iY + 1 - fY) + bUpRight * (fX - iX) * (iY + 1 - fY) + bDownLeft * (iX + 1 - fX) * (fY - iY) + bDownRight * (fX - iX) * (fY - iY);
      g = gUpLeft * (iX + 1 - fX) * (iY + 1 - fY) + gUpRight * (fX - iX) * (iY + 1 - fY) + gDownLeft * (iX + 1 - fX) * (fY - iY) + gDownRight * (fX - iX) * (fY - iY);
      r = rUpLeft * (iX + 1 - fX) * (iY + 1 - fY) + rUpRight * (fX - iX) * (iY + 1 - fY) + rDownLeft * (iX + 1 - fX) * (fY - iY) + rDownRight * (fX - iX) * (fY - iY);
      outRowPointer[0][j * 3 + 0] = b;
      outRowPointer[0][j * 3 + 1] = g;
      outRowPointer[0][j * 3 + 2] = r;
    }
    jpeg_write_scanlines(&out, outRowPointer, 1);
  }
  //Process the last line.
  in.output_scanline = height - 1;
  jpeg_read_scanlines(&in, inRowPointer, 1);
  for (j = 0; j < destWidth; j++) {
    fX = ((float) j) / factor;
    iX = (int) fX;
    bUpLeft = inRowPointer[0][iX * 3 + 0];
    bUpRight = inRowPointer[0][(iX + 1) * 3 + 0];
    gUpLeft = inRowPointer[0][iX * 3 + 1];
    gUpRight = inRowPointer[0][(iX + 1) * 3 + 1];
    rUpLeft = inRowPointer[0][iX * 3 + 2];
    rUpRight = inRowPointer[0][(iX + 1) * 3 + 2];
    b = bUpLeft * (iX + 1 - fX) + bUpRight * (fX - iX);
    g = gUpLeft * (iX + 1 - fX) + gUpRight * (fX - iX);
    r = rUpLeft * (iX + 1 - fX) + rUpRight * (fX - iX);
    outRowPointer[0][j * 3 + 0] = b;
    outRowPointer[0][j * 3 + 1] = g;
    outRowPointer[0][j * 3 + 2] = r;
  }
  jpeg_write_scanlines(&out, outRowPointer, 1);
  //free memory
  free(inRowPointer[0]);
  free(baseInRowPointer[0]);
  free(outRowPointer[0]);
  // close resource
  jpeg_finish_decompress(&in);
  jpeg_destroy_decompress(&in);
  fclose(inFile);
  jpeg_finish_compress(&out);
  jpeg_destroy_compress(&out);
  fclose(outFile);
  return(1);
}
/**
* SWAP OF THE ROW - PRIVATE FUNCTION
*/
void bb_jpeg_swaprow(unsigned char *src, unsigned char *dest) {
  unsigned char *temp;
  temp = dest;
  dest = src;
  src = temp;
}
/**
* SET CA LOCATION
*/
void bb_set_ca(const char* path) {
 if(strlen(path)>510){
    fprintf(stderr,"23401 - Path for Ca root is too long\n");
    return;
 }
 int x=strlen(path);
 strncpy(CaLocation, path, x+1);
 return;
}
/**
* FUNCTION TO MAKE CONFIGURATION
*/
char * bb_set_configuration(char * pwdconf,char *calendar,char *language,char *onlinevisibility,char *autodownloadphotos,char *autodownloadaudio,char *autodownloadvideos,char *autodownloaddocuments){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[8192];
 char action[64];
 error[0]=0;
 if(strlen(calendar)>0 && strcmp(calendar,"gregorian")!=0 && strcmp(calendar,"islamic")!=0){
        strcpy(error,"27501 - Calendar is wrong (gregorian/islamic)");
        goto CLEANUP;
 }
 if(strcmp(language,"en")!=0 && strcmp(language,"ar")!=0 && strlen(language)>0){
        strcpy(error,"27502 - Language is wrong");
        goto CLEANUP;
 }
 if((strlen(onlinevisibility)>0 && onlinevisibility[0]!='Y' && onlinevisibility[0]!='N') || strlen(onlinevisibility)>1) {
        strcpy(error,"27503 - On-line visibility is wrong");
        goto CLEANUP;
 }
 if((strlen(autodownloadaudio)>0 && atoi(autodownloadaudio)!=0 && atoi(autodownloadaudio)!=1 && atoi(autodownloadaudio)!=2) || strlen(autodownloadaudio)>1){
        strcpy(error,"27504 - Auto-download settings for audio is wrong");
        goto CLEANUP;
 }
 if((strlen(autodownloadphotos)>0 && atoi(autodownloadphotos)!=0 && atoi(autodownloadphotos)!=1 && atoi(autodownloadphotos)!=2)  || strlen(autodownloadphotos)>1){
        strcpy(error,"27504 - Auto-download settings for photos is wrong");
        goto CLEANUP;
 }
 if((strlen(autodownloadvideos)>0 && atoi(autodownloadvideos)!=0 && atoi(autodownloadvideos)!=1 && atoi(autodownloadvideos)!=2)  || strlen(autodownloadvideos)>1){
        strcpy(error,"27504 - Auto-download settings for videos is wrong");
        goto CLEANUP;
 }
 if((strlen(autodownloaddocuments)>0 && atoi(autodownloaddocuments)!=0 && atoi(autodownloaddocuments)!=1 && atoi(autodownloaddocuments)!=2)  || strlen(autodownloaddocuments)>1){
        strcpy(error,"27504 - Auto-download settings for documents is wrong");
        goto CLEANUP;
 }
 if(strlen(pwdconf)==0){
       strcpy(error,"configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"setconfiguration",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"calendar\":\"%s\",\"language\":\"%s\",\"onlinevisibility\":\"%s\",\"autodownloadphotos\":\"%s\",\"autodownloadaudio\":\"%s\",\"autodownloadvideos\":\"%s\",\"autodownloaddocuments\":\"%s\"}",action,calendar,language,onlinevisibility,autodownloadphotos,autodownloadaudio,autodownloadvideos,autodownloaddocuments);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO SET NOTIFICATIONS
*/
char * bb_set_notifications(char * pwdconf,char *groupchatid,char *contactnumber,char *soundname,char *vibration,char * priority,char *popup,char *dtmute){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 if(strlen(contactnumber)>31){
        strcpy(error,"27501 - Contact number is too long (max 32)");
        goto CLEANUP;
 }
 if(contactnumber==NULL){
        strcpy(error,"27502 - Contact number cannot be NULL");
        goto CLEANUP;
 }
 if(strlen(groupchatid)>31){
        strcpy(error,"27503 - Contact number cannot be NULL");
        goto CLEANUP;
 }
 if(strlen(dtmute)!=19 && strlen(dtmute)!=0){
        strcpy(error,"27510 - date/time mute is wrong");
        goto CLEANUP;
 }
 if(strlen(soundname)>31){
        strcpy(error,"27504 - Sound name is too long (max 32)");
        goto CLEANUP;
 }
 if((priority[0]!='N' && priority[0]!='Y') || strlen(priority)!=1){
       strcpy(error,"27505 - Priority is wrong");
        goto CLEANUP;
 }
 if((vibration[0]!='N' && vibration[0]!='Y') || strlen(vibration)!=1){
       strcpy(error,"27506 - Vibration is wrong");
        goto CLEANUP;
 }
 if((popup[0]!='N' && popup[0]!='Y') || strlen(popup)!=1){
       strcpy(error,"27507 - Popup is wrong");
        goto CLEANUP;
 }
 
 if(strlen(pwdconf)==0){
       strcpy(error,"configuration is missing");
       goto CLEANUP;
 }
 strncpy(action,"setnotification",63);
 sprintf(requestjson,"{\"action\":\"%s\",\"contactnumber\":\"%s\",\"groupchatid\":\"%s\",\"soundname\":\"%s\",\"vibration\":\"%s\",\"priority\":\"%s\",\"popup\":\"%s\",\"dtmute\":\"%s\"}",action,contactnumber,groupchatid,soundname,vibration,priority,popup,dtmute);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO GET NOTIFICATIONS
*/
char * bb_get_notifications(char * pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 strncpy(action,"getnotification",63);
 sprintf(requestjson,"{\"action\":\"%s\"}",action);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO GET CONFIGURATION
*/
char * bb_get_configuration(char * pwdconf){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 strncpy(action,"getconfiguration",63);
 sprintf(requestjson,"{\"action\":\"%s\"}",action);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO DELETE VOICE CALL
*/
char * bb_delete_voicecalls(char * pwdconf,char *callid){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 error[0]=0;
 strncpy(action,"deletevoicecalls",63);
 if(strlen(callid)>256){
       strcpy(error,"27678 - callid is too long");
       goto CLEANUP;
 }
 sprintf(requestjson,"{\"action\":\"%s\",\"callid\":\"%s\"}",action,callid);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"27679 -No reply from server, please try later");
       goto CLEANUP;
 }
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO DELETE MESSAGE
*/
char * bb_delete_message(char * pwdconf,char *msgid){
 char error[256];
 char *replyerror;
 char *reply;
 char *replyn;
 char requestjson[2048];
 char action[64];
 char recipient[64];
 int nm=0;
 char *msgtodelete;
 char *replyg;
 char *replygn;
 char msgidref[64];
 error[0]=0;
 strncpy(action,"deletemessage",63);
 if(strlen(msgid)>64){
       strcpy(error,"27750 - msgid is too long");
       goto CLEANUP;
 }
 sprintf(requestjson,"{\"action\":\"%s\",\"msgid\":\"%s\"}",action,msgid);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"27751 -No reply from server, please try later");
       goto CLEANUP;
 }
 if(verbose) printf("reply deletemessage: %s\n",reply);
 recipient[0]=0;
 bb_json_getvalue("recipient",reply,recipient,63);
 if(strlen(recipient)>0){
     replyn=NULL;
     replyn= bb_send_delete_nofification(recipient,msgid,pwdconf);
     if(verbose) printf("reply delete notification: %s\n",replyn);
     if(replyn!=NULL){
          if(verbose) printf("Notification Answer 1: %s\n",replyn);
          free(replyn);
     }
 }
 verbose=0;
 // CANCELLATION OF ALL LINKED MESSAGE BY MSGREF
 while(1){
     msgtodelete=NULL;
     msgtodelete=bb_json_getvalue_fromarray("msgtodelete",reply,nm);
     if(msgtodelete==NULL)
        break;
     msgidref[0]=0;
     bb_json_getvalue("id",msgtodelete,msgidref,63);
     if(strlen(msgidref)==0){
        free(msgtodelete);
        nm++;
        continue;
     }
     sprintf(requestjson,"{\"action\":\"%s\",\"msgid\":\"%s\"}",action,msgidref);
     replyg=bb_send_request_server(requestjson,action,pwdconf);
     if(replyg==NULL){
            strcpy(error,"27751 -No reply from server, please try later");
            free(msgtodelete);
            goto CLEANUP;
     }
     recipient[0]=0;
     bb_json_getvalue("recipient",replyg,recipient,63);
     if(strlen(recipient)>0){
         replygn=NULL;
         replygn= bb_send_delete_nofification(recipient,msgidref,pwdconf);
         if(replygn!=NULL){
             if(verbose) printf("Notification Answer: %s\n",replygn);
             free(replygn);
         }
     }
     free(replyg);
     free(msgtodelete);
     nm++;
 }
 
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO DELETE CHAT ONE-TO-ONE OR GROUP CHAT
*/
char * bb_delete_chat(char * pwdconf,char *recipient,char *groupid){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 int nm=0;
 char *msgtodelete;
 error[0]=0;
 strncpy(action,"deletechat",63);
 if(strlen(recipient)>64){
       strcpy(error,"27750 - recipient is too long");
       goto CLEANUP;
 }
 sprintf(requestjson,"{\"action\":\"%s\",\"recipient\":\"%s\",\"groupid\":\"%s\"}",action,recipient,groupid);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"27751 -No reply from server, please try later");
       goto CLEANUP;
 }
 if(verbose) printf("reply deletechat: %s\n",reply);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO SET AUTO-DELETE CHAT ONE-TO-ONE OR GROUP CHAT
*/
char * bb_autodelete_chat(char * pwdconf,char *recipient,char *groupid,int seconds){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 int nm=0;
 char *msgtodelete;
 error[0]=0;
 strncpy(action,"autodeletechat",63);
 if(strlen(recipient)>64){
       strcpy(error,"27750 - recipient is too long");
       goto CLEANUP;
 }
 if(strlen(groupid)>64){
       strcpy(error,"27751 - groupid is too long");
       goto CLEANUP;
 }
 if(seconds<0){
       strcpy(error,"27752 - seconds cannot be negative");
       goto CLEANUP;

 }
 
 sprintf(requestjson,"{\"action\":\"%s\",\"recipient\":\"%s\",\"groupid\":\"%s\",\"seconds\":\"%d\"}",action,recipient,groupid,seconds);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"27751 -No reply from server, please try later");
       goto CLEANUP;
 }
 if(verbose) printf("reply autodeletechat: %s\n",reply);
 //SEND SYSTEM ALERT
 char SAanswer[64];
 char SAmsgalert[512];
 char * SAreply=NULL;
 memset(SAmsgalert,0x0,512);
 bb_json_getvalue("answer", reply,SAanswer , 64);
 if(strcmp(SAanswer,"OK")==0 && atoi(groupid)>0){
    sprintf(SAmsgalert,"[AUTODELETE]Messages will self-disappear after [%d seconds] from this point.",seconds);
    SAreply=bb_send_systemalert(recipient,groupid,SAmsgalert,pwdconf);
    if(verbose==1) printf("SAreply: %s\n",SAreply);
    if(SAreply!=NULL) free(SAreply);
}
//END SYSTEM ALERT
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO GET CONFIGURATIIN OF AUTO-DELETE CHAT ONE-TO-ONE OR GROUP CHAT
*/
char * bb_autodelete_chat_getconf(char * pwdconf,char *recipient,char *groupid){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 int nm=0;
 char *msgtodelete;
 error[0]=0;
 strncpy(action,"autodeletechatgetconf",63);
 if(strlen(recipient)>64){
       strcpy(error,"27750 - recipient is too long");
       goto CLEANUP;
 }
 if(strlen(groupid)>64){
       strcpy(error,"27751 - groupid is too long");
       goto CLEANUP;
 }
 sprintf(requestjson,"{\"action\":\"%s\",\"recipient\":\"%s\",\"groupid\":\"%s\"}",action,recipient,groupid);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"27751 -No reply from server, please try later");
       goto CLEANUP;
 }
 if(verbose) printf("reply autodeletechat get conf: %s\n",reply);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}

/**
* FUNCTION TO GET READ RECEIPT FOR A GROUP MESSAGE
*/
char * bb_get_read_receipts_groupmsg(char * pwdconf,char *msgid){
 char error[256];
 char *replyerror;
 char *reply;
 char *replyn;
 char requestjson[2048];
 char action[64];
 char recipient[64];
 int nm=0;
 char *msgtodelete;
 char *replyg;
 char *replygn;
 char msgidref[64];
 error[0]=0;
 strncpy(action,"getreadreceiptsgroup",63);
 if(strlen(msgid)>64){
       strcpy(error,"28750 - msgid is too long");
       goto CLEANUP;
 }
 sprintf(requestjson,"{\"action\":\"%s\",\"msgid\":\"%s\"}",action,msgid);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"28751 -No reply from server, please try later");
       goto CLEANUP;
 }
 if(verbose) printf("reply read receipts group: %s\n",reply);
 
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO SET ON-LINE/OFF-LINE STATUS OF THE USER\n
* STATUS CAN BE "online","offline"
*/
char * bb_set_onoffline(char *pwdconf,char *status){
 char error[256];
 char *replyerror;
 char *reply;
 char *replyn;
 char requestjson[2048];
 char action[64];
 char recipient[64];
 int nm=0;
 char *contactsonline;
 char *replyg;
 char *replygn;
 char answer[64];
 error[0]=0;
 if(strcmp(status,"online")!=0 && strcmp(status,"offline")!=0){
       strcpy(error,"28750 - Status is not acceptable, it must online/offline");
       goto CLEANUP;
 }
 strncpy(action,"getonlinecontacts",63);
 sprintf(requestjson,"{\"action\":\"%s\"}",action);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"27751 -No reply from server, please try later");
       goto CLEANUP;
 }
 if(verbose) printf("reply get on-line contacts: %s\n",reply);
 answer[0]=0;
 bb_json_getvalue("answer",reply,answer,63);
 if(strcmp(answer,"OK")!=0){
       bb_json_getvalue("message",reply,error,255);
       goto CLEANUP;
 }
 sprintf(requestjson,"{\"action\":\"setonoffline\",\"status\":\"%s\"}",status);
 replygn=bb_send_request_server(requestjson,action,pwdconf);
 if(replygn==NULL){
    strcpy(error,"28855 -No reply from server, please try later");
    goto CLEANUP;
 }
 answer[0]=0;
 bb_json_getvalue("answer",replygn,answer,63);
 if(strcmp(answer,"OK")!=0){
       bb_json_getvalue("message",replygn,error,255);
       free(replygn);
       goto CLEANUP;
 }
 free(replygn);

 // SEND NOTIFICATION FOR STATUS CHANGE
 while(1){
     contactsonline=NULL;
     contactsonline=bb_json_getvalue_fromarray("contactsonline",reply,nm);
     if(contactsonline==NULL)
        break;
     recipient[0]=0;
     bb_json_getvalue("recipient",contactsonline,recipient,63);
     if(strlen(recipient)==0){
        free(contactsonline);
        nm++;
        continue;
     }
     sprintf(requestjson,"{\"action\":\"notifyonoffline\",\"recipient\":\"%s\",\"status\":\"%s\"}",recipient,status);
     replyg=bb_send_request_server(requestjson,action,pwdconf);
     if(replyg==NULL){
            strcpy(error,"28855 -No reply from server, please try later");
            free(contactsonline);
            goto CLEANUP;
     }
     bb_json_getvalue("answer",replyg,answer,63);
     if(strcmp(answer,"OK")!=0){
       bb_json_getvalue("message",replyg,error,255);
       free(replyg);
       goto CLEANUP;
     }
     free(replyg);
     free(contactsonline);
     nm++;
 }
 
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 free(reply);
 reply=malloc(512);
 strcpy(reply,"{\"answer\":\"OK\",\"message\":\"Status changed and notified\"}");
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO SET THE NETWORK CURRENTLY IN USE
* networktype can be "wifi" "mobile"
*/
char * bb_set_networktype(char *pwdconf,char *networktype){
 char error[256];
 char *replyerror;
 char *reply;
 char *replyn;
 char requestjson[2048];
 char action[64];
 char recipient[64];
 int nm=0;
 char *contactsonline;
 char *replyg;
 char *replygn;
 char answer[64];
 error[0]=0;
 if(strcmp(networktype,"wifi")!=0 && strcmp(networktype,"mobile")!=0){
       strcpy(error,"28750 - Network type  is not acceptable, it must wifi/mobile");
       goto CLEANUP;
 }
 strcpy(action,"setnetworktype");
 sprintf(requestjson,"{\"actioninternal\":\"setnetworktype\",\"networktype\":\"%s\"}",networktype);
 if(verbose) printf("requestjson: %s\n",requestjson);
 replygn=bb_send_request_server(requestjson,action,pwdconf);
 if(replygn==NULL){
    strcpy(error,"28855 -No reply from server, please try later");
    goto CLEANUP;
 }
 answer[0]=0;
 bb_json_getvalue("answer",replygn,answer,63);
 if(strcmp(answer,"OK")!=0){
       bb_json_getvalue("message",replygn,error,255);
       free(replygn);
       goto CLEANUP;
 }
 free(replygn);

 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 reply=malloc(512);
 strcpy(reply,"{\"answer\":\"OK\",\"message\":\"Network type has been  changed\"}");
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"KO\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/**
* FUNCTION TO SET AUTO-DELETE MESSAGE
*/
char * bb_autodelete_message(char * pwdconf,char *msgid,char *seconds){
 char error[256];
 char *replyerror;
 char *reply;
 char requestjson[2048];
 char action[64];
 
 error[0]=0;
 strncpy(action,"autodeletemessage",63);
 if(strlen(msgid)>64){
       strcpy(error,"27750 - msgid is too long");
       goto CLEANUP;
 }
 if(atoi(seconds)<15){
       strcpy(error,"27751 - seconds must be >15");
       goto CLEANUP;
 }
 sprintf(requestjson,"{\"action\":\"%s\",\"msgid\":\"%s\",\"seconds\":\"%s\"}",action,msgid,seconds);
 reply=bb_send_request_server(requestjson,action,pwdconf);
 if(reply==NULL){
       strcpy(error,"27751 -No reply from server, please try later");
       goto CLEANUP;
 }

    

 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(reply);

 CLEANUP:
 replyerror=malloc(512);
 sprintf(replyerror,"{\"answer\":\"OK\",\"message\":\"%s\"}",error);
 memset(error,0x0,256);
 memset(action,0x0,64);
 memset(requestjson,0x0,2048);
 return(replyerror);
}
/******************************************************************
* FUNCTION TO INIT GLOBAL VARS TO BE CALLED AT THE STARTUP ONLY
*/
void bb_init(void){
int i,x;
    for(i=0;i<=9;i++){
         SvtpReadAC[i].sq=0;
         SvtpReadAC[i].sqseed=0;
         memset(SvtpReadAC[i].key,0x0,64);
         memset(SvtpReadAC[i].keyseed,0x0,32);
         memset(&SvtpReadAC[i].destination,0x0,sizeof(SvtpReadAC[i].destination));
         SvtpReadAC[i].fdsocket=0;
         SvtpReadAC[i].portbinded=0;
         SvtpReadAC[i].statusvoicecall=0;
         SvtpReadAC[i].asyncrunning=0;
         SvtpReadAC[i].audioconference=0;
         SvtpReadAC[i].portpunched=0;
         memset(SvtpReadAC[i].error,0x0,512);
         memset(&SvtpReadAC[i].svtpbuf,0x0,sizeof(SvtpReadAC[i].svtpbuf[100]));
         memset(SvtpReadAC[i].ringbuf,0x0,16320);
         SvtpReadAC[i].ringbufptr=0;
         SvtpReadAC[i].ringbuflst=-1;
        for(x=0;x<=9;x++)  SvtpReadAC[i].ringbuflstmerge[x]=-1;
         SvtpReadAC[i].opusencoder=NULL;
         SvtpReadAC[i].opusdecoder=NULL;
    }
    return;
}
/**
* FUNCTION TO RESET A SESSION
*/
void bb_init_session(int session){
int i,x;
        if(session<0 || session>9)
             return;
         i=session;
         SvtpReadAC[i].sq=0;
         SvtpReadAC[i].sqseed=0;
         memset(SvtpReadAC[i].key,0x0,64);
         memset(SvtpReadAC[i].keyseed,0x0,32);
         memset(&SvtpReadAC[i].destination,0x0,sizeof(SvtpReadAC[i].destination));
         SvtpReadAC[i].fdsocket=0;
         SvtpReadAC[i].portbinded=0;
         SvtpReadAC[i].statusvoicecall=0;
         SvtpReadAC[i].asyncrunning=0;
         SvtpReadAC[i].audioconference=0;
         SvtpReadAC[i].portpunched=0;
         memset(SvtpReadAC[i].error,0x0,512);
         memset(&SvtpReadAC[i].svtpbuf,0x0,sizeof(SvtpReadAC[i].svtpbuf[100]));
         memset(SvtpReadAC[i].ringbuf,0x0,16320);
         SvtpReadAC[i].ringbufptr=0;
         SvtpReadAC[i].ringbuflst=-1;
         for(x=0;x<=9;x++)  SvtpReadAC[i].ringbuflstmerge[x]=-1;
         SvtpReadAC[i].opusencoder=NULL;
         SvtpReadAC[i].opusdecoder=NULL;
         return;
}


/**
* FUNCTION TO GENERATE A UNIQUE MSGREF
*/
void bb_gen_msgref(char * msgref){
    unsigned char buf[128];
    unsigned char hash[128];
    memset(hash,0x0,128);
    memset(buf,0x0,128);
    bb_crypto_random_data(buf);
    bb_sha3_256(buf,64,hash);
    bb_bin2hex(hash,32,buf);
    buf[32]=0;
    strncpy(msgref,buf,32);
    msgref[32]=0;
    memset(hash,0x0,128);
    memset(buf,0x0,128);
    return;
}
/**
* FUNCTION TO CHECK IF AUTODOWNLOAD MUST BE EXECUTED\n
* RETURN 1 OF YES AND 0 FOR NO
*/
int bb_check_autodownload(char *filename,char *autodownloadphotos,char * autodownloadvideos,char * autodownloadaudios,char *autodownloaddocuments){
    char extension[16];
    int x;
    memset(extension,0x0,16);
    x=strlen(filename);
    if(filename[x-4]=='.')
        strncpy(extension,&filename[x-4],16);
    if(filename[x-5]=='.')
        strncpy(extension,&filename[x-5],16);
    if(filename[x-3]=='.')
        strncpy(extension,&filename[x-3],16);
    //printf("@@@@@@@@@@@ extension: %s filename: %s autodownloadphotos: %s\n",extension,filename,autodownloadphotos);
    if(strcmp(extension,".mov")==0 || strcmp(extension,".mp4")==0 || strcmp(extension,".avi")==0 || strcmp(extension,".wmv")==0 || strcmp(extension,".3gp")==0
      || strcmp(extension,".MOV")==0 || strcmp(extension,".MP4")==0 || strcmp(extension,".AVI")==0 || strcmp(extension,".WMW")==0 || strcmp(extension,".3GP")==0)
    {
        if(autodownloadvideos[0]=='Y' || autodownloadvideos[0]=='\0')
            return(1);
        else
            return(0);
    }
    if(strcmp(extension,".png")==0 || strcmp(extension,".jpg")==0 || strcmp(extension,".jpeg")==0 || strcmp(extension,".gif")==0 || strcmp(extension,".svg")==0
       || strcmp(extension,".PNG")==0 || strcmp(extension,".JPG")==0 || strcmp(extension,".JPEG")==0 || strcmp(extension,".GIF")==0 || strcmp(extension,".SVG")==0
    ){
        if(autodownloadphotos[0]=='Y' || autodownloadphotos[0]=='\0')
            return(1);
        else
            return(0);
    }
    if(strcmp(extension,".m4a")==0 || strcmp(extension,".mp3")==0 || strcmp(extension,".wav")==0 || strcmp(extension,".wma")==0 || strcmp(extension,".aac")==0
       || strcmp(extension,".M4A")==0 || strcmp(extension,".MP3")==0 || strcmp(extension,".WAV")==0 || strcmp(extension,".WMA")==0 || strcmp(extension,".AAC")==0
    ){
        if(autodownloadaudios[0]=='Y' || autodownloadaudios[0]=='\0')
            return(1);
        else
            return(0);
    }
    if(autodownloaddocuments[0]=='Y' || autodownloaddocuments[0]=='\0')
        return(1);
    else
        return(0);
    
}
void bb_set_hostname(char *hostname) {
    strcpy(bbhostname, hostname);
}

void bb_set_interlapush_hostname(char *hostname) {
    strcpy(bbpushhostname, hostname);
}
 
/*#include "blackbox.h"

void main(void){
unsigned char s[256];
unsigned char d[512];
int len;
strcpy(s,"test for base64 asjjkj kjasjkkja asjka asjjkas saksa  aslksa asklklsa askkjas ajkjas askjkas jkasjkjka askja");
s[92]=0;
len=bb_encode_base64(s,92,d);
printf("%d - %s - %s\n",len,d,s);
strcpy(s,"                                                                                                            ");
len=bb_decode_base64(d,s);
s[len]=0;
printf("%d (%d)- %s\n",len,strlen(s),s);

exit(0);
}*/
/**
* ENCODE A BUFFER IN BASE64
*/
int bb_encode_base64(unsigned char * source, int sourcelen,unsigned char * destination)
{
    int len;
    len=EVP_EncodeBlock(destination, source, sourcelen);
    return(len);
}
/**
* DECODE BASE64 STRING IN A BUFFER, return lenght decoded
*/
int bb_decode_base64(unsigned char * source, unsigned char * destination)
{
    int len,dlen,x;
    len=strlen(source);
    x=0;
    if(len==0){
        destination[0]=0;
        return(0);
    }
    if(source[len-1]=='=') x++;
    if(source[len-2]=='=') x++;
    dlen=EVP_DecodeBlock(destination, source, len);
    return(dlen-x);
}

//*** ORIGIN: ../blackbox-server/bb_encode_decode_base64.c
/*#include "blackbox.h"
                
void main(void)
{
char key[512];
char keyb64[512];
char keyjson[512];
char buffer[512];
char encrypted[512];
int buffer_len=64;
int encrypted_len;
key[0]=0;
// TEST WITH KEY SET BEFORE THE ENCRYPTION
bb_crypto_random_data(key);
bb_crypto_random_data(&key[64]);
bb_encode_base64(key,96,keyb64);
printf("Key generated 768 bits: %s\n",keyb64);
bb_symmetrickey_to_jsonkey(key,keyjson);
printf("Json Key: %s\n",keyjson);
sprintf(buffer,"Plain text for testing ecryption 3 layers with key set before");
if(bb_encrypt_buffer_setkey(buffer,buffer_len,encrypted,&encrypted_len,keyjson)==0)
    fprintf(stderr,"Encryption failed");
printf("encrypted_len: %d\n", encrypted_len);
buffer[0]=0;
if(bb_decrypt_buffer(buffer,&buffer_len,encrypted,encrypted_len,keyjson)==0)
    fprintf(stderr,"Encryption failed");
printf("buffer decripted: %s\n",buffer);
printf("keyjson: %s\n",keyjson);
exit(0);


// TEST WITH AUTO-GENERATED KEY JSON
sprintf(buffer,"Plain text for testing ecryption 3 layers");
if(bb_encrypt_buffer(buffer,buffer_len,encrypted,&encrypted_len,key)==0)
    fprintf(stderr,"Encryption failed");
printf("key %s\n",key);
printf("key length %d\n",strlen(key));
printf("encrypted_len: %d\n", encrypted_len);

buffer[0]=0;
if(bb_decrypt_buffer(buffer,&buffer_len,encrypted,encrypted_len,key)==0)
    fprintf(stderr,"Encryption failed");
printf("buffer: %s\n",buffer);
exit;
}*/

/**
* CONVERSION OF A SYMMETRIC KEY OF 768 BITS (96 CHARS) TO JSON KEY IN BASE 64
*/
int bb_symmetrickey_to_jsonkey(unsigned char * key, char *jsonkey){
  unsigned char rd[128];
  char error[128]={""};
  unsigned char keyaes[64];
  unsigned char ivaes[32];
  unsigned char tagaes[64];
  unsigned char keycamellia[64];
  unsigned char ivcamellia[32];
  unsigned char keychacha[64];
  unsigned char ivchacha[32];
  unsigned char keyaesb64[128];
  unsigned char ivaesb64[64];
  unsigned char tagaesb64[64];
  unsigned char keycamelliab64[128];
  unsigned char ivcamelliab64[64];
  unsigned char keychachab64[128];
  unsigned char ivchachab64[64];
  int i;
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<64;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  if(bb_crypto_random_data(rd)==0){
    strcpy(error,"260 - Error generating true random data");
    goto CLEANUP;
  }
  memcpy(keyaes,&key[0],32);
  memcpy(keycamellia,&key[32],32);
  memcpy(keychacha,&key[64],32);
  memcpy(ivaes,&rd[0],16);
  memcpy(ivcamellia,&rd[16],16);
  memcpy(ivchacha,&rd[32],16);
  memset(tagaes,32,12);
  //* GENERATING KEY IN BASE64 +JSON
  if(!bb_encode_base64(keyaes,32,keyaesb64)){
    strcpy(error,"232 - Error encoding in base64 keyaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivaes,16,ivaesb64)){
    strcpy(error,"233 - Error encoding in base64 ivaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(tagaes,16,tagaesb64)){
    strcpy(error,"234 - Error encoding in base64 tagaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keycamellia,32,keycamelliab64)){
    strcpy(error,"235 - Error encoding in base64 keycamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivcamellia,16,ivcamelliab64)){
    strcpy(error,"236 - Error encoding in base64 ivcamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keychacha,32,keychachab64)){
    strcpy(error,"237 - Error encoding in base64 keychacha");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivchacha,16,ivchachab64)){
    strcpy(error,"238 - Error encoding in base64 ivchacha");
    goto CLEANUP;
  }
  sprintf(jsonkey,"{\"keyaes\":\"%s\",\"ivaes\":\"%s\",\"tagaes\":\"%s\",\"keycamellia\":\"%s\",\"ivcamellia\":\"%s\",\"keychacha\":\"%s\",\"ivchacha\":\"%s\"}",keyaesb64,ivaesb64,tagaesb64,keycamelliab64,ivcamelliab64,keychachab64,ivchachab64);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  return(1);
  
  CLEANUP:
  fprintf(stderr,"%s\n",error);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  return(0);
}
/**
* DECRYPT BUFFER WITH AES256+GCM,CAMELLIA+OFB,CHACHA20
*/
int bb_decrypt_buffer(unsigned char * buffer, int *buffer_len,unsigned char * encrypted,int encrypted_len, char *key){
  unsigned char rd[128];
  char error[128]={""};
  unsigned char keyaes[64];
  unsigned char ivaes[32];
  unsigned char tagaes[64];
  unsigned char keycamellia[64];
  unsigned char ivcamellia[32];
  unsigned char keychacha[64];
  unsigned char ivchacha[32];
  unsigned char keyaesb64[128];
  unsigned char ivaesb64[64];
  unsigned char tagaesb64[64];
  unsigned char keycamelliab64[128];
  unsigned char ivcamelliab64[64];
  unsigned char keychachab64[128];
  unsigned char ivchachab64[64];
  char *eb=NULL;
  char *ebb=NULL;
  int eb_len;
  int ebb_len;
  int i;
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<64;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  //** LOAD KEYS IV AND TAG(AES+GCM)
  if(!bb_json_getvalue("keyaes",key,keyaesb64,64)){
     strcpy(error,"239 - Error reading key AES");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivaes",key,ivaesb64,32)){
     strcpy(error,"240 - Error reading IV AES");
     goto CLEANUP;
  }
 if(!bb_json_getvalue("tagaes",key,tagaesb64,32)){
     strcpy(error,"241 - Error reading TAG AES");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("keycamellia",key,keycamelliab64,64)){
     strcpy(error,"242 - Error reading key CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivcamellia",key,ivcamelliab64,32)){
     strcpy(error,"243 - Error reading IV CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("keychacha",key,keychachab64,64)){
     strcpy(error,"244 - Error reading key CHACHA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivchacha",key,ivchachab64,32)){
     strcpy(error,"245 - Error reading IV CHACHA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keyaesb64,keyaes)){
      strcpy(error,"246 - Error decoding key AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivaesb64,ivaes)){
      strcpy(error,"247 - Error decoding IV AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(tagaesb64,tagaes)){
      strcpy(error,"248 - Error decoding TAG AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keycamelliab64,keycamellia)){
      strcpy(error,"249 - Error decoding key CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivcamelliab64,ivcamellia)){
      strcpy(error,"250 - Error decoding IV CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keychachab64,keychacha)){
      strcpy(error,"251 - Error decoding key CHACHA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivchachab64,ivchacha)){
      strcpy(error,"252 - Error decoding IV CHACHA");
     goto CLEANUP;
  }
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - Json Key has been loaded\n");
  eb=malloc(encrypted_len+16);
  eb_len=0;
  if(eb==NULL){
     strcpy(error,"253 - Error allocating eb buffer");
     goto CLEANUP;
  }
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - eb space allocated\n");
  if(!bb_decrypt_buffer_chacha20(eb,&eb_len,encrypted,encrypted_len,keychacha,ivchacha)){
    strcpy(error,"254 - Error decrypting buffer CHACHA20");
    goto CLEANUP;
  }
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - chacha20 done\n");
  ebb=malloc(encrypted_len+16);
  ebb_len=0;
  if(ebb==NULL){
     strcpy(error,"253 - Error allocating eb buffer");
     goto CLEANUP;
  }
  if(!bb_decrypt_buffer_camellia_ofb(ebb,&ebb_len,eb,eb_len,keycamellia,ivcamellia)){
    strcpy(error,"254 - Error decrypting the buffer CAMELLIA");
    goto CLEANUP;
  }
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - camellia done\n");
  if(!bb_decrypt_buffer_aes_gcm(buffer,buffer_len,ebb,ebb_len,keyaes,ivaes,tagaes)){
    strcpy(error,"255 - Error decrypting the buffer AES");
    goto CLEANUP;
  }
  //if(verbose) hexDump("AES",buffer,*buffer_len);
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - aes done\n");
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<64;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  if(eb!=NULL) free(eb);
  if(ebb!=NULL) free(ebb);
  return(1);
  
  CLEANUP:
  fprintf(stderr,"%s\n",error);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<64;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  if(eb!=NULL) free(eb);
  if(ebb!=NULL) free(ebb);
  return(0);
}
/**
* ENCRYPT BUFFER WITH AES256+GCM,CAMELLIA+OFB,CHACHA20
* KEY IS GENERATED AN RETURNED IN THE VARIABLE 768 char is required
*/
int bb_encrypt_buffer(unsigned char * buffer, int buffer_len,unsigned char * encrypted,int * encrypted_len, char *key){
  unsigned char rd[128];
  char error[128]={""};
  unsigned char keyaes[64];
  unsigned char ivaes[32];
  unsigned char tagaes[32];
  unsigned char keycamellia[64];
  unsigned char ivcamellia[32];
  unsigned char keychacha[64];
  unsigned char ivchacha[32];
  unsigned char keyaesb64[64];
  unsigned char ivaesb64[64];
  unsigned char tagaesb64[64];
  unsigned char keycamelliab64[128];
  unsigned char ivcamelliab64[64];
  unsigned char keychachab64[128];
  unsigned char ivchachab64[64];
  char *eb=NULL;
  char *ebb=NULL;
  int eb_len;
  int ebb_len;
  int i;
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  
  // AES+GCM encryption
  if(bb_crypto_random_data(rd)==0){
    strcpy(error,"224 - Error generating true random data");
    goto CLEANUP;
  }
  memcpy(keyaes,&rd[0],32);
  memcpy(ivaes,&rd[32],16);
  eb=malloc(buffer_len+16);
  eb_len=0;
  if(eb==NULL){
   strcpy(error,"225 - Error allocating temporary space for encryption");
    goto CLEANUP;
  }
  if(!bb_encrypt_buffer_aes_gcm(buffer,buffer_len,eb,&eb_len,keyaes,ivaes,tagaes)){
    strcpy(error,"226 - Error encrypting the buffer in AES");
    goto CLEANUP;
  }
  // CAMELLIA+OFB encryption
  for(i=0;i<128;i++) rd[0]=0;
  if(bb_crypto_random_data(rd)==0){
    strcpy(error,"227 - Error generating true random data");
    goto CLEANUP;
  }
  memcpy(keycamellia,&rd[0],32);
  memcpy(ivcamellia,&rd[32],16);
  ebb=malloc(buffer_len+16);
  ebb_len=0;
  if(ebb==NULL){
   strcpy(error,"228 - Error allocating temporary space for encryption");
    goto CLEANUP;
  }
  if(!bb_encrypt_buffer_camellia_ofb(eb,eb_len,ebb,&ebb_len,keycamellia,ivcamellia)){
    strcpy(error,"229 - Error encrypting the file CAMELLIA");
    goto CLEANUP;
  }
  // CHACHA20 encryption
  for(i=0;i<128;i++) rd[0]=0;
  if(bb_crypto_random_data(rd)==0){
    strcpy(error,"230 - Error generating true random data");
    goto CLEANUP;
  }
  memcpy(keychacha,&rd[0],32);
  memcpy(ivchacha,&rd[32],16);
  if(!bb_encrypt_buffer_chacha20(ebb,ebb_len,encrypted,encrypted_len,keychacha,ivchacha)){
    strcpy(error,"231 - Error encrypting the file CHACHA20");
    goto CLEANUP;
  }
  //* GENERATING KEY IN BASE64 +JSON
  if(!bb_encode_base64(keyaes,32,keyaesb64)){
    strcpy(error,"232 - Error encoding in base64 keyaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivaes,16,ivaesb64)){
    strcpy(error,"233 - Error encoding in base64 ivaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(tagaes,16,tagaesb64)){
    strcpy(error,"234 - Error encoding in base64 tagaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keycamellia,32,keycamelliab64)){
    strcpy(error,"235 - Error encoding in base64 keycamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivcamellia,16,ivcamelliab64)){
    strcpy(error,"236 - Error encoding in base64 ivcamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keychacha,32,keychachab64)){
    strcpy(error,"237 - Error encoding in base64 keychacha");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivchacha,16,ivchachab64)){
    strcpy(error,"238 - Error encoding in base64 ivchacha");
    goto CLEANUP;
  }
  sprintf(key,"{\"keyaes\":\"%s\",\"ivaes\":\"%s\",\"tagaes\":\"%s\",\"keycamellia\":\"%s\",\"ivcamellia\":\"%s\",\"keychacha\":\"%s\",\"ivchacha\":\"%s\"}",keyaesb64,ivaesb64,tagaesb64,keycamelliab64,ivcamelliab64,keychachab64,ivchachab64);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  if(eb!=NULL) free(eb);
  if(ebb!=NULL) free(ebb);
  return(1);
  
  CLEANUP:
  fprintf(stderr,"%s\n",error);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  if(eb!=NULL) free(eb);
  if(ebb!=NULL) free(ebb);
  return(0);
}
/**
* ENCRYPT BUFFER WITH AES256+GCM,CAMELLIA+OFB,CHACHA20\n
* KEY IS USED FOR THE ENCRYPTION, IT MUST RESPECT A SPECIFIC JSON\n
* KEY IS WRITTEN BACK WITH TAGAES calculated properly
*/
int bb_encrypt_buffer_setkey(unsigned char * buffer, int buffer_len,unsigned char * encrypted,int * encrypted_len, char *key){
  unsigned char rd[128];
  char error[128]={""};
  unsigned char keyaes[64];
  unsigned char ivaes[32];
  unsigned char tagaes[32];
  unsigned char keycamellia[64];
  unsigned char ivcamellia[32];
  unsigned char keychacha[64];
  unsigned char ivchacha[32];
  unsigned char keyaesb64[64];
  unsigned char ivaesb64[64];
  unsigned char tagaesb64[64];
  unsigned char keycamelliab64[128];
  unsigned char ivcamelliab64[64];
  unsigned char keychachab64[128];
  unsigned char ivchachab64[64];
  int i;
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  //** LOAD KEYS IV AND TAG(AES+GCM)
  if(!bb_json_getvalue("keyaes",key,keyaesb64,64)){
     strcpy(error,"239 - Error reading key AES");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivaes",key,ivaesb64,32)){
     strcpy(error,"240 - Error reading IV AES");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("keycamellia",key,keycamelliab64,64)){
     strcpy(error,"242 - Error reading key CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivcamellia",key,ivcamelliab64,32)){
     strcpy(error,"243 - Error reading IV CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("keychacha",key,keychachab64,64)){
     strcpy(error,"244 - Error reading key CHACHA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivchacha",key,ivchachab64,32)){
     strcpy(error,"245 - Error reading IV CHACHA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keyaesb64,keyaes)){
      strcpy(error,"246 - Error decoding key AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivaesb64,ivaes)){
      strcpy(error,"247 - Error decoding IV AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keycamelliab64,keycamellia)){
      strcpy(error,"249 - Error decoding key CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivcamelliab64,ivcamellia)){
      strcpy(error,"250 - Error decoding IV CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keychachab64,keychacha)){
      strcpy(error,"251 - Error decoding key CHACHA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivchachab64,ivchacha)){
      strcpy(error,"252 - Error decoding IV CHACHA");
     goto CLEANUP;
  }
  
  // AES+GCM encryption
  char *eb=malloc(buffer_len+16);
  int eb_len=0;
  if(eb==NULL){
   strcpy(error,"225 - Error allocating temporary space for encryption");
    goto CLEANUP;
  }
  if(!bb_encrypt_buffer_aes_gcm(buffer,buffer_len,eb,&eb_len,keyaes,ivaes,tagaes)){
    strcpy(error,"226 - Error encrypting the buffer in AES");
    goto CLEANUP;
  }
  // CAMELLIA+OFB encryption
  char *ebb=malloc(buffer_len+16);
  int ebb_len=0;
  if(ebb==NULL){
   strcpy(error,"228 - Error allocating temporary space for encryption");
   free(eb);
    goto CLEANUP;
  }
  if(!bb_encrypt_buffer_camellia_ofb(eb,eb_len,ebb,&ebb_len,keycamellia,ivcamellia)){
    strcpy(error,"229 - Error encrypting the file CAMELLIA");
    free(eb);
    free(ebb);
    goto CLEANUP;
  }
  free(eb);
  // CHACHA20 encryption
  if(!bb_encrypt_buffer_chacha20(ebb,ebb_len,encrypted,encrypted_len,keychacha,ivchacha)){
    strcpy(error,"231 - Error encrypting the file CHACHA20");
    free(ebb);
    goto CLEANUP;
  }
  free(ebb);
  //* GENERATING KEY IN BASE64 +JSON
  if(!bb_encode_base64(keyaes,32,keyaesb64)){
    strcpy(error,"232 - Error encoding in base64 keyaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivaes,16,ivaesb64)){
    strcpy(error,"233 - Error encoding in base64 ivaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(tagaes,16,tagaesb64)){
    strcpy(error,"234 - Error encoding in base64 tagaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keycamellia,32,keycamelliab64)){
    strcpy(error,"235 - Error encoding in base64 keycamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivcamellia,16,ivcamelliab64)){
    strcpy(error,"236 - Error encoding in base64 ivcamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keychacha,32,keychachab64)){
    strcpy(error,"237 - Error encoding in base64 keychacha");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivchacha,16,ivchachab64)){
    strcpy(error,"238 - Error encoding in base64 ivchacha");
    goto CLEANUP;
  }
  sprintf(key,"{\"keyaes\":\"%s\",\"ivaes\":\"%s\",\"tagaes\":\"%s\",\"keycamellia\":\"%s\",\"ivcamellia\":\"%s\",\"keychacha\":\"%s\",\"ivchacha\":\"%s\"}",keyaesb64,ivaesb64,tagaesb64,keycamelliab64,ivcamelliab64,keychachab64,ivchachab64);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  return(1);
  
  CLEANUP:
  fprintf(stderr,"%s\n",error);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  return(0);
}

/*#include "bb_encrypt_decrypt_buffer_aes_gcm.c"
#include "bb_encrypt_decrypt_buffer_camellia_ofb.c"
#include "bb_encrypt_decrypt_buffer_chacha20.c"
#include "bb_crypto_randomdata.c"
#include "bb_encode_decode_base64.c"
#include "bb_sha.c"
#include "bb_json.c"*/

//*** ORIGIN: ../blackbox-server/bb_encrypt_decrypt_buffer.c
/*#include "blackbox.h"
                
void main(void)
{
char key[64];
char iv[64];
char tag[16];
unsigned char buffer[1024];
unsigned char encrypted[1024];
int encrypted_len=0;
int buffer_len=64;
int i;
sprintf(buffer,"Test encryption of a clear text");
strcpy(iv,"1234567890123456");
strcpy(key,"123456789012345K");
bb_encrypt_buffer_aes_gcm(buffer,buffer_len,encrypted,&encrypted_len,key,iv,tag);
printf("encrypted_len: %d\n",encrypted_len);
buffer[0]=0;
buffer_len=0;
bb_decrypt_buffer_aes_gcm(buffer,&buffer_len,encrypted,encrypted_len,key,iv,tag);
printf("decrypted buffer: %s\n",buffer);
exit;

}*/
/**
* FILE ENCRYPTION BY AES256 + GCM (key MUST be 256 bit)
*/
int bb_decrypt_buffer_aes_gcm(unsigned char * buffer, int *buffer_len,unsigned char *encrypted, int encrypted_len, const void * key, const void * iv,char * tag){
    int f_len = 0;
    int iv_len=12;
    int i;
    char error[128]={"\0"};
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"197 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL)){
        strcpy(error,"198 - Error initialising the AES-256 GCM, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, iv_len, NULL)){
        strcpy(error,"199 - Error initialising the AES-256 GCM - IV LEN, libssl may be wrong version or missing");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"200 - Error initialising the AES-256 GCM - KEY and IV");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(EVP_DecryptUpdate(ctx, buffer, buffer_len, encrypted, encrypted_len) == 0){
           sprintf(error, "201 - EVP_DecryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           EVP_CIPHER_CTX_free(ctx);
           goto CLEANUP;
    }
    if(!EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, tag)){
        sprintf(error, "202 - Error EVP_CIPHER_CTX_ctrl failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    f_len=0;
    if(EVP_DecryptFinal_ex(ctx, buffer, &f_len) == 0) {
        sprintf(error, "203 - Error EVP_DecryptFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));

        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(f_len>0)
      buffer_len=buffer_len+f_len;
    for(i=0;i<128;i++) error[i]=0;
    EVP_CIPHER_CTX_free(ctx);
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    for(i=0;i<128;i++) error[i]=0;
    return(0);
    
}
/**
* BUFFER ENCRYPTION BY AES256 + GCM (key MUST be 256 bit)
*/
int bb_encrypt_buffer_aes_gcm(unsigned char * buffer, int buffer_len,unsigned char * encrypted, int *encrypted_len,const void * key, const void * iv,char * tag){
    char error[128]={"\0"};
    int iv_len=12;
    int f_len,i;
    
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"190 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL)){
        strcpy(error,"191 - Error initialising the AES-256 GCM, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, iv_len, NULL)){
        strcpy(error,"192 - Error initialising the AES-256 GCM - IV LEN, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"193 - Error initialising the AES-256 GCM - KEY and IV");
        goto CLEANUP;
    }
    if(EVP_EncryptUpdate(ctx, encrypted, encrypted_len, buffer, buffer_len) == 0){
           sprintf(error, "194 - EVP_CipherUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           EVP_CIPHER_CTX_free(ctx);
           goto CLEANUP;
    }
    f_len=0;
    if(EVP_EncryptFinal_ex(ctx, encrypted, &f_len) == 0) {
        sprintf(error, "195 - Error EVP_CipherFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(f_len>0)
        encrypted_len=encrypted_len+f_len;
    if(1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, tag)){
        sprintf(error, "196 - Error EVP_CIPHER_CTX_ctrl failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    
    EVP_CIPHER_CTX_free(ctx);
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    memset(error,0x0,128);
    return(0);
    
}


//*** ORIGIN: ../blackbox-server/bb_encrypt_decrypt_buffer_aes_gcm.c
/*#include "blackbox.h"
                
void main(void)
{
char key[64];
char iv[64];
char buffer[256]={"plain text for encryption test"};
int buffer_len=64;
char encrypted[256];
int encrypted_len;
int i;
strcpy(iv,"1234567890123456");
strcpy(key,"123456789012345K");
bb_encrypt_buffer_camellia_ofb(buffer,buffer_len,encrypted,&encrypted_len,key,iv);
printf("encrypted len: %d\n",encrypted_len);
bb_decrypt_buffer_camellia_ofb(buffer,&buffer_len,encrypted,encrypted_len,key,iv);
buffer[buffer_len]=0;
printf("decrypted len: %d\n",buffer_len);
printf("decrypted text: %s\n",buffer);
exit;

}*/
/**
* Buffer decryption CAMELLIA + OFB (key MUST be 256 bit)
*/
int bb_decrypt_buffer_camellia_ofb(unsigned char * buffer,int *buffer_len,unsigned char * encrypted,int encrypted_len,unsigned char *key,unsigned char *iv)
{
    int f_len = 0;
    //int iv_len=16;
    int i;
    char error[128]={"\0"};
    
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"204 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, EVP_camellia_256_ofb(), NULL, NULL, NULL)){
        strcpy(error,"205 - Error initialising the CAMELLIA OFB libssl may be wrong version or missing");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"206 - Error initialising the CAMELLIA OFB - KEY and IV");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(EVP_DecryptUpdate(ctx, buffer, buffer_len, encrypted, encrypted_len) == 0){
        sprintf(error, "207 - EVP_DecryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(EVP_DecryptFinal_ex(ctx, &buffer[*buffer_len], &f_len) == 0) {
        sprintf(error, "208 - Error EVP_DecryptFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    EVP_CIPHER_CTX_free(ctx);
    for(i=0;i<128;i++) error[i]=0;
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    for(i=0;i<128;i++) error[i]=0;
    return(0);
    
}
/**
* FILE ENCRYPTION BY CAMELLIA +OFB (key MUST be 256 bit)
*/
int bb_encrypt_buffer_camellia_ofb(unsigned char * buffer,int buffer_len,unsigned char * encrypted,int * encrypted_len,unsigned char *key,unsigned char *iv){
    int f_len = 0;
    //int iv_len=16;
    int i;
    char error[128]={"\0"};
    
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"209 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, EVP_camellia_256_ofb(), NULL, NULL, NULL)){
        EVP_CIPHER_CTX_free(ctx);
        strcpy(error,"210 - Error initialising the CAMELLIA OFB, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"211 - Error initialising the CAMELLIA OFB - KEY and IV");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(EVP_EncryptUpdate(ctx, encrypted, encrypted_len, buffer, buffer_len) == 0){
           sprintf(error, "212 - EVP_EncryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           EVP_CIPHER_CTX_free(ctx);
           goto CLEANUP;
    }
    if(EVP_EncryptFinal_ex(ctx, &encrypted[*encrypted_len], &f_len) == 0) {
        sprintf(error, "213 - Error EVP_CipherFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(f_len) *encrypted_len=*encrypted_len+f_len;
    EVP_CIPHER_CTX_free(ctx);
    for(i=0;i<128;i++) error[i]=0;
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    for(i=0;i<128;i++) error[i]=0;
    return(0);
    
}



//*** ORIGIN: ../blackbox-server/bb_encrypt_decrypt_buffer_camellia_ofb.c
/*#include "blackbox.h"
                
void main(void)
{
char key[64];
char iv[64];
int i;
strcpy(iv,"1234567890123456");
strcpy(key,"123456789012345K");
char buffer[256]={"plain text for encryption test"};
int buffer_len=64;
char encrypted[256];
int encrypted_len;
bb_encrypt_buffer_chacha20(buffer,buffer_len,encrypted,&encrypted_len,key,iv);
printf("encrypted len: %d\n",encrypted_len);
bb_decrypt_buffer_chacha20(buffer,&buffer_len,encrypted,encrypted_len,key,iv);
buffer[buffer_len]=0;
printf("decrypted len: %d\n",buffer_len);
printf("decrypted text: %s\n",buffer);

exit;

}*/
/**
* BUFFER DECRYPTION BY CHACHA20 (key MUST be 256 bit)
*/
int bb_decrypt_buffer_chacha20(unsigned char * buffer,int * buffer_len,unsigned char * encrypted,int encrypted_len,unsigned char *key,unsigned char *iv)
{
    int f_len = 0;
    //int iv_len=16;
    int i;
    char error[128]={"\0"};
    
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"219 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, EVP_chacha20(), NULL, NULL, NULL)){
        strcpy(error,"220 - Error initialising the CHACHA20  libssl may be wrong version or missing");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"221 - Error initialising the CHACHA20 - KEY and IV");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(EVP_DecryptUpdate(ctx, buffer, buffer_len, encrypted, encrypted_len) == 0){
           sprintf(error, "222 - EVP_DecryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           EVP_CIPHER_CTX_free(ctx);
           goto CLEANUP;
    }
    if(EVP_DecryptFinal_ex(ctx, &buffer[*buffer_len], &f_len) == 0) {
        sprintf(error, "223 - Error EVP_DecryptFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(f_len>0) *buffer_len=*buffer_len+f_len;

    
    EVP_CIPHER_CTX_free(ctx);
    for(i=0;i<128;i++) error[i]=0;
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    for(i=0;i<128;i++) error[i]=0;
    return(0);
    
}
/**
* BUFFER ENCRYPTION BY CHACHA20(key MUST be 256 bit)
*/
int bb_encrypt_buffer_chacha20(unsigned char * buffer,int buffer_len,unsigned char * encrypted,int * encrypted_len,unsigned char *key,unsigned char *iv){
    int f_len = 0;
    //int iv_len=16;
    int i;
    char error[128]={"\0"};
    
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"214 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, EVP_chacha20(), NULL, NULL, NULL)){
        strcpy(error,"215 - Error initialising the CHACHA20 libssl may be wrong version or missing");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"216 - Error initialising the CHACHA20 - KEY and IV");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(EVP_EncryptUpdate(ctx, encrypted, encrypted_len, buffer, buffer_len) == 0){
           sprintf(error, "217 - EVP_EncryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           EVP_CIPHER_CTX_free(ctx);
           goto CLEANUP;
    }
    if(EVP_EncryptFinal_ex(ctx, &encrypted[*encrypted_len], &f_len) == 0) {
        sprintf(error, "218 - Error EVP_CipherFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(f_len) *encrypted_len=*encrypted_len+f_len;
    
    EVP_CIPHER_CTX_free(ctx);
    for(i=0;i<128;i++) error[i]=0;
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    for(i=0;i<128;i++) error[i]=0;
    return(0);
    
}



//*** ORIGIN: ../blackbox-server/bb_encrypt_decrypt_buffer_chacha20.c
/*#include "blackbox.h"

void main(void){
char rd[128];
if(bb_crypto_random_data(rd)==0)
    printf("error getting random data\n");
bb_hexdump("Random Data",rd,64);
}*/
/**
* FUNCTION TO GET 512 BITS (64 BYTES) OF CRYPTO RANDOM DATA
*/
int bb_crypto_random_data(char * rd){
    char buf[128];
    int i,r;
    long mt;
    struct timeval currentTime;
    char source[512],destination[512],tm[64];
    char error[256];
    //cleanup
    for(i=0;i<128;i++) buf[i]=0;
    for(i=0;i<64;i++) tm[i]=0;
    for(i=0;i<512;i++) destination[i]=0;
    for(i=0;i<512;i++) source[i]=0;
    for(i=0;i<256;i++) error[i]=0;
    r=0;
    //** read /dev/urandom
    int urnd = open("/dev/urandom", O_RDONLY);
    read(urnd, &buf[0], 32);
    close(urnd);
    //** get microtime
    gettimeofday(&currentTime, NULL);
    mt= currentTime.tv_sec * (int)1e6 + currentTime.tv_usec;
        sprintf(tm,"%016ld\n",mt);
        memcpy(&buf[32],tm,16);
        gettimeofday(&currentTime, NULL);
    mt= currentTime.tv_sec * (int)1e6 + currentTime.tv_usec;
        sprintf(tm,"%016ld\n",mt);
        memcpy(&buf[48],tm,16);
        // sha2 and sha3 with microtime
    if(!bb_sha3_256(buf,64,destination))
        return(0);
    memcpy(source,destination,32);
    gettimeofday(&currentTime, NULL);
    mt= currentTime.tv_sec * (int)1e6 + currentTime.tv_usec;
        sprintf(tm,"%016ld\n",mt);
        memcpy(&source[32],tm,16);
    if(!bb_sha2_256(source,48,destination))
        return(0);
        
    memcpy(source,destination,32);
    gettimeofday(&currentTime, NULL);
    mt= currentTime.tv_sec * (int)1e6 + currentTime.tv_usec;
        sprintf(tm,"%016ld\n",mt);
        memcpy(&source[32],tm,16);
    if(!bb_sha3_256(source,48,destination))
        return(0);

    memcpy(source,destination,32);
    gettimeofday(&currentTime, NULL);
    mt= currentTime.tv_sec * (int)1e6 + currentTime.tv_usec;
        sprintf(tm,"%016ld\n",mt);
        memcpy(&source[32],tm,16);
    if(!bb_sha2_512(source,48,destination))
        return(0);
        
    memcpy(source,destination,64);
    gettimeofday(&currentTime, NULL);
    mt= currentTime.tv_sec * (int)1e6 + currentTime.tv_usec;
        sprintf(tm,"%016ld\n",mt);
        memcpy(&source[64],tm,16);
    r=bb_sha3_512(source,80,destination);
    if(r==0) return(0);
    //CLEANUP
    memcpy(rd,destination,64);
    for(i=0;i<128;i++) buf[i]=0;
    for(i=0;i<64;i++) tm[i]=0;
    for(i=0;i<512;i++) source[i]=0;
    for(i=0;i<512;i++) destination[i]=0;
    return(r);
}

/*
#include "bb_sha.c"
#include "bb_hexdump.c"
*/


//*** ORIGIN: ../blackbox-server/bb_crypto_randomdata.c
/*#include "blackbox.h"

void main(void){
char s[256];
char d[512];
int len;
strcpy(s,"test for base64 asjjkj kjasjkkja asjka asjjkas saksa  aslksa asklklsa askkjas ajkjas askjkas jkasjkjka askja");
s[100]=0;
len=bb_sha3_256(s,80,d);
printf("%d - %s - %s\n",len,d,s);
exit(0);
}*/
/**
* HASHING A BUFFER WITH SHA2-256
*/
int bb_sha3_256(unsigned char * source, int sourcelen,unsigned char * destination)
{
    int dlen;
    char error[256];
    error[0]=0;
    EVP_MD_CTX *mdctx;
    if((mdctx = EVP_MD_CTX_create()) == NULL){
        strcpy(error,"100 - Error creating hashing object, openssl library could miss or be wrong");
        goto CLEANUP;
    }
    if(1 != EVP_DigestInit_ex(mdctx, EVP_sha3_256(), NULL)){
        strcpy(error,"101 - Error creating sha3-256 object, openssl library could miss or be wrong");
        EVP_MD_CTX_destroy(mdctx);
        goto CLEANUP;
    }
    if(1 != EVP_DigestUpdate(mdctx, source, sourcelen)){
        strcpy(error,"102 - Error calculating the hash - sha3-256");
        EVP_MD_CTX_destroy(mdctx);
        goto CLEANUP;
    }
    if(1 != EVP_DigestFinal_ex(mdctx, destination, &dlen)){
        strcpy(error,"103 - Error generating the hash - sha3-256");
        EVP_MD_CTX_destroy(mdctx);
        goto CLEANUP;
    }
    EVP_MD_CTX_destroy(mdctx);
    return(dlen);

    CLEANUP:
    fprintf(stderr,"%s\n",error);
    return(0);
}
/**
* HASHING A BUFFER WITH SHA3-512
*/
int bb_sha3_512(unsigned char * source, int sourcelen,unsigned char * destination)
{
    int dlen;
    char error[256];
    error[0]=0;
    EVP_MD_CTX *mdctx;
    if((mdctx = EVP_MD_CTX_create()) == NULL){
        strcpy(error,"104 - Error creating hashing object, openssl library could miss or be wrong");
        goto CLEANUP;
    }
    if(1 != EVP_DigestInit_ex(mdctx, EVP_sha3_512(), NULL)){
        strcpy(error,"105 - Error creating sha3-512 object, openssl library could miss or be wrong");
        goto CLEANUP;
    }
    if(1 != EVP_DigestUpdate(mdctx, source, sourcelen)){
        EVP_MD_CTX_destroy(mdctx);
        strcpy(error,"106 - Error calculating the hash - sha3-512");
        goto CLEANUP;
    }
    if(1 != EVP_DigestFinal_ex(mdctx, destination, &dlen)){
        EVP_MD_CTX_destroy(mdctx);
        strcpy(error,"107 - Error generating the hash - sha3-512");
        goto CLEANUP;
    }
    EVP_MD_CTX_destroy(mdctx);
    return(dlen);
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    return(0);
}

/**
* HASHING A BUFFER WITH SHA2-256
*/
int bb_sha2_256(unsigned char * source, int sourcelen,unsigned char * destination)
{
    int dlen;
    char error[256];
    error[0]=0;
    EVP_MD_CTX *mdctx;
    if((mdctx = EVP_MD_CTX_create()) == NULL){
        strcpy(error,"108 - Error creating hashing object, openssl library could miss or be wrong");
        goto CLEANUP;
    }
    if(1 != EVP_DigestInit_ex(mdctx, EVP_sha256(), NULL)){
        strcpy(error,"109 - Error creating sha256 object, openssl library could miss or be wrong");
        EVP_MD_CTX_destroy(mdctx);
        goto CLEANUP;
    }
    if(1 != EVP_DigestUpdate(mdctx, source, sourcelen)){
        strcpy(error,"110 - Error calculating the hash - sha256");
        EVP_MD_CTX_destroy(mdctx);
        goto CLEANUP;
    }
    if(1 != EVP_DigestFinal_ex(mdctx, destination, &dlen)){
        strcpy(error,"111 - Error generating the hash - sha256");
        EVP_MD_CTX_destroy(mdctx);
        goto CLEANUP;
    }
    EVP_MD_CTX_destroy(mdctx);
    return(dlen);

    CLEANUP:
    fprintf(stderr,"%s\n",error);
    return(0);
}
/**
* HASHING A BUFFER WITH SHA2-512
*/
int bb_sha2_512(unsigned char * source, int sourcelen,unsigned char * destination)
{
    int dlen;
    char error[256];
    error[0]=0;
    EVP_MD_CTX *mdctx;
    if((mdctx = EVP_MD_CTX_create()) == NULL){
        strcpy(error,"112 - Error creating hashing object, openssl library could miss or be wrong");
        goto CLEANUP;
    }
    if(1 != EVP_DigestInit_ex(mdctx, EVP_sha512(), NULL)){
        strcpy(error,"113 - Error creating sha512 object, openssl library could miss or be wrong");
        goto CLEANUP;
    }
    if(1 != EVP_DigestUpdate(mdctx, source, sourcelen)){
        EVP_MD_CTX_destroy(mdctx);
        strcpy(error,"114 - Error calculating the hash - sha512");
        goto CLEANUP;
    }
    if(1 != EVP_DigestFinal_ex(mdctx, destination, &dlen)){
        EVP_MD_CTX_destroy(mdctx);
        strcpy(error,"115 - Error generating the hash - sha512");
        goto CLEANUP;
    }
    EVP_MD_CTX_destroy(mdctx);
    return(dlen);
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    return(0);
}

//*** ORIGIN: ../blackbox-server/bb_sha.c

/**
* FUNCTION TO GET A JSON RECORD FROM AN ARRAY INSIDE A 2 LEVEL JSON\n
* RETURN A CHAR * TO THE RECORD OR NULL IN CASE OF NOT PRESENT THE \n
* REQUEST ELEMENT OF THE ARRAY (NR) (THE FIRST RECORD START FROM 0\n
* THE RETURN CHAR * MUST BE FREE() IF NOT NULL
*/
char * bb_json_getvalue_fromarray(char * name,char *json,int nr){
int len,i,x,c,z,sv,ev;
char *sj=NULL;
char *answ=NULL;
char buffer[1024];
if(strlen(name)>512)
 return(NULL);
if(json[0]!='{')
    return(NULL);
if(nr<0)
    return(NULL);
len=strlen(json);
//NORMALIZE JSON REMOVING WHITE SPACES [TODO]
sprintf(buffer,"\"%s\":[",name);
//printf("buffer: %s\n",buffer);
sj=strstr(json,buffer);
if(sj==NULL)
   return(NULL);
x=strlen(sj);
for(i=0;i<x;i++){
  if(sj[i]==']'){
      //sj[i]=0;
      x=i;
      break;
  }
}
sj=sj+4+strlen(name);
// SJ HAS ONLY THE ARRAY WITHOUT []
//printf("sj: %s\n",sj);
//x=strlen(sj);
c=0;
sv=-1;
ev=-1;
for(i=0;i<x;i++){
  if(sj[i]=='{' && c==nr)
      sv=i;
  if(sj[i]=='}' && c==nr)
      ev=i;
  if(sj[i]=='}' && c!=nr)
      c++;
  if(sv>-1 && ev>-1 && ev>sv){
      z=ev-sv+2;
      answ=malloc(z+10);
      memset(answ,0x0,z+10);
      strncpy(answ,&sj[sv],z-1);
      answ[z-1]=0;
      return(answ);
  }
}
return(NULL);
}
/**
* FUNCTION TO GET FIELD VALUE FROM A JSON SINGLE RECORD
*/
int bb_json_getvalue(char * name,char *json,char *destination,int maxlen){
int len,i,startj,endj,startn,endn,startv,endv,doubledot;
char fieldname[512];
char fieldvalue[16385];
int fieldlength=0;
startj=0;
endj=0;
startn=0;
endn=0;
startv=0;
endv=0;
doubledot=0;
len=strlen(json);
//check start for json string
if(json[0]!='{')
    return(0);
    
for(i=0;i<len;i++){
    //printf("Processing: %d %c startn: %d endn: %d startv %d endv %d \n",i,json[i],startn,endn,startv,endv);
    if(json[i]=='{' && startj==0){
        startj=1;
        continue;
    }
    if(json[i]=='}' && startj>0 && startn==0 && startv==0){
        endj=i;
        break;
    }
    if(json[i]=='"' && json[i-1]!='\\' &&  startn==0){
        startn=i;
        endn=0;
        continue;
    }
    if(json[i]=='"' && startn>0 && json[i-1]!='\\' && endn==0){
        endn=i;
        fieldlength=endn-startn-1;
        if(fieldlength>511) fieldlength=511;
        strncpy(fieldname,&json[startn+1],fieldlength);
        fieldname[fieldlength]=0;
        //printf("fieldname: %s\n",fieldname);
        startv=0;
        endv=0;
        continue;
    }
    if(json[i]==':'&& endn>0 && startn>0 && startv==0 && endv==0)
        continue;
    if(json[i]=='"' && json[i-1]!='\\' &&  startv==0){
        startv=i;
        endv=0;
        continue;
    }
    if(json[i]=='"' && startv>0 && json[i-1]!='\\' && endv==0 & endn>0 && startn>0){
        endv=i;
        fieldlength=endv-startv-1;
        if(fieldlength>16384) fieldlength=16384;
        strncpy(fieldvalue,&json[startv+1],fieldlength);
        fieldvalue[fieldlength]=0;
        //printf("fieldvalue: %s\n",fieldvalue,startv,endv);
        if(strcmp(fieldname,name)==0){
            if(strlen(fieldvalue)>maxlen) fieldvalue[maxlen-2]=0;
            bb_json_remove_escapes(fieldvalue);
            strcpy(destination,fieldvalue);
            return(strlen(fieldvalue));
        }
        continue;
    }
    if(json[i]==',' && startn>0 && endn>0 && startv>0 && endv>0){
        startn=0;
        endn=0;
        startv=0;
        endv=0;
        continue;
    }
}
return(0);

}
int bb_json_remove_escapes(char * v){
 if(strlen(v)==0)
     return(0);
 char s[16];
 sprintf(s,"%c%c",0x5C,0x27);
 char * const buf1=bb_str_replace(v,s,"\'");
 sprintf(s,"%c%c",0x5C,0x22);
 char * const buf2=bb_str_replace(v,s,"\"");
 int i;
 i=strlen(v);
 strncpy(v,buf2,i);
 free(buf1);
 free(buf2);
 return(strlen(v));
}
/**
* FUNCTION TO REMOVE FIELD FROM A JSON STRING\n
* IT UPDATES THE ORIGINAL JSON
*/
int bb_json_removefield(char *json,char *fieldname){
    char *buf=NULL;
    char *buf1=NULL;
    char fieldnames[512];
    int x,i,pos,ca,cp,lastpos;
    x=strlen(json);
    if(x==0){
        fprintf(stderr,"8400 - bb_json_removefield.c: json cannot be 0 length");
        return(0);
    }
    if(strlen(fieldname)>500)
    {
        fprintf(stderr,"8401 - bb_json_removefield.c: fieldname is too long");
        return(0);
    }
    buf1=bb_str_replace(json,"\" : \"","\":\"");
    strcpy(json,buf1);
    free(buf1);
    buf1=bb_str_replace(json,"\" :\"","\":\"");
    strcpy(json,buf1);
    free(buf1);
    buf1=bb_str_replace(json,"\": \"","\":\"");
    strcpy(json,buf1);
    free(buf1);
    sprintf(fieldnames,"\"%s\":",fieldname);
    if(strstr(json,fieldnames)==NULL){
        //fprintf(stderr,"8402 - bb_json_removefield.c: fieldname not found");
        return(0);
    }
    buf=malloc(x+1);
    if(buf==NULL){
        return(0);
    }

    strcpy(buf,json);
    pos=strstr(json,fieldnames)-json-1;
    ca=0;
    cp=0;
    lastpos=pos;
    for(i=pos;i<x;i++){
        if(json[i]=='"' && json[i-1]!='\\')
            ca++;
        if(json[i]==':' && json[i-1]=='"' && json[i+1]=='"')
            cp++;
        if(ca>=4 && cp>0){
            lastpos=i;
            break;
        }
    }
    if(pos>0 && json[pos-1]==',')
        pos=pos-1;
    memset(json,0x0,x);
    strncpy(json,buf,pos);
    strcat(json,&buf[lastpos+1]);
    free(buf);
    return(1);
        
}
/**
* ESCAPE A STRING FOR JSON STRING
*/
int bb_json_escapestr(char *json,char *jsonescaped,int maxlen){
    int jsonlen,buflen,i,j;
    jsonlen=strlen(json);
    if(jsonlen>maxlen){
        fprintf(stderr,"23902 - destination is smaller of origin");
        return(0);
    }
    memset(jsonescaped,0x0,maxlen);
    for(i=0;i<jsonlen;i++){
        if(json[i]=='\n'){
            strncat(jsonescaped,"\\n",3);
            continue;
        }
        if(json[i]=='\r'){
            strncat(jsonescaped,"\\r",3);
            continue;
        }
        if(json[i]=='\f'){
            strncat(jsonescaped,"\\f",3);
            continue;
        }
        if(json[i]=='\b'){
            strncat(jsonescaped,"\\b",3);
            continue;
        }
        if(json[i]=='\t'){
            strncat(jsonescaped,"\\t",3);
            continue;
        }
        if(json[i]=='"'){
            strncat(jsonescaped,"\\\"",3);
            continue;
        }
        strncat(jsonescaped,&json[i],1);
    }
   return(strlen(jsonescaped));
}
//#include "bb_str_replace.c"
//*** ORIGIN: ../blackbox-server/bb_json.c
//#include "blackbox.h"

/*EXAMPLE TOTP
void main(void){
uint32_t totp=0;
uint8_t key[64]={"GEZDQ43HG4ZTEYTTHAZW4MRZHB3TGYTKONUGU4Y=\0"};
uint64_t tm;
tm=floor(time(NULL) / 30);
totp=bbtotp(key);
printf("TOTP=%u\n",totp);
printf("Check=%d\n",bbtotpcheck(key,totp));
}*/
/**
* GET TOTP ON CURRENT UTC SYSTEM TIME
*/
uint32_t bbtotp(uint8_t *key)
{
    int digits=10;
    time_t tm;
    tm=floor(time(NULL) / 30);
    size_t kl;
    kl=strlen(key);
    if(kl>64) kl=64;
    uint32_t totp;
    totp = bbhotp(key, kl, tm, digits);
    return totp;
}
/**
* CHECK TOTP VALIDITY +-60 SECONDS AND CURRENT TIME
*/
uint32_t bbtotpcheck(uint8_t *key,uint32_t totpc)
{
    int digits=10;
    time_t tm;
    size_t kl;
    uint32_t totp;
    kl=strlen(key);
    if(kl>64) kl=64;
    tm=floor(time(NULL) / 30);
    totp = bbhotp(key, kl, tm, digits);
    if(totp==totpc)
        return(1);
    tm=floor((time(NULL)-29) / 30);
    totp = bbhotp(key, kl, tm, digits);
    if(totp==totpc)
        return(1);
    tm=floor((time(NULL)+29) / 30);
    totp = bbhotp(key, kl, tm, digits);
    if(totp==totpc)
        return(1);
    tm=floor((time(NULL)-59) / 30);
    totp = bbhotp(key, kl, tm, digits);
    if(totp==totpc)
        return(1);
    tm=floor((time(NULL)+59) / 30);
    totp = bbhotp(key, kl, tm, digits);
    if(totp==totpc)
        return(1);
    return(0);
}
//*****************************************************
uint8_t *bbhmac(unsigned char *key, int kl, uint64_t interval)
{

    return (uint8_t *)HMAC(EVP_sha512(), key, kl,
            (const unsigned char *)&interval, sizeof(interval), NULL, 0);
}

uint32_t bbdt(uint8_t *digest)
{

    uint64_t offset;
    uint32_t bin_code;
    // dynamically truncates hash
    offset   = digest[19] & 0x0f;
    bin_code = (digest[offset]  & 0x7f) << 24
        | (digest[offset+1] & 0xff) << 16
        | (digest[offset+2] & 0xff) <<  8
        | (digest[offset+3] & 0xff);
    return bin_code;
}


uint32_t mod_hotp(uint32_t bin_code, int digits)
{
    int power = pow(10, digits);
    uint32_t otp = bin_code % power;
    return otp;
}

uint32_t bbhotp(uint8_t *key, size_t kl, uint64_t interval, int digits)
{

    uint8_t *digest;
    uint32_t result;
    uint32_t endianness;
    endianness = 0xdeadbeef;
    if ((*(const uint8_t *)&endianness) == 0xef) {
        interval = ((interval & 0x00000000ffffffff) << 32) | ((interval & 0xffffffff00000000) >> 32);
        interval = ((interval & 0x0000ffff0000ffff) << 16) | ((interval & 0xffff0000ffff0000) >> 16);
        interval = ((interval & 0x00ff00ff00ff00ff) <<  8) | ((interval & 0xff00ff00ff00ff00) >>  8);
    };
    //First Phase, get the digest of the message using the provided key ...
    digest = (uint8_t *)bbhmac(key, kl, interval);
    //digest = (uint8_t *)HMAC(EVP_sha1(), key, kl, (const unsigned char *)&interval, sizeof(interval), NULL, 0);
    //Second Phase, get the dbc from the algorithm
    uint32_t dbc = bbdt(digest);
    //Third Phase: calculate the mod_k of the dbc to get the correct number
    result = mod_hotp(dbc, digits);
    return result;

}

//*** ORIGIN: ../blackbox-server/bb_totp.c
/*#include "blackbox.h"
void main(void){

unsigned char hash[1024];
char sign[1024];
char publickeypem[8192];
char privatekeypem[8192];
int signlen;
int hashlen;
int r=0;
sprintf(hash,"db965b623437c6c433646f434f01aa8dca8edb0401413a2c093d8ff33391309fa29bc89dfb8cdf3de655e7c6590fc06640305b35abc98935aedb96eb39a86c88");
hashlen=strlen(hash);
//strcpy(publickeypem,"-----BEGIN PUBLIC KEY-----\nMIGnMBAGByqGSM49AgEGBSuBBAAnA4GSAAQAtr6IJHVBQ7wkkZlk0m478XhFx9zO\nzPnsaPBBDe3Ulz4/LiIo+KikLMSiRAu9MgsJitm+e3UGWJv8qF4AUsXH9vuMoUZm\ndcwADnSsWI9U24gtCQXjRxLSYUeO1W02CUjCZLQ7fh9138pdFWHi5RTMq5mPP22/\nGV0rO+9gHPgKs0HgP70HBQFnJvLCuSt6S1g=\n-----END PUBLIC KEY-----\n");
//strcpy(privatekeypem,"-----BEGIN EC PRIVATE KEY-----\nMIHuAgEBBEgBuTKo4+sKAEIU5YX9dkAqXt4omjgyLXSMaPxLndYrSPxVPlAzCBI7\nmhvzsQ6jBLidWU3ETCuY2m5DEJ/IngJtdVRuAbstqZWgBwYFK4EEACehgZUDgZIA\nBAC2vogkdUFDvCSRmWTSbjvxeEXH3M7M+exo8EEN7dSXPj8uIij4qKQsxKJEC70y\nCwmK2b57dQZYm/yoXgBSxcf2+4yhRmZ1zAAOdKxYj1TbiC0JBeNHEtJhR47VbTYJ\nSMJktDt+H3Xfyl0VYeLlFMyrmY8/bb8ZXSs772Ac+AqzQeA/vQcFAWcm8sK5K3pL\nWA==\n-----END EC PRIVATE KEY-----\n");
int f;
f=open("sample-cert.pem",O_RDONLY);
read(f,publickeypem,8192);
close(f);

f=open("sample-key.pem",O_RDONLY);
read(f,privatekeypem,8192);
close(f);
if(!bb_sign_ec(hash,hashlen,sign,&signlen,privatekeypem)){
    printf("Error making signature\n");
}else{
    printf("Sign: %s\n",sign);
}
//r=bb_verify_ec(hash,hashlen,sign,publickeypem);
//printf("Signature verification: %d\n",r);
printf("pk=%s\n",publickeypem);
r=bb_verify_ec_certificate(hash,hashlen,sign,publickeypem);
printf("Signature verification: %d\n",r);

}*/


/**
* FUNCTION TO SIGN AN HASH RECEIVING THE PRIVATE KEY IN PEM FORMAT
* RETURN A SIGNATURE IN BASE64 FROM DER FORMAT
*/
int bb_sign_ec(unsigned char *hash,int hashlen,char * sign, int *signlen,char * privatekeypem)
{
        BIO *biop=NULL;
        EC_KEY *key=NULL;
        EVP_PKEY *pkp = NULL;
        unsigned char signder[1024];
        int len;
        int signderlen;
        char error[128]={""};
        //CREATE EC STRUCTURE FROM privatekeypem
    biop = BIO_new(BIO_s_mem());
        if(biop==NULL){
            strcpy(error,"320 - Error creating BIO object for privatekeypem\n");
            goto CLEANUP;
        }
        len = BIO_puts(biop, privatekeypem);
        if(len<=0){
            strcpy(error,"321 - Error writing BIO object for privatekeypem\n");
            goto CLEANUP;
        }
        if(verbose) printf("bb_sign_verify_ec.c: len= %d\n",len);
        PEM_read_bio_PrivateKey(biop, &pkp, NULL, NULL);
        if(pkp==NULL){
            strcpy(error,"322 - Error loading private key privatekeypem from EC bio\n");
            goto CLEANUP;
        }
        key = EVP_PKEY_get1_EC_KEY(pkp);
    if(key==NULL){
            strcpy(error,"323 - Error converting private key privatekeypem to EC structure\n");
            goto CLEANUP;
        }
        // SIGN
        signderlen=0;
        memset(signder,0x0,1024);
        if (!ECDSA_sign(0, hash, hashlen, signder, &signderlen, key)){
            strcpy(error,"324 - Error making ECDSA signature\n");
            goto CLEANUP;
        }
        if(verbose) printf("hash: %s\nhashlen: %d\n",hash,hashlen);
        if(verbose) printf("signderlen: %d\n",signderlen);
        *signlen=bb_encode_base64(signder,signderlen,sign);
        if (verbose) printf("signlen: %d\n",*signlen);
        if(*signlen<=0){
            strcpy(error,"325 - error converting signature in base64\n");
            goto CLEANUP;
        }
        if(key!=NULL) EC_KEY_free(key);
        if(biop!=NULL) BIO_free(biop);
    if(pkp!=NULL) EVP_PKEY_free(pkp);
        return(1);
        
        CLEANUP:
        fprintf(stderr,"%s\n",error);
        if(key!=NULL) EC_KEY_free(key);
        if(biop!=NULL) BIO_free(biop);
        if(pkp!=NULL) EVP_PKEY_free(pkp);
        return(0);

}
/**
* FUNCTION TO VERIFY A SIGN OF AN HASH RECEIVING THE PUBLICK PEM FORMAT
* RETURN 1 for signature NOT valid, 2 for valid, -1 for error verifyin
*/
int bb_verify_ec(unsigned char *hash,int hashlen,char * sign,char * publickeypem)
{
        BIO *biop=NULL;
        EC_KEY *key=NULL;
        EVP_PKEY *pkp = NULL;
        unsigned char signder[1024];
        int len;
        int r=0;
        int signderlen;
        char error[128]={""};
        //CREATE EC STRUCTURE FROM publickeypem
    biop = BIO_new(BIO_s_mem());
        if(biop==NULL){
            strcpy(error,"326 - Error creating BIO object for publickeypem\n");
            goto CLEANUP;
        }
        len = BIO_puts(biop, publickeypem);
        if(verbose) printf("bb_sign_verify_ec.c: len= %d\n",len);
        if(len<=0){
            strcpy(error,"327 - Error writing BIO object for publickeypem\n");
            goto CLEANUP;
        }
        PEM_read_bio_PUBKEY(biop, &pkp, NULL, NULL);
        if(pkp==NULL){
            strcpy(error,"328 - Error loading public key publickeypem from EC bio\n");
            goto CLEANUP;
        }
        key = EVP_PKEY_get1_EC_KEY(pkp);
    if(key==NULL){
            strcpy(error,"329 - Error converting publickeypem to EC structure\n");
            goto CLEANUP;
        }
        signderlen=bb_decode_base64(sign,signder);
        // VERIFY SIGN
        if(verbose) printf("hash: %s\nhashlen: %d\n",hash,hashlen);
        if(verbose) printf("signderlen: %d\n",signderlen);
        r=ECDSA_verify(0, hash, hashlen, signder, signderlen, key);
        if (r==-1){
            strcpy(error,"330 - Error verifying  ECDSA signature\n");
            goto CLEANUP;
        }
        printf("r: %d\n",r);
        if(key!=NULL) EC_KEY_free(key);
        if(biop!=NULL) BIO_free(biop);
    if(pkp!=NULL) EVP_PKEY_free(pkp);
        return(r+1);
        
        CLEANUP:
        fprintf(stderr,"%s\n",error);
        if(key!=NULL) EC_KEY_free(key);
        if(biop!=NULL) BIO_free(biop);
        if(pkp!=NULL) EVP_PKEY_free(pkp);
        return(0);

}
/**
* FUNCTION TO VERIFY A SIGN OF AN HASH RECEIVING A CERTIFICATE PEM FORMAT
* RETURN 1 for signature NOT valid, 2 for valid, -1 for error verifying
*/
int bb_verify_ec_certificate(unsigned char *hash,int hashlen,char * sign,char * certificatepem)
{
        BIO *biop=NULL;
        EC_KEY *key=NULL;
        EVP_PKEY *pkp = NULL;
        X509 *cert = NULL;
        unsigned char signder[1024];
        int len;
        int r=0;
        int signderlen;
        char error[128]={""};
        //CREATE EC STRUCTURE FROM publickeypem
    biop = BIO_new(BIO_s_mem());
        if(biop==NULL){
            strcpy(error,"356 - Error creating BIO object for certificatepem\n");
            goto CLEANUP;
        }
        len = BIO_puts(biop, certificatepem);
        if(len<=0){
            strcpy(error,"357 - Error writing BIO object for certificatepem\n");
            goto CLEANUP;
        }
        cert = PEM_read_bio_X509(biop, NULL, 0, NULL);
        if(cert ==NULL) {
            strcpy(error,"358 - Error loading certificate\n");
            goto CLEANUP;
        }
        if ((pkp = X509_get_pubkey(cert)) == NULL){
            strcpy(error,"359 - Error loading public key\n");
            goto CLEANUP;
        }
        key = EVP_PKEY_get1_EC_KEY(pkp);
    if(key==NULL){
            strcpy(error,"360 - Error converting publickeypem to EC structure\n");
            goto CLEANUP;
        }
        signderlen=bb_decode_base64(sign,signder);
        // VERIFY SIGN
        if(verbose) printf("hash: %s\nhashlen: %d\n",hash,hashlen);
        if(verbose) printf("signderlen: %d\n",signderlen);
        r=ECDSA_verify(0, hash, hashlen, signder, signderlen, key);
        if (r==-1){
            strcpy(error,"361 - Error verifying  ECDSA signature\n");
            goto CLEANUP;
        }
        if(key!=NULL) EC_KEY_free(key);
        if(biop!=NULL) BIO_free(biop);
    if(pkp!=NULL) EVP_PKEY_free(pkp);
    X509_free(cert);
        return(r+1);
        
        CLEANUP:
        fprintf(stderr,"%s\n",error);
        if(key!=NULL) EC_KEY_free(key);
        if(biop!=NULL) BIO_free(biop);
        if(pkp!=NULL) EVP_PKEY_free(pkp);
        if(cert!=NULL) X509_free(cert);
        return(0);

}

//#include "bb_encode_decode_base64.c"

//*** ORIGIN: ../blackbox-server/bb_sign_verify_ec.c
/*#include "blackbox.h"
                
void main(void)
{
unsigned char buffer[512];
unsigned char *decrypted;
char publickeypem[8192];
char certificatepem[8192];
char privatekeypem[8192];
char encryptedjson[8192];
int buffer_len,x;
int f;
sprintf(buffer,"Test encryption using Eliptic curve sect521r1, converted in json structure");
buffer_len=strlen(buffer);

//strcpy(publickeypem,"-----BEGIN PUBLIC KEY-----\nMIGnMBAGByqGSM49AgEGBSuBBAAnA4GSAAQAtr6IJHVBQ7wkkZlk0m478XhFx9zO\nzPnsaPBBDe3Ulz4/LiIo+KikLMSiRAu9MgsJitm+e3UGWJv8qF4AUsXH9vuMoUZm\ndcwADnSsWI9U24gtCQXjRxLSYUeO1W02CUjCZLQ7fh9138pdFWHi5RTMq5mPP22/\nGV0rO+9gHPgKs0HgP70HBQFnJvLCuSt6S1g=\n-----END PUBLIC KEY-----\n");
//strcpy(privatekeypem,"-----BEGIN EC PRIVATE KEY-----\nMIHuAgEBBEgBuTKo4+sKAEIU5YX9dkAqXt4omjgyLXSMaPxLndYrSPxVPlAzCBI7\nmhvzsQ6jBLidWU3ETCuY2m5DEJ/IngJtdVRuAbstqZWgBwYFK4EEACehgZUDgZIA\nBAC2vogkdUFDvCSRmWTSbjvxeEXH3M7M+exo8EEN7dSXPj8uIij4qKQsxKJEC70y\nCwmK2b57dQZYm/yoXgBSxcf2+4yhRmZ1zAAOdKxYj1TbiC0JBeNHEtJhR47VbTYJ\nSMJktDt+H3Xfyl0VYeLlFMyrmY8/bb8ZXSs772Ac+AqzQeA/vQcFAWcm8sK5K3pL\nWA==\n-----END EC PRIVATE KEY-----\n");
f=open("sample-cert.pem",O_RDWR);
x=read(f,certificatepem,8191);
close(f);
certificatepem[x]=0;
f=open("sample-publickey.pem",O_RDWR);
x=read(f,publickeypem,8191);
close(f);
publickeypem[x]=0;
f=open("sample-privatekey.pem",O_RDWR);
x=read(f,privatekeypem,8191);
close(f);
privatekeypem[x]=0;

printf("Certificate: %s\nPublic key: %s\nPrivate key: %s\n",certificatepem,publickeypem,privatekeypem);

verbose=0;
bb_encrypt_buffer_ec(buffer,buffer_len,certificatepem,encryptedjson);
printf("DEBUG: %s\nlen:%d\n",encryptedjson,strlen(encryptedjson));
memset(buffer,0x0,512);
buffer_len=0;
decrypted=bb_decrypt_buffer_ec(decrypted,&buffer_len,privatekeypem,encryptedjson);
decrypted[buffer_len]=0;
printf("DEBUG: Decrypted buffer:%s\n len:%d\n",decrypted,buffer_len);
exit;

}*/
/**
* DECRYPT BUFFER USING ELIPTIC CURVE \n
* allocates the spaces required for buffer and write the size in buffer_len\n
* you MUST free(buffer) when possible
*/
char * bb_decrypt_buffer_ec(int *buffer_len,char * privatekeypem,char *encryptedjson){
   unsigned char secretkey[128];
   char error[128]={""};
   char tagaesb64[32];
   char ivaesb64[32];
   char ivcamelliab64[32];
   char ivchachab64[32];
   char secretkeyb64[512];
   char peerkeypem[512]={""};
   char peerkeypemb64[512]={""};
   unsigned char keyaes[64];
   unsigned char keycamellia[64];
   unsigned char keychacha[64];
   char keyaesb64[64];
   char keycamelliab64[64];
   char keychachab64[64];
   char jsonkey[512];
   int x,encrypted_len;
   char *encrypted=NULL;
   char *encryptedb64=NULL;
   char *buffer=NULL;
   if(!bb_json_getvalue("ephemeralpublickey",encryptedjson,peerkeypemb64,512)){
      strcpy(error,"300 - Error reading ephemeralpublickey from json structure");
      //printf("encryptejson: %s\n",encryptedjson);
      buffer=malloc(64);
      buffer[0]=0;
      *buffer_len=0;
      return(buffer);
   }
   bb_decode_base64(peerkeypemb64,peerkeypem);
   if(!bb_ecdhe_compute_secretkey_receiver(peerkeypem,secretkey,privatekeypem)){
      strcpy(error,"301 - Error computing secret key");
      goto CLEANUP;
   }
   bb_encode_base64(secretkey,96,secretkeyb64);
   if(verbose) printf("Secret key: %s\n",secretkeyb64);

   if(!bb_json_getvalue("ivaes",encryptedjson,ivaesb64,32)){
      strcpy(error,"302 - Error reading ivaes from json structure");
      goto CLEANUP;
   }
   if(!bb_json_getvalue("tagaes",encryptedjson,tagaesb64,32)){
      strcpy(error,"303 - Error reading tagaes from json structure");
      goto CLEANUP;
   }
   if(!bb_json_getvalue("ivcamellia",encryptedjson,ivcamelliab64,32)){
      strcpy(error,"304 - Error reading ivcamellia from json structure");
      goto CLEANUP;
   }
   if(!bb_json_getvalue("ivchacha",encryptedjson,ivchachab64,32)){
      strcpy(error,"305 - Error reading ivchacha from json structure");
      goto CLEANUP;
   }
   memcpy(keyaes,&secretkey[0],32);
   memcpy(keycamellia,&secretkey[32],32);
   memcpy(keychacha,&secretkey[64],32);
  //* GENERATING KEY IN BASE64 +JSON
  if(!bb_encode_base64(keyaes,32,keyaesb64)){
    strcpy(error,"306 - Error encoding in base64 keyaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keycamellia,32,keycamelliab64)){
    strcpy(error,"307 - Error encoding in base64 keycamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keychacha,32,keychachab64)){
    strcpy(error,"308 - Error encoding in base64 keychacha");
    goto CLEANUP;
  }
  sprintf(jsonkey,"{\"keyaes\":\"%s\",\"ivaes\":\"%s\",\"tagaes\":\"%s\",\"keycamellia\":\"%s\",\"ivcamellia\":\"%s\",\"keychacha\":\"%s\",\"ivchacha\":\"%s\"}",keyaesb64,ivaesb64,tagaesb64,keycamelliab64,ivcamelliab64,keychachab64,ivchachab64);
  //printf("Decryption jsonkey: %s\n",jsonkey);
  //*** decrypt the buffer
  x=strlen(encryptedjson);
  buffer=malloc(x);
  encrypted=malloc(x);
  encryptedb64=malloc(x);
  if(!bb_json_getvalue("encrypted",encryptedjson,encryptedb64,strlen(encryptedjson))){
      strcpy(error,"309 - Error reading encrypted from json structure");
      goto CLEANUP;
   }
  encrypted_len=bb_decode_base64(encryptedb64,encrypted);
  if(!bb_decrypt_buffer(buffer,buffer_len,encrypted,encrypted_len,jsonkey)){
      strcpy(error,"310 - Error decrypting");
      goto CLEANUP;
  }
  if(encrypted!=NULL) free(encrypted);
  if(encryptedb64!=NULL) free(encryptedb64);
  memset(keyaes,0x0,64);
  memset(keycamellia,0x0,64);
  memset(keychacha,0x0,64);
  memset(keyaesb64,0x0,64);
  memset(keycamelliab64,0x0,64);
  memset(keychachab64,0x0,64);
  memset(ivaesb64,0x0,32);
  memset(ivcamelliab64,0x0,32);
  memset(ivchachab64,0x0,32);
  memset(secretkeyb64,0x0,512);
  memset(peerkeypem,0x0,512);
  memset(peerkeypemb64,0x0,512);
  memset(jsonkey,0x0,512);
  memset(tagaesb64,0x0,32);
  memset(error,0x0,128);
  x=0;
  encrypted_len=0;
  return(buffer);
   
  CLEANUP:
  fprintf(stderr,"%s\n",error);
  if(encrypted!=NULL) free(encrypted);
  if(encryptedb64!=NULL) free(encryptedb64);
  memset(keyaes,0x0,64);
  memset(keycamellia,0x0,64);
  memset(keychacha,0x0,64);
  memset(keyaesb64,0x0,64);
  memset(keycamelliab64,0x0,64);
  memset(keychachab64,0x0,64);
  memset(ivaesb64,0x0,32);
  memset(ivcamelliab64,0x0,32);
  memset(ivchachab64,0x0,32);
  memset(secretkeyb64,0x0,512);
  memset(peerkeypem,0x0,512);
  memset(peerkeypemb64,0x0,512);
  memset(jsonkey,0x0,512);
  memset(tagaesb64,0x0,32);
  memset(error,0x0,128);
  x=0;
  encrypted_len=0;
  return(NULL);

}

/**
* ENCRYPT BUFFER USING ELIPTIC CURVE \n
* WRITE IN encrypted A JSON STRUCTURE WITH FIELDS ENCODED IN BASE64\n
* encrypted must have enough space allocated, 1024 bytes of overhead \n
* + 50% increase of the buffer for the encoding should be allocated
*/
int bb_encrypt_buffer_ec(unsigned char *buffer,int buffer_len,char * peerpublickeypem,char *encryptedjson){
   unsigned char secretkey[128];
   char error[128]={""};
   char ephemeralpublickey[512]={""};
   char ephemeralpublickeyb64[1024]={""};
   char keyjson[512]={""};
   char * encrypted=NULL;
   char * encryptedb64=NULL;
   //char * peerpublickeypemb64=NULL;
   int encrypted_len=0;
   char tagaesb64[32];
   char ivaesb64[32];
   char ivcamelliab64[32];
   char ivchachab64[32];
   memset(secretkey,0x0,128);
   memset(ephemeralpublickey,0x0,512);
   memset(ephemeralpublickeyb64,0x0,1024);
   memset(error,0x0,128);
   memset(tagaesb64,0x0,32);
   memset(ivaesb64,0x0,32);
   memset(ivcamelliab64,0x0,32);
   memset(ivchachab64,0x0,32);
   //*** compute secret key with peer public key
   if(!bb_ecdhe_compute_secretkey_sender(peerpublickeypem,secretkey,ephemeralpublickey)){
        strcpy(error,"261 - Error computing secret key by ECDHE");
        goto CLEANUP;
   }
   // convert secretkey to json structure including IV and TAG
   if(!bb_symmetrickey_to_jsonkey(secretkey,keyjson)){
        strcpy(error,"262 - Error converting secret key in json");
        goto CLEANUP;
   }
   encrypted=malloc(buffer_len+32);
   if(encrypted==NULL){
         strcpy(error,"263 - Error allocating memory for encryption EC");
         goto CLEANUP;
   }
   if(verbose) printf("jsonkey: %s\n\n",keyjson);
   // symmetric encryption with 3 layers
   if(!bb_encrypt_buffer_setkey(buffer,buffer_len,encrypted,&encrypted_len,keyjson)){
         strcpy(error,"264 - Error in symmetric encryption of EC encryption");
         goto CLEANUP;
   }
   if(encrypted_len<=0){
         strcpy(error,"265 - Error in symmetric encryption of EC encryption");
         goto CLEANUP;
   }
   encryptedb64=malloc(encrypted_len*2);
   if(encryptedb64==NULL){
         strcpy(error,"266 - Error allocating memory for encryption EC");
         goto CLEANUP;
   }
   // convert encrypted buffer in base64
   if(!bb_encode_base64(encrypted,encrypted_len,encryptedb64)){
         strcpy(error,"267 - Error converting in base64 during EC encryption");
         goto CLEANUP;
   }
   //** build the json answer
   if(!bb_json_getvalue("ivaes",keyjson,ivaesb64,32)){
       strcpy(error,"268 - Error reading IV AES");
      goto CLEANUP;
   }
   if(!bb_json_getvalue("ivcamellia",keyjson,ivcamelliab64,32)){
       strcpy(error,"269 - Error reading IV CAMELLIA");
      goto CLEANUP;
   }
   if(!bb_json_getvalue("ivchacha",keyjson,ivchachab64,32)){
       strcpy(error,"269 - Error reading IV CHACHA");
      goto CLEANUP;
   }
   if(!bb_json_getvalue("tagaes",keyjson,tagaesb64,32)){
       strcpy(error,"271 - Error reading TAG AES");
      goto CLEANUP;
   }
   //printf("tagaes: %s\n",tagaesb64);
   //printf("keyjson: %s\n",keyjson);
   if(strlen(peerpublickeypem)>4096){
      strcpy(error,"270 - Peer public key too long");
      goto CLEANUP;
   }
   if(!bb_encode_base64(ephemeralpublickey,strlen(ephemeralpublickey),ephemeralpublickeyb64)){
         strcpy(error,"272 - Error converting in base64 during EC encryption");
         goto CLEANUP;
   }
   // write the json
   sprintf(encryptedjson,"{\"ephemeralpublickey\":\"%s\",\"ivaes\":\"%s\",\"ivcamellia\":\"%s\",\"ivchacha\":\"%s\",\"tagaes\":\"%s\",\"encrypted\":\"%s\"}",ephemeralpublickeyb64,ivaesb64,ivcamelliab64,ivchachab64,tagaesb64,encryptedb64);
   memset(secretkey,0x0,128);
   memset(ephemeralpublickey,0x0,512);
   memset(ephemeralpublickeyb64,0x0,1024);
   memset(error,0x0,128);
   memset(tagaesb64,0x0,32);
   memset(ivaesb64,0x0,32);
   memset(ivcamelliab64,0x0,32);
   memset(ivchachab64,0x0,32);
   if(encryptedb64!=NULL) memset(encryptedb64,0x0,encrypted_len*2);
   if(encrypted!=NULL) memset(encrypted,0x0,buffer_len+32);
   if(encrypted!=NULL) free(encrypted);
   if(encryptedb64!=NULL) free(encryptedb64);
   return(1);
   
   CLEANUP:
   memset(secretkey,0x0,128);
   memset(ephemeralpublickey,0x0,512);
   memset(ephemeralpublickeyb64,0x0,1024);
   memset(tagaesb64,0x0,32);
   memset(ivaesb64,0x0,32);
   memset(ivcamelliab64,0x0,32);
   memset(ivchachab64,0x0,32);
   if(encryptedb64!=NULL) memset(encryptedb64,0x0,encrypted_len*2);
   if(encrypted!=NULL) memset(encrypted,0x0,buffer_len+32);
   if(encrypted!=NULL) free(encrypted);
   if(encryptedb64!=NULL) free(encryptedb64);
   fprintf(stderr,"%s\n",error);
   memset(error,0x0,128);
   return(0);
}

/*#include "bb_encrypt_decrypt_buffer.c"
#include "bb_encrypt_decrypt_buffer_aes_gcm.c"
#include "bb_encrypt_decrypt_buffer_camellia_ofb.c"
#include "bb_encrypt_decrypt_buffer_chacha20.c"
#include "bb_crypto_randomdata.c"
#include "bb_encode_decode_base64.c"
#include "bb_sha.c"
#include "bb_json.c"
#include "bb_ecdhe_compute_secretkey.c"
*/
//*** ORIGIN: ../blackbox-server/bb_encrypt_decrypt_buffer_ec.c
/*#include "blackbox.h"
void main(void){
size_t secret_len;
char peerkeypem[4096];
char secretkey[4096];
char secretkeyb64[4096];
char ephemeralpublickey[4096];
char privatekeypem[4096];
int i;
strcpy(peerkeypem,"-----BEGIN PUBLIC KEY-----\nMIGnMBAGByqGSM49AgEGBSuBBAAnA4GSAAQEuFO3tGjIMbFbnQG22K8LP6PGsx0o\n1VnLWPe8lMZAo9KSNkfjMBCkI5e6RokdB9FB+7twH5sxfnj3xv5VIwRasuoudxSu\nkA8CAbm2pEntQi/g/vaVNBUrq9Zn/vIccBxNYb9nx6zp/PueGO7U5q6EbIzGqWzD\ngrw2BNwU05XpxMBGueMedzxTwMiQ43CgxxI=\n-----END PUBLIC KEY-----\n");
strcpy(peerkeypem,"-----BEGIN PUBLIC KEY-----\nMIGnMBAGByqGSM49AgEGBSuBBAAnA4GSAAQAtr6IJHVBQ7wkkZlk0m478XhFx9zO\nzPnsaPBBDe3Ulz4/LiIo+KikLMSiRAu9MgsJitm+e3UGWJv8qF4AUsXH9vuMoUZm\ndcwADnSsWI9U24gtCQXjRxLSYUeO1W02CUjCZLQ7fh9138pdFWHi5RTMq5mPP22/\nGV0rO+9gHPgKs0HgP70HBQFnJvLCuSt6S1g=\n-----END PUBLIC KEY-----\n");
strcpy(privatekeypem,"-----BEGIN EC PRIVATE KEY-----\nMIHuAgEBBEgBuTKo4+sKAEIU5YX9dkAqXt4omjgyLXSMaPxLndYrSPxVPlAzCBI7\nmhvzsQ6jBLidWU3ETCuY2m5DEJ/IngJtdVRuAbstqZWgBwYFK4EEACehgZUDgZIA\nBAC2vogkdUFDvCSRmWTSbjvxeEXH3M7M+exo8EEN7dSXPj8uIij4qKQsxKJEC70y\nCwmK2b57dQZYm/yoXgBSxcf2+4yhRmZ1zAAOdKxYj1TbiC0JBeNHEtJhR47VbTYJ\nSMJktDt+H3Xfyl0VYeLlFMyrmY8/bb8ZXSs772Ac+AqzQeA/vQcFAWcm8sK5K3pL\nWA==\n-----END EC PRIVATE KEY-----\n");
int f;
f=open("sample-cert.pem",O_RDONLY);
read(f,peerkeypem,8192);
close(f);
//f=open("sample-publickey.pem",O_RDONLY);
//read(f,peerkeypem,8192);
//close(f);
f=open("sample-privatekey.pem",O_RDONLY);
read(f,privatekeypem,8192);
close(f);


printf("peerkeypem: %s",peerkeypem);
ephemeralpublickey[0]=0;
if(!bb_ecdhe_compute_secretkey_sender(peerkeypem,secretkey,ephemeralpublickey))
    printf("Error getting secret\n");
else{
   printf("Ephemeral Public Key: %s\n",ephemeralpublickey);
   bb_encode_base64(secretkey,96,secretkeyb64);
   printf("Secretkey from Sender: %s\n",secretkeyb64);
}
if(!bb_ecdhe_compute_secretkey_receiver(ephemeralpublickey,secretkey,privatekeypem))
    printf("Error getting secret from receiver\n");
else{
   bb_encode_base64(secretkey,96,secretkeyb64);
   printf("Secretkey from Receiver: %s\n",secretkeyb64);
}
exit(0);
}*/
/**
* DERIVE SECRET KEY FROM PEER PUBLIC KEY OR A CERTIFICATE AND THE SENDER PRIVATE KEY\n
* WRITE SECRET KEY  768 bits (96 unsigned chars)
*/
int bb_ecdhe_compute_secretkey_receiver(char *peerkeypem,unsigned char *secretkey,char * privatekeypem)
{
    BIO *biop=NULL;
    BIO *bio=NULL;
    EC_KEY *key=NULL;
    EC_KEY *peerkey=NULL;
    EVP_PKEY *pk = NULL;
    EVP_PKEY *pkp = NULL;
    X509 *cert = NULL;
    int len;
    char error[128]={""};
    int field_size;
        size_t secret_len;
        unsigned char *secret=NULL;
    //CREATE EC STRUCTURE FROM peerkeypem
    bio = BIO_new(BIO_s_mem());
        if(bio==NULL){
            strcpy(error,"290 - Error creating BIO object for peerkeypem\n");
            goto CLEANUP;
        }
        len = BIO_puts(bio, peerkeypem);
        if(len<=0){
            strcpy(error,"291 - Error writing BIO object for peerkeypem\n");
            goto CLEANUP;
        }
        if(strstr(peerkeypem,"-----BEGIN CERTIFICATE-----")!=NULL){
            cert = PEM_read_bio_X509(biop, NULL, 0, NULL);
            if(cert ==NULL) {
                strcpy(error,"358 - Error loading certificate\n");
                   goto CLEANUP;
               }
            if ((pk = X509_get_pubkey(cert)) == NULL){
                strcpy(error,"359 - Error loading public key\n");
                goto CLEANUP;
            }
        }
        else{
            PEM_read_bio_PUBKEY(bio, &pk, NULL, NULL);
            if(pk==NULL){
                strcpy(error,"292 - Error loading public key peerkeypem from EC bio\n");
                goto CLEANUP;
            }
    }
        peerkey = EVP_PKEY_get1_EC_KEY(pk);
    if(peerkey==NULL){
            strcpy(error,"293 - Error converting public key peerkeypem to EC structure\n");
            goto CLEANUP;
        }
        //CREATE EC STRUCTURE FROM privatekeypem
    biop = BIO_new(BIO_s_mem());
        if(biop==NULL){
            strcpy(error,"294 - Error creating BIO object for privatekeypem\n");
            goto CLEANUP;
        }
        len = BIO_puts(biop, privatekeypem);
        if(len<=0){
            strcpy(error,"295 - Error writing BIO object for privatekeypem\n");
            goto CLEANUP;
        }
        PEM_read_bio_PrivateKey(biop, &pkp, NULL, NULL);
        if(pkp==NULL){
            strcpy(error,"296 - Error loading private key privatekeypem from EC bio\n");
            goto CLEANUP;
        }
        key = EVP_PKEY_get1_EC_KEY(pkp);
    if(key==NULL){
            strcpy(error,"297 - Error converting private key privatekeypem to EC structure\n");
            goto CLEANUP;
        }
    field_size = EC_GROUP_get_degree(EC_KEY_get0_group(peerkey));
    secret_len = (field_size+7)/8;
    //if (verbose) printf("Field size: %d Secret len: %zu\n",field_size,secret_len);
    /* Allocate the memory for the shared secret */
    if(NULL == (secret = OPENSSL_malloc(secret_len*2))){
        strcpy(error,"298 - Error allocating memory for secret key\n");
            goto CLEANUP;
    }
    if(verbose) printf("key memory space allocated\n");
    /* Derive the shared secret */
    secret_len = ECDH_compute_key(secret, secret_len, EC_KEY_get0_public_key(peerkey),key, NULL);
    //if(verbose) printf("Secret key derived [%d]\n",secret_len);
    if(secret_len<=0){
            OPENSSL_free(secret);
        strcpy(error,"299 - Error deriving the secret key\n");
            goto CLEANUP;
    }
    //** RETURN THE SECRETKEY VALUE AND LENGHT
    bb_sha3_512(secret,secret_len,secretkey);
    bb_sha2_256(secret,secret_len,&secretkey[64]);
    //hexDump("Secretkey",secretkey,96);
    OPENSSL_free(secret);
    if(key!=NULL) EC_KEY_free(key);
    if(peerkey!=NULL) EC_KEY_free(peerkey);
    if(pk!=NULL) EVP_PKEY_free(pk);
    if(pkp!=NULL) EVP_PKEY_free(pkp);
    if(bio!=NULL) BIO_free(bio);
    if(biop!=NULL) BIO_free(biop);
    if(cert!=NULL) X509_free(cert);
    return(1);
    /* Clean up */
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    if(key!=NULL) EC_KEY_free(key);
    if(peerkey!=NULL) EC_KEY_free(peerkey);
    if(pk!=NULL) EVP_PKEY_free(pk);
    if(pkp!=NULL) EVP_PKEY_free(pkp);
    if(bio!=NULL) BIO_free(bio);
    if(biop!=NULL) BIO_free(biop);
    if(cert!=NULL) X509_free(cert);
    return(0);
}

/**
* DERIVE SECRET KEY FROM PEER PUBLIC KEY (or a CERTIFICATE)\n
* WRITE SECRET KEY  768 bits (96 unsigned chars)\n
* WRITE ephemeralpublickey (284 chars)
*/
int bb_ecdhe_compute_secretkey_sender(char *peerkeypem,unsigned char *secretkey,char * ephemeralpublickey)
{
    EC_KEY *key=NULL;
    EC_KEY *peerkey=NULL;
    EVP_PKEY *pk = NULL;
    BIO* bio=NULL;
    BIO *biopk=NULL;
    int field_size;
    X509 *cert = NULL;
    size_t secret_len;
    unsigned char *secret=NULL;
    char error[128]={""};
    char *bioptr;
    long biod;
    /* Create an Elliptic Curve Key object and set it up to use the Sect 521r1 curve */
    if(NULL == (key = EC_KEY_new_by_curve_name(NID_secp521r1))){
        strcpy(error,"160 - Error creating object with curve secp521r1\n");
        goto CLEANUP;
    }
    if(verbose) printf("Object Sect521r1 created\n");
    /* Generate the private and public key */
    if(1 != EC_KEY_generate_key(key)){
            strcpy(error,"161 - Error generating key EC curve secp521r1\n");
            goto CLEANUP;
    }
    if(verbose) printf("Key Generated Secp521r1\n");
    
    biopk = BIO_new(BIO_s_mem());
    PEM_write_bio_EC_PUBKEY(biopk, key);
    if(verbose) printf("write bio done\n");
    biod=BIO_get_mem_data(biopk,&bioptr);
    //if(verbose) printf("bio len: %ld\n",biod);
    //if(verbose) printf("bioptr: %s\n",bioptr);
    if(biod>0) memcpy(ephemeralpublickey,bioptr,284);
    //if(verbose) printf("Ephemeral public key: %s\n",ephemeralpublickey);
    

        bio = BIO_new(BIO_s_mem());
        if(bio==NULL){
            strcpy(error,"162 - Error creating BIO object\n");
            goto CLEANUP;
        }
        if(verbose) printf("Bio object created\n");
    int len = BIO_puts(bio, peerkeypem);
    if(len<=0){
            strcpy(error,"163 - Error writing BIO object\n");
            goto CLEANUP;
    }
    if(strstr(peerkeypem,"-----BEGIN CERTIFICATE-----")!=NULL){
                cert = PEM_read_bio_X509(bio, NULL, 0, NULL);
                if(cert ==NULL) {
                        strcpy(error,"164 - Error loading certificate\n");
                       goto CLEANUP;
                }
                if ((pk = X509_get_pubkey(cert)) == NULL){
                    strcpy(error,"164 - Error loading public key\n");
                    goto CLEANUP;
                }
        }
        else{
                PEM_read_bio_PUBKEY(bio, &pk, NULL, NULL);
                if(pk==NULL){
                    strcpy(error,"164 - Error loading public key peerkeypem from EC bio\n");
                    goto CLEANUP;
                }
        }
    if(verbose) printf(" bb_ecdhe_compute_secretkey.c echde -  pubkey loaded\n");
        peerkey = EVP_PKEY_get1_EC_KEY(pk);
        if(peerkey==NULL){
            strcpy(error,"165 - Error converting publc key to EC structure\n");
            goto CLEANUP;
        }
        if(verbose) printf(" bb_ecdhe_compute_secretkey.c Key converted to EC structure\n");
        //EC_KEY_set_asn1_flag(peerkey, OPENSSL_EC_NAMED_CURVE);
    /* Calculate the size of the buffer for the shared secret */
    field_size = EC_GROUP_get_degree(EC_KEY_get0_group(peerkey));
    secret_len = (field_size+7)/8;
    //if (verbose) printf(" bb_ecdhe_compute_secretkey.c Field size: %d Secret len: %zu\n",field_size,secret_len);
    /* Allocate the memory for the shared secret */
    if(NULL == (secret = OPENSSL_malloc(secret_len))){
        strcpy(error,"166 - Error allocating memory for secret key\n");
            goto CLEANUP;
    }
    if(verbose) printf("key memory space allocated\n");
    /* Derive the shared secret */
    secret_len = ECDH_compute_key(secret, secret_len, EC_KEY_get0_public_key(peerkey),key, NULL);
    if(verbose) printf("Secret key derived [%d]\n",secret_len);
    if(secret_len<=0){
            OPENSSL_free(secret);
        strcpy(error,"167 - Error deriving the secret key\n");
            goto CLEANUP;
    }
    //if(verbose) printf(" bb_ecdhe_compute_secretkey.c Field size: %d Secret len: %d\n",field_size,secret_len);
    //** RETURN THE SECRETKEY VALUE AND LENGHT
    bb_sha3_512(secret,secret_len,secretkey);
    bb_sha2_256(secret,secret_len,&secretkey[64]);
    OPENSSL_free(secret);
    if(key!=NULL) EC_KEY_free(key);
    if(peerkey!=NULL) EC_KEY_free(peerkey);
    if(bio!=NULL) BIO_free(bio);
    if(biopk!=NULL) BIO_free(biopk);
    if(cert!=NULL) X509_free(cert);
    if(pk!=NULL) EVP_PKEY_free(pk);
    return(1);
    /* Clean up */
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    if(key!=NULL) EC_KEY_free(key);
    if(peerkey!=NULL) EC_KEY_free(peerkey);
    if(bio!=NULL) BIO_free(bio);
    if(biopk!=NULL) BIO_free(biopk);
    if(cert!=NULL) X509_free(cert);
    if(pk!=NULL) EVP_PKEY_free(pk);
    return(0);
    
}
//#include "bb_sha.c"
//#include "bb_encode_decode_base64.c"

//*** ORIGIN: ../blackbox-server/bb_ecdhe_compute_secretkey.c
/*#include "blackbox.h"
                
void main(void)
{
char key[512];
key[0]=0;
if(bb_encrypt_file("test.txt","test.enc",key)==0)
    fprintf(stderr,"Encryption failed");
printf("key %s\n",key);
printf("key length %d\n",strlen(key));
if(bb_decrypt_file("test.enc","test.cop",key)==0)
    fprintf(stderr,"Encryption failed");
}*/
/**
* DECRYPT FILE WITH AES256+GCM,CAMELLIA+OFB,CHACHA20
*/
int bb_decrypt_file(const char * infile, const char * outfilefinal, char *key){
  unsigned char rd[128];
  char error[128]={""};
  unsigned char keyaes[64];
  unsigned char ivaes[32];
  unsigned char tagaes[64];
  char tmpfileaes[256];
  unsigned char keycamellia[64];
  unsigned char ivcamellia[32];
  char tmpfilecamellia[256];
  unsigned char keychacha[64];
  unsigned char ivchacha[32];
  unsigned char keyaesb64[128];
  unsigned char ivaesb64[64];
  unsigned char tagaesb64[64];
  unsigned char keycamelliab64[128];
  unsigned char ivcamelliab64[64];
  unsigned char keychachab64[128];
  unsigned char ivchachab64[64];
  char outfile[512];
  int i,x;
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<256;i++) tmpfileaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<256;i++) tmpfilecamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<64;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  if(strlen(outfilefinal)>256){
    strcpy(error,"117 - Destination name is too long max 256 chars");
    goto CLEANUP;
  }
    strcpy(outfile,outfilefinal);
    strcat(outfile,".tmp");
  //** LOAD KEYS IV AND TAG(AES+GCM)
  if(!bb_json_getvalue("keyaes",key,keyaesb64,64)){
     strcpy(error,"127 - Error reading key AES");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivaes",key,ivaesb64,32)){
     strcpy(error,"128 - Error reading IV AES");
     goto CLEANUP;
  }
 if(!bb_json_getvalue("tagaes",key,tagaesb64,32)){
     strcpy(error,"129 - Error reading TAG AES");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("keycamellia",key,keycamelliab64,64)){
     strcpy(error,"129 - Error reading key CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivcamellia",key,ivcamelliab64,32)){
     strcpy(error,"130 - Error reading IV CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("keychacha",key,keychachab64,64)){
     strcpy(error,"131 - Error reading key CHACHA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivchacha",key,ivchachab64,32)){
     strcpy(error,"132 - Error reading IV CHACHA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keyaesb64,keyaes)){
      strcpy(error,"133 - Error decoding key AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivaesb64,ivaes)){
      strcpy(error,"134 - Error decoding IV AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(tagaesb64,tagaes)){
      strcpy(error,"135 - Error decoding TAG AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keycamelliab64,keycamellia)){
      strcpy(error,"136 - Error decoding key CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivcamelliab64,ivcamellia)){
      strcpy(error,"137 - Error decoding IV CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keychachab64,keychacha)){
      strcpy(error,"138 - Error decoding key CHACHA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivchachab64,ivchacha)){
      strcpy(error,"139 - Error decoding IV CHACHA");
     goto CLEANUP;
  }
  sprintf(tmpfilecamellia,"%s.camellia",infile);
  if(!bb_decrypt_file_chacha20(infile,tmpfilecamellia,keychacha,ivchacha)){
    strcpy(error,"142 - Error decrypting the file CHACHA20");
    goto CLEANUP;
  }
  sprintf(tmpfileaes,"%s.aes",infile);
  if(!bb_decrypt_file_camellia_ofb(tmpfilecamellia,tmpfileaes,keycamellia,ivcamellia)){
    strcpy(error,"141 - Error decrypting the file CAMELLIA");
    goto CLEANUP;
  }
  if(!bb_decrypt_file_aes_gcm(tmpfileaes,outfile,keyaes,ivaes,tagaes)){
    strcpy(error,"140 - Error decrypting the file AES");
    printf("tmpfileaes: %s\n outfile: %s\n",tmpfileaes,outfile);
    goto CLEANUP;
  }
  //bb_securedeletefile(tmpfileaes);
  //bb_securedeletefile(tmpfilecamellia);
  unlink(tmpfileaes);
  unlink(tmpfilecamellia);
  unlink(outfilefinal);
  rename(outfile,outfilefinal);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<256;i++) tmpfileaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<256;i++) tmpfilecamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<64;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  return(1);
  
  CLEANUP:
  fprintf(stderr,"%s\n",error);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<256;i++) tmpfileaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<256;i++) tmpfilecamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<64;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  return(0);
}

/**
* ENCRYPT FILE WITH AES256+GCM,CAMELLIA+OFB,CHACHA20
* KEY IS GENERATED AN RETURNED IN THE VARIABLE 1024 char is required
*/
int bb_encrypt_file(const char * infile, const char * outfile, char *key){
  unsigned char rd[128];
  char error[128]={""};
  unsigned char keyaes[64];
  unsigned char ivaes[32];
  unsigned char tagaes[32];
  char tmpfileaes[256];
  unsigned char keycamellia[64];
  unsigned char ivcamellia[32];
  char tmpfilecamellia[256];
  unsigned char keychacha[64];
  unsigned char ivchacha[32];
  unsigned char keyaesb64[64];
  unsigned char ivaesb64[64];
  unsigned char tagaesb64[64];
  unsigned char keycamelliab64[128];
  unsigned char ivcamelliab64[64];
  unsigned char keychachab64[128];
  unsigned char ivchachab64[64];
  int i;
  char *ss;
  char originfilename[512];
  char encryptedfilename[512];
  char buffer[256];
  struct stat sb;
  int filesize=0;
  
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<256;i++) tmpfileaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<256;i++) tmpfilecamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  memset(originfilename,0x0,256);
  memset(encryptedfilename,0x0,256);
  if(strlen(outfile)>256){
    strcpy(error,"117 - Destination name is too long max 256 chars");
    goto CLEANUP;
  }
  if(strlen(infile)>256){
    strcpy(error,"117b - Origin name is too long max 256 chars");
    goto CLEANUP;
  }
  
  // AES+GCM encryption
  if(bb_crypto_random_data(rd)==0){
    strcpy(error,"116 - Error generating true random data");
    goto CLEANUP;
  }
  memcpy(keyaes,&rd[0],32);
  memcpy(ivaes,&rd[32],16);
  sprintf(tmpfileaes,"%s.aes",infile);
  if(!bb_encrypt_file_aes_gcm(infile,tmpfileaes,keyaes,ivaes,tagaes)){
    strcpy(error,"118 - Error encrypting the file in AES");
    goto CLEANUP;
  }
  // CAMELLIA+OFB encryption
  for(i=0;i<128;i++) rd[0]=0;
  if(bb_crypto_random_data(rd)==0){
    strcpy(error,"119 - Error generating true random data");
    goto CLEANUP;
  }
  memcpy(keycamellia,&rd[0],32);
  memcpy(ivcamellia,&rd[32],16);
  sprintf(tmpfilecamellia,"%s.camellia",infile);
  if(!bb_encrypt_file_camellia_ofb(tmpfileaes,tmpfilecamellia,keycamellia,ivcamellia)){
    strcpy(error,"120 - Error encrypting the file CAMELLIA");
    goto CLEANUP;
  }
  //bb_securedeletefile(tmpfileaes);
  unlink(tmpfileaes);
  // CHACHA20 encryption
  for(i=0;i<128;i++) rd[0]=0;
  if(bb_crypto_random_data(rd)==0){
    strcpy(error,"121 - Error generating true random data");
    goto CLEANUP;
  }
  memcpy(keychacha,&rd[0],32);
  memcpy(ivchacha,&rd[32],16);
  if(!bb_encrypt_file_chacha20(tmpfilecamellia,outfile,keychacha,ivchacha)){
    strcpy(error,"122 - Error encrypting the file CHACHA20");
    goto CLEANUP;
  }
  //bb_securedeletefile(tmpfilecamellia);
  unlink(tmpfilecamellia);
  //* GENERATING KEY IN BASE64 +JSON
  if(!bb_encode_base64(keyaes,32,keyaesb64)){
    strcpy(error,"123 - Error encoding in base64 keyaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivaes,16,ivaesb64)){
    strcpy(error,"124 - Error encoding in base64 ivaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(tagaes,16,tagaesb64)){
    strcpy(error,"124 - Error encoding in base64 tagaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keycamellia,32,keycamelliab64)){
    strcpy(error,"125 - Error encoding in base64 keycamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivcamellia,16,ivcamelliab64)){
    strcpy(error,"126 - Error encoding in base64 ivcamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keychacha,32,keychachab64)){
    strcpy(error,"125 - Error encoding in base64 keychacha");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivchacha,16,ivchachab64)){
    strcpy(error,"126 - Error encoding in base64 ivchacha");
    goto CLEANUP;
  }
  
  strcpy(originfilename,infile);
  strcpy(encryptedfilename,outfile);
  bb_strip_path(originfilename);
  bb_strip_path(encryptedfilename);
 /* while(strstr(originfilename,"/")!=NULL){
       strcpy(buffer,originfilename);
       ss=strstr(buffer,"/");
       strcpy(originfilename,(ss+1));
   }
  while(strstr(encryptedfilename,"/")!=NULL){
       strcpy(buffer,encryptedfilename);
       ss=strstr(buffer,"/");
       strcpy(encryptedfilename,(ss+1));
   }*/
  if(stat(outfile, &sb)>=0)
     filesize=sb.st_size;
  sprintf(key,"{\"originfilename\":\"%s\",\"encryptedfilename\":\"%s\",\"filesize\":\"%d\",\"keyaes\":\"%s\",\"ivaes\":\"%s\",\"tagaes\":\"%s\",\"keycamellia\":\"%s\",\"ivcamellia\":\"%s\",\"keychacha\":\"%s\",\"ivchacha\":\"%s\"}",originfilename,encryptedfilename,filesize,keyaesb64,ivaesb64,tagaesb64,keycamelliab64,ivcamelliab64,keychachab64,ivchachab64);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<256;i++) tmpfileaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<256;i++) tmpfilecamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  memset(originfilename,0x0,256);
  memset(encryptedfilename,0x0,256);
  return(1);
  
  CLEANUP:
  fprintf(stderr,"%s\n",error);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<256;i++) tmpfileaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<256;i++) tmpfilecamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  memset(originfilename,0x0,256);
  memset(encryptedfilename,0x0,256);
  return(0);
}
/*
#include "bb_encrypt_decrypt_file_aes_gcm.c"
#include "bb_encrypt_decrypt_file_camellia_ofb.c"
#include "bb_encrypt_decrypt_file_chacha20.c"
#include "bb_crypto_randomdata.c"
#include "bb_encode_decode_base64.c"
#include "bb_sha.c"
#include "bb_json.c"
#include "bb_securedeletefile.c"
*/
//*** ORIGIN: ../blackbox-server/bb_encrypt_decrypt_file.c
/*#include "blackbox.h"
                
void main(void)
{
char key[64];
char iv[64];
char tag[16];
int i;
strcpy(iv,"1234567890123456");
strcpy(key,"123456789012345K");
bb_encrypt_file_aes_gcm("test.txt","test.aes256",key,iv,tag);
printf("tag: %s\n",tagb64);
bb_decrypt_file_aes_gcm("test.aes256","test.dec",key,iv,tag);
exit;

}*/
/**
* FILE ENCRYPTION BY AES256 + GCM (key MUST be 256 bit)
*/
int bb_decrypt_file_aes_gcm(const char * infile, const char * outfile, const void * key, const void * iv,char * tag){
    int insize = 102400;
    int outsize=102400+512;
    unsigned char inbuf[insize], outbuf[outsize];
    int ofh = -1, ifh = -1;
    int u_len = 0, f_len = 0;
    int iv_len=12;
    int len=0;
    int i;
    int read_size;
    char error[1024]={"\0"};
    if(strlen(infile)>256){
        strcpy(error,"011a - Input file name is too long");
        goto CLEANUP;
    }
    if(strlen(outfile)>256){
        strcpy(error,"011b- Output file name is too long");
        goto CLEANUP;
    }
    
    if((ifh = open(infile, O_RDONLY)) == -1) {
        sprintf(error,"016 -  Could not open input file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if((ofh = open(outfile, O_CREAT | O_TRUNC | O_WRONLY, 0644)) == -1) {
        sprintf(error,"017 -  Could not open output file %s, errno = %s\n",outfile, strerror(errno));
        goto CLEANUP;
    }
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"011 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL)){
        strcpy(error,"012 - Error initialising the AES-256 GCM, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, iv_len, NULL)){
        strcpy(error,"013 - Error initialising the AES-256 GCM - IV LEN, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"014 - Error initialising the AES-256 GCM - KEY and IV");
        goto CLEANUP;
    }
    while((read_size = read(ifh, inbuf, insize)) > 0)
    {
        if(EVP_DecryptUpdate(ctx, outbuf, &len, inbuf, read_size) == 0){
           sprintf(error, "018 - EVP_DecryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           goto CLEANUP;
        }
        if(write(ofh, outbuf, len) != len) {
            sprintf(error, "019 - Writing to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
        u_len += len;
    }
    if(read_size == -1) {
        sprintf(error, "020 - Error Reading from the file %s failed. errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if(!EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, tag)){
        sprintf(error, "021 - Error EVP_CIPHER_CTX_ctrl failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(EVP_DecryptFinal_ex(ctx, outbuf, &f_len) == 0) {
        sprintf(error, "021 - Error EVP_DecryptFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(f_len) {
        if(write(ofh, outbuf, f_len) != f_len) {
            sprintf(error, "022 - Final write to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
    }
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    EVP_CIPHER_CTX_free(ctx);
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    return(0);
    
}
/**
* FILE ENCRYPTION BY AES256 + GCM (key MUST be 256 bit)
*/
int bb_encrypt_file_aes_gcm(const char * infile, const char * outfile, const void * key, const void * iv,char * tag){
    int insize = 102400;
    int outsize=102400+512;
    unsigned char inbuf[insize], outbuf[outsize];
    int ofh = -1, ifh = -1;
    int u_len = 0, f_len = 0;
    int iv_len=12;
    int len=0;
    int i;
    int read_size;
    char error[128]={"\0"};
    
    if((ifh = open(infile, O_RDONLY)) == -1) {
        sprintf(error,"006 -  Could not open input file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if((ofh = open(outfile, O_CREAT | O_TRUNC | O_WRONLY, 0644)) == -1) {
        sprintf(error,"007 -  Could not open output file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"001 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL)){
        strcpy(error,"002 - Error initialising the AES-256 GCM, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, iv_len, NULL)){
        strcpy(error,"003 - Error initialising the AES-256 GCM - IV LEN, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"004 - Error initialising the AES-256 GCM - KEY and IV");
        goto CLEANUP;
    }
    while((read_size = read(ifh, inbuf, insize)) > 0)
    {
        if(EVP_EncryptUpdate(ctx, outbuf, &len, inbuf, read_size) == 0){
           sprintf(error, "008 - EVP_CipherUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           goto CLEANUP;
        }
        if(write(ofh, outbuf, len) != len) {
            sprintf(error, "009 - Writing to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
        u_len += len;
    }
    if(read_size == -1) {
        sprintf(error, "010 - Error Reading from the file %s failed. errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if(EVP_EncryptFinal_ex(ctx, outbuf, &f_len) == 0) {
        sprintf(error, "011 - Error EVP_CipherFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, tag)){
        sprintf(error, "011 - Error EVP_CIPHER_CTX_ctrl failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(f_len) {
        if(write(ofh, outbuf, f_len) != f_len) {
            sprintf(error, "012 - Final write to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
    }
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    EVP_CIPHER_CTX_free(ctx);
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    return(0);
    
}



//*** ORIGIN: ../blackbox-server/bb_encrypt_decrypt_file_aes_gcm.c
/*#include "blackbox.h"
                
void main(void)
{
char key[64];
char iv[64];
char tag[64];
int i;
strcpy(iv,"1234567890123456");
strcpy(key,"123456789012345K");
bb_encrypt_file_camellia_ofb("test.txt","test.camellia",key,iv);
bb_decrypt_file_camellia_ofb("test.camellia","test.dec",key,iv);
exit;

}*/
/**
* FILE decryption CAMELLIA + OFB (key MUST be 256 bit)
*/
int bb_decrypt_file_camellia_ofb(const char * infile, const char * outfile, const void * key, const void * iv){
    int insize = 102400;
    int outsize=102400+512;
    unsigned char inbuf[insize], outbuf[outsize];
    int ofh = -1, ifh = -1;
    int u_len = 0, f_len = 0;
    int iv_len=16;
    int len=0;
    int i;
    int read_size;
    char error[128]={"\0"};
    
    if((ifh = open(infile, O_RDONLY)) == -1) {
        sprintf(error,"056 -  Could not open input file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if((ofh = open(outfile, O_CREAT | O_TRUNC | O_WRONLY, 0644)) == -1) {
        sprintf(error,"057 -  Could not open output file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"058 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, EVP_camellia_256_ofb(), NULL, NULL, NULL)){
        strcpy(error,"059 - Error initialising the CAMELLIA OFB libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"054 - Error initialising the CAMELLIA OFB - KEY and IV");
        goto CLEANUP;
    }
    while((read_size = read(ifh, inbuf, insize)) > 0)
    {
        if(EVP_DecryptUpdate(ctx, outbuf, &len, inbuf, read_size) == 0){
           sprintf(error, "058 - EVP_DecryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           goto CLEANUP;
        }
        if(write(ofh, outbuf, len) != len) {
            sprintf(error, "059 - Writing to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
        u_len += len;
    }
    if(read_size == -1) {
        sprintf(error, "060 - Error Reading from the file %s failed. errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if(EVP_DecryptFinal_ex(ctx, outbuf, &f_len) == 0) {
        sprintf(error, "061 - Error EVP_DecryptFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(f_len) {
        if(write(ofh, outbuf, f_len) != f_len) {
            sprintf(error, "062 - Final write to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
    }

    
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    EVP_CIPHER_CTX_free(ctx);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    return(0);
    
}
/**
* FILE ENCRYPTION BY CAMELLIA +OFB (key MUST be 256 bit)
*/
int bb_encrypt_file_camellia_ofb(const char * infile, const char * outfile, const void * key, const void * iv){
    int insize = 102400;
    int outsize=102400+512;
    unsigned char inbuf[insize], outbuf[outsize];
    int ofh = -1, ifh = -1;
    int u_len = 0, f_len = 0;
    int iv_len=16;
    int len=0;
    int i;
    int read_size;
    char error[128]={"\0"};
    
    if((ifh = open(infile, O_RDONLY)) == -1) {
        sprintf(error,"036 -  Could not open input file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if((ofh = open(outfile, O_CREAT | O_TRUNC | O_WRONLY, 0644)) == -1) {
        sprintf(error,"037 -  Could not open output file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"031 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, EVP_camellia_256_ofb(), NULL, NULL, NULL)){
        strcpy(error,"032 - Error initialising the CAMELLIA OFB, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"034 - Error initialising the CAMELLIA OFB - KEY and IV");
        goto CLEANUP;
    }
    while((read_size = read(ifh, inbuf, insize)) > 0)
    {
        if(EVP_EncryptUpdate(ctx, outbuf, &len, inbuf, read_size) == 0){
           sprintf(error, "038 - EVP_EncryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           goto CLEANUP;
        }
        if(write(ofh, outbuf, len) != len) {
            sprintf(error, "039 - Writing to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
        u_len += len;
    }
    if(read_size == -1) {
        sprintf(error, "040 - Error Reading from the file %s failed. errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if(EVP_EncryptFinal_ex(ctx, outbuf, &f_len) == 0) {
        sprintf(error, "041 - Error EVP_CipherFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(f_len) {
        if(write(ofh, outbuf, f_len) != f_len) {
            sprintf(error, "042 - Final write to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
    }
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    EVP_CIPHER_CTX_free(ctx);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    return(0);
    
}



//*** ORIGIN: ../blackbox-server/bb_encrypt_decrypt_file_camellia_ofb.c
/*#include "blackbox.h"
                
void main(void)
{
char key[64];
char iv[64];
char tag[64];
int i;
strcpy(iv,"1234567890123456");
strcpy(key,"123456789012345K");
bb_encrypt_file_chacha20("test.txt","test.chacha20",key,iv);
bb_decrypt_file_chacha20("test.chacha20","test.dec",key,iv);
exit;

}*/
/**
* FILE DECRYPTION BY CHACHA20 (key MUST be 256 bit)
*/
int bb_decrypt_file_chacha20(const char * infile, const char * outfile, const void * key, const void * iv){
    int insize = 102400;
    int outsize=102400+512;
    unsigned char inbuf[insize], outbuf[outsize];
    int ofh = -1, ifh = -1;
    int u_len = 0, f_len = 0;
    int iv_len=16;
    int len=0;
    int i;
    int read_size;
    char error[128]={"\0"};
    
    if((ifh = open(infile, O_RDONLY)) == -1) {
        sprintf(error,"076 -  Could not open input file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if((ofh = open(outfile, O_CREAT | O_TRUNC | O_WRONLY, 0644)) == -1) {
        sprintf(error,"077 -  Could not open output file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"078 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, EVP_chacha20(), NULL, NULL, NULL)){
        strcpy(error,"079 - Error initialising the CHACHA20  libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"074 - Error initialising the CHACHA20 - KEY and IV");
        goto CLEANUP;
    }
    while((read_size = read(ifh, inbuf, insize)) > 0)
    {
        if(EVP_DecryptUpdate(ctx, outbuf, &len, inbuf, read_size) == 0){
           sprintf(error, "078 - EVP_DecryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           goto CLEANUP;
        }
        if(write(ofh, outbuf, len) != len) {
            sprintf(error, "079 - Writing to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
        u_len += len;
    }
    if(read_size == -1) {
        sprintf(error, "080 - Error Reading from the file %s failed. errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if(EVP_DecryptFinal_ex(ctx, outbuf, &f_len) == 0) {
        sprintf(error, "081 - Error EVP_DecryptFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(f_len) {
        if(write(ofh, outbuf, f_len) != f_len) {
            sprintf(error, "082 - Final write to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
    }

    
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    EVP_CIPHER_CTX_free(ctx);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    return(0);
    
}
/**
* FILE ENCRYPTION BY CHACHA20(key MUST be 256 bit)
*/
int bb_encrypt_file_chacha20(const char * infile, const char * outfile, const void * key, const void * iv){
    int insize = 102400;
    int outsize=102400+512;
    unsigned char inbuf[insize], outbuf[outsize];
    int ofh = -1, ifh = -1;
    int u_len = 0, f_len = 0;
    int iv_len=16;
    int len=0;
    int i;
    int read_size;
    char error[128]={"\0"};
    
    if((ifh = open(infile, O_RDONLY)) == -1) {
        sprintf(error,"056 -  Could not open input file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if((ofh = open(outfile, O_CREAT | O_TRUNC | O_WRONLY, 0644)) == -1) {
        sprintf(error,"057 -  Could not open output file %s, errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"051 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, EVP_chacha20(), NULL, NULL, NULL)){
        strcpy(error,"052 - Error initialising the CHACHA20 libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"054 - Error initialising the CHACHA20 - KEY and IV");
        goto CLEANUP;
    }
    while((read_size = read(ifh, inbuf, insize)) > 0)
    {
        if(EVP_EncryptUpdate(ctx, outbuf, &len, inbuf, read_size) == 0){
           sprintf(error, "055 - EVP_EncryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           goto CLEANUP;
        }
        if(write(ofh, outbuf, len) != len) {
            sprintf(error, "059 - Writing to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
        u_len += len;
    }
    if(read_size == -1) {
        sprintf(error, "060 - Error Reading from the file %s failed. errno = %s\n", infile, strerror(errno));
        goto CLEANUP;
    }
    if(EVP_EncryptFinal_ex(ctx, outbuf, &f_len) == 0) {
        sprintf(error, "061 - Error EVP_CipherFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(f_len) {
        if(write(ofh, outbuf, f_len) != f_len) {
            sprintf(error, "042 - Final write to the file %s failed. errno = %s\n", outfile, strerror(errno));
            goto CLEANUP;
    }
    }
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    EVP_CIPHER_CTX_free(ctx);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    if(ifh != -1) close(ifh);
    if(ofh != -1) close(ofh);
    for(i=0;i<insize;i++) inbuf[0]=0;
    for(i=0;i<outsize;i++) outbuf[0]=0;
    for(i=0;i<128;i++) error[0];
    return(0);
    
}



//*** ORIGIN: ../blackbox-server/bb_encrypt_decrypt_file_chacha20.c

/**
 * Secure Delete File  provides the following public functions:
 *
 * void bb_sdel_init(int secure_random)
 *      Initializiation function for bb_sdel_overwrite. It needs to be called
 *      once at program start, not for each file to be overwritten.
 *      Options:
 *          secure_random - if != 0 defines that the secure random number
 *                          generator RANDOM_DEVICE should be used
 *
 * void bb_sdel_finnish()
 *      Clean-up function, if bb_sdel_init() was called in a program. It needs
 *      only to be called at the end of the program.
 *
 * int  bb_sdel_overwrite(int mode, int fd, long start, unsigned long bufsize,
 *                     unsigned long length, int zero)
 *      This is the heart of sdel-lib. It overwrites the target file
 *      descriptor securely to make life hard even for the NSA.
 *      Read the next paragraph for the techniques.
 *      Options:
 *          mode = 0 - once overwrite with random data
 *                 1 - once overwrite with 0xff, then once with random data
 *                 2 - overwrite 38 times with special values
 *          fd       - filedescriptor of the target to overwrite
 *          start    - where to start overwriting. 0 is from the beginning
 *                     this is needed for wiping swap spaces etc.
 *          bufsize  - size of the buffer to use for overwriting, depends
 *                     on the filesystem
 *          length   - amount of data to write (file size), 0 means until
 *                     an error occurs
 *          zero     - last wipe is zero bytes, not random
 *      returns 0 on success, -1 on errors
 *
     bb_sdel_unlink(nf,0,1,O_SYNC);
 * int  bb_sdel_unlink(char *filename, int directory, int truncate, int slow)
 *      First truncates the file (if it is not a directory), then renames it
 *      and finally rmdir/unlinks the target.
 *      Options:
 *          filename  - filename/directory to unlink/rmdir
 *          directory - if != 0, it is a directory
 *          truncate  - if != 0, it truncates the file
 *          slow      - is either O_SYNC (see open(2)) or 0
 *      returns 0 on success, -1 on errors
 *
 * For security reasons full 32kb blocks are written so that the whole block
 * on which the file(s) live are overwritten. (change #define #BLOCKSIZE)
 * Standard mode is a real security wipe for 38 times, flushing
 * the caches after every write. The wipe technique was proposed by Peter
 * Gutmann at Usenix '96 and includes 10 random overwrites plus 28 special
 * defined characters.
 *
 */

/*#include "blackbox.h"
void main(void){
printf("Secure delete: test.del\n");
if(bb_securedeletefile("test.del")==0)
    printf("Error erasing file");
else
    printf("test.del erased\n");
exit(0);
}*/
//
// STARTING FUNCTIONS
//
/**
* FUNCTION TO SECURE DELETE A FILE
*/
int bb_securedeletefile(char * nf){
    struct stat st;
    long fileSize;
    int fd = open(nf, O_RDWR);
    if(fd==-1){
        fprintf(stderr,"157 - File not found %s\n",nf);
        return(0);
    }
    if (stat(nf, &st) == 0)
        fileSize=st.st_size;
    else{
        fprintf(stderr, "157 - Cannot determine size of %s: %s\n",nf, strerror(errno));
        return(0);
    }
    bb_sdel_init(1);
    //if(verbose) printf("Overwriting file..\n");
    if(bb_sdel_overwrite(2,fd,0,1024,fileSize,0)==-1){
        fprintf(stderr,"155 - Error overwriting file\n");
        return(0);
    }
    //if(verbose) printf("Erasing file..\n");
    if(bb_sdel_unlink(nf,0,1,O_SYNC)==-1){
        fprintf(stderr,"156 - Error erasing file\n");
        return(0);
    }
    bb_sdel_finnish();
    return(1);
}
void __bb_sdel_fill_buf(char pattern[3], unsigned long bufsize, char *buf) {
    int loop;
    int where;
    
    for (loop = 0; loop < (bufsize / 3); loop++) {
        where = loop * 3;
    *buf++ = pattern[0];
    *buf++ = pattern[1];
    *buf++ = pattern[2];
    }
}

void __bb_sdel_random_buf(unsigned long bufsize, char *buf) {
    int loop;
    
    if (devrandom == NULL)
        for (loop = 0; loop < bufsize; loop++)
            *buf++ = (unsigned char) (256.0*rand()/(RAND_MAX+1.0));
    else
        fread(buf, bufsize, 1, devrandom);
}

void __bb_sdel_random_filename(char *filename) {
    int i;
    for (i = strlen(filename) - 1;
         (filename[i] != DIR_SEPERATOR) && (i >= 0);
         i--)
        if (filename[i] != '.') /* keep dots in the filename */
            filename[i] = 97+(int) ((int) ((256.0 * rand()) / (RAND_MAX + 1.0)) % 26);
}

void bb_sdel_init(int secure_random) {

    (void) setvbuf(stdout, NULL, _IONBF, 0);
    (void) setvbuf(stderr, NULL, _IONBF, 0);

    if (BLOCKSIZE<16384)
        fprintf(stderr, "144 -Programming Warning: in-compiled blocksize is <16k !\n");
    if (BLOCKSIZE % 3 > 0)
        fprintf(stderr, "145 Programming Error: in-compiled blocksize is not a multiple of 3!\n");

    srand( (getpid()+getuid()+getgid()) ^ time(0) );
    devrandom = NULL;
#ifdef RANDOM_DEVICE
    if (secure_random) {
        if ((devrandom = fopen(RANDOM_DEVICE, "r")) != NULL)
            if (verbose) printf("Using %s for random input.\n", RANDOM_DEVICE);
            
    }
#endif

    __internal_bb_sdel_init = 1;
}

void bb_sdel_finnish(void) {
    if (devrandom != NULL) {
        fclose(devrandom);
        devrandom = NULL;
    }
    if (! __internal_bb_sdel_init) {
        fprintf(stderr, "146 - Programming Error: function was not initialized before calling bb_sdel_finnish().\n");
        return;
    }
    __internal_bb_sdel_init = 0;
}

/**
 * secure_overwrite function parameters:
 * mode = 0 : once overwrite with random data
 *        1 : once overwrite with 0xff, then once with random data
 *        2 : overwrite 38 times with special values
 * fd       : filedescriptor of the target to overwrite
 * start    : where to start overwriting. 0 is from the beginning
 * bufsize  : size of the buffer to use for overwriting, depends on the filesystem
 * length   : amount of data to write (file size), 0 means until an error occurs
 *
 * returns 0 on success, -1 on errors
 */
int bb_sdel_overwrite(int mode, int fd, long start, unsigned long bufsize, unsigned long length, int zero) {
    unsigned long writes;
    unsigned long counter;
    int turn;
    int last = 0;
    char buf[65535];
    FILE *f;

    if (! __internal_bb_sdel_init)
        fprintf(stderr, "146 - Programming Error: bb_sdel was not initialized before bb_sdel_overwrite().\n");

    if ((f = fdopen(fd, "r+b")) == NULL)
        return -1;

/* calculate the number of writes */
    if (length > 0)
        writes = (1 + (length / bufsize));
    else
        writes = 0;

/* do the first overwrite */
    if (start == 0)
        rewind(f);
    else
        if (fseek(f, start, SEEK_SET) != 0)
            return -1;
    if (mode != 0 || zero) {
        if (mode == 0)
            __bb_sdel_fill_buf(std_array_00, bufsize, buf);
        else
            __bb_sdel_fill_buf(std_array_ff, bufsize, buf);
        if (writes > 0)
            for (counter=1; counter<=writes; counter++)
                fwrite(&buf, 1, bufsize, f); // dont care for errors
        else
            do {} while(fwrite(&buf, 1, bufsize, f) == bufsize);
        if (verbose)
            printf("*");
        fflush(f);
        if (fsync(fd) < 0)
            FLUSH;
        if (mode == 0)
            return 0;
    }

/* do the rest of the overwriting stuff */
    for (turn = 0; turn <= 36; turn++) {
        if (start == 0)
            rewind(f);
        else
            if (fseek(f, start, SEEK_SET) != 0)
                return -1;
        if ((mode < 2) && (turn > 0))
            break;
        if ((turn >= 5) && (turn <= 31)) {
            __bb_sdel_fill_buf(write_modes[turn-5], bufsize, buf);
            if (writes > 0)
                for (counter = 1; counter <= writes; counter++)
                    fwrite(&buf, 1, bufsize, f); // dont care for errors
            else
                do {} while(fwrite(&buf, 1, bufsize, f) == bufsize);
        } else {
            if (zero && ((mode == 2 && turn == 36) || mode == 1)) {
                last = 1;
                __bb_sdel_fill_buf(std_array_00, bufsize, buf);
            }
            if (writes > 0) {
            for (counter = 1; counter <= writes; counter++) {
                if (! last)
                        __bb_sdel_random_buf(bufsize, buf);
                fwrite(&buf, 1, bufsize, f); // dont care for errors
            }
        } else {
            do {
                if (! last)
                        __bb_sdel_random_buf(bufsize, buf);
            } while (fwrite(&buf, 1, bufsize, f) == bufsize); // dont care for errors
        }
        }
        fflush(f);
        if (fsync(fd) < 0)
            FLUSH;
        if (verbose)
            printf("*");
    }

    (void) fclose(f);
/* Hard Flush -> Force cached data to be written to disk */
    FLUSH;

    return 0;
}

/**
 * secure_unlink function parameters:
 * filename   : the file or directory to remove
 * directory  : defines if the filename poses a directory
 * truncate   : truncate file
 * slow       : do things slowly, to prevent caching
 *
 * returns 0 on success, -1 on errors.
 */
int bb_sdel_unlink(char *filename, int directory, int truncate, int slow) {
   int fd;
   int turn = 0;
   int result;
   char newname[strlen(filename) + 1];
   struct stat filestat;

/* open + truncating the file, so an attacker doesn't know the diskblocks */
   if (! directory && truncate)
       if ((fd = open(filename, O_WRONLY | O_TRUNC | slow)) >= 0)
           close(fd);

/* Generate random unique name, renaming and deleting of the file */
    strcpy(newname, filename); // not a buffer overflow as it has got the exact length

    do {
        __bb_sdel_random_filename(newname);
        if ((result = lstat(newname, &filestat)) >= 0)
            turn++;
    } while ((result >= 0) && (turn <= 100));

    if (turn <= 100) {
       result = rename(filename, newname);
       if (result != 0) {
          fprintf(stderr, "147 - Warning: Couldn't rename %s - ", filename);
          perror("");
          strcpy(newname, filename);
       }
    } else {
       fprintf(stderr,"148 - Warning: Couldn't find a free filename for %s!\n",filename);
       strcpy(newname, filename);
    }

    if (directory) {
        result = rmdir(newname);
        if (result) {
            fprintf(stderr,"149 - Warning: Unable to remove directory %s - ", filename);
            perror("");
        (void) rename(newname, filename);
    } else
        if (verbose)
            printf("Removed directory %s ...", filename);
    } else {
        result = unlink(newname);
        if (result) {
            fprintf(stderr,"150 - Warning: Unable to unlink file %s - ", filename);
            perror("");
            (void) rename(newname, filename);
        } else
            if (verbose)
                printf(" Removed file %s ...", filename);
    }

    if (result != 0)
        return -1;

    return 0;
}

void bb_sdel_wipe_inodes(char *loc, char **array) {
    char *template = malloc(strlen(loc) + 16);
    int i = 0;
    int fail = 0;
    int fd;

    if (verbose)
        printf("Wiping inodes ...");

    array = malloc(MAXINODEWIPE * sizeof(template));
    strcpy(template, loc);
    if (loc[strlen(loc) - 1] != '/')
        strcat(template, "/");
    strcat(template, "xxxxxxxx.xxx");
       
    while(i < MAXINODEWIPE && fail < 5) {
        __bb_sdel_random_filename(template);
        if (open(template, O_CREAT | O_EXCL | O_WRONLY, 0600) < 0)
            fail++;
        else {
            array[i] = malloc(strlen(template));
            strcpy(array[i], template);
            i++;
        }
    }
    FLUSH;
       
    if (fail < 5) {
        fprintf(stderr, "151 - Warning: could not wipe all inodes!\n");
    }
       
    array[i] = NULL;
    fd = 0;
    while(fd < i) {
        unlink(array[fd]);
        free(array[fd]);
        fd++;
    }
    free(array);
    array = NULL;
    FLUSH;
    if (verbose)
        printf(" Done ... ");
}

//*** ORIGIN: ../blackbox-server/bb_securedeletefile.c
/*#include "blackbox.h"
void main(void){
char fn[512]={"prova.txt"};
fn[0]=0;
bb_strip_path(fn);
printf("%s %d\n",fn,strlen(fn));

}*/
/**
* FUNCTION TO STRIP THE PATH FROM A FILE NAME
*/
void bb_strip_path(char * filename){
    char * buf;
    char *p;
    int i,x;
    x=strlen(filename);
    buf=malloc(x+1);
    for(i=x-1;i>=0;i--){
        if(filename[i]=='/'){
            strncpy(buf,&filename[i+1],x);
            strcpy(filename,buf);
            free(buf);
            return;
        }
    }
    free(buf);
    return;
}
//*** ORIGIN: ../blackbox-server/bb_strip_path.c
/*#include "blackbox.h"
int main () {
   const char haystack[1024] = "Ciccio";
   const char needle[1024] = "Ciccio";
   const char str[1024]= "Ciccio";
   char *ret;
   ret=bb_str_replace(haystack,needle,str);
   printf("Result: %s\n",ret);
   free(ret);
   return(0);
}*/
/**
* FUNCTION TO SEARCH AND REPLACE A STRING
*/
char* bb_str_replace(const char* string, const char* substr, const char* replacement) {
    char* tok = NULL;
    char* newstr = NULL;
    char* oldstr = NULL;
    int   oldstr_len = 0;
    int   substr_len = 0;
    int   replacement_len = 0;
    
    newstr = strdup(string);
    if(strcmp(string,substr)==0 &&  strcmp(substr,replacement)==0)
        return(newstr);
    substr_len = strlen(substr);
    replacement_len = strlen(replacement);

    if (substr == NULL || replacement == NULL) {
        return newstr;
    }
    if (strlen(substr)==0) {
        return newstr;
    }
    

    while ((tok = strstr(newstr, substr))) {
        oldstr = newstr;
        oldstr_len = strlen(oldstr);
        newstr = (char*)malloc(sizeof(char) * (oldstr_len - substr_len + replacement_len + 1));

        if (newstr == NULL) {
            free(oldstr);
            fprintf(stderr,"20500 -bb_str_replace.c: error allocating memory");
            return NULL;
        }

        memcpy(newstr, oldstr, tok - oldstr);
        memcpy(newstr + (tok - oldstr), replacement, replacement_len);
        memcpy(newstr + (tok - oldstr) + replacement_len, tok + substr_len, oldstr_len - substr_len - (tok - oldstr));
        memset(newstr + oldstr_len - substr_len + replacement_len, 0, 1);

        free(oldstr);
    }
    return newstr;
}

//*** ORIGIN: ../blackbox-server/bb_str_replace.c
/*#include "blackbox.h"
main(){
   char r[1024];
    bb_bin2hex("ciccio2828;a71092782390723@!#$%^&*(",100,r);
    printf("%s\n",r);
}*/
/**
* FUNCTION TO MAKE AN HEX DUMP OF A BINARY DATA
*/
void bb_hexdump(char *desc, void *addr, int len)
{
int i;
unsigned char buff[17];
unsigned char *pc = (unsigned char*)addr;
if (desc != NULL)
printf ("%s:\n", desc);
for (i = 0; i < len; i++) {
if ((i % 16) == 0) {
if (i != 0)
printf("  %s\n", buff);
printf("  %04x ", i);
        }
printf(" %02x", pc[i]);
if ((pc[i] < 0x20) || (pc[i] > 0x7e)) {
            buff[i % 16] = '.';
        } else {
            buff[i % 16] = pc[i];
        }
        buff[(i % 16) + 1] = '\0';
    }
while ((i % 16) != 0) {
printf("   ");
        i++;
    }
printf("  %s\n", buff);
return;
}
/**
* FUNCTION TO CONVERT A BINARY TO HEXDECIMAL PRINTABLE STRING
*/
void bb_bin2hex(unsigned char *binary,int binlen,char *destination)
{
int i;
char buf[10];
destination[0]=0;
for(i=0;i<binlen;i++){
  sprintf(buf,"%x",binary[i]);
  strcat(destination,buf);
}
return;
}

//*** ORIGIN: ../blackbox-server/bb_hexdump.c
/*#include "blackbox.h"
                
void main(void)
{
char key[64];
char iv[64];
int i;
strcpy(iv,"1234567890123456");
strcpy(key,"123456789012345K");
char buffer[256]={"plain text for encryption test"};
int buffer_len=64;
char encrypted[256];
int encrypted_len;
bb_encrypt_buffer_aes_ofb(buffer,buffer_len,encrypted,&encrypted_len,key,iv);
printf("encrypted len: %d\n",encrypted_len);
bb_decrypt_buffer_aes_ofb(buffer,&buffer_len,encrypted,encrypted_len,key,iv);
buffer[buffer_len]=0;
printf("decrypted len: %d\n",buffer_len);
printf("decrypted text: %s\n",buffer);

exit;

}*/
/**
* BUFFER DECRYPTION BY AES IN OFB MODE (key MUST be 256 bit)
*/
int bb_decrypt_buffer_aes_ofb(unsigned char * buffer,int * buffer_len,unsigned char * encrypted,int encrypted_len,unsigned char *key,unsigned char *iv)
{
    int f_len = 0;
    //int iv_len=16;
    int i;
    char error[128]={"\0"};
    
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"219 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, EVP_aes_256_ofb(), NULL, NULL, NULL)){
        strcpy(error,"220 - Error initialising the CHACHA20  libssl may be wrong version or missing");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(1 != EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"221 - Error initialising the CHACHA20 - KEY and IV");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(EVP_DecryptUpdate(ctx, buffer, buffer_len, encrypted, encrypted_len) == 0){
           sprintf(error, "222 - EVP_DecryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           EVP_CIPHER_CTX_free(ctx);
           goto CLEANUP;
    }
    if(EVP_DecryptFinal_ex(ctx, &buffer[*buffer_len], &f_len) == 0) {
        sprintf(error, "223 - Error EVP_DecryptFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(f_len>0) *buffer_len=*buffer_len+f_len;

    
    EVP_CIPHER_CTX_free(ctx);
    for(i=0;i<128;i++) error[i]=0;
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    for(i=0;i<128;i++) error[i]=0;
    return(0);
    
}
/**
* BUFFER ENCRYPTION BY AES IN OFB (key MUST be 256 bit)
*/
int bb_encrypt_buffer_aes_ofb(unsigned char * buffer,int buffer_len,unsigned char * encrypted,int * encrypted_len,unsigned char *key,unsigned char *iv){
    int f_len = 0;
    //int iv_len=16;
    int i;
    char error[128]={"\0"};
    
    EVP_CIPHER_CTX *ctx;
    if(!(ctx = EVP_CIPHER_CTX_new())){
        strcpy(error,"214 - Error initialising the EVP_CIPHER, libssl may be wrong version or missing");
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, EVP_aes_256_ofb(), NULL, NULL, NULL)){
        strcpy(error,"215 - Error initialising the CHACHA20 libssl may be wrong version or missing");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(1 != EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv)){
        strcpy(error,"216 - Error initialising the CHACHA20 - KEY and IV");
        EVP_CIPHER_CTX_free(ctx);
        goto CLEANUP;
    }
    if(EVP_EncryptUpdate(ctx, encrypted, encrypted_len, buffer, buffer_len) == 0){
           sprintf(error, "217 - EVP_EncryptUpdate failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
           EVP_CIPHER_CTX_free(ctx);
           goto CLEANUP;
    }
    if(EVP_EncryptFinal_ex(ctx, &encrypted[*encrypted_len], &f_len) == 0) {
        sprintf(error, "218 - Error EVP_CipherFinal_ex failed. OpenSSL error: %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto CLEANUP;
    }
    if(f_len) *encrypted_len=*encrypted_len+f_len;
    
    EVP_CIPHER_CTX_free(ctx);
    for(i=0;i<128;i++) error[i]=0;
    return(1);
    
    CLEANUP:
    fprintf(stderr,"%s\n",error);
    for(i=0;i<128;i++) error[i]=0;
    return(0);
    
}



//*** ORIGIN: ../blackbox-server/bb_encrypt_decrypt_buffer_aes_ofb.c
//*******************************************************************
//*** SHIELDED VOICE TRANSPORT PROTOCOL (EVOLUTION OF SRTP)
//*******************************************************************
/*#include "blackbox.h"
// MAIN
int verbose=1;
void main(int argc,char *argv[]){
SVTP svtp;
int x,i,f,lenrdp;
unsigned int sq,sqseed;
unsigned char key[64];
unsigned char datapacket[8192];
char ipdestination[64];
unsigned short int portdestination;
char rd[128];
//CHECK PARAMETER
f=0;
if(argc>1){
    if(strcmp(argv[1],"server")==0){
        printf("Server Starting\n");
        f=1;
    }else{
        f=0;
    }
}
if(f==0) printf("Client Starting\n");
//DATA EXCHANGE IN THE SIGNAL CHANNEL
bb_crypto_random_data(key);
bb_hexdump("key",key,64);
//bb_crypto_random_data(rd);
strcpy(rd,"ABCDEF0123456789012322354454");
memset(&sq,0x0,4);
memset(&sqseed,0x0,4);
memcpy(&sq,&rd,2);
memcpy(&sqseed,&rd[4],2);
printf("sq: %u, sqseed %u\n",sq,sqseed);
//sq=34567;
//sqseed=65345;
memcpy(key,"kkk3456789012345678901234567890123456789012345678901234567890kkk",64);
strcpy(ipdestination,"116.203.220.251");
strcpy(ipdestination,"0.0.0.0");
portdestination=10000;
printf("Sending to: %s port: %d\n",ipdestination,portdestination);
//INIT SVTP CONTEXT
if(bb_svtp_init(&svtp,sq,sqseed,key,ipdestination,portdestination)==0){
  printf("%s\n",svtp.error);
  exit(0);
}
//CLIENT PROCESS
if(f==0){
     FILE *f;
     int plen,tlen;
     f=fopen("test16bit.pcm","rb");
     printf("Sending data..\n");
    //SENDING DATA PACKET
    tlen=0;
    while(1){
          plen=fread(&datapacket,1,960,f);
          if(plen<=0)
             break;
          printf("sq: %d\n",svtp.sq);
          //bb_hexdump("datapacket",datapacket,plen);
          if(!bb_svtp_send_data(&svtp,datapacket,plen)){
            printf("%s\n",svtp.error);
            break;
        }
        tlen=tlen+plen;
        usleep(60000); //simulate a real audio flow (one packet each 60ms)
    }
    fclose(f);
    printf("Total bytes sent: %d\n",tlen);
}
//SERVER PROCESS

if(f==1){
    FILE *fptr;
    time_t st,tt;
    st=time(NULL);
    fptr = fopen("svtp.log","wb");
    while(1){
      tt=time(NULL);
      if(tt-st>=10) break;
      memset(datapacket,0x0,2048);
      lenrdp=bb_svtp_read_data(&svtp,datapacket,2048);
      if(lenrdp<=0){
            printf("Error: %s\n",svtp.error);
            continue;
      }
      bb_hexdump("Data packet received:",datapacket,lenrdp);
      x=fwrite(datapacket, lenrdp, 1, fptr);
      printf("Received - sq: %d lenrdp: %d \n",svtp.sq,lenrdp);
      st=time(NULL);
   }
   fclose(fptr);
}

//FREE SVTP BUFFERS
bb_svtp_free(&svtp);
}*/
/**
* FUNCTION TO READ SVTP DATA PACKET
*/
int bb_svtp_read_data(SVTP *svtp,unsigned char *datapacket,unsigned short int dplen){
    unsigned char buf[8192];
    unsigned char cbuf[8192];
    unsigned char cbuf2[8192];
    unsigned char bufhmac[8192];
    int bytesrcv,declen,maxlen;
    unsigned int sq,ssq;
    unsigned char buf1[32];
    unsigned char iv[32];
    unsigned char hmac[32];
    unsigned char punchbuf[256];
    memset(datapacket,0x0,dplen);
    short int pcmaudio[2048];
    int i,ix,old,isq,z,bytesent;
    time_t st,tt;
    if(dplen>2034){  //10 bytes are used for hmac and 4 for sequence counter
      fprintf(stderr, "5900 - bb-svtp.c: dplen is too long\n");
      return(-1);
    }
    //PUNCH HOLE IF NOT YET DONE
    if(svtp->portpunched==0){
         if(verbose) printf("bb_svtp.c - PUNCH HOLE: sending 5 udp packets to open NAT\n");
         bb_crypto_random_data(punchbuf);
         for(i=0;i<=4;i++){
           bytesent=sendto(svtp->fdsocket,punchbuf,64,0,(struct sockaddr *)&svtp->destination,sizeof(svtp->destination));
           if(bytesent<=0 && verbose) printf("bb-svtp.c: Error sending punch-hole data\n");
         }
         svtp->portpunched=1;
    }
    //END PUNCHHOLE
    START:
    st=time(NULL);
    while(1){
        /* BUFFERING REMOVED BECAUSE ADDING DELAY IN CASE OF REORDERING, BETTER TO DROP 60ms packet
        //CHECK BUFFER FOR PACKETS
        cbuf=bb_svtp_pull_datapacket_to_buffer(&svtp->svtpbuf[0],(svtp->sq+1),&z);
        if(cbuf!=NULL){
           if(z>dplen)
              maxlen=dplen;
           else
              maxlen=z;
           memcpy(datapacket,cbuf,maxlen);
           svtp->sq=svtp->sq+1;
           if(cbuf!=NULL){
               free(cbuf);
               cbuf=NULL;
           }
           if(verbose) printf("8670 - packet pulled from buffer %d\n",svtp->sq);
           return(maxlen);
        }*/
        // READ FROM SOCKET
        bytesrcv=recvfrom(svtp->fdsocket, buf, dplen+4, 0, NULL, NULL) ;
        tt=time(NULL);
        if(bytesrcv<=0 && tt-st<3){
            //printf("sleeping 10ms sec\n");
            usleep(10000);
            continue;
        }
        break;
    }
    if(bytesrcv==-1){
         strcpy(svtp->error,"5806 - Error receiving data packet - bb_svtp.c [");
         strncat(svtp->error,strerror(errno),64);
         strcat(svtp->error,"]");
         return(-1);
    }
    if(bytesrcv==0){
         strcpy(svtp->error,"5807 - Timeout receiving data packet (3 sec)- bb_svtp.c ");
         return(-1);
    }
    //printf("bytesrcv: %d\n",bytesrcv);
    //bb_hexdump("Encrypted data packet",buf,bytesrcv);
    //GET SEQUENCE NUMBER
    memcpy(&ssq,buf,4);
    sq=ssq ^ svtp->sqseed;
    //printf("Sequence Number: %u\n",sq);
    // GET IV
    memcpy(buf1,svtp->key,16);
    memcpy(&buf1[16],&ssq,4);
    //bb_hexdump("iv base",buf1,20);
    bb_sha3_256(buf1,20,iv);
    //bb_hexdump("iv:",iv,16);
    //DECRYPT
    if(!bb_decrypt_buffer_aes_ofb(cbuf2,&declen,&buf[4],bytesrcv-4,svtp->key,iv)){
        strcpy(svtp->error,"5808 - Error decrypting aes -  bb_svtp.c");
        return(-1);
    }
    if(!bb_decrypt_buffer_chacha20(cbuf,&declen,cbuf2,bytesrcv-4,svtp->key,iv)){
        strcpy(svtp->error,"5808 - Error decrypting chacha20 -  bb_svtp.c");
        return(-1);
    }
    z=declen-10;
    if(z<0){
        strcpy(svtp->error,"5809 - Error decrypting data packet - bb_svtp.c");
        return(-1);
    }
    //bb_hexdump("clear datapacket",cbuf,declen-10);
    //verifing HMAC
    memcpy(bufhmac,svtp->key,64);
    memcpy(&bufhmac[64],cbuf,declen);
    //bb_hexdump("base of sha3",bufhmac,54+declen);
    bb_sha3_256(bufhmac,54+declen,hmac);
    //bb_hexdump("hmac received",&cbuf[z],10);
    //bb_hexdump("hmac calculated",hmac,10);
    if(memcmp(hmac,&cbuf[z],10)!=0){
        strcpy(svtp->error,"5810 - Error authenticating packet data - bb_svtp.c");
        return(-1);
    }
    if(z>dplen)
     maxlen=dplen;
    else
     maxlen=z;
    //OUT OF SEQUENCE IS DROPPED
    if(sq<svtp->sq){
        memset(datapacket,0x0,dplen);
        goto START;
    }
    //DECODING
    z=opus_decode(svtp->opusdecoder,cbuf,maxlen,&pcmaudio[0],2048,0);
    if(z<=0){
        memset(datapacket,0x0,dplen);
        strcpy(svtp->error,"6510 - Error decoding audio packet");
        return(-1);
    }
    memcpy(datapacket,&pcmaudio[0],z*2);
    svtp->sq=sq;
    return(z*2);
}

/**
* SEND SVTP DATA PACKET
*/
int bb_svtp_send_data(SVTP *svtp,unsigned char *datapacketorigin,unsigned short int dplen){
    unsigned char buf[2048];
    unsigned char buf2[2048];
    unsigned char dphmac[2048];
    unsigned int ssq;
    unsigned char hmac[32];
    unsigned char iv[32];
    unsigned char buf1[32];
    int enclen,encodedlen;
    ssize_t bytesent;
    short int pcmaudio[2048];
    unsigned char datapacket[2048];
    if(dplen>4096){
      fprintf(stderr,"Data packet too long\n");
      return(0);
    }
    //ENCODE DATAPACKET OPUS CODEC
     memcpy(pcmaudio,datapacketorigin,dplen);
     encodedlen=opus_encode(svtp->opusencoder,&pcmaudio[0],(dplen/2),datapacket,2048);
     dplen=encodedlen;
     if(encodedlen<=0){
        strcpy(svtp->error,"5798 - Error encoding audio data packet");
        return(0);
    }
    //END ENCODING
    //HMAC-SHA3
    memcpy(buf,svtp->key,64);
    memcpy(&buf[64],datapacket,dplen);
    bb_sha3_256(buf,dplen+64,hmac);
    
    //SCRAMBLE SEQUENCE NUMBER
    ssq=svtp->sq ^ svtp->sqseed;
    memcpy(buf,&ssq,4);
    //IV
    memcpy(buf1,svtp->key,16);
    memcpy(&buf1[16],&ssq,4);
    bb_sha3_256(buf1,20,iv);
    //ENCRYPT AES 256 + CHACHA20
    memcpy(dphmac,datapacket,dplen);
    memcpy(&dphmac[dplen],hmac,10);
    if(!bb_encrypt_buffer_aes_ofb(dphmac,(int)(dplen+10),buf2,&enclen,svtp->key,iv)){
        strcpy(svtp->error,"5802 - Error encrypting chacha20 - bb_svtp.c");
        return(0);
    }
    if(!bb_encrypt_buffer_chacha20(buf2,(int)(dplen+10),&buf[4],&enclen,svtp->key,iv)){
        strcpy(svtp->error,"5802 - Error encrypting chacha20 - bb_svtp.c");
        return(0);
    }
    //SEND UDP DATAGRAM TO DESTINATION
    bytesent=sendto(svtp->fdsocket,buf,enclen+4,0,(struct sockaddr *)&svtp->destination,sizeof(svtp->destination));
    if(bytesent==-1){
        strcpy(svtp->error,"5803 - Error sending data packet - bb_svtp.c");
        return(0);
    }
    //UPDATE CONTEXT
    svtp->sq++;
    //CLEAN UP AND RETURN
    return(1);
}

/**
* INIT OF SVTP CONTEXT
*/
int bb_svtp_init(SVTP * svtp,unsigned int sq,unsigned int sqseed,unsigned char *key,char *ipdestination,unsigned short int portdestination){
    int i;
    int optval ;
    svtp->sq=sq;
    svtp->sqseed=sqseed;
    svtp->portpunched=0;
    memcpy(svtp->key,key,64);
    memset(svtp->error,0x0,128);
    //CREATE SOCKET
    svtp->fdsocket=socket(AF_INET, SOCK_DGRAM, 0);
    if(svtp->fdsocket<=0){
        strcpy(svtp->error,"5850 - error allocating UDP socket");
        return(0);
    }
    if(fcntl(svtp->fdsocket, F_SETFL, O_NONBLOCK)<0){
        strcpy(svtp->error,"5870 - error setting to NON-BLOCKING UDP socket");
        return(0);
    }
    optval = 1;
    setsockopt(svtp->fdsocket, SOL_SOCKET, SO_REUSEADDR, (const void *)&optval , sizeof(int));
    // SET DESTINATION ADDRESS
    memset(&svtp->destination,0x0,sizeof(svtp->destination));
    svtp->destination.sin_family = AF_INET;
    svtp->destination.sin_port = htons(portdestination);
    svtp->destination.sin_addr.s_addr=htonl(INADDR_ANY);
    //BINDING
    svtp->portbinded=0;
    if(bind(svtp->fdsocket, (const struct sockaddr *)&svtp->destination, sizeof(svtp->destination))==-1){
        strcpy(svtp->error,"5804 - Error binding socket - bb_svtp.c [");
        strncat(svtp->error,strerror(errno),64);
        strcat(svtp->error,"] ipaddress: ");
        strcat(svtp->error,ipdestination);
    }
    else{
           svtp->portbinded=1;
    }
    //SET DESTINATION ADDRESS
    if(strcmp(ipdestination,"0.0.0.0")==0){
            svtp->destination.sin_addr.s_addr=htonl(INADDR_ANY);
    }
    else{
      if(!inet_pton(AF_INET, ipdestination, &(svtp->destination.sin_addr))){
          strcpy(svtp->error,"5851 - invalid ip adress for udp socket");
          return(0);
      }
    }
    //** ALLOCATE ENCODER/DECODER FOR OPUS CODEC
    int fs=48000;
    int channels=1;
    int result=0;
    //ENCODER
    svtp->opusencoder=opus_encoder_create(fs,channels,OPUS_APPLICATION_VOIP,&result);
    if(result!=0){
     strcpy(svtp->error,"5852 - Error creating Opus encoder");
     return(0);
    }
    result=opus_encoder_ctl(svtp->opusencoder,OPUS_SET_VBR(0));
    if(result!=0){
     strcpy(svtp->error,"5853 - Error setting OPUS constant bit rate");
     return(0);
    }
/*    result=opus_encoder_ctl(svtp->opusencoder,OPUS_SET_MAX_BANDWIDTH(OPUS_BANDWIDTH_FULLBAND));
    if(result!=0){
     strcpy(svtp->error,"5854 - Error setting OPUS max bandwidth");
     return(0);
    }
    result=opus_encoder_ctl(svtp->opusencoder,OPUS_SET_BITRATE(128000));
    if(result!=0){
     strcpy(svtp->error,"5854 - Error setting OPUS bitrate");
     return(0);
    }*/
    //DECODER
    svtp->opusdecoder=opus_decoder_create(fs,channels,&result);
    if(result!=0){
     strcpy(svtp->error,"5855 - Error creating Opus decoder");
     return(0);
    }
    //*** INIT INTERNAL BUFFER
    for(i=0;i<=99;i++){
       svtp->svtpbuf[i].microtime=0;
       svtp->svtpbuf[i].sq=0;
       svtp->svtpbuf[i].dp=NULL;
    }
    return(1);
}
//** FUNCTION TO FREE THE ALLOCATED SPACE
void bb_svtp_free(SVTP * svtp){
   int i;
   close(svtp->fdsocket);
   opus_encoder_destroy(svtp->opusencoder);
   opus_decoder_destroy(svtp->opusdecoder);
   for(i=0;i<99;i++){
     if(svtp->svtpbuf[i].dp!=NULL){
       free(svtp->svtpbuf[i].dp);
       svtp->svtpbuf[i].dp=NULL;
     }
   }
   memset(svtp,0x0,sizeof(svtp));
   return;
}

/**
* FUNCTION TO PULL A CERTAIN PACKET
*/
unsigned char * bb_svtp_pull_datapacket_to_buffer(struct svtpbuffer *svtpbuf,unsigned int sq,int *buflen){
  int i,ii;
  unsigned char *r;
  long t;
  t=bb_get_microtime();
  for(i=0;i<=99;i++){
    if(svtpbuf[i].sq<=sq || (svtpbuf[i].sq>sq && t-svtpbuf[i].microtime>120)){
      r=svtpbuf[i].dp;
      *buflen=svtpbuf[i].dplen;
      for(ii=i;ii<99;ii++){
        svtpbuf[ii].microtime=svtpbuf[ii+1].microtime;
        svtpbuf[ii].sq=svtpbuf[ii+1].sq;
        svtpbuf[ii].dp=svtpbuf[ii+1].dp;
        svtpbuf[ii].dplen=svtpbuf[ii+1].dplen;
        if(svtpbuf[ii].microtime==0)
          break;
      }
      svtpbuf[ii].microtime=0;
      svtpbuf[ii].sq=0;
      svtpbuf[ii].dp=NULL;
      svtpbuf[ii].dplen=0;
      return(r);
    }
    if(svtpbuf[i].sq>sq || svtpbuf[i].sq==0)
      return(NULL);
  }
}

/**
* FUNCTION TO PUSH A DATA PACKET IN THE BUFFER
*/
void bb_svtp_push_datapacket_to_buffer(struct svtpbuffer *svtpbuf,unsigned int sq,unsigned char *datapacket,int dplen){
  int i,freeslot,nextslot;
  int ml=99;
  //SEARCH FREE SLOT AND POSITION
  freeslot=-1;
  nextslot=-1;
  for(i=0;i<=ml;i++){
     //AVOID DUPLICATED PACKETS
     if(svtpbuf[i].sq==sq)
       return;
    // MARK POSITION
     if(svtpbuf[i].sq>sq && nextslot==-1)
         nextslot=i;
    // FREE SLOT FOUND
    if(svtpbuf[i].microtime==0){
      freeslot=i;
      break;
    }
  }
  //SHIFT 1 SLOT FROM TOP WHEN FULL AND IT MUST BE ADDED ON TOP
  if(freeslot==-1 && nextslot==-1){
      freeslot=ml;
      free(svtpbuf[0].dp);
      for(i=0;i<freeslot;i++){
      svtpbuf[i].microtime=svtpbuf[i+1].microtime;
      svtpbuf[i].sq=svtpbuf[i+1].sq;
      svtpbuf[i].dp=svtpbuf[i+1].dp;
      svtpbuf[i].dplen=svtpbuf[i+1].dplen;
      }
  }
  //INSERT IN A CERTAIN POSITION DIFFERENT FROM 0, WHEN BUFFER FULL
  if(freeslot==-1 && nextslot>=1){
      freeslot=nextslot-1;
      free(svtpbuf[0].dp);
      for(i=0;i<nextslot;i++){
      //free(svtpbuf[i].dp);
      svtpbuf[i].microtime=svtpbuf[i+1].microtime;
      svtpbuf[i].sq=svtpbuf[i+1].sq;
      svtpbuf[i].dp=svtpbuf[i+1].dp;
      svtpbuf[i].dplen=svtpbuf[i+1].dplen;
      }
  }
  //IF THE NEXTSLOT IS 0, WE DO NOT ADD
  if(freeslot==-1 && nextslot==0){
      return;
  }
  //MOVE FREE SLOT TO POSITION IF HIGHER
  if(freeslot>nextslot && nextslot>-1){
    for(i=freeslot;i>=nextslot;i--){
          svtpbuf[i].microtime=svtpbuf[i-1].microtime;
          svtpbuf[i].sq=svtpbuf[i-1].sq;
          svtpbuf[i].dp=svtpbuf[i-1].dp;
          svtpbuf[i].dplen=svtpbuf[i-1].dplen;
    }
    freeslot=nextslot;
  }
  //SET THE DATA
  svtpbuf[freeslot].microtime=bb_get_microtime();
  svtpbuf[freeslot].sq=sq;
  svtpbuf[freeslot].dp=malloc(dplen);
  if(svtpbuf[freeslot].dp!=NULL){
      memcpy(svtpbuf[freeslot].dp,datapacket,dplen);
      svtpbuf[freeslot].dplen=dplen;
  }
  else{
    fprintf(stderr,"8765 - Error allocating memory\n");
    svtpbuf[freeslot].microtime=0;
    svtpbuf[freeslot].sq=0;
    svtpbuf[freeslot].dplen=0;
  }
  return;
}
/**
* FUNCTION TO READ MILLISECONDS FROM EPOCH
*/
long bb_get_microtime(void){
  struct timeval time;
  gettimeofday(&time, NULL);
  return time.tv_sec * 1000 + time.tv_usec / 1000;
}
/**
* FUNCTION TO DUMP SVTP BUFFER FOR DEBUG
*/
void bb_svtp_buffer_dump(struct svtpbuffer *svtpbuf){
      int i;
      for(i=0;i<=99;i++){
          if(svtpbuf[i].microtime>0){
          printf("i: %d\n",i);
          printf("microtime: %ld\n",svtpbuf[i].microtime);
          printf("sq: %d\n",svtpbuf[i].sq);
          printf("dplen: %d\n",svtpbuf[i].dplen);
          bb_hexdump("datapacket",svtpbuf[i].dp,svtpbuf[i].dplen);
          
        }
      }
      return;
}
//#include "../bb_sha.c"
//#include "../bb_encrypt_decrypt_buffer_chacha20.c"
//#include "../bb_hexdump.c"
//#include "../bb_encrypt_decrypt_buffer_aes_ofb.c"
//#include "../bb_crypto_randomdata.c"
//*** ORIGIN: bb_svtp.c
//*******************************************************************
//*** SHIELDED VIDEO TRANSPORT PROTOCOL (EVOLUTION OF SRTP)
//*******************************************************************
/*#include "blackbox.h"
int StatusVideoCall=0;
// MAIN
int verbose=1;
void main(int argc,char *argv[]){
SWTP swtp;
int x,i,f,lenrdp;
unsigned int sq,sqseed;
unsigned char key[64];
unsigned char datapacket[8192];
char ipdestination[64];
unsigned short int portdestination;
char rd[128];
//CHECK PARAMETER
f=0;
if(argc>1){
    if(strcmp(argv[1],"server")==0){
        printf("Server Starting\n");
        f=1;
    }else{
        f=0;
    }
}
if(f==0) printf("Client Starting\n");
//DATA EXCHANGE IN THE SIGNAL CHANNEL
bb_crypto_random_data(key);
bb_hexdump("key",key,64);
//bb_crypto_random_data(rd);
strcpy(rd,"ABCDEF0123456789012322354454");
memset(&sq,0x0,4);
memset(&sqseed,0x0,4);
memcpy(&sq,&rd,2);
memcpy(&sqseed,&rd[4],2);
printf("sq: %u, sqseed %u\n",sq,sqseed);
sq=34567;
sqseed=65345;
memcpy(key,"kkk3456789012345678901234567890123456789012345678901234567890kkk",64);
if(f==0)
  strcpy(ipdestination,"95.216.148.199");
else
  strcpy(ipdestination,"0.0.0.0");
portdestination=50000;
printf("Sending to: %s port: %d\n",ipdestination,portdestination);
//INIT SVTP CONTEXT
if(bb_swtp_init(&swtp,sq,sqseed,key,ipdestination,portdestination)==0){
  printf("%s\n",swtp.error);
  exit(0);
}*/
/*
// TEST PUSH PACKETS
//bb_swtp_dump_buffer(&swtp.buf[0]);
//exit(0);
strcpy(datapacket,"hello");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,1);
strcpy(datapacket,"hello 2");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,2);
strcpy(datapacket,"hello 3");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,3);
strcpy(datapacket,"hello 4");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,4);
strcpy(datapacket,"hello 5");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,5);
strcpy(datapacket,"hello 10");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,10);
strcpy(datapacket,"hello 11");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,11);
strcpy(datapacket,"hello 12");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,12);
strcpy(datapacket,"hello 6");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,6);
strcpy(datapacket,"hello 7");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,7);
strcpy(datapacket,"hello 8");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,8);
strcpy(datapacket,"hello 9");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,9);
bb_swtp_pull_buffer(&swtp.buf[0],datapacket,4);
bb_hexdump("pulled",datapacket,508);
strcpy(datapacket,"hello 13");
bb_swtp_push_buffer(&swtp.buf[0],datapacket,13);
bb_swtp_dump_buffer(&swtp.buf[0]);
exit(0);
*/
/*
//CLIENT PROCESS
if(f==0){
     FILE *f;
     int plen,tlen;
     f=fopen("testh265.mp4","rb");
     printf("Sending data..\n");
    //SENDING DATA PACKET
    tlen=0;
    while(1){
          memset(datapacket,0x0,1024);
          plen=fread(&datapacket,1,494,f);
          if(plen<=0)
             break;
          printf("sq: %d\n",swtp.sq);
          //bb_hexdump("datapacket",datapacket,plen);
          if(!bb_swtp_send_data(&swtp,datapacket)){
            printf("%s\n",swtp.error);
            break;
        }
        tlen=tlen+plen;
        usleep(1000);
    }
    fclose(f);
    printf("Total bytes sent: %d\n",tlen);
}
//SERVER PROCESS

if(f==1){
    FILE *fptr;
    time_t st,tt;
    st=time(NULL);
    fptr = fopen("swtp.log","wb");
    while(1){
      tt=time(NULL);
      if(tt-st>=10) break;
      memset(datapacket,0x0,2048);
      lenrdp=bb_swtp_read_data(&swtp,datapacket);
      if(lenrdp<=0){
            printf("Error: %s\n",swtp.error);
            continue;
      }
      //bb_hexdump("Data packet received:",datapacket,lenrdp);
      x=fwrite(datapacket, lenrdp, 1, fptr);
//      printf("Received - sq: %d lenrdp: %d \n",swtp.sq,lenrdp);
      st=time(NULL);
   }
   fclose(fptr);
}

//FREE SVTP BUFFERS
bb_swtp_free(&swtp);
}*/
/**
* READ SVTP DATA PACKET
*/
int bb_swtp_read_data(SWTP *swtp,unsigned char *datapacket){
    unsigned short int dplen=504;
    unsigned char cbuf[1024];
    unsigned char cbuf2[1024];
    unsigned char bufhmac[1024];
    int bytesrcv,declen,maxlen;
    unsigned int sq,ssq;
    unsigned char buf1[32];
    unsigned char iv[32];
    unsigned char hmac[32];
    unsigned char punchbuf[256];
    unsigned int newsq;
    memset(datapacket,0x0,dplen);
    int i,ix,old,isq,z,bytesent;
    time_t st,tt;
    char buf[1024];
    START:
    //PUNCH HOLE IF NOT YET DONE
    if(swtp->portpunched==0){
         if(verbose) printf("58507 - bb_swtp.c - PUNCH HOLE: sending 5 udp packets to open NAT\n");
         bb_crypto_random_data(punchbuf);
         for(i=0;i<=4;i++){
           bytesent=sendto(swtp->fdsocket,punchbuf,64,0,(struct sockaddr *)&swtp->destination,sizeof(swtp->destination));
           if(bytesent<=0 && verbose) printf("bb-swtp.c: Error sending punch-hole data\n");
         }
         swtp->portpunched=1;
    }
    //END PUNCHHOLE
    // PULL FROM BUFFER IF AVAILABLE THE DATAPACKET
    newsq=bb_swtp_pull_buffer(&swtp->buf[0],datapacket,swtp->sq+1);
    if(newsq>0){
        swtp->sq=newsq;
        if(verbose) printf("Pulled from buffer sq: %u\n",newsq);
        return(494);
    }
    
    st=time(NULL);
    while(1){
        // READ FROM SOCKET
        bytesrcv=recvfrom(swtp->fdsocket, buf, 508, 0, NULL, NULL) ;
        tt=time(NULL);
        if(bytesrcv<=0 && tt-st<10){
            //printf("sleeping 1ms \n");
            usleep(1000);
            continue;
        }
        break;
    }
    if(bytesrcv==-1){
         strcpy(swtp->error,"58509 - Error receiving data packet - bb_swtp.c [");
         strncat(swtp->error,strerror(errno),64);
         strcat(swtp->error,"]");
         return(-1);
    }
    if(bytesrcv==0){
         strcpy(swtp->error,"58510 - Timeout receiving data packet - bb_swtp.c ");
         return(-1);
    }
    //printf("bytesrcv: %d\n",bytesrcv);
    //bb_hexdump("Encrypted data packet",buf,bytesrcv);
    //GET SEQUENCE NUMBER
    memcpy(&ssq,buf,4);
    sq=ssq ^ swtp->sqseed;
    //printf("Sequence Number: %u\n",sq);
    // GET IV
    memcpy(buf1,swtp->key,16);
    memcpy(&buf1[16],&ssq,4);
    //bb_hexdump("iv base",buf1,20);
    bb_sha3_256(buf1,20,iv);
    //bb_hexdump("iv:",iv,16);
    //DECRYPT
    if(!bb_decrypt_buffer_aes_ofb(cbuf2,&declen,&buf[4],bytesrcv-4,swtp->key,iv)){
        strcpy(swtp->error,"58513 - Error decrypting aes -  bb_swtp.c");
        return(-1);
    }
    if(!bb_decrypt_buffer_chacha20(cbuf,&declen,cbuf2,bytesrcv-4,swtp->key,iv)){
        strcpy(swtp->error,"58514 - Error decrypting chacha20 -  bb_swtp.c");
        return(-1);
    }
    z=declen-10;
    //printf("declen: %d z: %d\n",declen,z);
    if(z<0){
        strcpy(swtp->error,"58515 - Error decrypting data packet - bb_swtp.c");
        return(-1);
    }
    //bb_hexdump("clear datapacket",cbuf,declen-10);
    //verifing HMAC
    memcpy(bufhmac,swtp->key,64);
    memcpy(&bufhmac[64],cbuf,declen);
    //bb_hexdump("base of sha3",bufhmac,54+declen);
    bb_sha3_256(bufhmac,54+declen,hmac);
    //bb_hexdump("hmac received",&cbuf[z],10);
    //bb_hexdump("hmac calculated",hmac,10);
    if(memcmp(hmac,&cbuf[z],10)!=0){
        strcpy(swtp->error,"58517 - Error authenticating packet data - bb_swtp.c");
        return(-1);
    }
    if(z>dplen)
     maxlen=dplen;
    else
     maxlen=z;

    memcpy(datapacket,cbuf,declen-10);
    // IF SQ IS A FUTURE PACKET, WE STORE IN BUFFER AND RETURN -3
    if(sq>swtp->sq+1)
    {
       bb_swtp_push_buffer(&swtp->buf[0],datapacket,sq);
       if(verbose) printf("Pushed to buffer sq: %u\n",sq);
       return(-3);
    }
    // IF SQ IS PREVIOUS SQ OF THE CURRENT ONE, WE RETURN -4
    if(sq<swtp->sq){
        if(verbose) printf("Old packet, dropped: %u\n",sq);
       return(-4);
    }
       
    //SQ IS OK WE RETURN DATAPACKET AND LENGTH OF THE DATA
    swtp->sq=sq;
    return(declen-10);
}

/**
* SEND SWTP DATA PACKET 494 bytes padded with \0 if shorter
* TOTAL UDP SIZE IS 508 BYTES (4 sequence and 10 hmac)
*/
int bb_swtp_send_data(SWTP *swtp,unsigned char *datapacket){
    unsigned short int dplen=494;
    unsigned short int tdplen;
    unsigned int ssq;
    unsigned char hmac[32];
    unsigned char iv[32];
    unsigned char buf1[32];
    unsigned char buf[1024];
    unsigned char buf2[1024];
    unsigned char dphmac[1048];
    int enclen,encodedlen;
    ssize_t bytesent;
    if(dplen>494){
        strcpy(swtp->error,"55800 - Size of the packet is too long, expected max 494 bytes - bb_swtp.c");
        return(0);
    }
    //HMAC-SHA3
    memcpy(buf,swtp->key,64);
    memcpy(&buf[64],datapacket,dplen);
    bb_sha3_256(buf,dplen+64,hmac);
    //bb_hexdump("base of sha3",buf,64+dplen);
    //bb_hexdump("sha3-hmac",hmac,10);
    
    //SCRAMBLE SEQUENCE NUMBER
    ssq=swtp->sq ^ swtp->sqseed;
    memcpy(buf,&ssq,4);
    //bb_hexdump("Scrambled Sequence Number:",buf,4);
    //printf("Scrambled Sequence number in digit: %u\n",ssq);
    //IV
    memcpy(buf1,swtp->key,16);
    memcpy(&buf1[16],&ssq,4);
    //bb_hexdump("iv base",buf1,20);
    bb_sha3_256(buf1,20,iv);
    //bb_hexdump("iv:",iv,16);
    //ENCRYPT AES 256 + CHACHA20
    memcpy(dphmac,datapacket,dplen);
    memcpy(&dphmac[dplen],hmac,10);
    //bb_hexdump("Clear data +hmac:",dphmac,dplen+10);
    if(!bb_encrypt_buffer_aes_ofb(dphmac,(int)(dplen+10),buf2,&enclen,swtp->key,iv)){
        strcpy(swtp->error,"55801 - Error encrypting chacha20 - bb_swtp.c");
        return(0);
    }
    if(!bb_encrypt_buffer_chacha20(buf2,(int)(dplen+10),&buf[4],&enclen,swtp->key,iv)){
        strcpy(swtp->error,"55802 - Error encrypting chacha20 - bb_swtp.c");
        return(0);
    }
    //SEND UDP DATAGRAM TO DESTINATION
    bytesent=sendto(swtp->fdsocket,buf,enclen+4,0,(struct sockaddr *)&swtp->destination,sizeof(swtp->destination));
    if(bytesent==-1){
        strcpy(swtp->error,"55803 - Error sending data packet - bb_swtp.c");
        return(0);
    }
    //printf("Byte sent: %u\n",bytesent);
    //bb_hexdump("SVTP Data packet:",buf,enclen+2);
    //UPDATE CONTEXT
    swtp->sq++;
    //CLEAN UP AND RETURN
    return(1);
}

/**
* INIT OF SWTP CONTEXT
*/
int bb_swtp_init(SWTP * swtp,unsigned int sq,unsigned int sqseed,unsigned char *key,char *ipdestination,unsigned short int portdestination){
    int i;
    int optval ;
    swtp->sq=sq;
    swtp->sqseed=sqseed;
    swtp->portpunched=0;
    swtp->cnt=0;
    memcpy(swtp->key,key,64);
    memset(swtp->error,0x0,128);
    //CREATE SOCKET
    swtp->fdsocket=socket(AF_INET, SOCK_DGRAM, 0);
    if(swtp->fdsocket<=0){
        strcpy(swtp->error,"55850 - error allocating UDP socket");
        return(0);
    }
    if(fcntl(swtp->fdsocket, F_SETFL, O_NONBLOCK)<0){
        strcpy(swtp->error,"55851 - error setting to NON-BLOCKING UDP socket");
        return(0);
    }
    optval = 1;
    setsockopt(swtp->fdsocket, SOL_SOCKET, SO_REUSEADDR, (const void *)&optval , sizeof(int));
    // SET DESTINATION ADDRESS
    memset(&swtp->destination,0x0,sizeof(swtp->destination));
    swtp->destination.sin_family = AF_INET;
    swtp->destination.sin_port = htons(portdestination);
    swtp->destination.sin_addr.s_addr=htonl(INADDR_ANY);
    //BINDING
    swtp->portbinded=0;
    if(bind(swtp->fdsocket, (const struct sockaddr *)&swtp->destination, sizeof(swtp->destination))==-1){
        strcpy(swtp->error,"55852 - Error binding socket - bb_swtp.c [");
        strncat(swtp->error,strerror(errno),64);
        strcat(swtp->error,"] ipaddress: ");
        strcat(swtp->error,ipdestination);
    }
    else{
           swtp->portbinded=1;
    }
    //SET DESTINATION ADDRESS
    if(strcmp(ipdestination,"0.0.0.0")==0){
            swtp->destination.sin_addr.s_addr=htonl(INADDR_ANY);
    }
    else{
      if(!inet_pton(AF_INET, ipdestination, &(swtp->destination.sin_addr))){
          strcpy(swtp->error,"55853 - invalid ip adress for udp socket");
          return(0);
      }
    }
    StatusVideoCall=0;
    for(i=0;i<=9;i++){
       swtp->buf[i].sq=0;
       memset(swtp->buf[i].datapacket,0x0,512);
    }
    return(1);
}
/**
* FUNCTION TO FREE THE ALLOCATED SPACE
*/
void bb_swtp_free(SWTP * swtp){
   close(swtp->fdsocket);
   memset(swtp,0x0,sizeof(swtp));
   return;
}

/**
* STORE A DATA PACKET IN THE SWTPBUFFER
*/
void bb_swtp_push_buffer(struct swtpbuffer  * sb,unsigned char *datapacket, unsigned int sq ){
    int i;
    unsigned int minsq;
    int minptr;
    int freeptr;
    freeptr=-1;
    minptr=-1;
    minsq=4294967295;
    for(i=0;i<=9;i++){
         if(sb[i].sq==0){
            freeptr=i;
            break;
         }
         //printf("step 0: sb[i].sq %u minsq %u\n",sb[i].sq,minsq);
         if(sb[i].sq<minsq){
              minptr=i;
              minsq=sb[i].sq;
              //printf("step 1: minptr %d minsq %u\n",minptr,minsq);
         }
     }
     if(freeptr==-1 && minptr>-1)
        freeptr=minptr;
     if(freeptr==-1){
         //fprintf(stderr,"something went wrong- freeptr:%d minsq %u minptr %d\n",freeptr,minsq,minptr);
         return;
     }
     // STORE THE DATAPACKET
     memcpy(&sb[freeptr].datapacket[0],datapacket,494);
     sb[freeptr].sq=sq;
     //printf("freeptr: %d %d\n",freeptr,sb[freeptr].sq);
     return;
}
// FUNCTION TO PULL A DATA PACKET BY SEQUENCE NUMBER
unsigned int bb_swtp_pull_buffer(struct swtpbuffer  * sb,unsigned char *datapacket, unsigned int sq ){
    int i,freeptr,minptr;
    unsigned int minsq,newsq;
    minptr=-1;
    minsq=-1;
    freeptr=-1;
    for(i=0;i<=9;i++){
         // SEND PACKET FROM BUFFER
         if(sb[i].sq==sq){
              memcpy(datapacket,sb[i].datapacket,494);
              memset(&sb[i].datapacket[0],0x0,512);
              sb[i].sq=0;
              return(sq);
         }
         if(sb[i].sq<minsq && sb[i].sq>0){
             minsq=sb[i].sq;
             minptr=i;
         }
         if(sb[i].sq==0)
             freeptr=i;
     }
     //BUFFER IS FULL, WE DETECT PACKET LOST AND RELEASE THE LOWER SQ
     if(freeptr==-1 && minsq>sq && minptr>-1){
              i=minptr;
              memcpy(datapacket,sb[i].datapacket,494);
              newsq=sb[i].sq;
              memset(&sb[i].datapacket[0],0x0,512);
              sb[i].sq=0;
              return(newsq);
     }
     return(0);
}

// FUNCTION TO DUMP CURRENT BUFFER FOR DEBUGGING PURPOSE
void bb_swtp_dump_buffer(struct swtpbuffer  * sb){
  int i;
  for(i=0;i<=9;i++){
       printf("Ptr: %d  Sq: %u\n",i,sb[i].sq);
       bb_hexdump("DataPacket",sb[i].datapacket,494);
  }
  return;
}
/*
#include "../bb_sha.c"
#include "../bb_encrypt_decrypt_buffer_chacha20.c"
#include "../bb_hexdump.c"
#include "../bb_encrypt_decrypt_buffer_aes_ofb.c"
#include "../bb_crypto_randomdata.c"
*/
//*** ORIGIN: bb_swtp.c
/*#include "blackbox.h"
void  bb_push_messages_client(char *mobilenumber,PushMsgCallback cb);
void pushmessagecallback(int i);
int verbose=0;
unsigned char KeyPush[256];
int PushServerFd=0;
//****** BEGIN EXAMPLE
void main(void){
char serveripaddress[128];
char mobilenumber[64];
strcpy(serveripaddress,"127.0.0.1");
FILE *f=fopen("/dev/shm/blackbox-a9853dba16e986d75f1b74fb8baa559af37661e6fd0465610372f8a61fe595d.key","rb");
fread(KeyPush,1,96,f);
fclose(f);
bb_hexdump("pushkeys",KeyPush,96);

strcpy(mobilenumber,"9660000102");
verbose=1;
int x;
PushMsgCallback cb;
cb=pushmessagecallback;
bb_push_messages_client(mobilenumber,cb);
exit(0);
}
void pushmessagecallback(int i){
   fprintf(stderr,"pushmessagecallback: %d\n",i);
   return;
}
//****** END EXAMPLE */
//*******************************************************************
//*** FUNCTION TO CONNECT TO RECEIVE PUSH MESSAGES
//*******************************************************************
void bb_push_messages_client(char *mobile_number,PushMsgCallback cb){
int port=4444;
char serveripaddress[256];
unsigned char iv[128];
unsigned char signature[128];
unsigned char bufsign[1024];
unsigned char cleardata[1024];
unsigned char packetdata[1024];
unsigned char pushkeys[128];
char mobilenumber[64];
int tlen;
int datalen;
unsigned char encdataaes[256];
unsigned char encdatacamellia[256];
unsigned char encdatachacha[256];
int enclen,blen;
struct timeval timeout;
timeout.tv_sec = 3;
timeout.tv_usec = 0;

START:
PushServerFd=0;
memcpy(pushkeys,KeyPush,96);
strcpy(serveripaddress,"95.183.55.249");
memset(mobilenumber,0x0,64);
strncpy(mobilenumber,mobile_number,64);
bb_crypto_random_data(iv); //64 BYTES OF RANDOM DATA FOR IV
memset(bufsign,0x0,1024);
memcpy(bufsign,iv,48);
memcpy(&bufsign[48],mobilenumber,64);
memcpy(&bufsign[112],pushkeys,96);
tlen=208;
memset(signature,0x0,128);
bb_sha3_512(bufsign,tlen,signature);  //64 BYTES OF SIGNATURE
if(verbose) bb_hexdump("signature",signature,64);
if(verbose) bb_hexdump("bufsign",bufsign,tlen);
memset(cleardata,0x0,1024);
memcpy(cleardata,mobilenumber,64); // 64 BYTES CLEAR DATA WITH MOBILENUMBER PADDED WITH \0
memcpy(&cleardata[64],signature,64); //64 BYTES CLEAR DATA WITH SIGNATURE (TOTAL 128 BYTES)
if(verbose) bb_hexdump("Clear Data",cleardata,128);
memset(encdataaes,0x0,256);
memset(encdatacamellia,0x0,256);
memset(encdatachacha,0x0,256);
if(bb_encrypt_buffer_aes_ofb(cleardata,128,encdataaes,&enclen,pushkeys,iv)==0)
    fprintf(stderr,"26100 - Error during AES encryption\n");
if(bb_encrypt_buffer_camellia_ofb(encdataaes,128,encdatacamellia,&enclen,&pushkeys[32],&iv[16])==0)
    fprintf(stderr,"26100 - Error during AES encryption\n");
if(bb_encrypt_buffer_chacha20(encdatacamellia,128,encdatachacha,&enclen,&pushkeys[64],&iv[32])==0)
    fprintf(stderr,"26100 - Error during CHACHA20 encryption\n");
memset(packetdata,0x0,1024);
memcpy(packetdata,iv,48);
memcpy(&packetdata[48],encdatachacha,128); //PACKET DATA 176 BYTES
memset(signature,0x0,128);
bb_sha3_256(mobilenumber,64,signature); //HASH OF MOBILE NUMBER
memcpy(&packetdata[176],signature,32);  // TOTAL PACKET DATA 208 BYTES
if(verbose) bb_hexdump("IV +vEncrypted data",packetdata,208);
//CONNECTING TO TCP SERVER
int sockfd,w;
struct sockaddr_in servaddr;
sockfd = socket(AF_INET, SOCK_STREAM, 0);
if (sockfd == -1) {
        fprintf(stderr,"26202 - Socket creation failed...\n");
        fprintf(stderr,"26203 - Waiting 15 seconds to try again \n");
        sleep(15);
        close(sockfd);
        goto START;
}
PushServerFd=sockfd;
memset(&servaddr,0x0,sizeof(servaddr));
servaddr.sin_family = AF_INET;
servaddr.sin_addr.s_addr = inet_addr(serveripaddress);
servaddr.sin_port = htons(port);
if (connect(sockfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) != 0) {
        fprintf(stderr,"26203 - connection with the server %s failed...\n",serveripaddress);
        fprintf(stderr,"26203 - Waiting 15 seconds to try again \n");
        sleep(15);
        close(sockfd);
        goto START;
}
//SET TIMEOUT
if (setsockopt (sockfd, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout,sizeof(timeout)) < 0)
        fprintf(stderr,"26200 - setsockopt failed for reading\n");
if (setsockopt (sockfd, SOL_SOCKET, SO_SNDTIMEO, (char *)&timeout,sizeof(timeout)) < 0)
        fprintf(stderr,"26201 - setsockopt failed for writing\n");
//SEND TO PUSH SERVER[
//w=send(sockfd,packetdata, 208,MSG_NOSIGNAL); /// NOT WORKING ON IOS
w=write(sockfd,packetdata, 208);
if(PushServerFd==0) return;
if(w!=208){
       fprintf(stderr,"26204 - writing failed to %s...\n",serveripaddress);
       close(sockfd);
       return;
}
//READING PUSH MESSAGES
char bufr[1024];
int r=0;
while(1){
   r=0;
   memset(bufr,0x0,1024);
   if(verbose) printf("26210 - Waiting for push message\n");
   //r=recv(sockfd,bufr,1024,MSG_NOSIGNAL);
   r=read(sockfd,bufr,176);
   if(PushServerFd==0) return;
   if(r==0){
      if(verbose) printf("26205 - No data in the queue....[%d]\n",r);
      if(PushServerFd==0) return;
      usleep(100000);
      continue;
   }
   if(r<0){
      if(verbose) printf("26205 - Error reading socket,reconnecting...[%d]\n",r);
      if(PushServerFd==0) return;
      if(errno==35){
           usleep(100000);
           continue;
       }else{
           sleep(1);
           goto START;
       }
   }
   if(verbose) bb_hexdump("26211 -Received from Push Server",bufr,r);
   memset(cleardata,0x0,1024);
   bb_decrypt_buffer_chacha20(encdatacamellia,&blen,&bufr[48],r-48,&pushkeys[64],&bufr[32]);
   bb_decrypt_buffer_camellia_ofb(encdataaes,&blen,encdatacamellia,r-48,&pushkeys[32],&bufr[16]);
   bb_decrypt_buffer_aes_ofb(cleardata,&blen,encdataaes,r-48,&pushkeys[0],&bufr[0]);
   if(verbose) bb_hexdump("26212 - Decrypted Data",cleardata,r-48);
   //VERIFY SIGNATURE
   memset(bufsign,0x0,1024);
   memcpy(bufsign,bufr,48);
   memcpy(&bufsign[48],cleardata,64);
   memcpy(&bufsign[112],pushkeys,96);
   tlen=208;
   memset(signature,0x0,128);
   bb_sha3_512(bufsign,tlen,signature);  //64 BYTES OF SIGNATURE
   if(verbose) bb_hexdump("26213  - Data Signed",bufsign,tlen);
   if(verbose) bb_hexdump("26214 - Signature Calculated",signature,64);
   if(verbose) bb_hexdump("26215 - Signature Received",&cleardata[64],64);
   if(memcmp(signature,&cleardata[64],64)!=0){
         fprintf(stderr,"26005 -Signature error push message dropped\n");
   }
   // SEND ACK
    write(sockfd,bufr,10);
   //MAKE CALL BACK
   
   if(strcmp(cleardata,"newmsg")==0){
      if(verbose) printf("26006 - Call back for new msg\n");
      cb(0);
   }
   if(strcmp(cleardata,"voicecall")==0){
      if(verbose) printf("26007 - Call back for new voice call\n");
      cb(1);
   }
   if(strcmp(cleardata,"videocall")==0){
      if(verbose) printf("26007 - Call back for new voice call\n");
      cb(2);
   }
   
}
close(sockfd);
return;
}
//*******************************************************************
//*** FUNCTION TO CLOSE CONNECTION TO RECEIVE PUSH MESSAGES
//*******************************************************************
void bb_push_messages_client_close(void){
 int fd;
 if(PushServerFd>0){
     fd=PushServerFd;
     PushServerFd=0;
     close(fd);
 }
  return;
}
/*#include "../bb_crypto_randomdata.c"
#include "../bb_encode_decode_base64.c"
#include "../bb_sha.c"
#include "../bb_encrypt_decrypt_buffer_chacha20.c"
#include "../bb_encrypt_decrypt_buffer_aes_ofb.c"
#include "../bb_encrypt_decrypt_buffer_camellia_ofb.c"
#include "../bb_hexdump.c"*/

//*** ORIGIN: ../blackbox-server/pushmessages/bb_client_connect_pushserver.c
/*#include "blackbox.h"
//void bb_keystore_userpwd(char *keyuser,unsigned char * pwdconfenc,int pwdconfenclen,char *tmpfolder);
//void bb_keyget_userpwd(char *keyuser,unsigned char * pwdconfenc,int pwdconfenclen,char *tmpfolder);
void main(void){
char pwdconf[8192];
unsigned char pwdconfenc[8192];
char key[96];
int x,j;
FILE *f;
//strcpy(pwdconf,"configuration data in clear text");
memset(pwdconf,0x0,8192);
f=fopen("p.conf","rb");
fread(pwdconf,1,8192,f);
fclose(f);
strcpy(key,"Qwaszx12345.");
bb_hexdump("Original Pwdconf",pwdconf,512);
x=bb_encrypt_pwdconf(pwdconf,key,pwdconfenc,"/tmp");
printf("%d\n",x);
bb_hexdump("Encrypted pwdconf",pwdconfenc,x);
//unlink("/tmp/74d5ae2718bbfa1c7f7a251023ab2f02d3ea39d5e020961e54e20034ccfc710d.enc");
printf("************************************\n");
memset(pwdconf,0x0,8192);
j=bb_decrypt_pwdconf(pwdconfenc,x,"",pwdconf,"/tmp");
printf("j==%d\n",j);
bb_hexdump("Decrypted Pwdconf",pwdconf,j);
}*/
/**
* FUNCTION TO DECRYPT A STORED PPASSWORD
*/
void bb_keyget_userpwd(char *keyuser,unsigned char * pwdconfenc,int pwdconfenclen,char *tmpfolder){
    char key[512];
    unsigned char keyderived[256];
    char hardcoded[256]={"44f1a8100117e9b9d2a3d63d2980758bbaefee1a7f465c51cc609aa514223b95"};
    unsigned char hash[128];
    unsigned char hashbuf[128];
    unsigned char salt[128];
    unsigned char buf[1024];
    unsigned char encdataaes[8192];
    unsigned char encdatacamellia[8192];
    unsigned char encdatachacha[8192];
    unsigned char encdatafile[8192];
    char *tmpfile;
    FILE *f;
    int a,b,kl,rounds,i,enclen,p,ts;
    memset(key,0x0,512);
    memcpy(key,keyuser,strlen(keyuser));
    memcpy(salt,pwdconfenc,64);
    memcpy(buf,salt,64);
    memcpy(&buf[64],hardcoded,strlen(hardcoded));
    p=64+strlen(hardcoded);
    memcpy(&buf[p],pwdconfenc,pwdconfenclen);
    ts=64+strlen(hardcoded)+pwdconfenclen;
     // KEY DERIVATION
    bb_sha3_512(buf,ts,hash);
    memcpy(&a,hash,sizeof(a));
    memcpy(&b,&hash[16],sizeof(b));
    rounds=a*b;
    if(rounds<0) rounds=rounds*(-1);
    while(rounds>1000000)
        rounds=rounds/8;
    for(i=0;i<rounds;i++){
        bb_sha3_512(hash,64,hashbuf);
        memcpy(hash,hashbuf,64);
    }
    bb_sha3_512(hash,64,hashbuf);
    memcpy(&hash[64],hashbuf,32);
    memcpy(keyderived,hash,96); //key derived from hardcoded and pwdconfenc (different for each user)
    kl=512; // KEYUSER PADDED TO 512
    //bb_hexdump("Get USER KEY pwdconfenc:",pwdconfenc,pwdconfenclen);
    //bb_hexdump("Get USER KEY Derived Key:",keyderived,96);
    //bb_hexdump("Get USER KEY Salt key:",salt,64);
    // READ THE KEY FILE TO DECRYPT
    tmpfile=malloc(strlen(tmpfolder)+512);
    strcpy(tmpfile,tmpfolder);
    strcat(tmpfile,"/test/74d5ae2718bbfa1c7f7a251023ab2f02d3ea39d5e020961e54e20034ccfc710d.enc");
    f=fopen(tmpfile,"rb");
    free(tmpfile);
    if(f==NULL) return;
    fread(encdatafile,1,576,f);
    fclose(f);
    //DECRYPT
    if(bb_decrypt_buffer_chacha20(encdatacamellia,&enclen,&encdatafile[64],512,&keyderived[64],&salt[32])==0)
        fprintf(stderr,"28102 - Error during CHACHA20 decryption\n");
    if(bb_decrypt_buffer_camellia_ofb(encdataaes,&enclen,encdatacamellia,512,&keyderived[32],&salt[16])==0)
        fprintf(stderr,"28101 - Error during CAMELLIA decryption\n");
    if(bb_decrypt_buffer_aes_ofb(keyuser,&kl,encdataaes,512,keyderived,salt)==0)
        fprintf(stderr,"28100 - Error during AES decryption\n");
   //bb_hexdump("Keyuser:",keyuser,512);
    return;
}
/**
* FUNCTION TO ENCRYPT AND STORE A PASSWORD
*/
void bb_keystore_userpwd(char *keyuser,unsigned char * pwdconfenc,int pwdconfenclen,char *tmpfolder){
    char key[512];
    unsigned char keyderived[256];
    char hardcoded[256]={"44f1a8100117e9b9d2a3d63d2980758bbaefee1a7f465c51cc609aa514223b95"};
    unsigned char hash[128];
    unsigned char hashbuf[128];
    unsigned char salt[128];
    unsigned char buf[1024];
    unsigned char encdataaes[8192];
    unsigned char encdatacamellia[8192];
    unsigned char encdatachacha[8192];
    unsigned char encdatafile[8192];
    char *tmpfile;
    FILE *f;
    int a,b,kl,rounds,i,enclen,p,ts;
    memset(key,0x0,512);
    memcpy(key,keyuser,strlen(keyuser));
    memcpy(salt,pwdconfenc,64);
    memcpy(buf,salt,64);
    memcpy(&buf[64],hardcoded,strlen(hardcoded));
    p=64+strlen(hardcoded);
    memcpy(&buf[p],pwdconfenc,pwdconfenclen);
    ts=64+strlen(hardcoded)+pwdconfenclen;
     // KEY DERIVATION
    bb_sha3_512(buf,ts,hash);
    memcpy(&a,hash,sizeof(a));
    memcpy(&b,&hash[16],sizeof(b));
    rounds=a*b;
    if(rounds<0) rounds=rounds*(-1);
    while(rounds>1000000)
        rounds=rounds/8;
    for(i=0;i<rounds;i++){
        bb_sha3_512(hash,64,hashbuf);
        memcpy(hash,hashbuf,64);
    }
    bb_sha3_512(hash,64,hashbuf);
    memcpy(&hash[64],hashbuf,32);
    memcpy(keyderived,hash,96); //key derived from hardcoded and pwdconfenc (different for each user)
    //bb_hexdump("key Store pwdconfenc:",pwdconfenc,pwdconfenclen);
    //bb_hexdump("Key Store Derived Key:",keyderived,96);
    //bb_hexdump("Key Store Salt key:",salt,64);
    //bb_hexdump("key Store clear data:",key,512);
    kl=512; // KEYUSER PADDED TO 512
    if(bb_encrypt_buffer_aes_ofb(key,kl,encdataaes,&enclen,keyderived,salt)==0)
        fprintf(stderr,"38100 - Error during AES encryption\n");
    if(bb_encrypt_buffer_camellia_ofb(encdataaes,kl,encdatacamellia,&enclen,&keyderived[32],&salt[16])==0)
        fprintf(stderr,"38101 - Error during CAMELLIA encryption\n");
    if(bb_encrypt_buffer_chacha20(encdatacamellia,kl,encdatachacha,&enclen,&keyderived[64],&salt[32])==0)
        fprintf(stderr,"38102 - Error during CHACHA20 encryption\n");
    //bb_hexdump("Encrypted data",encdatachacha,enclen);
    memcpy(encdatafile,salt,64);
    memcpy(&encdatafile[64],encdatachacha,enclen);
    // SAVE ON DISK THE ENCRYPTED KEYUSER
    tmpfile=malloc(strlen(tmpfolder)+512);
    strcpy(tmpfile,tmpfolder);
    strcat(tmpfile,"/test/74d5ae2718bbfa1c7f7a251023ab2f02d3ea39d5e020961e54e20034ccfc710d.enc");
    f=fopen(tmpfile,"wb");
    free(tmpfile);
    if(f==NULL) return;
    fwrite(encdatafile,1,enclen+64,f);
    fclose(f);
    return;
}
/**
* FUNCTION TO DECRYPT PWDCONF MAKING EXPANSION USING SALTING OF THE KEY
*/
int bb_decrypt_pwdconf(unsigned char *pwdconfenc,int pwdconfenclen,char *keyp,char *pwdconf,char *tmpfolder){
    int pwdconflen;
    unsigned char keyderived[256];
    unsigned char hash[128];
    unsigned char hashbuf[128];
    unsigned char salt[128];
    unsigned char buf[1024];
    unsigned char encdataaes[8192];
    unsigned char encdatacamellia[8192];
    unsigned char encdatachacha[8192];
    unsigned char key[512];
    int a,b,kl,rounds,i,enclen;
    if(strlen(keyp)==0){
        //TRY TO GET FROM KEY FROM ENCRYPTED FILE IF PRESENT
        memset(key,0x0,512);
        bb_keyget_userpwd(key,pwdconfenc,pwdconfenclen,tmpfolder);
        if(strlen(key)==0){
            printf("######## error get key from file\n");
            
            return(0);
        }
    }else{
        strcpy(key,keyp);
    }
    //bb_hexdump("******key Store clear data:",key,512);
    if(strlen(key)>96) key[96]=0;
    kl=strlen(key);
    memcpy(salt,pwdconfenc,64);
    memcpy(buf,salt,64);
    memcpy(&buf[64],key,kl);
    // KEY DERIVATION
    bb_sha3_512(buf,kl+64,hash);
    memcpy(&a,hash,sizeof(a));
    memcpy(&b,&hash[16],sizeof(b));
    rounds=a*b;
    if(rounds<0) rounds=rounds*(-1);
    while(rounds>1000000)
        rounds=rounds/8;
//    printf("rounds: %d\n",rounds);
    for(i=0;i<rounds;i++){
        bb_sha3_512(hash,64,hashbuf);
        memcpy(hash,hashbuf,64);
    }
    bb_sha3_512(hash,64,hashbuf);
    memcpy(&hash[64],hashbuf,32);
    memcpy(keyderived,hash,96);
  //  bb_hexdump("Original key",key,kl);
    //bb_hexdump("Derived Key:",keyderived,96);
    //bb_hexdump("Salt key:",salt,64);
    if(bb_decrypt_buffer_chacha20(encdatacamellia,&enclen,&pwdconfenc[64],pwdconfenclen-64,&keyderived[64],&salt[32])==0)
        fprintf(stderr,"28102 - Error during CHACHA20 decryption\n");
    if(bb_decrypt_buffer_camellia_ofb(encdataaes,&enclen,encdatacamellia,pwdconfenclen-64,&keyderived[32],&salt[16])==0)
        fprintf(stderr,"28101 - Error during CAMELLIA decryption\n");
    if(bb_decrypt_buffer_aes_ofb(pwdconf,&pwdconflen,encdataaes,enclen,keyderived,salt)==0)
    fprintf(stderr,"28100 - Error during AES decryption\n");
    pwdconf[pwdconflen]=0;
    //bb_hexdump("Decrypted data",pwdconf,pwdconflen);
    return(pwdconflen);
}
/**
* FUNCTION TO ENCRYPT PWDCONF MAKING EXPANSION AND SALTING OF THE KEY
*/
int bb_encrypt_pwdconf(char *pwdconf,char *key,unsigned char *pwdconfenc,char *tmpfolder){
    int pwdconflen;
    unsigned char keyderived[256];
    unsigned char hash[128];
    unsigned char hashbuf[128];
    unsigned char salt[128];
    unsigned char buf[1024];
    unsigned char encdataaes[8192];
    unsigned char encdatacamellia[8192];
    unsigned char encdatachacha[8192];
    int a,b,kl,rounds,i,enclen;
    if(strlen(key)>96) key[96]=0;
    kl=strlen(key);
    pwdconflen=strlen(pwdconf);
    if(pwdconflen>8192) return(-1);
    bb_crypto_random_data(salt);
    memcpy(buf,salt,64);
    memcpy(&buf[64],key,kl);
    // KEY DERIVATION
    bb_sha3_512(buf,kl+64,hash);
    memcpy(&a,hash,sizeof(a));
    memcpy(&b,&hash[16],sizeof(b));
    rounds=a*b;
    if(rounds<0) rounds=rounds*(-1);
    while(rounds>1000000)
        rounds=rounds/8;
    //printf("rounds: %d\n",rounds);
    for(i=0;i<rounds;i++){
        bb_sha3_512(hash,64,hashbuf);
        memcpy(hash,hashbuf,64);
    }
    bb_sha3_512(hash,64,hashbuf);
    memcpy(&hash[64],hashbuf,32);
    memcpy(keyderived,hash,96);
    //bb_hexdump("Original key",key,kl);
    //bb_hexdump("Expanded Key:",keyderived,96);
    //bb_hexdump("Salt key:",salt,64);
    if(bb_encrypt_buffer_aes_ofb(pwdconf,pwdconflen,encdataaes,&enclen,keyderived,salt)==0)
        fprintf(stderr,"28100 - Error during AES encryption\n");
    if(bb_encrypt_buffer_camellia_ofb(encdataaes,pwdconflen,encdatacamellia,&enclen,&keyderived[32],&salt[16])==0)
        fprintf(stderr,"28101 - Error during CAMELLIA encryption\n");
    if(bb_encrypt_buffer_chacha20(encdatacamellia,pwdconflen,encdatachacha,&enclen,&keyderived[64],&salt[32])==0)
        fprintf(stderr,"28102 - Error during CHACHA20 encryption\n");
    //bb_hexdump("Encrypted data",encdatachacha,enclen);
    memcpy(pwdconfenc,salt,64);
    memcpy(&pwdconfenc[64],encdatachacha,enclen);
    //STORE THE ENCRYPTED KEY ON DISK
    bb_keystore_userpwd(key,pwdconfenc,enclen+64,tmpfolder);
    // RETURN
    return(64+enclen);
}
/*#include "../bb_sha.c"
#include "../bb_crypto_randomdata.c"
#include "../bb_hexdump.c"
#include "../bb_encrypt_decrypt_buffer_aes_ofb.c"
#include "../bb_encrypt_decrypt_buffer_camellia_ofb.c"
#include "../bb_encrypt_decrypt_buffer_chacha20.c"*/

//*** ORIGIN: bb_encrypt_decrypt_pwdconf.c
/*#define _GNU_SOURCE
#include "blackbox.h"
char DocumentPath[512]={""};
int verbose=1;
//***MAIN EXAMPLE
void main(void){
bb_clean_tmp_files();
}
//*** END EXAMPLE
*/
/***
* FUNCTION TO CLEAN TEMPORARY FILE USED IN CERTAIN CONFIGURATIO TO STORE THE MASTER PASSWORD
*/
void bb_clean_tmp_masterpwdfile(char *tmpfolder){
    char tmpfile[1024];
    FILE *f;
    char rd[1024];
    char randomdata[1024];
    int i;
    strncpy(tmpfile,tmpfolder,512);
    strncat(tmpfile,"/test/74d5ae2718bbfa1c7f7a251023ab2f02d3ea39d5e020961e54e20034ccfc710d.enc",1023);
    bb_crypto_random_data(rd);
    f=fopen(tmpfile,"wb");
    if(f==NULL) return;
    for(i=0;i<=9;i++)
        fwrite(rd,512,1,f);
    fclose(f);
    unlink(tmpfile);
    return;
}

/**
* FUNCTION TO CLEAN TEMPORARY FILES FROM Documents PATH
*/
void bb_clean_tmp_files(void){
//    return; // CANCELLATION SUSPENDED BECAUSE OF SPEED COMPLAINTS (temporary change)
    if(strlen(DocumentPath)==0){
        strncpy(DocumentPath,getenv("HOME"),256);
        strncat(DocumentPath,"/Documents/test/",32);
    }
    if(verbose) printf("18700 - Checking tmp files in: %s\n",DocumentPath);
    if(nftw(DocumentPath, bb_delete_tmp_files, 4096, 0) == -1)
    {
                fprintf(stderr,"18701 - Error reading documents folder: %s",DocumentPath);
                return;
    }
    return;
}
/**
* CALL BACK FROM NFTW() TO SCAN THE DOCUMENTS PATH AND DELETE
*/
static int bb_delete_tmp_files(const char *fpath, const struct stat *sb,int tflag, struct FTW *ftwbuf)
{
    char fn[512];
    char buf[512];
    FILE *f;
    unsigned int fd;
    int x;
    if(tflag == FTW_D){
        return(0);
    }
    strncpy(fn,fpath,511);
    x=strlen(fn);
    if(strcmp(&fn[x-4],".enc")==0){
        strncpy(buf,fn,511);
        buf[x-4]=0;
        if(access(buf,F_OK|R_OK)==0){
            if(verbose) printf("18703 - Deleting: %s\n",buf);
            unlink(buf); //NO OVERWRITE BECAUSE THE SSD WILL WRITE ELSEWHERE IN ANY CASE
        }
        /*strncat(buf,".jpg",16);
        if(access(buf,F_OK|R_OK)==0){
                        if(verbose) printf("18704 - Deleting: %s\n",buf);
                        unlink(buf); //NO OVERWRITE BECAUSE THE SSD WILL WRITE ELSEWHERE IN ANY CASE
                }*/
    }
    memset(buf,0x0,512);
        memset(fn,0x0,512);
    return(0);
}
//#include "../bb_crypto_randomdata.c"
//#include "../bb_sha.c"

//*** ORIGIN: bb_clean_tmp_files.c
/*#define _GNU_SOURCE
#include "blackbox.h"
char DocumentPath[512]={""};
int verbose=1;
//*******************************************************************************
//************* FILE SECURE DELETE DEFINITION
//*******************************************************************************
#define BLOCKSIZE    32769
#define RANDOM_DEVICE    "/dev/urandom"
#define DIR_SEPERATOR    '/'
#define FLUSH        sync()
#define MAXINODEWIPE    4194304
unsigned char write_modes[27][3] = {
    {"\x55\x55\x55"}, {"\xaa\xaa\xaa"}, {"\x92\x49\x24"}, {"\x49\x24\x92"},
    {"\x24\x92\x49"}, {"\x00\x00\x00"}, {"\x11\x11\x11"}, {"\x22\x22\x22"},
    {"\x33\x33\x33"}, {"\x44\x44\x44"}, {"\x55\x55\x55"}, {"\x66\x66\x66"},
    {"\x77\x77\x77"}, {"\x88\x88\x88"}, {"\x99\x99\x99"}, {"\xaa\xaa\xaa"},
    {"\xbb\xbb\xbb"}, {"\xcc\xcc\xcc"}, {"\xdd\xdd\xdd"}, {"\xee\xee\xee"},
    {"\xff\xff\xff"}, {"\x92\x49\x24"}, {"\x49\x24\x92"}, {"\x24\x92\x49"},
    {"\x6d\xb6\xdb"}, {"\xb6\xdb\x6d"}, {"\xdb\x6d\xb6"}
};
unsigned char std_array_ff[3] = "\xff\xff\xff";
unsigned char std_array_00[3] = "\x00\x00\x00";

FILE *devrandom = NULL;
int __internal_bb_sdel_init = 0;
//*******************************************************************************
//***MAIN EXAMPLE
void main(void){
bb_wipe_all_files();
}
//*** END EXAMPLE*/
/**
* FUNCTION TO CLEAN TEMPORARY FILES FROM Documents PATH
*/
void bb_wipe_all_files(void){
    char cache[768];
    if(strlen(DocumentPath)==0){
        strncpy(DocumentPath,getenv("HOME"),256);
        strncat(DocumentPath,"/Documents/test/",32);
    }
    if(verbose) printf("18700 - Checking files in: %s\n",DocumentPath);
    if(nftw(DocumentPath, bb_securedelete_all_files, 8192, 0) == -1)
    {
                fprintf(stderr,"18701 - Error reading documents folder: %s",DocumentPath);
                return;
    }
    strncpy(cache,DocumentPath,512);
    strncat(cache,"cache/",16);
    if(verbose) printf("18710 - Checking files in: %s\n",cache);
    if(nftw(cache, bb_securedelete_all_files, 8192, 0) == -1)
    {
                fprintf(stderr,"18711 - Error reading documents folder: %s",cache);
                return;
    }
    return;
}
/**
* CALL BACK FRO NFTW() TO SCAN THE DOCUMENTS PATH AND DELETE
*/
static int bb_securedelete_all_files(const char *fpath, const struct stat *sb,int tflag, struct FTW *ftwbuf)
{
    FILE *f;
    unsigned int fd;
    char fn[1024];
    int x;
    if(tflag == FTW_D){
        return(0);
    }
    strncpy(fn,fpath,1024);
    if(access(fn,F_OK|R_OK)==0){
        if(verbose) printf("18703 - Secure Deleting: %s\n",fn);
        bb_securedeletefile(fn);
    }
    return(0);
}
//#include "../bb_securedeletefile.c"

//*** ORIGIN: bb_wipe_all_files.c
/**
* DECRYPT FILE TO BUFFER WITH AES256+GCM,CAMELLIA+OFB,CHACHA20
*/
unsigned char * bb_decrypt_file_to_buffer(char * filename,char *key, int *buffer_len){
  unsigned char rd[128];
  char error[128]={""};
  unsigned char keyaes[64];
  unsigned char ivaes[32];
  unsigned char tagaes[64];
  unsigned char keycamellia[64];
  unsigned char ivcamellia[32];
  unsigned char keychacha[64];
  unsigned char ivchacha[32];
  unsigned char keyaesb64[128];
  unsigned char ivaesb64[64];
  unsigned char tagaesb64[64];
  unsigned char keycamelliab64[128];
  unsigned char ivcamelliab64[64];
  unsigned char keychachab64[128];
  unsigned char ivchachab64[64];
  unsigned char * encrypted;
  unsigned char * buffer=NULL;
  int encrypted_len=0;
  encrypted=NULL;
  char *eb=NULL;
  char *ebb=NULL;
  int eb_len;
  int ebb_len;
  int i;
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<64;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  printf("key: %s\n",key);
  //** LOAD KEYS IV AND TAG(AES+GCM)
  if(!bb_json_getvalue("keyaes",key,keyaesb64,64)){
     strcpy(error,"239 - Error reading key AES");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivaes",key,ivaesb64,32)){
     strcpy(error,"240 - Error reading IV AES");
     goto CLEANUP;
  }
 if(!bb_json_getvalue("tagaes",key,tagaesb64,32)){
     strcpy(error,"241 - Error reading TAG AES");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("keycamellia",key,keycamelliab64,64)){
     strcpy(error,"242 - Error reading key CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivcamellia",key,ivcamelliab64,32)){
     strcpy(error,"243 - Error reading IV CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("keychacha",key,keychachab64,64)){
     strcpy(error,"244 - Error reading key CHACHA");
     goto CLEANUP;
  }
  if(!bb_json_getvalue("ivchacha",key,ivchachab64,32)){
     strcpy(error,"245 - Error reading IV CHACHA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keyaesb64,keyaes)){
      strcpy(error,"246 - Error decoding key AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivaesb64,ivaes)){
      strcpy(error,"247 - Error decoding IV AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(tagaesb64,tagaes)){
      strcpy(error,"248 - Error decoding TAG AES");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keycamelliab64,keycamellia)){
      strcpy(error,"249 - Error decoding key CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivcamelliab64,ivcamellia)){
      strcpy(error,"250 - Error decoding IV CAMELLIA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(keychachab64,keychacha)){
      strcpy(error,"251 - Error decoding key CHACHA");
     goto CLEANUP;
  }
  if(!bb_decode_base64(ivchachab64,ivchacha)){
      strcpy(error,"252 - Error decoding IV CHACHA");
     goto CLEANUP;
  }
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - Json Key has been loaded\n");
  // get file size
  struct stat st;
  stat(filename, &st);
  encrypted_len = st.st_size;
  if(encrypted_len<=0){
   strcpy(error,"252a - File to decrypt is empty or not found");
    goto CLEANUP;
  }
  // read the file content in encrypted
  // opening the file
  int ifh;
  int read_size;
  if((ifh = open(filename, O_RDONLY)) == -1) {
     sprintf(error,"252b -  Could not open input file %s, errno = %s\n", filename, strerror(errno));
     goto CLEANUP;
  }
  // allocate space for reading
  encrypted=malloc(encrypted_len+16);
  if(encrypted==NULL){
   strcpy(error,"252c - Error allocating temporary space for encryption");
    goto CLEANUP;
  }
  // read the whole file
  read_size = read(ifh, encrypted, encrypted_len);
  if(read_size<encrypted_len){
   sprintf(error, "252d - Error Reading from the file %s failed. errno = %s\n", filename, strerror(errno));
   goto CLEANUP;
  }
  // close the file handle
  if(ifh != -1) close(ifh);
  // allocate eb for decrypting
  if(verbose) printf("bb_encrypt_decrypt_file_to_buffer.c - bytes read: %ld %ld\n",encrypted_len,read_size);
  eb=malloc(encrypted_len+16);
  eb_len=0;
  if(eb==NULL){
     strcpy(error,"253 - Error allocating eb buffer");
     goto CLEANUP;
  }
  // decrypt layer chacha20
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - eb space allocated\n");
  if(!bb_decrypt_buffer_chacha20(eb,&eb_len,encrypted,encrypted_len,keychacha,ivchacha)){
    strcpy(error,"254 - Error decrypting buffer CHACHA20");
    goto CLEANUP;
  }
  free(encrypted);
  encrypted=NULL;
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - chacha20 done- bytes: %ld\n",eb_len);
  ebb=malloc(encrypted_len+16);
  ebb_len=0;
  if(ebb==NULL){
     strcpy(error,"253 - Error allocating ebb buffer");
     goto CLEANUP;
  }
  // decrypt camellia layer
  if(!bb_decrypt_buffer_camellia_ofb(ebb,&ebb_len,eb,eb_len,keycamellia,ivcamellia)){
    strcpy(error,"254 - Error decrypting the buffer CAMELLIA");
    goto CLEANUP;
  }
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - camellia done - bytes: %ld\n",ebb_len);
  free(eb);
  eb=NULL;
  buffer=malloc(encrypted_len+16);
  //*buffer_len= encrypted_len+16;
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - preparing AES bytes allocated: %ld\n",encrypted_len+16);
  if(buffer==NULL){
     strcpy(error,"254a - Error allocating buffer");
     goto CLEANUP;
  }
  if(!bb_decrypt_buffer_aes_gcm(buffer, buffer_len,ebb,ebb_len,keyaes,ivaes,tagaes)){
    strcpy(error,"255 - Error decrypting the buffer AES");
    goto CLEANUP;
  }
  //if(verbose) hexDump("AES",buffer,*buffer_len);
  if(verbose) printf("bb_encrypt_decrypt_buffer.c - aes done\n");
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<64;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  if(eb!=NULL) free(eb);
  if(ebb!=NULL) free(ebb);
  if(encrypted!=NULL) free(encrypted);
  return(buffer);
  
  CLEANUP:
  fprintf(stderr,"%s\n",error);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<64;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  if(eb!=NULL) free(eb);
  if(ebb!=NULL) free(ebb);
  if(encrypted!=NULL) free(encrypted);
  return(NULL);
}
/**
* ENCRYPT BUFFER WITH AES256+GCM,CAMELLIA+OFB,CHACHA20
* KEY IS GENERATED AN RETURNED IN THE VARIABLE 768 char is required
*/
unsigned char *  bb_encrypt_file_to_buffer(unsigned char * filename,char *key,int * encrypted_len){
  unsigned char rd[128];
  char error[128]={""};
  unsigned char keyaes[64];
  unsigned char ivaes[32];
  unsigned char tagaes[32];
  unsigned char keycamellia[64];
  unsigned char ivcamellia[32];
  unsigned char keychacha[64];
  unsigned char ivchacha[32];
  unsigned char keyaesb64[64];
  unsigned char ivaesb64[64];
  unsigned char tagaesb64[64];
  unsigned char keycamelliab64[128];
  unsigned char ivcamelliab64[64];
  unsigned char keychachab64[128];
  unsigned char ivchachab64[64];
  unsigned char * encrypted=NULL;
  char *buffer=NULL;
  char *eb=NULL;
  char *ebb=NULL;
  int eb_len;
  int ebb_len;
  int i;
  int buffer_len=0;
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  
  // AES+GCM encryption
  if(bb_crypto_random_data(rd)==0){
    strcpy(error,"224 - Error generating true random data");
    goto CLEANUP;
  }
  memcpy(keyaes,&rd[0],32);
  memcpy(ivaes,&rd[32],16);

  // get file size
  struct stat st;
  stat(filename, &st);
  buffer_len = st.st_size;
  if(buffer_len<=0){
   strcpy(error,"225a - File to encrypt is empty or not found");
    goto CLEANUP;
  }
  // read the file content in buffer
  // opening the file
  int ifh;
  int read_size;
  if((ifh = open(filename, O_RDONLY)) == -1) {
     sprintf(error,"225b -  Could not open input file %s, errno = %s\n", filename, strerror(errno));
     goto CLEANUP;
  }
  // allocate space for reading
  buffer=malloc(buffer_len+16);
  if(buffer==NULL){
   strcpy(error,"225c - Error allocating temporary space for encryption");
    goto CLEANUP;
  }
  // read the whole file
  read_size = read(ifh, buffer, buffer_len);
  if(read_size<buffer_len){
   sprintf(error, "225d - Error Reading from the file %s failed. errno = %s\n", filename, strerror(errno));
   goto CLEANUP;
  }
//  bb_hexdump("file",buffer,read_size);
  // close the file handle
  if(ifh != -1) close(ifh);
  // allocate space for destination encrypted buffer
  eb=malloc(buffer_len+16);
  eb_len=0;
  if(eb==NULL){
   strcpy(error,"225 - Error allocating temporary space for encryption");
    goto CLEANUP;
  }
  // encrypt in AES
  if(!bb_encrypt_buffer_aes_gcm(buffer,buffer_len,eb,&eb_len,keyaes,ivaes,tagaes)){
    strcpy(error,"226 - Error encrypting the buffer in AES");
    goto CLEANUP;
  }
  //free buffer
  free(buffer);
  buffer=NULL;
//  bb_hexdump("eb",eb,eb_len);
  // CAMELLIA+OFB encryption
  for(i=0;i<128;i++) rd[0]=0;
  if(bb_crypto_random_data(rd)==0){
    strcpy(error,"227 - Error generating true random data");
    goto CLEANUP;
  }
  memcpy(keycamellia,&rd[0],32);
  memcpy(ivcamellia,&rd[32],16);
  ebb=malloc(buffer_len+16);
  ebb_len=0;
  if(ebb==NULL){
   strcpy(error,"228 - Error allocating temporary space for encryption");
    goto CLEANUP;
  }
  if(!bb_encrypt_buffer_camellia_ofb(eb,eb_len,ebb,&ebb_len,keycamellia,ivcamellia)){
    strcpy(error,"229 - Error encrypting the file CAMELLIA");
    goto CLEANUP;
  }
//  bb_hexdump("ebb",ebb,ebb_len);
  // CHACHA20 encryption
  for(i=0;i<128;i++) rd[0]=0;
  if(bb_crypto_random_data(rd)==0){
    strcpy(error,"230 - Error generating true random data");
    goto CLEANUP;
  }
  free(eb);
  eb=NULL;
  memcpy(keychacha,&rd[0],32);
  memcpy(ivchacha,&rd[32],16);
  encrypted=malloc(buffer_len+16);
  if(encrypted==NULL){
    strcpy(error,"228a - Error allocating temporary space for encryption");
    goto CLEANUP;
  }
  if(!bb_encrypt_buffer_chacha20(ebb,ebb_len,encrypted,encrypted_len,keychacha,ivchacha)){
    strcpy(error,"231 - Error encrypting the file CHACHA20");
    goto CLEANUP;
  }
//  bb_hexdump("encrypted",encrypted,*encrypted_len);
  //* GENERATING KEY IN BASE64 +JSON
  if(!bb_encode_base64(keyaes,32,keyaesb64)){
    strcpy(error,"232 - Error encoding in base64 keyaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivaes,16,ivaesb64)){
    strcpy(error,"233 - Error encoding in base64 ivaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(tagaes,16,tagaesb64)){
    strcpy(error,"234 - Error encoding in base64 tagaes");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keycamellia,32,keycamelliab64)){
    strcpy(error,"235 - Error encoding in base64 keycamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivcamellia,16,ivcamelliab64)){
    strcpy(error,"236 - Error encoding in base64 ivcamellia");
    goto CLEANUP;
  }
  if(!bb_encode_base64(keychacha,32,keychachab64)){
    strcpy(error,"237 - Error encoding in base64 keychacha");
    goto CLEANUP;
  }
  if(!bb_encode_base64(ivchacha,16,ivchachab64)){
    strcpy(error,"238 - Error encoding in base64 ivchacha");
    goto CLEANUP;
  }
  sprintf(key,"{\"keyaes\":\"%s\",\"ivaes\":\"%s\",\"tagaes\":\"%s\",\"keycamellia\":\"%s\",\"ivcamellia\":\"%s\",\"keychacha\":\"%s\",\"ivchacha\":\"%s\"}",keyaesb64,ivaesb64,tagaesb64,keycamelliab64,ivcamelliab64,keychachab64,ivchachab64);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  if(eb!=NULL) free(eb);
  if(ebb!=NULL) free(ebb);
  if(buffer!=NULL) free(buffer);
  return(encrypted);
  
  CLEANUP:
  fprintf(stderr,"%s\n",error);
  for(i=0;i<128;i++) rd[0]=0;
  for(i=0;i<64;i++) keyaes[0]=0;
  for(i=0;i<32;i++) ivaes[0]=0;
  for(i=0;i<64;i++) keycamellia[0]=0;
  for(i=0;i<32;i++) ivcamellia[0]=0;
  for(i=0;i<32;i++) tagaes[0]=0;
  for(i=0;i<128;i++) error[0]=0;
  for(i=0;i<64;i++) keychacha[0]=0;
  for(i=0;i<32;i++) ivchacha[0]=0;
  for(i=0;i<128;i++) keyaesb64[0]=0;
  for(i=0;i<64;i++) ivaesb64[0]=0;
  for(i=0;i<64;i++) tagaesb64[0]=0;
  for(i=0;i<128;i++) keycamelliab64[0]=0;
  for(i=0;i<64;i++) ivcamelliab64[0]=0;
  for(i=0;i<128;i++) keychachab64[0]=0;
  for(i=0;i<64;i++) ivchachab64[0]=0;
  if(eb!=NULL) free(eb);
  if(ebb!=NULL) free(ebb);
  if(buffer!=NULL) free(buffer);
  return(NULL);
}

