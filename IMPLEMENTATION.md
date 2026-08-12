# InnenFlow (Android) — implementation

> Written for whoever opens this repo cold, including future you. What is here,
> why it is shaped this way, and where the sharp edges are. Not a changelog.

---

## 1. What this is

The Flutter app. One of two clients — the other is the website — against one
backend.

```
        ┌──────────────────┐
        │  Firebase Auth   │   identity only
        └────────┬─────────┘
                 │ ID token on every request
        ┌────────┴─────────┐
        │    This app      │
        └────────┬─────────┘
                 ▼
        ┌──────────────────┐        ┌──────────────────┐
        │  InnenFlow API   │◀───────│     Website      │
        └────────┬─────────┘        └──────────────────┘
                 ▼
           ┌──────────┐
           │ MongoDB  │
           └──────────┘
                 ▲
        ┌────────┴─────────┐
        │  Firebase Cloud  │   push delivery only
        │    Messaging     │
        └──────────────────┘
```

The app holds no credentials of its own and decides no authorization. Every
request carries a Firebase ID token, the server verifies it, and the server
decides what may be read. **Nothing in this app decides what a user may see** —
that was `firestore.rules`' job and it is now the API's. The app's own checks
only decide which buttons to draw.

---

## 2. The migration this repo is in the middle of

Application data has moved from Firestore to MongoDB behind the API. Most of the
app is migrated; `lib/services/community_service.dart` is not yet.

**Every realtime Firestore listener is gone.** There were eleven `snapshots()`
subscriptions — the Sanctuary, the counselling inbox, the chat, the transcript,
the support queue, the admin alerts, the reflections watchlist, the profile, the
thought of the day. Each was a websocket held open for as long as a widget was
mounted, per query, per device.

They had to go regardless: MongoDB has no client realtime channel. But the
replacement is genuinely better for the case that mattered — **a listener only
fires while the app is running.** Somebody who closed the app never found out
their counsellor had replied.

### What replaced them: `lib/services/api_feed.dart`

An `ApiFeed<T>` exposes a `Stream`, so the existing `StreamBuilder` call sites
did not have to be rewritten, and reloads on exactly three events:

1. **On open** — the widget subscribes, the data arrives.
2. **On a push** — FCM delivers a data-only message the moment the server writes
   something worth knowing about. Same signal the listener gave, over a
   connection the device already pays for, and it also arrives when the app is
   closed.
3. **On demand** — `refresh()`, wired to pull-to-refresh and called after the
   screen's own writes.

**Nothing polls on a timer.** A timer would be strictly worse than the listener it
replaced: same held resource, plus latency, plus traffic on a quiet app. If a
feed looks stale, the fix is a push for the event that changed it, not a shorter
interval.

A failed refresh is logged and swallowed rather than emitted as a stream error —
an error tears the subscription down, so one dropped request on a train would
leave the screen permanently dead.

---

## 3. Layout

```
lib/
  main.dart                 go_router table, FCM wiring
  core/
    constants/              app_constants, counselling, thoughts_365, articles
    theme/app_theme.dart    ← the design tokens the website copies
    utils/
  models/                   fromJson / toJson against the API
  providers/auth_provider   who is signed in; the `admin` claim
  screens/                  one directory per feature
  services/
    api_service.dart        the HTTP client — the website's api.ts is a port
    api_feed.dart           the listener replacement (§2)
    firebase_messaging_service.dart
    notification_center.dart  the unread badge
    notification_service.dart local notification rendering
    journal, meditation, affirmation, blog, counselling,
    community, follow, profile, product, purchase, moderation, …
```

---

## 4. The decisions worth knowing

### `api_service.dart` has two timeouts

The API is on a free tier that suspends after inactivity and cold-starts on the
next request — the best part of a minute, during which the socket is open and
simply quiet. A flat 20 s budget turns every first launch of the morning into
"could not reach the server", which is a false accusation: the server is fine, it
is getting dressed.

So the first request of a process gets 75 s and everything after it gets 20 s.
`warmUp()` fires during boot behind the first frame, so the cold start overlaps
with the member looking at the dashboard.

It also retries **once** on `token_expired`. An ID token lives an hour and the app
can sit backgrounded for longer; without the retry the first request after
resuming fails with a 401 the user reads as "something went wrong".

### `notification_center.dart` — four listeners became one request

The unread badge used to be derived on the handset from four open Firestore
streams. Now the server counts, and the answer arrives two ways: one call to
`/api/notifications/unread` on launch and on resume, and an FCM push when
something happens. **At a hundred thousand installs that is four hundred thousand
held connections against a few requests per member per session.**

