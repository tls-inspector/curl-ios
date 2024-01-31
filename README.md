# curl-ios

Pre-compiled libcurl framework for iOS and iPadOS applications! Automatically updated within 24-hours of a new release of curl.

## Using the pre-compiled framework

1. Download and extract curl.xcframework.zip from the latest release
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

The following config parameters are always provided: `--disable-shared`, `--enable-static`, `--with-secure-transport --without-libpsl`
