# Budgetify — marketing campaign

Assets and plan for the Google Ads App campaign, built 2026-08-16 and reviewed
2026-09-03. Nothing here is live: the campaign is staged, not started.

```
ads content/
  copy.md                 English + Hindi + Hinglish copy, validated
  validate.py             fails if any line is over Google's limit
  build-ad-images.mjs     composes the image assets from real app captures
  build-ad-videos.sh      cuts the 58s launch film to ad lengths
  images/                 20 PNGs — 8 concepts, up to 3 ratios each
  video/                  4 MP4s — 15s and 30s, 9:16 and 1:1
```

Rebuild either set with `node build-ad-images.mjs` / `./build-ad-videos.sh`.

The **feature graphic** lives next door at `../playstore/feature-graphic.png`
(`node ../playstore/build-feature-graphic.mjs`). It is a Play listing asset, but
an App campaign pulls it into ad placements automatically — which is why the ad
preview showed a banner before a single image asset had been uploaded. It counts
as campaign creative whether or not you upload anything here.

---

## Reviewed 2026-09-03

**Changed in this pass**

- **`02-reads-sms` now shows a bank SMS.** It did not. The concept whose entire
  claim is "it reads your bank SMS" was cropped to the amount and the direction
  arrow, and the `Original Message` panel — the raw ICICI text the parse came
  from — sat below the frame in all three ratios. The crop moved from 96 to 570,
  and the ad now carries the amount, the payee it resolved (`Zomato`), the
  account, and the message it resolved them from, in one shot. That panel is the
  product's whole argument; it should not have been the part left out.
- **A Hindi ad group's copy exists.** The campaign targeted India in English and
  Hindi and had English assets only. `copy.md` now carries five Hindi headlines,
  five Hindi descriptions and alternates, plus a Hinglish set to test later.
- Stale counts in this file and in `copy.md` (both still said 12 images).

**Still open, in the order it costs you money**

1. **The store page, again.** The listing was last measured on 2026-08-08 at
   **v1.44.3, 5+ installs, 0 ratings** (`../playstore/listing/README.md`); this
   repo is on 1.83.0. Every rupee of ad spend is multiplied by that page's
   conversion rate, and paid traffic lands on whatever is live, not on what is
   built. Confirm what is actually on the store before the first impression.
2. **The video end card contradicts `copy.md`.** All four cuts close on **"Get it
   free on Google Play"**, and `copy.md` says in as many words not to claim
   *free*, because Plus is a real purchase. Both positions are defensible — the
   download *is* free, and Play draws its own "Free" badge — but they cannot
   both be the rule. Either relax the rule for the standard Play phrasing, or
   re-render the end card. Do not ship them disagreeing.
3. **`07-your-language` shows an untranslated string.** The Hindi capture behind
   "Budgetify speaks your language" renders `₹66,830 saved of ₹95,000 income` in
   English. `lib/widgets/savings_summary.dart` reaches for `context.l10n`
   everywhere else but hardcodes two lines — that one and `Overspent by …`. It
   is a small product bug, and a bad one to buy traffic for, since it is on
   screen in the ad that promises localisation.
4. **The demo persona is not the audience.** The seeded screens show ₹95,000
   monthly income and a 70% savings rate. For a campaign aimed at people in
   general, that is a top-percentile household, and the numbers quietly say "not
   for you". Reseeding is not free — `../playstore/captures/` feeds the Play
   screenshots too, so both sets get re-shot together — but it is the highest-
   leverage creative change left.
5. **No 16:9 video.** The four cuts are 9:16 and 1:1, so the campaign never
   serves YouTube in-stream. A real 16:9 means re-rendering from
   `marketing/budgetify-launch-film.html` at that canvas, not letterboxing.
6. **The film source is not in git.** `budgetify-launch-film.html`,
   `render-film.mjs` and `rebuild-from-transcript.py` are untracked and exist on
   one machine. The `.mp4` master is ignored by design; the sources should not
   be. Losing them means the ad cuts can never be re-made.

**What an install is worth, honestly**

Plus is ₹49/month, ₹499/year, ₹1499 lifetime, and every new install starts a
**90-day trial** (`EntitlementService.trialDuration`). After Play's 15% cut, a
yearly subscription nets about ₹424 and a lifetime about ₹1274. So at a ₹25
target CPI, break-even is roughly **1 in 17 installs buying a year**, or 1 in 51
buying lifetime — and the first rupee cannot arrive until the trial ends three
months after the click. With no in-app telemetry you will not be able to measure
any of it.

That is not an argument against advertising. It is an argument for treating the
budget as **the price of distribution and reviews**, deciding the number up
front, and judging the campaign on Play Console's retained-installer curve —
because nothing else about it is measurable this year.

