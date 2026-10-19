# GeoShare for iOS

A SwiftUI map link converter inspired by [GeoShare for Android](https://github.com/jakubvalenta/geoshare). Share a map link to the GeoShare extension, copy its coordinates, or save it for the main app. The main app opens the location in Apple Maps, Organic Maps, CoMaps, Google Maps, Waze, OpenStreetMap, or a custom web map.

The app uses a simple placeholder map-pin icon. Its editable SVG is in `Design/AppIcon.svg`.

## Build

On a Mac with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
open GeoShare.xcodeproj
```

Select your development team and register the app group `group.app.gwal3n.geoshare` for both targets before installing on a device. The GitHub Actions workflow builds with the **iOS 26 SDK** and uploads an **unsigned** IPA artifact. The minimum supported iOS version remains 17. Installing on a device still requires signing with your own Apple development or distribution identity.

## Current link support

Offline extraction covers coordinate pairs, `geo:` links, Google Maps place and direction URLs, Apple Maps, OpenStreetMap, Waze, and Organic Maps/CoMaps short links. Short links such as `maps.app.goo.gl` are followed after the user taps **Resolve online** or enables **Connect automatically**. A map service may omit coordinates or change its page format; in that case conversion can fail or return a place name only.

The iOS Share extension cannot reliably launch another app directly under Apple's supported extension APIs. It can copy coordinates or a `geo:` link, share an Apple Maps link, and save the link for the main app. Open GeoShare to choose a destination app. This differs from Android GeoShare's one step chooser. Other Android features, including full provider parity, place list API extraction, contact saving, and automatic actions, are not implemented yet.

## Parity with Android GeoShare

This app covers the core share/paste, coordinate extraction, and open-in-another-map flow, but it does not have full feature parity. Android GeoShare supports many more input providers (including 2GIS, Amap, Baidu, IGN, Kagi Maps, Mapy.com, OsmAnd, Plus Codes, and Yandex Maps), place lists, automatic actions, navigation actions, contact saving, and online API/server fallbacks. The iOS app has a smaller provider set and uses the main app to open a destination after sharing. The exact Google Maps short link in `Tests/iOS/GoogleLinkTests.swift` is tested on an iOS simulator; other providers are not comprehensively verified.

In Settings, **Connect automatically** allows online resolution without prompting for each link. The setting applies to the app and its Share extension. Settings also shows the installed app version so you can check that the latest IPA is installed.

## Credit and license

Parsing behavior was informed by GeoShare's public URL cases and documentation. This project is an independent Swift implementation. See [NOTICE](NOTICE) and [COPYING](COPYING).
