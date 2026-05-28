// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6.3.3"),
        .package(name: "sign_in_with_apple", path: "../.packages/sign_in_with_apple-8.0.0"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.4"),
        .package(name: "share_plus", path: "../.packages/share_plus-12.0.2"),
        .package(name: "path_provider_foundation", path: "../.packages/path_provider_foundation-2.4.1"),
        .package(name: "image_picker_ios", path: "../.packages/image_picker_ios-0.8.12+2"),
        .package(name: "google_sign_in_ios", path: "../.packages/google_sign_in_ios-5.9.0"),
        .package(name: "geocoding_ios", path: "../.packages/geocoding_ios-3.1.0"),
        .package(name: "stripe_ios", path: "../.packages/stripe_ios-11.5.0"),
        .package(name: "flutter_local_notifications", path: "../.packages/flutter_local_notifications-19.5.0"),
        .package(name: "firebase_storage", path: "../.packages/firebase_storage-12.4.10"),
        .package(name: "firebase_core", path: "../.packages/firebase_core-3.15.2"),
        .package(name: "firebase_messaging", path: "../.packages/firebase_messaging-15.2.10"),
        .package(name: "firebase_auth", path: "../.packages/firebase_auth-5.7.0"),
        .package(name: "firebase_app_check", path: "../.packages/firebase_app_check-0.3.2+10"),
        .package(name: "cloud_functions", path: "../.packages/cloud_functions-5.6.2"),
        .package(name: "cloud_firestore", path: "../.packages/cloud_firestore-5.6.12"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "sign-in-with-apple", package: "sign_in_with_apple"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "path-provider-foundation", package: "path_provider_foundation"),
                .product(name: "image-picker-ios", package: "image_picker_ios"),
                .product(name: "google-sign-in-ios", package: "google_sign_in_ios"),
                .product(name: "geocoding-ios", package: "geocoding_ios"),
                .product(name: "stripe-ios", package: "stripe_ios"),
                .product(name: "flutter-local-notifications", package: "flutter_local_notifications"),
                .product(name: "firebase-storage", package: "firebase_storage"),
                .product(name: "firebase-core", package: "firebase_core"),
                .product(name: "firebase-messaging", package: "firebase_messaging"),
                .product(name: "firebase-auth", package: "firebase_auth"),
                .product(name: "firebase-app-check", package: "firebase_app_check"),
                .product(name: "cloud-functions", package: "cloud_functions"),
                .product(name: "cloud-firestore", package: "cloud_firestore"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
