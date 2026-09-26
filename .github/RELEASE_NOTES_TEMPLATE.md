<!--
  The shape every Docket release takes. The workflow attaches this file as the
  body of a draft release; fill the placeholders, then publish.
-->

## What changed

> **TODO - placeholder.** Replace this whole list before publishing.
- 
- 

### Fixed

> **TODO - placeholder.** Delete this section if nothing broke.
- 

---

## Requirements

macOS 26. Docket reads the real Dock's own preferences and draws against the
current SDK; there is no build for anything earlier.

## This build is unsigned

It is signed ad-hoc - no Apple Developer certificate, no notarisation. Nothing
is wrong with the download; it just has no identity Apple recognises, so
Gatekeeper stops it the first time.

Opening it on macOS 26:

1. Open the **.dmg** and drag **Docket** onto the Applications alias inside it.
   (The .zip is there too if you prefer it; unzip and move the app across
   yourself.) Install it before the next step, because the permission you are
   about to grant is attached to where the app lives, and granting it while the
   app sits in Downloads means granting it again later.
2. Double-click it. macOS refuses, saying it cannot verify the app is free of
   malware. Click **Done**.
3. Open **System Settings ▸ Privacy & Security** and scroll to **Security**.
   There is a line there about Docket being blocked, with an **Open Anyway**
   button. Click it and authenticate.
4. Launch Docket again and confirm **Open Anyway**.

Control-clicking the app and choosing Open - the old advice, still all over
the internet - no longer works for this. macOS stopped honouring that shortcut
in Sequoia, and macOS 26 sends you to Privacy & Security instead.

If macOS still refuses, or calls the app damaged, the download's quarantine
flag is the thing in the way:

```sh
xattr -dr com.apple.quarantine /Applications/Docket.app
```

Prefer to avoid all of this? Build it yourself - `brew install xcodegen`,
`xcodegen generate`, and the build instructions in the README. A local build
signed with your own certificate has none of these problems.

## After it launches, look at the menu bar

Docket is an accessory app: no Dock tile, no entry in the app switcher, no
window on launch. If you double-click it and seem to get nothing, it started
fine - its status item is in the menu bar, and everything (settings, quitting)
is behind that.

## Permissions it will ask for

- **Automation** - Now Playing reads Spotify, Apple Music, or a scriptable
  browser tab over Apple Events. macOS asks the first time it tries; approving
  it under **Privacy & Security ▸ Automation** is what makes the widget show
  anything. The browser fallback additionally needs *Allow JavaScript from
  Apple Events* in that browser's Develop menu.
- **Calendars** and **Reminders** - asked only when you open those widgets'
  detail panels, and only for what they display.
- **Location** - the weather widget asks, for your city. macOS does not present
  that prompt to an accessory app with no ordinary window, so the request
  quietly goes nowhere; set a city by hand in **Settings ▸ Widgets** instead.

Nothing is sent anywhere. Docket is not sandboxed because reading the Dock's
preferences and driving other apps over Apple Events both require it.

---

## Credit where it is due

Docket exists because of [**Dockset**](https://dockset.app), a genuinely
lovely macOS app by an independent developer, who had the idea of a widget
shelf beside the Dock and executed it beautifully. Docket is an independent
reimplementation and a learning exercise, written from scratch and from the
outside - it is not affiliated with, endorsed by, or connected to Dockset in
any way.

If you want the polished, supported, commercial article, go and buy Dockset.
It is worth paying for, and paying independent developers for their work is
how apps like it keep getting made.