---

## Two things to fix before any money moves

### 1. The $500 credit is not $500 of free advertising

Google's promotional credit is a **spend-matching** offer, not a grant. The
India tiers work out as: accrue ₹X of your own ad cost within **60 days** of
applying the code, and Google then issues ₹X of credit. So "$500 free" means
committing roughly **₹40,000 of real money first**, and the campaign has to run
hard enough to hit that inside 60 days or the credit never arrives at all.

The mechanics that bite:

- The code must be applied **within 14 days of your first ad impression**. Apply
  it before you launch, not after you see how it is going.
- The credit takes **up to 35 days** to appear after the threshold is met.
- The credit itself **expires**, typically 60–90 days after issue.
- Spend before the code was applied does not count toward the threshold.

None of that makes the offer bad — it is a genuine 2x on money you were going to
spend. It is only bad if you budgeted ₹0 and expected ₹40,000 of traffic.
**Verify your specific offer's threshold and window in Billing → Promotions
before planning around a number.**

### 2. Open testing can be advertised — but it will convert badly

Good news first: Google explicitly supports **open testing ads** in App
campaigns, so being on the open track is not a blocker. Your app has a public
listing and already ranks #1 for its own name.

The problem is what happens after the click. An open-testing listing tells the
visitor they are joining a test. Paid traffic is colder than organic traffic and
needs *more* reassurance, not less — and it lands on a page that says
"unreleased", shows **0 ratings**, and carries a store description that is still
the stale one until the rewritten listing goes live.

Every rupee of ad spend is multiplied by that page's conversion rate. Fixing the
page is free. Buying traffic to a page you have not fixed is not.

**Sequence: production release → publish the rewritten listing → collect first
ratings → then spend.**

---

## What you can and cannot measure

This is the constraint that shapes the whole campaign, and it is a direct
consequence of a decision worth keeping: the release build has **no INTERNET
permission**, so Firebase, Google Analytics and every third-party attribution
SDK are all impossible to install.

| | Available |
|---|---|
| Install conversions from Google Play | **Yes** — codeless, via the Google Ads ↔ Play Console link |
| First opens | No — needs Firebase or an attribution partner |
| In-app events, trials, purchases | No |
| Target ROAS / target CPA on in-app actions | No |
| Retention by acquisition channel | **Yes** — Play Console, not Google Ads |

So:

- Run **App campaign for installs**, bidding **target CPI**. The action-based and
  ROAS-based campaign types need event data you cannot send.
- **Link Google Ads to Play Console first.** Without it you have no conversion
  signal at all and the campaign optimises blind.
- Your analytics is **Play Console → Grow → Acquisition reports**, which breaks
  retained installers down by acquisition channel. That is where you find out
  whether paid installs stay — Google Ads itself will never tell you.

**Judge the campaign on Play Console's retained-installer curve for the Google
Ads channel versus organic.** Install count in Google Ads is a vanity number
here; you have no fraud signal and no quality signal inside the ads account.

---

## Campaign setup

| Setting | Value | Why |
|---|---|---|
| Type | App campaign → App installs | Only type your measurement supports |
| Platform | Android | Play-only product |
| Location | India | The parser is built for Indian bank and UPI SMS |
| Language | English + Hindi | App ships 6 languages; start with the two biggest |
| Ad groups | One per script | An App campaign mixes assets inside a group, so English and Hindi lines must not share one |
| Bidding | Target CPI, "All users" | Not "users likely to perform an in-app action" — that needs events |
| Budget | See below | |
| Assets | 5 headlines + 5 descriptions per ad group, 20 images, 4 videos | All in this folder |

### Budget

Google's guidance for App campaigns is a daily budget of **at least 50× your
target CPI**, so the algorithm gets enough conversions per day to learn.

| Target CPI | Google's recommended daily | Monthly |
|---|---|---|
| ₹15 | ₹750 | ~₹22,500 |
| ₹25 | ₹1,250 | ~₹37,500 |
| ₹40 | ₹2,000 | ~₹60,000 |

If you want the credit's 60-day threshold and the 50× rule to line up, ₹20–25
target CPI at ₹1,000–1,250/day gets you to ~₹40,000 in about 35 days — inside
the window with room to spare.

Below roughly ₹500/day the campaign will learn slowly and noisily. That is not a
reason to skip it; it is a reason to run it for longer before judging it, and to
change **one** thing at a time.

### Videos must go to YouTube first

