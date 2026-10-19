# GeoShare for iOS

A SwiftUI map link converter inspired by [GeoShare for Android](https://github.com/jakubvalenta/geoshare). Share a map link to the GeoShare extension, copy its coordinates, or choose a destination app. The main app opens the location in Apple Maps, Organic Maps, CoMaps, Google Maps, Waze, OpenStreetMap, or a custom web map.

The app uses a simple placeholder map-pin icon. Its editable SVG is in `Design/AppIcon.svg`.

## Build

On a Mac with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
open GeoShare.xcodeproj
```

Select your development team and register the app group `group.app.gwal3n.geoshare` for both targets before installing on a device. The GitHub Actions workflow builds with the **iOS 26 SDK** and uploads an **unsigned** IPA artifact. The minimum supported iOS version remains 17. Installing on a device still requires signing with your own Apple development or distribution identity.

## Current link support

Offline extraction covers coordinate pairs, `geo:` links, Google Maps place and direction URLs, Apple Maps, OpenStreetMap, Waze, Organic Maps/CoMaps, OsmAnd, Mapy.com, Magic Earth, Cartes IGN, Kagi Maps, Yahoo Maps, and 2GIS/Urbi coordinate URLs. Google Maps place lists use Google's linked list-data response, with a JavaScript page-state fallback on iOS. Short links such as `maps.app.goo.gl` are followed after the user taps **Resolve online** or enables **Connect automatically**. A map service may omit coordinates or change its page format; in that case conversion can fail or return a place name only.

The Share extension now displays destination choices. It asks iOS to open the selected destination, then offers a system activity sheet with a web map link if iOS refuses. Apple's documented `NSExtensionContext.open` support does not include Share extensions, so one-tap app launching from the share sheet cannot be guaranteed. The main app remains available as a fallback. Other Android features, including full provider parity, contact saving, and automatic actions, are not implemented yet.

## Parity with Android GeoShare

This app covers the core share/paste, coordinate extraction, and open-in-another-map flow, but it does not have full feature parity. Android GeoShare still supports more providers (including Amap, Baidu, Plus Codes, and Yandex Maps), automatic actions, navigation actions, contact saving, and online API/server fallbacks. The iOS Share extension's app launch is limited by iOS; it falls back to the system sheet. The Tulsa Google Maps short link and a public Google place list are tested on an iOS simulator; other providers have parser smoke tests but are not comprehensively verified online.

In Settings, **Connect automatically** allows online resolution without prompting for each link. The setting applies to the app and its Share extension. Settings also shows the installed app version so you can check that the latest IPA is installed.

## Credit and license

Parsing behavior was informed by GeoShare's public URL cases and documentation. This project is an independent Swift implementation. See [NOTICE](NOTICE) and [COPYING](COPYING).
