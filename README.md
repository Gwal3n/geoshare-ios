# GeoShare for iOS

A SwiftUI map link converter inspired by [GeoShare for Android](https://github.com/jakubvalenta/geoshare). Share a map link to the GeoShare extension, copy its coordinates, or save it for the main app. The main app opens the location in Apple Maps, Organic Maps, CoMaps, Google Maps, Waze, OpenStreetMap, or a custom web map.

## Build

On a Mac with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
open GeoShare.xcodeproj
```

Select your development team and register the app group `group.app.gwal3n.geoshare` for both targets before installing on a device. The GitHub Actions workflow builds an **unsigned** IPA artifact. Installing it on a device still requires signing with your own Apple development or distribution identity.

## Current link support

Offline extraction covers coordinate pairs, `geo:` links, Google Maps place and direction URLs, Apple Maps, OpenStreetMap, Waze, and common coordinate queries. Short links such as `maps.app.goo.gl` are followed only after the user taps **Resolve online**. A map service may omit coordinates or change its page format; in that case conversion can fail or return a place name only.

The iOS Share extension cannot reliably launch another app directly under Apple's supported extension APIs. It can copy coordinates or a `geo:` link, share an Apple Maps link, and save the link for the main app. Open GeoShare to choose a destination app. This differs from Android GeoShare's one step chooser. Other Android features, including full provider parity, place list API extraction, contact saving, and automatic actions, are not implemented yet.

## Credit and license

Parsing behavior was informed by GeoShare's public URL cases and documentation. This project is an independent Swift implementation. See [NOTICE](NOTICE) and [COPYING](COPYING).
