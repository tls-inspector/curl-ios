# libcurl-ios

A simple build script to compile libcurl to a dylib framework for iOS apps. This script is loosely based off of [x2on/OpenSSL-for-iPhone](https://github.com/x2on/OpenSSL-for-iPhone).

# Instructions

It's as simple as:

```
./build-ios.sh <curl_version>
```

Then add the resulting curl.framework package to your app and you're done.