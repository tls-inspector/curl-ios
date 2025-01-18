# curl-ios

Pre-compiled libcurl framework for iOS and iPadOS applications! Automatically updated within 24-hours of a new release of curl.

This copy of curl is built to use [OpenSSL](https://github.com/tls-inspector/openssl-ios).

## Using the pre-compiled framework

1. Download and extract curl.xcframework.zip or curl_swift.xcframework.zip from the latest release.
1. Compare the SHA-256 checksum of the downloaded framework with the fingerprint in the release
    ```bash
    shasum -a 256 curl.xcframework.zip
    ```
    1. _Optionally_ download the signing key from this repo and the curl.xcframework.zip.sig from the release and verify the signature
        ```bash
        openssl dgst -sha256 -verify signingkey.pem -signature curl.xcframework.zip.sig curl.xcframework.zip
        ```
1. Select your target in Xcode and click the "+" under Frameworks, Libraries, and Embedded Content  
    ![Screenshot of the Frameworks, Libraries, and Embedded Content section in Xcode with the plus button circled](resources/frameworks.png)
1. Click "Add Other" then "Add Files..."  
    ![Screenshot of a dropdown menu with the add files option highlighted](resources/addfiles.png)
1. Select the extracted curl.xcframework directory

## Compile it yourself

Use the included build script to compile a specific version or customize the configuration options

```
./build-ios.sh <curl version> [optional configure parameters]
```

To enable signature verification of downloaded artifacts set the `VERIFY` environment variable to `1`.

If you are building for use with a Swift package, you need to set the `WITH_MODULE_MAP` environment variable to `1`.

The following curl build parameters are always specified: `--disable-shared`, `--enable-static`, `--with-openssl`, and `--without-libpsl`

## Using Curl in Swift

This package provides support for using Curl in swift. When compiling this package you must define the `WITH_MODULE_MAP` environment variable with a value of `1`. This will create a .xcframework file that includes a modulemap.

### Swift Shim

This library includes a shim header to work-around some incompatibilities with curl and Swift's C interoperability. Curl
uses C macro functions that accept variables of any type and Swift does not support this.

When using `curl_easy_setopt` in Swift, you will need to use one of the provided shim functions specific to the
datatype, such as `curl_easy_setopt_string`.
