# curl-ios

A script to compile curl for iOS and iPadOS applications.

# Instructions

It's as simple as:

```
./build-ios.sh <curl version> [optional configure parameters]
```

The following config parameters are always provided: `--disable-shared`, `--enable-static`, `--with-secure-transport`

Then add the resulting `curl.xcframework` package to your app and you're finished.

# License

This script is licensed under GPLv3. curl is licensed under MIT.