Google Ads cannot take an MP4 upload for a video asset — it takes a YouTube URL.
Upload the four cuts as **unlisted** (they do not need to be public, and unlisted
keeps them off your channel's front page).

Upload all orientations. A landscape-only campaign never serves on Shorts; a
portrait-only campaign gives up in-stream and Display inventory.

---

## The assets

### Images — 20, the maximum an ad group takes

| Concept | Angle | Ratios |
|---|---|---|
| `01-automatic` | Every rupee tracked. Zero typing. | all three |
| `02-reads-sms` | It reads your bank SMS. | all three |
| `03-no-internet` | No internet permission. | all three |
| `04-where-it-went` | See where it actually went. | all three |
| `05-product` | No overlay at all — product only | all three |
| `06-recurring` | Nothing bills you by surprise. | landscape, square |
| `07-your-language` | Budgetify speaks your language. | landscape, portrait |
| `08-net-worth` | Watch your net worth compound. | square |

Ratios are 1200×628 (landscape, required), 1200×1200 (square, required) and
1200×1500 (portrait, optional but unlocks extra inventory). All under 5 MB, PNG.
**Upload all 20** — you do not pick between them, Google picks which shape fits
each placement.

**The three ratios are not three copies of one asset.** Google does not resize
across placements — it serves 1.91:1 to Display, 1:1 to Discover and mobile
feeds, and 4:5 to inventory neither of the others reaches. Each ratio has to be
supplied separately or that inventory simply goes unserved.

Google asks for **at least 4 landscape, 4 square and 2 portrait** to reach a
strong Ad Strength rating, and takes **up to 20 per ad group**. The spread here
is **7 landscape / 7 square / 6 portrait**, weighted toward landscape and square
because landscape draws the most Display inventory and square dominates Discover
and mobile feeds. That is the ceiling — to add a new concept later, retire a
weak one from the asset report first.

`05-product` carries no overlay text on purpose. Google draws its own app icon,
headline and Install button over the creative, and its guidance is to include at
least one untexted image per ratio so something in the set is not competing with
that chrome. The only words in it are the app's own UI.

`03-no-internet` deliberately carries no phone. A screenshot cannot show the
*absence* of a permission, so the claim carries itself — and four near-identical
phone shots collapse into one blurred rectangle at the size these actually get
seen at. It closes on the app's own motto rather than an invented tagline.

### Video — 2 lengths × 2 ratios

Cut from the 58s launch film. Google recommends 10–30s for install campaigns;
58s is a brand film, not an ad.

| File | Structure |
|---|---|
| `budgetify-30s-*` | problem → product → **privacy** → CTA |
| `budgetify-15s-*` | problem → product → CTA |

Every cut point is a multiple of 2.5s because the score runs at 96 BPM and one
bar is 2.5s — the difference between a cut that sounds like an edit and one that
sounds like a mistake. The 30s keeps the privacy beat, which is the reason to
pick this app over a free tracker that phones home; the 15s trades it for length.

**The 16:9 variant is missing on purpose.** The film is natively 1080×1920. A
16:9 version made by letterboxing it would be two-thirds empty bars, and a
centre crop would cut the captions, which sit low in nearly every beat. A real
16:9 means re-rendering from `marketing/budgetify-launch-film.html` at that
canvas. Worth doing before a serious flight — say the word and I will.

---

## What to spend on instead, first

At 0 ratings and an unreleased-track listing, paid installs are the *expensive*
way to get the next hundred users, and you cannot measure their quality. Cheaper
moves, roughly in order of leverage:

1. **Production release + the rewritten listing.** Already written and waiting in
   `marketing/playstore/listing/`. Rank takes 2–4 weeks to settle, so the clock
   should start now rather than after the ad spend.
2. **First 20 ratings.** The in-app prompt ships (v1.70.0) but only fires for
   Play-installed builds after four weeks. Ask people directly.
3. **The film, posted organically.** The 9:16 cuts are Shorts/Reels-native and
   cost nothing to post. A privacy-first Indian finance app is a story that
   communities like r/india and r/IndiaInvestments will actually engage with —
   the same wedge the ad copy uses.
4. **Then paid**, with the store page fixed and a few ratings on it, so the money
   lands on a page that converts.

---

## Risks worth naming

- **Junk installs.** India install campaigns can attract low-quality traffic, and
  with no in-app telemetry your only detector is the Play Console retention
  curve. Check it weekly; if retained installers from Ads sit far below organic,
  the campaign is buying nothing.
- **The SMS permission.** Reading SMS is the product, and it is also the scariest
  permission on the platform. The copy leads with what the app *cannot* do
  (reach the network) precisely to defuse that — keep it that way.
- **Brand-name collisions.** At least eight unrelated products ship as
  "Budgetify". Bidding on the brand term buys clicks for other people's apps;
  win on claim queries, not brand queries.