Read state moved with it. It used to live in `SharedPreferences` with a
reasonable argument that "have *I* seen this on *this phone*" is a local
question. That held while the badge was computed on the handset. It does not now:
the server needs to know what has been seen in order to count, and a member with
a phone and a tablet expects reading on one to quiet the other.

### Push messages are data-only, always

No `notification` block is ever sent. A `notification` message is rendered by the
OS before the app sees it — and on Android in the background the app never sees
it at all — which would break both the unread badge (nothing to observe) and tap
routing (the route lives in the payload and has to reach the handler).

So every message arrives as data and is drawn through `NotificationService` on
the `brahma_alerts_channel` the app already declares. One rendering path for
local and remote notifications instead of two that drift.

### The anonymous board cannot identify anyone, including you

A reflection carries no account identifier. Authorship lives in a separate
collection no member account can read — deliberately, so the board cannot be
joined against the member list. The device knows which posts are its own only
from a **private watchlist**, and the server independently checks authorship
before allowing a delete.

Deleting an account removes the authorship record rather than the posts. The post
stays and becomes genuinely unattributable, instead of disappearing and taking
other people's replies with it. **Deleting the authorship record is what makes
the erasure real.**

### `isAdmin` is a signed claim, never an email comparison

It comes from the `admin` custom claim inside the Firebase-signed ID token. It
cannot be guessed, forged or self-assigned, and the same claim is what the API
checks server-side. The getter only drives which controls are visible.

This replaced a version that compared against a hardcoded operator email **paired
with a hardcoded password** — a credential that shipped inside the APK, so anyone
who unzipped it could sign in as the operator.

### The client no longer asserts privilege anywhere

Three cases were removed in the API migration:

- `createBlog(autoPublish: auth.isAdmin)` — a request politely declaring its own
  privilege. The server reads the claim from the token instead.
- `sendText(sender: _me)` in counselling — a member's build could label its own
  message `admin` and impersonate a counsellor in the transcript. The server
  derives the role from the token.
- Comment and article authorship — name, email and uid were sent and checked
  against `request.auth.uid` by a rule. All three come off the token now.

### Account deletion is one server call

It used to delete across fifteen collections from the device, and carried an
honest comment about the consequence: if one refused it continued anyway and left
"unreachable orphan data". That is a partial erasure of somebody who asked to be
forgotten, and Play treats account deletion as a promise rather than a best
effort.

`DELETE /api/profile/me` either sweeps everything or reports what it could not,
on a connection that cannot be interrupted by backgrounding the app halfway
through. Firebase Auth is deleted **after** it returns — every route authorises
against a valid token, so destroying the credential first would lock the account
out of its own deletion.

### Counselling: what moved to the server

- **`purgeAfter`** was computed from `DateTime.now()` on the handset. A wrong
  clock could lengthen the retention window on the most sensitive data in the
  product. Stamped by the server now, enforced by a MongoDB TTL index — so it
  happens whether or not anybody opens the app again.
- **`purgeExpired()`** consequently does nothing and is kept only for call-site
  compatibility.
- **The scripted messages** (welcome, payment instructions, approval, goodbye)
  are written by the server in the same request as the state change they explain.
  They used to be written by whichever handset made the change, so a killed app
  between the two left a session live with nothing explaining why.

### A day is the member's local day — `dayMarker` in `core/utils/stats_utils.dart`

Every streak, every "did I write today", every square on the consistency grid
goes through `dayMarker`, and it used to read `.year/.month/.day` straight off
whatever DateTime it was handed. The API answers with ISO strings ending in `Z`,
so `DateTime.parse` returns a **UTC** DateTime — while `todayMarker()` read the
components off `DateTime.now()`, which is local. Every comparison was a UTC day
against a local one.

East of Greenwich that quietly files anything written after local midnight under
the previous day. In IST the window is 00:00–05:30, which for this product is not
an edge case — it is the hour the whole thing is about. Measured on a real
account: the dashboard said a 4-day streak where the server said 9, and showed
"Today's Entry: Pending" for an entry written twenty minutes earlier. The four
days it dropped were the four written after midnight.

`dayMarker` now calls `.toLocal()` before reading the components (and still
returns a UTC container, because `subtract(Duration(days: 1))` on a local
DateTime lands on 23:00 across a DST boundary). `StreakService.parseDayKey`
builds a **local** date for the same reason — as `DateTime.utc(y, m, d)` a
recovered day came back as the previous day for anyone west of Greenwich, so the
streak the recovery was bought to repair stayed broken. `CraftStats._day` and the
consistency grid had the same shape and got the same fix.

