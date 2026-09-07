# Go and Tell — App Store listing & submission steps

Everything below is ready to paste into App Store Connect. Character limits
are Apple's; every field here fits.

## 1. Submission steps (in order)

1. **Supabase**: run `supabase/migrate_church_pastor.sql` in the SQL editor
   (done 2026-09-04) and the CJC location fix.
2. **Record the preview** on your iPhone (Settings → Control Center → add
   Screen Recording). Portrait, dark mode, 20–25 s, trimmed so Control Center
   never shows. Take 3–6 screenshots during the same walk-through.
3. **Xcode**: open `app/ios/The Evangelist.xcworkspace`, select
   *Any iOS Device (arm64)*, Product → Archive, then *Distribute App →
   App Store Connect → Upload*.
4. **App Store Connect → My Apps → your app**:
   - App Information: Name **Go and Tell**, Subtitle, Category *Lifestyle*
     (secondary *Social Networking*), Privacy Policy URL.
   - Pricing: Free.
   - App Privacy: fill in the data types (see §5).
   - Version page: paste Promotional Text, Description, Keywords, Support URL,
     What's New; upload the preview + screenshots to the **6.9-inch iPhone**
     slot; pick the build you uploaded.
   - Age Rating: answer the questionnaire (nothing sensitive → 4+).
   - App Review Information: paste the Review Notes (§4). No demo account is
     needed — the app opens as a guest.
5. **TestFlight** (optional but recommended): install the uploaded build on
   your phone via TestFlight and run through the tour once more.
6. Press **Add for Review → Submit**. Review usually takes 1–3 days.

## 2. Listing copy

**Name** (30 max): `Go and Tell`

**Subtitle** (30 max): `Track and share your outreach`

**Promotional text** (170 max):
> Every Gospel conversation counts. Log it in one tap, follow up with the people
> you meet, and see who is out sharing near you.

**Keywords** (100 max, comma-separated, no spaces):
`evangelism,outreach,gospel,church,discipleship,follow up,ministry,christian,missions,prayer`

**Description** (4000 max):

Go and Tell is the simple companion for anyone who shares their faith. Log
what happened in a tap, keep track of the people you meet, and stay encouraged
by a community doing the same.

WHAT YOU CAN DO
• Log a conversation, a prayer or a decision in one tap
• Build a daily streak and a weekly mission that keeps you going
• Save the people you meet and get reminded when a follow-up is due
• Mark the journey: conversation, follow-up, decision, connected to a church
• Share testimonies and encourage others in the Community feed
• See evangelists live near you on the map, and the churches taking part
• Join your home church, or register it for verification
• Daily encouragement: a verse and a tiny mission for today

MADE FOR CHURCHES TOO
Churches can register, get verified by our team, and, with each member's
permission, receive the details of new contacts so nobody falls through the
cracks.

YOUR PRIVACY
You choose whether you appear on the map, and only while you are actively out
sharing. Contacts are shared with your church only if you turn that on. You can
delete your account and data at any time from Profile.

Explore everything as a guest. Create an account with Apple, Google or email
the first time you save something, so nothing is lost.

Go. Share. Disciple. Make disciples.

**What's New** (first version):
> First release. Log outreach in one tap, follow up with the people you meet,
> see the map of evangelists and verified churches near you, and share
> testimonies with the community.

**Support URL**: your website or a page with a contact email.
**Marketing URL** (optional): your website.
**Copyright**: `2026 CJC Grace Tech`

## 3. Preview & screenshot shot list (record in this order)

1. Splash → Home (the streak card)
2. Tap the orange + → Log Conversation → the confirmation
3. Add Person → save
4. My People → open a person → follow-up
5. Map tab → tap a church pin → the church card
6. Community → a testimony post
7. Profile → "How Go and Tell works"

## 4. App Review notes (paste into "Notes")

> Go and Tell opens as a guest with no login required; every screen can be
> explored immediately. Creating an account (Apple, Google or email) is only
> requested when the reviewer saves something. Sign in with Apple is offered
> wherever third-party login is offered. Account deletion is under Profile →
> Delete account. Location is optional and used only to centre the map and,
> when the user opts in, to show them on the map during an active outreach.
> Church listings are verified manually by our team before being marked
> verified. Reporting and blocking are available on every post and profile.

## 5. App Privacy answers

Data collected, linked to the user: **Name, Email, Coarse Location (optional),
User Content (posts, contacts the user records), Identifiers (user ID)**.
Used for **App Functionality** only. Not used for tracking. No third-party
advertising.
