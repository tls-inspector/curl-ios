#ifndef CURL_SHIM
#define CURL_SHIM

#import <curl/curl.h>
#include <stdint.h>

static inline CURLcode curl_easy_setopt_string(CURL *handle, CURLoption option, const char *parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

static inline CURLcode curl_easy_setopt_int(CURL *handle, CURLoption option, int parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

static inline CURLcode curl_easy_setopt_binary(CURL *handle, CURLoption option, const uint8_t *parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

static inline CURLcode curl_easy_setopt_write_function(CURL *handle, CURLoption option, curl_write_callback parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

static inline CURLcode curl_easy_setopt_debug_function(CURL *handle, CURLoption option, curl_debug_callback parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

static inline CURLcode curl_easy_setopt_pointer(CURL *handle, CURLoption option, void *parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

static inline CURLcode curl_easy_setopt_slist(CURL *handle, CURLoption option, struct curl_slist *parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

#endif