The server has always used the caller's real timezone offset (`tzOffset` in the
backend's `routes/profile.js`), so it was right the whole time and the two
disagreed on the same screen.

### The 🤖 sheet shows the member their own session

The assistant sheet on the dashboard is one thing for members and another for
operators: `_AdminChatsPanel` for an admin — who is waiting, who has paid, who is
mid-conversation — and the fee card plus "Connect Now" for everybody else.

That second half told the same story to everybody, including the member who had
already booked, already paid and was waiting to hear back. Their session was
reachable (`/counselling` opens it rather than the intake form) but nothing on
the sheet said so, so the icon that exists to tell somebody what is happening was
the one place that did not. `_MySessionCard` is now the first card: the status,
what happens next, the counsellor's last line if they have replied, and a button
that goes there. With no session it renders nothing and the sheet reads exactly
as before.

### Deep work: a milestone, its todos, and an honest verdict

`screens/activities/deep_work_screen.dart`, at `/deep-work`. The order on the
screen is the feature:

1. **Milestones first.** Everything else this app measures is a habit — did you
   sit, did you write, did you practise. Habits answer "did you turn up", which
   the journal and the streak already answer well, and cannot answer "is the
   thing getting finished". For somebody working towards a job switch or an
   album that is the only question that matters. Suggestions are seeded from
   their craft, because "next milestone" is an intimidating blank and a
   recognisable one when phrased in their own work. A target date is optional
   and says so — inventing a deadline for somebody is how an app starts lying
   about urgency.

   **As many as they actually have.** This ran one at a time for about a day, on
   the reasoning that three current goals is a backlog. That is a fine opinion
   about focus and a wrong one about lives: somebody studying for an exam is
   also training for a race and also shipping a side project. The screen is a
   list; each milestone opens to its own steps and its own verdict.
2. **Then their own todos.** Add, tick, delete. Nothing else: no priorities, no
   sub-tasks, no dependencies. Anything more is a second job.
3. **Then the analysis, and it is allowed to be bad news.** Percent done, steps
   left, days of real deep work in the last fortnight, the current run, and one
   sentence of verdict — on course, behind by roughly this much a week, or the
   date has passed and should be moved rather than carried as guilt. An app
   that only ever says "great job" is one nobody believes the third time.

The milestones and todos are their own record (`/api/practice/milestones`); the
**days worked** come from the journal's `craftDone` by local calendar day, and
ticking "deep work done today" here writes that same field. One definition of a
working day, so this screen and the consistency chart cannot disagree.

**Achievements are counted month by month**, by the server, in the member's own
calendar — a strip at the top of the deep work list and a full card on
analytics. Counted server-side rather than from the loaded list because that
list is paged: a total derived from page one is right until somebody has more
than a page of achievements and quietly wrong for ever after. Analytics is the
only place that shows what has actually been *finished*, and finished things are
what people forget they did.

This is also what forced `JournalEntry.copyWith` to be fixed. It named only the
sixteen scalar fields and silently dropped the eight list-and-map ones, so
`copyWith(mood: 4)` returned an entry with no habits, no practices, no craft and
no check-in. Nothing had ever called it, which is the only reason no journal was
damaged.

### A member's article is a draft; an operator's is published

`POST /api/blogs` files anything a member writes as `pending`. It is invisible
to everybody but its author and the operator until it is approved, and the only
path to public is the review strip at the top of `/blogs` — which the operator
is alerted to (`type: 'blog_review'`), the same way they are alerted to a
counselling request. Approving is `PATCH /api/blogs/:id/review`, and the
broadcast to every member fires inside that same request, so nobody is told
about an article before it is readable. Turning one down is not a delete: the
author keeps the draft and reads the note that came with the decision.

An operator's own article publishes on the spot, because the queue exists to put
a person between a stranger's writing and the library and they are that person.
The price is that publishing has no undo short of deleting the article, and the
compose screen says so before they tap.

### The thought of the day belongs to a day, not to whoever set it last

`metadata/thought_of_the_day` had no expiry. A line an operator published in
March was still the thought of the day in August, which made the 365 bundled
thoughts — the whole point of `constants/thoughts_365.dart` — unreachable unless
somebody remembered to press "Back to automatic".

The picker stamps its write with `Thoughts365.dateKey(DateTime.now())`, and the
dashboard honours the override only while that stamp equals the reader's own
local today; a value with no stamp is one written before this existed and counts
as expired. So the default is the rotation and the override is a deliberate act
about one day.

