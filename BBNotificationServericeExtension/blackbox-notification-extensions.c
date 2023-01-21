#include "blackbox-notification-extensions.h"

//***************************************************************
//*** FUNCTION TO SEND RECEIVED/DELIVERED RECEIPT TO SERVER
//***************************************************************
char * bb_send_received_receipt(char *tokenreceipt){
  char error[512];
  char *reply=NULL;
  char msg[1024];
  char bbhostname[128]={"95.183.55.249"};
  int bbport=443;
  int lenreply;
  if(strlen(tokenreceipt)==0){
    strcpy(error,"1000 - Token receipt is empty");
    goto CLEANUP;
  }
  if(strlen(tokenreceipt)>63){
    strcpy(error,"1001 - Token receipt is too long");
    goto CLEANUP;
  }
  memset(msg,0x0,1024);
  sprintf(msg,"{\"action\":\"messagedelivered\",\"tokenreceipt\":\"%s\"}",tokenreceipt);
  printf("msg: %s\n",msg);
  reply=bb_tls_sendmsg(bbhostname,bbport,msg,&lenreply);
  if(reply==NULL){
    strcpy(error,"1002 - Error sending TLS message");
    goto CLEANUP;
  }
  return(reply);
CLEANUP:
  reply=malloc(1024);
  sprintf(reply,"{\"answer\":\"KO\",\"message\":\%s\"",error);
  return(reply);
}
//**************************************************************
//** FUNCTION TO SEND MESSAGE TO SERVER
//**************************************************************
char * bb_tls_sendmsg(char *hostname,int port,char *msg,int *lenreply){
  //*** PUBLIC KEY OF SERVER CERTIFICATE TO PIN IN DER FORMAT ENCODED IN BASE64 (CHANGE IT FOR PRODUCTION)
    char publickey[]={"MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQARlcZydlINPt/n0SNA+5bA6u/23yLUogaKS6DgMsL90AN3DQnvhdQCROdiOn829ZNjG79HbS89rzWTElN4lBMBMwBu9n5QcWnFwDGJT2RVDpEcjwO+on1+9+aV5T73OuQR/ljtEEBwO9YulgnqamaUDGysRKwtCalsYWl3n0anmVFhb0="};

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
  if(strcmp(tempb64,publickey)!=0){
    sprintf(error,"2011 - Public key is not matching the hard coded %s",hostname);
    close(server);
    goto CLEANUP;
  }
  //*** END CERTIFICATE PINNING
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
    strcpy(error,"2013n - Error reading  message, no answer ");
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
    bytes = SSL_read(ssl, &reply[ptr], mr);
    if(bytes<=0)
      break;
    ptr=ptr+bytes;
    reply[ptr]=0;
    c++;
    if(c>=9999) break;
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
//******************************************************************
//*** FUNCTION TO VERIFY THE CERTIFICATE PRESENTED FROM THE SERVER
//*****************************************************************
int bb_verify_callback(int preverify, X509_STORE_CTX* x509_ctx)
{
  /* For error codes, see http://www.openssl.org/docs/apps/verify.html  */
  
  int depth = X509_STORE_CTX_get_error_depth(x509_ctx);
  int err = X509_STORE_CTX_get_error(x509_ctx);
  
  X509* cert = X509_STORE_CTX_get_current_cert(x509_ctx);
  X509_NAME* iname = cert ? X509_get_issuer_name(cert) : NULL;
  X509_NAME* sname = cert ? X509_get_subject_name(cert) : NULL;
  
  
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
//*******************************************************
//*** ENCODE A BUFFER IN BASE64
//*******************************************************
int bb_encode_base64(unsigned char * source, int sourcelen,unsigned char * destination)
{
  int len;
  len=EVP_EncodeBlock(destination, source, sourcelen);
  return(len);
}
//***********************************************************
//* DECODE BASE64 STRING IN A BUFFER, return lenght decoded
//***********************************************************
int bb_decode_base64(unsigned char * source, unsigned char * destination)
{
  int len,dlen,x;
  len=strlen(source);
  if(len==0){
    destination[0]=0;
    return(0);
  }
  x=0;
  if(source[len-1]=='=') x++;
  if(source[len-2]=='=') x++;
  dlen=EVP_DecodeBlock(destination, source, len);
  return(dlen-x);
}
