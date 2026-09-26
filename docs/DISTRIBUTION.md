# Distribution

How Docket gets found, under one constraint: **subtle**. Nothing here is a
launch. Nothing here asks anyone for a star.

The working theory is the one that actually holds for developer tools: the most
effective promotion for a technical project is publishing the technical
findings, and letting the project be the footnote. Docket has a shelf of those
findings. Most of the document below is about which ones are worth publishing,
where, and which ones would embarrass you.

Every rule in here was checked against the source that enforces it, or is
marked **UNVERIFIED** and told you to go and read it yourself. A wrong rule in
this file gets someone banned from a community, so the honest gaps are left as
gaps.

---

## Where the project actually stands

Checked on 26 September 2026 against the GitHub API:

| | |
| --- | --- |
| Repository created | 25 September 2026 |
| Age | 1 day |
| Stars / forks / watchers | 1 / 0 / 0 |
| Releases | 1 (`v0.1.0`) |
| Open issues | 97 |
| Signing | ad-hoc, not notarised |
| Topics | `appkit` `dock` `macos` `macos-app` `menubar` `swift` `swiftui` `widgets` |
| Pages | off |

Two of those numbers close doors on their own, and they are the first two
things to internalise:

1. **The repository is one day old.** Homebrew will not look at anything under
   30 days. Several other channels treat a week-old repository as a launch
   post, which is the thing you are trying not to do.
2. **The build is unsigned.** As of 1 September 2026 this makes the official
   Homebrew cask repository permanently unavailable, not temporarily. Section 2
   has the detail.

Neither is a reason to hurry. Both are reasons to spend the next few months
writing rather than posting.

---

## The order to do this in

Roughly the first six months, assuming this stays a hobby project.

1. **Now.** README as landing page (section 4). Personal Homebrew tap (section
   2). Keep closing issues.
2. **Weeks 2 to 8.** Write post #1 and post #2 from section 3. Publish them
   somewhere you own. Do not submit them anywhere yet.
3. **Week 8 onwards.** Submit one post, to one place, and answer every reply.
   Wait to see what happens before submitting a second.
4. **Month 3 onwards.** `open-source-mac-os-apps` and `awesome-mac` (section
   1). A second and third release.
5. **Month 6 onwards, and only if the numbers moved.** Show HN, once, for the
   app. Reconsider homebrew-cask only if you have paid for a Developer ID.

The thing that fails here is not doing any of it. The thing that fails
embarrassingly is doing step 3 in week one.

---

## 1. Channels

### Show HN