Midnight is handled twice on purpose: a one-shot `Timer` aimed at the next
midnight, for a handset left on the dashboard overnight, and a lifecycle check
on resume, because a sleeping phone does not fire timers. The website applies
the identical rule against its own copy of the list.

### Deleting a notification means deleting it

### Deleting a notification means deleting it

Three feeds, and every one of them can now be emptied and stay empty.

- **The X** on a broadcast or an announcement is a dismissal — a broadcast is
  one document everybody reads, so removing it would remove it for the whole
  user base. It is permanent for that member all the same: the server keeps the
  record, every feed filters against it, and it survives a reinstall and a
  second handset.
- **The bin**, for an operator, is `DELETE /api/notifications/:id` and takes the
  notification off everybody's feed for good. Announcements have had this;
  the feed that actually raises the badge had no way to take anything back.
- **Clear this list**, in the app bar, empties whichever tab is open. Twenty
  taps is how "I deleted them and they came back" starts — somebody gives up
  halfway and concludes it did not work.

### There is no member-facing update check

"App Updates" is gone from the profile. An update check is the store's job, and
what the screen actually did was tell a member the build they were running was
the build they were running. The admin control that matters is still there —
"Publish this build as latest" writes `app_config/version`, which is what
prompts every other installation on next open.

---

## 5. Running it

```bash
flutter pub get
flutter run

# against a local API — 10.0.2.2 is the host as seen from the emulator,
# where `localhost` is the emulator itself
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

flutter analyze
```

Production is the default base URL, so a release build needs no flags and
**cannot ship pointing at somebody's laptop**.

Firebase setup — Google sign-in needs SHA-1 and SHA-256 fingerprints in the
console; phone/OTP needs the same for Play Integrity. FCM setup including the
APNs key is in `docs/FCM-SETUP.md` in the [backend repo](https://github.com/itzshashi07/innenflow-backend).

### What this repo deploys to Firebase, and what it does not

```bash
firebase deploy --only firestore    # rules + indexes, from here
```

`firebase.json` here covers **Firestore rules, indexes and the Flutter platform
config — nothing else.** The Cloud Functions this app calls
(`backend_service.dart`) live in the backend repo and are deployed from there.

It used to be the other way round: this `firebase.json` named
`"source": "../functions"`, deploying a directory that was not in this
repository. It only ever resolved because both folders happened to sit inside
one workspace on one machine, and a fresh clone of this repo deployed nothing.

The **rules tests also live in the backend repo** (`firestore-tests/`), reading
`firestore.rules` from a checkout of this one. Change a rule here and run that
suite before deploying — it is the thing that catches a loosened rule.

---

## 6. The other two repos

| Part | Repo |
|---|---|
| This app | `github.com/itzshashi07/Brahma-Journal-app` |
| API + Cloud Functions + rules tests | `github.com/itzshashi07/innenflow-backend` |
| Website | `github.com/itzshashi07/brahma-journal-web-app` |

**A change that spans two is two commits to two remotes.**

Things that must move together:

- **Design tokens.** `lib/core/theme/app_theme.dart` is the source; the website's
  `tailwind.config.ts` copies it. A near-miss on the purple is more noticeable
  than a completely different design, because the eye reads it as the same thing
  rendered wrong.
- **Legal copy.** `lib/screens/legal/legal_screen.dart` ↔ the website's
  `src/content/legal.ts`.
- **API shapes.** A changed response breaks both clients.
- **`firestore.rules`** ↔ the backend's `firestore-tests/`. The file is deployed
  from here and tested from there.
- **Callable names.** The strings in `lib/services/backend_service.dart`
  (`createSubscription`, `verifyProductPayment`, `sendSupportEmail`,
  `setAdminClaim`, …) are the exported names in the backend's
  `functions/index.js`. Renaming one fails at runtime with `NOT_FOUND`, not at
  build time — there is nothing to catch it but this note.

---

## 7. Known gaps

- **`community_service.dart` is still on Firestore.** Its one listener was removed
  (it was dead code — `NotificationCenter` reads the watchlist over the API), but
  the reads and writes have not been migrated.
- **The legal copy still says Firestore in places.** The website's version
  describes the current architecture; this one should be brought into line.
- **No iOS build yet.** The website is the iOS story for now — it works fully in
  Safari and can be added to the home screen.
- **`_seenAt` semantics changed** with the badge moving server-side. Read state is
  now per account rather than per device. Intended, but worth knowing if
  something looks different across two handsets.
