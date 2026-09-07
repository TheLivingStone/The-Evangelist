# App Review reply — Guideline 2.1 "Information Needed"

Paste everything under "NOTES" into App Store Connect → App Review
Information → Notes, and attach the recording. Replace the two bracketed
placeholders first.

## What Apple asked for, and where each answer is

| # | Request | Answer |
|---|---------|--------|
| 1 | Physical-device recording from app launch, incl. registration / login / deletion, UGC report + block, permission prompts | New recording per the script below (`GoAndTell_ReviewRecording.mp4`) |
| 2 | Devices and OS versions tested | In notes §2 |
| 3 | Functions, audience, problem, value | In notes §3 |
| 4 | Setup instructions + credentials | In notes §4 (needs the demo account) |
| 5 | External services | In notes §5 |
| 6 | Regional differences | In notes §6 |
| 7 | Regulated industry / protected material | In notes §7 |

## Recording script (record in ONE take on your iPhone, do not stop)

Before recording: delete the app from the phone and reinstall from TestFlight
(or the build I installed), so every prompt appears fresh. Turn on Do Not
Disturb so no notifications drop in. Have a throw-away email ready for the
demo account (e.g. `review@` on a domain you control, or a fresh Gmail).

1. Start the screen recording on the HOME SCREEN, then tap the Go and Tell icon.
2. Onboarding: Begin → verses → type a name and city → pick a goal → finish.
3. Home: the "Start here" tip appears → Got it.
4. Tap + → "Log Conversation" tip → Got it → tap Log Conversation.
   The "Create your account" sheet appears: fill name, email, password →
   Save & continue. (This is the registration flow.) The conversation logs.
5. Tap + → Add Person → fill first name, where you met, status → Save.
6. Tap + → My People → open the person → Follow-up → confirm.
7. Community tab → the compose tip → Got it → tap the pencil → write a short
   testimony → Post. Then on someone else's post: tap ⋯ → Report → send.
   Tap ⋯ again → Block → confirm. Open Profile → Blocked accounts → Unblock.
8. Map tab → the LOCATION PROMPT appears → Allow While Using App → tip →
   Got it → tap a church pin → Find & register churches → Register a church →
   type an address → search → show the pin → cancel with the back arrow.
9. Profile → toggle "Show me on the map" on and off → How Go and Tell works →
   back → sign out (top-right icon) → sign back in with the same email and
   password (this is the login flow).
10. Profile → Delete account → Delete → confirm. The app returns to the
    guest/sign-in state. Stop the recording.

Then send me the file and I will trim only dead time, never the flows.

---

## NOTES (paste into App Store Connect)

Thank you for the review. Answers to each point:

**1. Screen recording.** Attached: recorded on an iPhone 15 Pro Max running
iOS 26.6.1. It starts from the Home Screen launch and shows, in order:
onboarding, account registration (email), logging outreach, adding and
following up with a contact, posting user content, reporting and blocking
another user (and unblocking from Profile → Blocked accounts), the location
permission prompt and the map, church registration, sign out and sign in,
and account deletion (Profile → Delete account).

**2. Devices tested.** iPhone 15 Pro Max (iOS 26.6.1, physical device);
iPhone 17 Pro and iPhone 16 (iOS 26.5 simulator); iPad Air 13-inch M3
(iPadOS 18.6 simulator, for layout).

**3. What the app does and for whom.** Go and Tell is a personal outreach
journal for Christians who share their faith. Users log conversations,
prayers and decisions in one tap, keep a private list of the people they meet
with follow-up reminders, and see their streak and totals. A community feed
lets them post testimonies and encourage one another, and a map shows other
users who are currently out sharing (opt-in, approximate) and churches that
have registered and been verified by our team. Target audience: adult
church members, evangelism teams and pastors. The problem it solves: people
who share their faith have no simple way to remember who they spoke to,
follow up, or stay motivated; churches have no way to connect new contacts
to a local congregation. The app is free, with no purchases or subscriptions.

**4. Access and setup.** The app opens as a guest with no login; every
screen can be viewed immediately. Creating an account is required only
when saving data, and can be done with Apple, Google or email. Demo account
for the reviewer: email `[DEMO EMAIL]`, password `[DEMO PASSWORD]`. This
account already has sample contacts, posts and a registered church. No
sample files are needed. Account deletion is under Profile → Delete account.

**5. External services.** Supabase (authentication, PostgreSQL database with
row-level security, file storage for post photos, and an edge function that
performs account deletion); Sign in with Apple and Google Sign-In (optional
login methods); Apple CoreLocation geocoding and, as a fallback,
OpenStreetMap Nominatim (turning a typed church address into a map pin);
Esri ArcGIS basemap tiles (the map imagery). No payment processors, no
advertising or analytics SDKs, no AI services.

**6. Regional differences.** None. The app functions identically in all
regions and is offered in English only. The map works worldwide.

**7. Regulated industry and third-party material.** The app does not operate
in a regulated industry and contains no third-party content beyond brief
Scripture quotations (a few verses), which are used within the publishers'
free-use terms with the required copyright notices shown in the app
(Profile → About & credits). All other content is created by the app's users.