**Verified** against [the Show HN guidelines](https://news.ycombinator.com/showhn.html).

What they say that matters:

- Show HN is for "something you've made that other people can play with". An
  app people can download and run qualifies.
- "Blog posts, sign-up pages, newsletters, lists, and other reading material"
  are explicitly **not** Show HN. A write-up goes to the front page as an
  ordinary submission, not as a Show HN.
- "Please don't ask friends to upvote or comment. That's not ok on HN." This
  includes a group chat. HN detects voting rings and the penalty lands on the
  submission and the account.
- Title must begin with `Show HN:`. No exclamation marks, no adjectives. `Show
  HN: Docket, an open-source shelf for the macOS Dock` is the shape.
- Version bumps do not qualify. "A major overhaul is probably ok", `0.1.1` is
  not.

How this fits the constraint: **one Show HN, once, and not yet.** A Show HN
from a one-day-old repository with one star reads as a launch. A Show HN in six
months from a repository with a release history, closed issues and two
well-received write-ups behind it reads as a project. The submission itself is
subtle if the comment you leave on it is a real engineering comment rather than
a pitch. The first comment from the author is the whole post, in practice. Use
it to say what was hard, not what it does.

The ordinary-submission route matters more. A technical write-up submitted
without `Show HN:` competes on its own merits, and the project link at the
bottom is the footnote. That is the mechanism this whole document is built
around.

### Lobsters

**Verified** against [lobste.rs/about](https://lobste.rs/about) and
[the tag list](https://lobste.rs/tags).

- **Invitation only.** You cannot sign up. The about page suggests contacting a
  recognisable community member, or getting in touch if something you wrote has
  already been posted. That second route is the honest one and it is also the
  order you want: write first, get read, then be invited.
- **New accounts are restricted for 70 days.** Green usernames cannot submit
  links from new domains, cannot flag, and cannot use certain tags. Plan on
  being unable to do anything useful for over two months after being invited.
- **Self-promotion has a stated ceiling.** "It's great to have authors
  participate in the community, but not to exploit it as a write-only tool for
  product announcements or driving traffic to their work." The guideline puts
  self-promotional content under 25% of your submissions and comments. So you
  need roughly four unrelated contributions for every one of your own.
- The `show` tag exists ("Show Lobsters / Projects") but is **restricted to
  established users**. A new account cannot use it.
- Relevant tags exist and are active: `mac` (Apple macOS), `swift` (Swift
  programming).
- The on-topic test is stated as: "Will this improve the reader's next program?
  Will it deepen their understanding of their last program? Will it be more
  interesting in five or ten years?" A findings post passes that test. An app
  announcement mostly does not.

Verdict: Lobsters is the highest-quality audience for exactly the posts in
section 3, and it is structurally closed to you for at least three months.
Treat it as something you become eligible for by writing, not a channel you
open.

### Reddit

**UNVERIFIED, and you must check this yourself.** Reddit blocks automated
reading from this environment, so none of the subreddit rules below could be
read at source. Everything in this subsection is a pointer to where the rule
lives, not the rule.

Before posting anywhere on Reddit, open the subreddit and read, in this order:

1. The rules in the sidebar, in full.
2. Any pinned or wiki post about self-promotion.
3. The last two weeks of posts, to see whether developers posting their own
   work actually survive there.

Check each of these specifically, because they are the ones that get people
banned:

- Whether developer self-posts are allowed at all, or only in a weekly thread.
- Whether a minimum account age or subreddit karma applies.
- Whether a flair is mandatory (several app subreddits auto-remove unflaired
  posts).
- Whether disclosure of authorship is required in the title or body. Where it
  is required, say it in the first line regardless.
- Whether a free and open-source app is exempt from a promotion rule, or
  whether the rule is about promotion of any kind.

The subreddits worth reading the rules of, in likely order of fit:

| Subreddit | Why | Status |
| --- | --- | --- |
| r/macapps | Largest Mac app community. Roughly 250k members. | Rules UNVERIFIED. Reported as strict on self-promotion; a companion subreddit r/MacOSApps is reported as more permissive. Verify both. |
| r/MacOSApps | Reported to be the developer-friendly counterpart. | Rules UNVERIFIED. |
| r/swift | Swift developers. A findings post fits better than the app. | Rules UNVERIFIED. |
| r/opensource | Open-source projects. | Rules UNVERIFIED. |
| r/SideProject | Explicitly for people's own projects. | Rules UNVERIFIED. Low signal, high tolerance. |
| r/apple | Do not. | Reported to prohibit self-promotion outright. Verify, then almost certainly do not post. |
| r/macOS | General macOS users, not developers. | Rules UNVERIFIED. Poor fit either way. |

The subtle version of Reddit is not a post. It is being a person who answers
Mac development questions in r/swift for a few months, whose flair or comment
history happens to contain the project. That costs more and works better, and
it does not depend on any of the rules above.

One rule that is not subreddit-specific and is worth writing down: posting the
same link to several subreddits in a short window is what Reddit's own spam
handling is built to catch, and it is also the exact behaviour the "subtle"
constraint rules out. One subreddit. One post. Answer the replies.

### Mastodon

**Verified** against the iOS Dev Space instance API.

[iosdev.space](https://iosdev.space) is the Apple-platform developer instance.
"A Mastodon server for all swift developers."

- Registration is **open but approval-required, and a reason is required**. You
  write a sentence about who you are and a human reads it.
- 313 monthly active users. Small. That is the point: it is the right 313.
- The instance rules are conduct rules only (be polite, no bigotry, content
  warnings on inflammatory topics, no adult content, 18+). **There is no
  self-promotion rule.** Mac and iOS developers posting what they are building
  is the normal content of the instance.

This is the single best fit for the constraint in the whole document. A
Mastodon account on an Apple developer instance that posts an occasional
technical note, with a link when there is something to link to, is not
marketing. It is just being in the room. It compounds slowly and it never reads
as a campaign.

Hashtags do real discovery work on Mastodon, because there is no algorithm
doing it for you. `#macOS`, `#Swift`, `#SwiftUI`, `#OpenSource` are the
obvious ones. Two or three per post, not eight.

### Bluesky

**Partly verified.** Bluesky is the larger network (reported over 40 million
registered accounts against Mastodon's roughly 10 to 12 million), and its
custom feed marketplace means anyone can publish a topical feed that anyone can
subscribe to, which is genuinely better discovery for a small account than
Mastodon offers.

There is no gatekeeping to verify: registration is open and there is no
instance-level self-promotion rule to break. That makes it lower-risk and
lower-signal than iosdev.space.

**UNVERIFIED:** which specific Swift or Mac developer feeds are active and
worth being findable in. Before posting, search Bluesky for the Swift and macOS
feeds and see who is actually in them.

Recommendation: hold both accounts, post the same technical notes to both, and
do not cross-post promotional copy to either. If you only want one, take
iosdev.space, because the audience is more precisely correct.

### Swift Forums

**Verified** against [forums.swift.org/categories](https://forums.swift.org/categories).

There is a **Community Showcase** category, described as "Announcements of
Swift-related content, conferences, projects, and products". That is an
explicit, sanctioned place to announce a Swift project, which makes it one of
the few channels where posting about your own work is the stated purpose rather
than a tolerated exception.

Do not use Related Projects (it is for open-source projects *within the Swift
community*, meaning language and tooling, not apps built with Swift), and
obviously not Announcements (Swift project and release announcements only).

This is worth one post, written as an engineering note rather than a launch,
once the app is past `0.1`.

### Product Hunt

**Verified enough to say no.**

Product Hunt works, and it works by a mechanism that is the exact opposite of
this project's constraint. Every current guide to launching a developer tool
there describes the same four things: seed the product's forum thread for weeks
before launch day, write a listing scannable in five seconds, have a human
answer every comment for a full 24 hours, and plan the six weeks after. That is
a coordinated campaign with a countdown on it.

It is also badly matched to what Docket is. Product Hunt ranks products;
Docket is a hobby reimplementation with seven placeholder widgets and 97 open
issues. And there is a third problem that section 5 covers: Product Hunt's
entire frame is comparative, and comparison is the one frame this project
cannot be put in.

**Do not use Product Hunt.** There is no subtle version of it.

### Awesome lists

The two worth submitting to, both verified by reading their contribution rules
and checking they are alive.

**`serhii-londar/open-source-mac-os-apps`** ([repo](https://github.com/serhii-londar/open-source-mac-os-apps)).
50,571 stars, last pushed 10 September 2026. This is the single best-fitting
list: it is *only* open-source macOS apps, which is exactly what Docket is.

Their stated requirements:

- The project must not "lack recent commit". Docket is fine.
- The README must be "clear" and "written in English". Docket's is both.
- **Edit `applications.json`, not `README.md`.** The README is generated.
- Required fields: `title`, `short_description`, `repo_url`, `categories`,
  `icon_url`, `screenshots`, `official_site`, `languages`.
- Search for duplicates first. One pull request per suggestion. Short,
  descriptive description ending in a full stop. Check spelling. No trailing
  whitespace.

The rules do not address submitting your own app, which in practice means it is
accepted. `icon_url` and `screenshots` are required, so this submission needs
the icon hosted at a stable URL, which is a reason to do GitHub Pages
(section 4) first.

**`jaywcjlove/awesome-mac`** ([repo](https://github.com/jaywcjlove/awesome-mac)).
114,903 stars, pushed 25 September 2026. Much larger reach, much broader scope
(all Mac software, not only open source), so a smaller share of its readers
care.

Their process is an **issue, not a pull request**, using the
`🎉 Addition to list` template. It asks for a link, an explanation of why it
should be added, and a checklist confirming you searched for duplicates. No
star threshold is stated. The list marks open-source entries with their own
icon, which is worth having.

**`matteocrippa/awesome-swift`** ([repo](https://github.com/matteocrippa/awesome-swift)).
26,290 stars, pushed 1 September 2026. Requirements are explicit and Docket
fails the fit test rather than the criteria:

- At least 15 stars on GitHub. Docket has 1.
- MIT is an accepted licence. Fine.
- Swift 5 or above, actively maintained, documented, English README. All fine.
- Edit `contents.json`, not the README.

But the list is organised into library categories (`command-line` and so on)
and it exists for Swift packages people depend on, not applications. Submitting
an app there is a category error even if it clears 15 stars. **Skip it.**

**`iCHAIT/awesome-macOS`** (19,260 stars, pushed 23 August 2026) is a possible
third. **UNVERIFIED:** its contribution requirements were not read. Read them
before submitting.

**`herrbischoff/awesome-macos-command-line` is archived.** Do not submit.

Timing: all of these are fair game once the project has a second release and
some commit history behind it. Submitting a one-day-old repository to a
114,000-star list is not subtle, it is conspicuous.

---

## 2. Homebrew

This is the section with the bad news in it, and the bad news is worth knowing
precisely, because it changes what is worth building.

### homebrew-cask is closed to Docket, and it is not a timing problem

Three independent rules block it. Any one of them is fatal on its own.

**(a) The Gatekeeper rule. This is the permanent one.**

From [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks), verbatim:

> On macOS, apps, installers and other executable artefacts that Gatekeeper can
> assess must pass Homebrew's Gatekeeper checks and must not require System
> Integrity Protection or Gatekeeper to be disabled or bypassed.

The supporting history, which is what makes this final rather than negotiable:

- Homebrew deprecated the `--no-quarantine` flag in 4.7.0 (October 2025) and
  removed the remaining code in July 2026. The `quarantine false` escape hatch
  that unsigned casks used is gone.
- Homebrew is **disabling every cask that fails the Gatekeeper check on 1
  September 2026**. That date has passed. Roughly 387 of about 7,624 casks were
  already deprecated under this policy.
- Homebrew's project lead stated the decision was maintainers' own, made to
  reduce unsupported bug reports, and that the issue tracker was for
  coordinating the work rather than relitigating the decision.

Docket is ad-hoc signed and not notarised. It fails this check by construction.
**No amount of stars fixes this.** The only route into homebrew-cask is a paid
Apple Developer Program membership, a Developer ID certificate, and
notarisation in the release workflow. That is a real option and it would also
fix the location-consent limitation in the README, but it is a separate
decision about money, not a distribution tactic.

**(b) The age rule.**

From [the Package Acceptance Policy](https://docs.brew.sh/Package-Acceptance-Policy):

> A code repository less than 30 days old is normally not eligible.

Docket's repository is one day old.

**(c) The notability rule, and note which threshold applies to you.**

Also from the Package Acceptance Policy. For software hosted in a code
repository, the thresholds are:

- **At least 30 forks, 30 watchers or 75 stars** for a submission by someone
  other than the repository owner.
- **At least 90 forks, 90 watchers or 225 stars for a self-submission by the
  repository owner.**

You would be self-submitting, so the bar is 90/90/225, not 30/30/75. Docket is
at 1/0/0.

The policy also notes that these metrics "may not represent the notability of
an established application when the repository is used only to host its
binaries", which is a carve-out for established apps, not for new ones.

**Conclusion: do not open a homebrew-cask pull request.** It will be closed,
and opening one against three documented rules is the specific waste of
everyone's time this section exists to prevent.

### A personal tap, which is the actual answer

**Verified** against [docs.brew.sh/Taps](https://docs.brew.sh/Taps) and the
maintainer position in Homebrew discussion #6482:

> Anyone can create their own Tap and add whatever they'd like to it. By
> default, we don't even check signing status on third-party taps.

So the tap route is explicitly sanctioned, not a loophole.

Mechanics:

- The repository must be named `homebrew-<something>`. `nparashar150/homebrew-tap`
  is the conventional choice and gives users `brew tap nparashar150/tap`.
- Users then run `brew install --cask docket`, or the fully qualified
  `brew install nparashar150/tap/docket`.
- Code in a tap runs with the user's privileges, which is why Homebrew has a
  `brew trust` step and why your tap's README should be honest about what it
  installs.

What the tap does **not** get you, and must therefore say plainly:

Because `--no-quarantine` is gone, installing Docket from your tap does not
skip Gatekeeper. The download is quarantined exactly as a browser download is,
and the user still walks the **System Settings ▸ Privacy & Security ▸ Open
Anyway** path already documented in the README. A tap saves them finding the
release page; it does not save them the dialog. Say so in the tap README, in
one sentence, rather than letting them discover it.

**UNVERIFIED:** whether Homebrew's audit tooling will begin flagging or warning
on unsigned casks in third-party taps in future. The maintainer statement above
says they do not check today. Do not build anything that depends on that never
changing.

How this is subtle: a tap is the least promotional distribution mechanism that
exists. It is a line in your README. Nobody finds it who was not already
looking for you, which is precisely why it belongs in the "do it now" list
rather than the "wait" list.

---

## 3. The writing plan

The premise: publish the finding, let the project be the footnote. The footnote
is one line at the end of the post saying where the finding came from, with a
link. Not a paragraph. Not a screenshot gallery.

Before the list, three corrections. Publishing a rediscovery as a discovery
makes you look silly; publishing something factually wrong makes you look
worse, and two of the findings in the brief do not survive checking as stated.

### Corrections to make before writing anything

**`CGWindowListCreateImage` was not removed in macOS 26.** It was marked
obsoleted in the **macOS 15.0** SDK. The compiler error people hit is
`'CGWindowListCreateImage' is unavailable: obsoleted in macOS 15.0 - Please use
ScreenCaptureKit instead`, and it has been breaking builds since 2024 (MacPorts
ticket #71136, JUCE issue #1414, google/eclipsa-audio-plugin issue #10). If you
publish "removed in macOS 26", the first reply will be that link. Fix the
version before this sentence appears anywhere. It is not a post in its own case
either way; it is one line in a post about something else.

**The MediaRemote gate has a published workaround, and it works.**
`ungive/mediaremote-adapter` (BSD-3-Clause) reads Now Playing on macOS 15.4 and
later without disabling SIP and without any private entitlement. The mechanism:
processes whose bundle identifier begins with `com.apple.` are granted access,
and the system Perl at `/usr/bin/perl` reports such an identifier, so running
the adapter through it gets the framework to answer. Writing "MediaRemote is
gated and there is nothing you can do" is now wrong. The gate itself is also
thoroughly covered already: LyricFever #94, pock/now-playing-widget #7,
GhostBar #9 and others all document it, and the Rust crate `media-remote` ships
against it. **This is not a post.** At most it is a paragraph inside a post
about why Docket scripts the players instead, and that paragraph has to credit
mediaremote-adapter and say why Docket did not take that route. If there is no
good answer to "why not", the honest move is to take that route.

**The CoreLocation finding has a confound and is currently unpublishable.**
The README says the prompt never appears because Docket is an accessory app
with no ordinary window. CONTRIBUTING.md says macOS will not offer location
consent to an ad-hoc binary because there is no stable identity to attach the
grant to. Those are two different causes for one symptom, and the build has
both conditions at once. The published evidence points at the second: what
Apple's forums and the field reports say cannot prompt is `LSBackgroundOnly`,
and `LSUIElement` is the documented *fix* for that, while CoreLocation is
widely reported to need a real, stably signed bundle. Before this becomes a
post, run the experiment that separates them: build the same app with a
self-signed certificate from the login keychain, changing nothing else, and see
whether the prompt appears. If it does, the README's Known Limits entry is
wrong and should be corrected regardless of whether you ever publish. **That
correction is worth more than the post.**

### The posts, ranked

**1. Why you cannot host another app's widget on macOS, and how to find that out
from an Info.plist**

- **The single point:** the capability is closed by an entitlement that only
  Notification Centre and Control Centre carry, and you can establish that
  yourself by reading WidgetKit's own `Info.plist` rather than by filing a
  feedback and waiting.
- **Where:** your own site first. Then Lobsters (`mac`, `swift`) if you are in
  by then, or HN as an ordinary submission. Cross-post the link to
  iosdev.space.
- **Why a reader cares:** anyone who has ever wanted to build a launcher, a
  dashboard, a Stream Deck-alike or a Dock replacement has had this idea and
  has no idea it is closed. The answer saves them a week.
- **Novelty: high, and the only one of the seven where a search finds no
  existing write-up.** Searches for third-party WidgetKit hosting return
  general WidgetKit documentation, feature requests against other apps
  (BetterTouchTool's community has an open one), and nothing that states the
  gate or shows how it was established. If you publish one thing, publish this.
- **Caveat:** the post is only as good as its evidence. Show the actual
  `Info.plist` path, the actual entitlement key, and the actual clients that
  hold it, with the commands used to find them. Without that it is an assertion
  and someone will contradict it.

**2. Finding a dead feature by posting real `NSEvent`s at a replica view**

- **The single point:** a SwiftUI hit-testing bug is invisible to every
  assertion you can write about layout, and the only test that catches it
  delivers a real event to a real window. Docket's `InteractionTests` do this,
  and the defects they caught (an empty content shape removing controls from
  hit testing, a borderless panel unable to take a keystroke, a non-key window
  swallowing the first press) were all "the click never arrived".
- **Where:** iOS Dev Weekly ([suggest.iosdevweekly.com](https://suggest.iosdevweekly.com/)),
  which is a form that goes straight to Dave Verwer. Then Lobsters (`swift`).
- **Why a reader cares:** it is a technique they can copy on Monday, not a fact
  about one API. Testing technique posts age well, which is exactly the
  Lobsters criterion ("will it be more interesting in five or ten years").
- **Novelty: the rule is old, the technique is not.** Be careful with framing.
  "A descendant gesture beats its ancestor" is documented behaviour that
  Hacking with Swift has covered for years, along with the fix
  (`highPriorityGesture`). If you write that as a discovery, someone will link
  the tutorial within the hour. Write it as: here is a behaviour that is
  documented, here is why documentation did not save me, here is the harness
  that did. That version is novel and it is also true.

**3. Following the real Dock instead of copying it**

- **The single point:** a second Dock-like thing should read `com.apple.dock`
  and subscribe to the Dock's own change notification rather than keeping its
  own copy of size, edge, magnification and auto-hide. No second set of
  preferences, nothing to keep in sync, and no asking the user a question macOS
  already asked.
- **Where:** your own site, then HN as an ordinary submission. This is the post
  most likely to interest people who do not write Swift, because the argument
  is a design argument about not duplicating system state.
- **Why a reader cares:** the "don't mirror a system preference" rule
  generalises well past macOS, and the specific mechanism (a documented public
  domain with an undocumented schema, read defensively with Apple's own
  defaults as fallback) is a pattern worth copying.
- **Novelty: medium.** `com.apple.dock.prefchanged` is documented on CocoaDev
  and has been known for years, so the notification is not the news. The news
  is treating the whole preference domain as the source of truth and building
  the defensive read around it. Frame it that way.
- **Blocker, and this one is real:** issue #12 in this repository says the
  Dock-preferences observer is currently registered on the local
  `NotificationCenter` rather than `DistributedNotificationCenter`, which means
  the behaviour the README describes does not actually work in the shipped
  build. **Do not publish this post until #12 is fixed.** Someone will clone
  the repository and check, and being caught describing behaviour your code
  does not have is worse than never publishing.
- **Second caveat:** the magnification curve. Docket uses
  `(1 + cos(πd/r)) / 2` and the README calls it "Apple's own curve". Searching
  for that finds Docket's README and nothing else, which is good news for
  novelty and bad news for the claim: there is no public evidence that this is
  the formula Apple's Dock uses. Unless you have that evidence, write it as
  "the curve that matches how the Dock feels, and why a linear ramp and a
  gaussian both fail", which is the more interesting argument anyway and is
  fully defensible.

**4. A field guide to permissions on an unsigned Mac app**

- **The single point:** every confusing thing about permissions on an unsigned
  Mac app comes from one cause. TCC anchors the grant to the code signature,
  an ad-hoc signature is a hash of the exact binary, so every rebuild is a new
  app, the old grant silently stops applying, and the toggle in System Settings
  still reads "on" because the toggle describes the old identity.
- **Where:** your own site. Do not submit this one anywhere. Link it from the
  README and from issue replies.
- **Why a reader cares:** it explains a symptom thousands of people have hit
  and almost nobody has a name for.
- **Novelty: low. This is well covered.** The cdhash explanation and the
  self-signed-certificate fix appear across many project issue trackers already
  (gutter #7, LiveTranscribe #4, AgentWrangler #56, macos-app-template #61 and
  more). Publishing it as a discovery would be the exact failure this section
  is about.
- **Why it is still on the list:** as documentation, not as a post. It is
  genuinely useful to Docket's own users, and a post that collects the cause,
  the symptom and the standard fix in one place with a working
  `Config/Local.xcconfig` example earns its keep as a reference. It must lead
  with "this is known, here it is in one place" rather than "I found this". And
  it must include the self-signed local certificate fix, because a post that
  describes the problem and omits the standard fix reads as not having looked.

**Not posts:**

- **`NSWindow.sharingType` and screen capture.** Well covered and officially
  answered. Apple has stated in Developer Forums that there are no public APIs
  for preventing screen capture, the constant is documented as legacy, and the
  behaviour is written up in tauri #14200, Apple forum thread 792152, and Pierce
  Freeman's "Building a (kind of) invisible mac app". There is nothing left to
  add.
- **`CGWindowListCreateImage`.** Wrong version in the brief, and covered since
  2024. One line in another post at most.
- **MediaRemote.** See the correction above.

### The shape of a post

Worth writing down because it is what keeps this subtle:

- The finding is the whole post. The app appears once, at the end, in a
  sentence like "this came up building Docket, an open-source Dock shelf", with
  a link.
- Show the commands and the output. A finding without its evidence is an
  opinion.
- Say what you tried that did not work. That is the part that proves you did
  the work and it is the part readers remember.
- Never write a post whose title contains the app's name unless the post is
  about the app.
- One post at a time. Two in a week is a campaign.

---

## 4. The unglamorous things that compound

These are dull, they take an afternoon each, and over a year they do more than
any single post.

**GitHub topics.** Already set, and set well: `appkit` `dock` `macos`
`macos-app` `menubar` `swift` `swiftui` `widgets`. Two possible additions worth
considering, both real GitHub topics with real traffic: `hacktoberfest` if you
ever want drive-by contributions (it is a commitment, not a tag), and
`dock-replacement` or `launcher` if either matches how people actually search.
Do not add topics that describe aspiration rather than the code.

**Repository description.** Already good. It says what it is, what it does, and
credits the inspiration in one line. Leave it alone.

**The README as a landing page.** Already the strongest asset this project has
and probably the best thing about it. It has screenshots, it explains the
mechanisms rather than listing features, and the Known Limits section is
unusually honest. Three small things:

- The `homepage` field currently points at `releases/latest`. If you do GitHub
  Pages, point it there instead, and let the page point at releases.
- The test count badge says 241 and the brief says 248. Drift like that gets
  noticed on exactly the kind of technical post this document recommends. Make
  it a generated badge or check it each release.
- The install instructions bury the Gatekeeper path under a download link. It
  is the first thing every user hits. Consider promoting it.

**GitHub Pages.** Currently off. Worth turning on for two concrete reasons that
have nothing to do with marketing:

1. `open-source-mac-os-apps` requires `icon_url` and `screenshots` at stable
   URLs. A Pages site gives you those.
2. Posts need somewhere to live that is yours. Publishing on a platform you do
   not own means the posts stop existing when the platform does.

Keep it to one page plus the posts. A hobby project with a marketing site is a
tell.

**alternativeto.net. Read section 5 before doing this.** AlternativeTo is
community-maintained: entries, alternatives and recommendations all come from
users rather than from the site or the vendors, and there is no verified rule
preventing a developer from adding their own app. **UNVERIFIED:** the exact
submission mechanics and moderation policy could not be read; the About page
does not cover them.

The problem is structural rather than procedural. AlternativeTo exists to
answer "what can I use instead of X", and the moment Docket is on it, other
users can and will add Dockset as the thing it is an alternative to. You cannot
prevent that and you cannot moderate it. **Recommendation: do not submit
Docket to AlternativeTo.** The channel's whole purpose is the one frame this
project has committed to staying out of, and the traffic is not worth being the
person who put it there.

**Regular releases.** The most underrated item on this list. A repository with
`v0.1.0`, `v0.1.1`, `v0.1.2` and `v0.2.0` over four months reads as alive. One
release and 97 open issues reads as abandoned, whatever the commit graph says.
Releases are also the only thing here that requires no audience: they work on
the people who find you later.

With 97 open issues and 46 of them defects, there is no shortage of material.
Ship a patch release whenever three or four defects close. The tag-and-it-
happens flow in CONTRIBUTING.md already makes this nearly free.

**Answer every issue.** Slowly is fine. A project where the author replies is a
project people come back to. This is the entire "community building" section
and it does not need a longer one.

---

## 5. What not to do

### The Dockset constraint

This is the non-negotiable one, and it rules out more than it first appears to.

Docket is an independent reimplementation of a commercial app made by an
independent developer. NOTICE.md credits that generously and specifically, down
to naming the two design decisions this project learned by looking at the
original. That posture is not decoration and it is not a legal hedge. It is the
condition under which this project is allowed to exist publicly at all.

**Therefore:**

- **Never describe Docket as a free alternative to Dockset.** Not in a post,
  not in a submission title, not in a Reddit comment, not in a reply to someone
  else who says it first.
- **Never describe Docket as "like Dockset but open source", "Dockset for
  free", or any construction with "instead of" in it.** The README's own
  wording is the model: "it is not 'the free version' of it, and it is not
  trying to replace or compete with it".
- **Never submit Docket to a channel whose purpose is comparison.**
  AlternativeTo is the clearest case and is ruled out above. Any "open-source
  alternatives to paid apps" list, thread, newsletter or roundup is ruled out
  by the same logic, and those are numerous and they will look like easy wins.
  They are not wins. They are the specific thing that is off the table.
- **Never accept a comparative framing offered by someone else.** If a
  commenter says "oh, this is basically free Dockset", the reply is a friendly
  correction and a link to NOTICE.md, every time, including when it costs you
  the upvote. That reply is also, incidentally, the single most credibility-
  building thing you can post.
- **Never put the word Dockset in a title.** Anywhere. A title is the part that
  travels without its context, and "Docket vs Dockset" is a headline you cannot
  take back.
- **Never SEO against it.** No page, tag, topic or description targeting people
  searching for Dockset. The repository description already handles this
  correctly by saying "Inspired by Dockset", which is credit, not capture.
- **If Dockset's developer ever asks for anything**, the answer is yes, and
  quickly. That is the whole posture in one sentence.

The honest cost of this constraint: the comparison frame is the single most
effective way to promote this project, and it is permanently unavailable. Every
recommendation in this document is shaped by working around that, which is why
the emphasis falls so heavily on publishing findings. A findings post has no
comparative frame available to it, which makes it the safest possible channel
as well as the most effective one.

### The rest

- **Do not open a homebrew-cask pull request.** Three documented rules block
  it. Section 2.
- **Do not launch on Product Hunt.** Section 1.
- **Do not post the same link to multiple subreddits.** It is against Reddit's
  spam handling, against several subreddits' rules, and against the constraint.
- **Do not ask anyone to upvote anything.** HN states this explicitly and
  enforces it; every other community that does not state it still notices.
- **Do not open a Show HN yet**, and never open a second one for a version
  bump.
- **Do not submit to awesome lists this month.** Wait for a commit history and
  a second release.
- **Do not publish the MediaRemote, `sharingType` or `CGWindowListCreateImage`
  findings as discoveries.** All three are well covered, and one of them is
  wrong as stated. Section 3.
- **Do not publish the Dock-following post until issue #12 is fixed.** The post
  would describe behaviour the shipped build does not have.
- **Do not claim the raised-cosine curve is Apple's own** without evidence.
- **Do not build a marketing site.** One Pages page. A hobby project with a
  funnel is a tell, and the honesty of the README is this project's actual
  differentiator.
- **Do not let the README overstate.** The Known Limits section is the most
  trust-building thing in the repository precisely because it costs something
  to write. Every future claim should be held to that standard, and the two
  claims flagged in section 3 should be checked against it now.

---

## What is unverified in this document

Listed together so none of it gets mistaken for checked fact:

- **Every Reddit subreddit rule.** Reddit could not be read from here. All of
  section 1's Reddit subsection is pointers, not rules.
- **Which Bluesky Swift and macOS feeds are active.**
- **`iCHAIT/awesome-macOS` contribution requirements.**
- **AlternativeTo's submission mechanics and moderation policy.** The
  recommendation not to use it does not depend on these.
- **Whether Homebrew will begin checking signing status on third-party taps.**
  They state they do not today.
- **Whether `LSUIElement` or ad-hoc signing is the actual cause of the missing
  CoreLocation prompt.** The experiment that settles it is in section 3.
- **Whether Apple's Dock uses the raised-cosine curve.** Only that the curve
  produces the right result.
