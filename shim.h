#ifndef CURL_SHIM
#define CURL_SHIM

/*
 * This shim enables Swift applications to interact with some of curl's function macros which aren't
 * compatible with Swift.
*/

#import <curl/curl.h>
#include <stdint.h>

/// Invoke curl_easy_setopt with a string parameter
static inline CURLcode curl_easy_setopt_string(CURL *handle, CURLoption option, const char *parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

/// Invoke curl_easy_setopt with an int parameter
static inline CURLcode curl_easy_setopt_int(CURL *handle, CURLoption option, int parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

/// Invoke curl_easy_setopt with a byte array parameter
static inline CURLcode curl_easy_setopt_binary(CURL *handle, CURLoption option, const uint8_t *parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

/// Invoke curl_easy_setopt with a callback function parameter
static inline CURLcode curl_easy_setopt_write_function(CURL *handle, CURLoption option, curl_write_callback parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

/// Invoke curl_easy_setopt with a debug function parameter
static inline CURLcode curl_easy_setopt_debug_function(CURL *handle, CURLoption option, curl_debug_callback parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

/// Invoke curl_easy_setopt with a pointer parameter
static inline CURLcode curl_easy_setopt_pointer(CURL *handle, CURLoption option, void *parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

/// Invoke curl_easy_setopt with a slist parameter
static inline CURLcode curl_easy_setopt_slist(CURL *handle, CURLoption option, struct curl_slist *parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

/// Invoke curl_easy_setopt with a blob parameter
static inline CURLcode curl_easy_setopt_blob(CURL *handle, CURLoption option, struct curl_blob *parameter)
{
    return curl_easy_setopt(handle, option, parameter);
}

/// Invoke curl_easy_getinfo for getting a string value
static inline CURLcode curl_easy_getinfo_string(CURL *handle, CURLINFO info, const char **parameter)
{
    return curl_easy_getinfo(handle, info, parameter);
}

/// Invoke curl_easy_getinfo for getting an int value
static inline CURLcode curl_easy_getinfo_int(CURL *handle, CURLINFO info, int *parameter)
{
    return curl_easy_getinfo(handle, info, parameter);
}

/// Invoke curl_easy_getinfo for getting a byte array value
static inline CURLcode curl_easy_getinfo_binary(CURL *handle, CURLINFO info, const uint8_t **parameter)
{
    return curl_easy_getinfo(handle, info, parameter);
}

#endif
