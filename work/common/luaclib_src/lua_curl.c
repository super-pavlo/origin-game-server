#include <lua.h>
#include <lauxlib.h>
#include <curl/curl.h>
#include <string.h>

/*
struct data {
  char trace_ascii; // 1 or 0
};
 
static
void dump(const char *text,
          FILE *stream, unsigned char *ptr, size_t size,
          char nohex)
{
  size_t i;
  size_t c;
 
  unsigned int width = 0x10;
 
  if(nohex)
    // without the hex output, we can fit more on screen
    width = 0x40;
 
  fprintf(stream, "%s, %10.10lu bytes (0x%8.8lx)\n",
          text, (unsigned long)size, (unsigned long)size);
 
  for(i = 0; i<size; i += width) {
 
    fprintf(stream, "%4.4lx: ", (unsigned long)i);
 
    if(!nohex) {
      // hex not disabled, show it
      for(c = 0; c < width; c++)
        if(i + c < size)
          fprintf(stream, "%02x ", ptr[i + c]);
        else
          fputs("   ", stream);
    }
 
    for(c = 0; (c < width) && (i + c < size); c++) {
      // check for 0D0A; if found, skip past and start a new line of output
      if(nohex && (i + c + 1 < size) && ptr[i + c] == 0x0D &&
         ptr[i + c + 1] == 0x0A) {
        i += (c + 2 - width);
        break;
      }
      fprintf(stream, "%c",
              (ptr[i + c] >= 0x20) && (ptr[i + c]<0x80)?ptr[i + c]:'.');
      // check again for 0D0A, to avoid an extra \n if it's at width
      if(nohex && (i + c + 2 < size) && ptr[i + c + 1] == 0x0D &&
         ptr[i + c + 2] == 0x0A) {
        i += (c + 3 - width);
        break;
      }
    }
    fputc('\n', stream); // newline
  }
  fflush(stream);
}
 
static
int my_trace(CURL *handle, curl_infotype type,
             char *data, size_t size,
             void *userp)
{
  struct data *config = (struct data *)userp;
  const char *text;
  (void)handle; // prevent compiler warning 
 
  switch(type) {
  case CURLINFO_TEXT:
    fprintf(stderr, "== Info: %s", data);
    // FALLTHROUGH
  default: // in case a new one is introduced to shock us 
    return 0;
 
  case CURLINFO_HEADER_OUT:
    text = "=> Send header";
    break;
  case CURLINFO_DATA_OUT:
    text = "=> Send data";
    break;
  case CURLINFO_SSL_DATA_OUT:
    text = "=> Send SSL data";
    break;
  case CURLINFO_HEADER_IN:
    text = "<= Recv header";
    break;
  case CURLINFO_DATA_IN:
    text = "<= Recv data";
    break;
  case CURLINFO_SSL_DATA_IN:
    text = "<= Recv SSL data";
    break;
  }
 
  dump(text, stderr, (unsigned char *)data, size, config->trace_ascii);
  return 0;
}
*/

static size_t write_func(void *buffer, size_t size, size_t nmemb, void *userp)
{
  size_t realSize = size * nmemb;
  if(realSize <= 1024)
    memcpy(userp, buffer, realSize);
  return realSize;
}

static
int luploadfile(lua_State* L)
{
    struct curl_httppost* form = NULL;
    struct curl_httppost* last = NULL;

    curl_global_init(CURL_GLOBAL_ALL);

    CURL* curl = curl_easy_init();
    if(!curl)
        return 0;

    char retData[1024] = {0};
    const char* url = lua_tostring(L, 1);
    const char* filename = lua_tostring(L, 2);
    size_t datalen;
    const char* data = lua_tolstring(L, 3, &datalen);
    const char* gid = lua_tostring(L, 4);
    const char* sign = lua_tostring(L, 5);
    
    curl_formadd(&form, &last,
                CURLFORM_COPYNAME, "g_id",
                CURLFORM_COPYCONTENTS, gid,
                CURLFORM_END);

    curl_formadd(&form, &last,
                CURLFORM_COPYNAME, "v",
                CURLFORM_COPYCONTENTS, "3",
                CURLFORM_END);
            
    curl_formadd(&form, &last,
                CURLFORM_COPYNAME, "sign",
                CURLFORM_COPYCONTENTS, sign,
                CURLFORM_END);
    
    curl_formadd(&form, &last,
                CURLFORM_COPYNAME, "video",
                CURLFORM_BUFFER, filename,
                CURLFORM_BUFFERPTR, data,
                CURLFORM_BUFFERLENGTH, datalen,
                CURLFORM_END);

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_HTTPPOST, form);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_func);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void*)retData);
    curl_easy_setopt(curl, CURLOPT_TCP_KEEPALIVE, 1L);

    // debug
    /*
    struct data config;
    // enable ascii tracing
    config.trace_ascii = 1;
    curl_easy_setopt(curl, CURLOPT_DEBUGFUNCTION, my_trace);
    curl_easy_setopt(curl, CURLOPT_DEBUGDATA, &config);
    // the DEBUGFUNCTION has no effect until we enable VERBOSE
    curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
    // example.com is redirected, so we tell libcurl to follow redirection
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    */

    CURLcode res = curl_easy_perform(curl);

    curl_formfree(form);
    curl_easy_cleanup(curl);
    curl_global_cleanup();

    lua_pushboolean(L, res == CURLE_OK);
    if(res == CURLE_OK)
        lua_pushstring(L, retData);
    else
        lua_pushstring(L,  curl_easy_strerror(res));
    return 2;
}

int luaopen_curl_core(lua_State* L)
{
    luaL_checkversion(L);
	luaL_Reg l[] =
	{
		{ "uploadfile", luploadfile },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}