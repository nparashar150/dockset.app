# Plinth

A free, open-source Dock shelf for macOS — live widgets, app groups and folders
in a strip that sits beside Apple's Dock, or replaces it.

Inspired by [Dockset](https://dockset.app). Independent reimplementation, not
affiliated with or endorsed by it.

---

## What it does

**Follows your real Dock.** Size, edge, magnification and auto-hide are read
through to `com.apple.dock` rather than copied, so there is nothing to keep in
sync when you drag the size slider in System Settings. Your pinned apps are
mirrored; the shelf adds what the Dock cannot hold. Resize the shelf yourself and
only the *size* stops following — the edge and hiding still do.

**Magnification that matches.** The same raised-cosine falloff Apple's Dock uses,
with the peak and radius taken from your own `largesize` and `tilesize`. A linear
ramp makes neighbours lurch; a gaussian never quite reaches zero, so distant icons
drift.

**Widgets, seventeen kinds.** Clock and world clock, CPU/memory/disk, battery
across your Mac and its accessories, network throughput, weather, stopwatch,
countdown, alarm, focus timer, progress through the day, sticky notes, hydration,
stocks and a watchlist, AirDrop, and Now Playing.

**Now Playing reads what is actually playing** — Spotify and Apple Music over
Apple Events, falling back to whatever video a scriptable browser tab has going.
`MediaRemote` would be the obvious route and has been entitlement-gated since
15.4: it loads, the symbol resolves, and it returns an empty dictionary.

**Widgets you can use, not just read.** Timers start and stop, the countdown
restarts, notes are typed in place, the alarm toggles, and the metric, span and
symbol tiles page through what they show. Clicking a widget opens a detail panel
where it says everything it knows.

**App groups.** Drop one icon onto another and hold for a moment to make a group,
the way iOS does. Tinted, named, opening into a panel you can drag icons back out
of. A group left holding one item gives way to that icon.

**And the rest.** Overflow scrolling with the trackpad, drag to reorder anywhere
in the row, the launch bounce, folders and files, and layouts you can save and
write back to Apple's Dock.

---

## Building

Requires macOS 26 and Xcode. The Xcode project is generated, so it is not in the
tree:

```sh
brew install xcodegen
xcodegen generate
xcodebuild -scheme Plinth -configuration Release build
```

Tests:

```sh
xcodebuild -scheme PlinthTests -configuration Debug test
```

Plinth is an accessory app — no Dock tile, no menu bar of its own. Its only
permanent UI is a status item.

### Signing

Signing is configured for a specific development team in `project.yml`. Change
`DEVELOPMENT_TEAM` and `CODE_SIGN_IDENTITY` to your own, or set
`CODE_SIGN_IDENTITY: "-"` to build ad-hoc — but note that macOS will not issue
some permission grants to an ad-hoc binary, because there is no stable identity
to attach them to.

---

## Tests

236 tests, and almost all of them exist because something broke.

The coordinate conversions have the most coverage, because that was the most
repeated defect: the shelf sits centred inside a panel longer than itself, and
converting between a screen position and a position along the row needs that
inset. The hover label pointed at the wrong icon, then the drop gap opened away
from the pointer, then the two drifted apart again. The suite asserts the round
trip — a slot centre taken out and brought back must return that slot.

`InteractionTests` deliver real `NSEvent`s to a window. The worst defects here
were all "the click never arrived", and none were visible in the layout maths: an
empty content shape removed every widget's controls from hit testing, a borderless
panel could not take a keystroke, and a non-key window swallowed the first press.
No assertion on a value catches any of that.

---

## Known limits

- **Location consent is not reachable.** The weather widget asks CoreLocation for
  your city; macOS does not present the prompt to an accessory app with no
  ordinary window, and promoting the app to `.regular` first — which is what makes
  the Apple Events prompt appear — does not change it. Set a city in Settings ▸
  Widgets instead.
- **Third-party integrations are not implemented.** Stripe, Paddle and Shopify
  widgets exist in the catalog and have no service behind them.
- **Removal uses a deprecated API on purpose.** `NSAnimationEffect` is the Dock's
  own poof, and Apple withdrew it suggesting a *cursor* as the replacement. It
  still renders, and a real poof beats a hand-drawn puff of smoke.
- **Apple Events need consent.** Reading Spotify, Music or a browser tab requires
  approving Plinth under Privacy & Security ▸ Automation, and browser fallback
  additionally needs "Allow JavaScript from Apple Events" in that browser's
  develop menu.

---

## Licence

MIT.
