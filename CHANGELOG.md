# Changelog

All notable changes to Budgetify are documented here. Dates are in
`YYYY-MM-DD`. Everything stays on-device — these features add capability
without adding any network access.

## [1.75.1] — 2026-08-15

Everything below landed after 1.75.0's build was cut, so this is the first
release any of it reaches. One item reverses something 1.75.0 announced.

### Fixed

- **Flicking "Match app icon to my royal" force-closed the app.** 1.75.0 said
  the switch would reconcile the icon the moment you flipped it, "silently: no
  confirm and no restart". That was wrong about the platform. Android applies
  an alternate icon by disabling the launcher component the app is currently
  running on, and it tears the running task down when it does — whatever
  `DONT_KILL_APP` implies. So the switch closed the app, with nothing asked,
  for an avatar you had not chosen to keep yet. **The icon now only ever
  changes on Save**, through the same confirm-and-restart prompt as before.
  Two more silent swaps went with it: one at startup (a crash on launch) and
  one in the middle of a restore.
- **The launch parade sometimes did not play at all.** A session gets one
  entrance, and there were two ways to spend it on nothing: a dialog already on
  screen when the app opened, and a dialog arriving a beat later, mid-parade —
  a rating prompt, a restore, a tutorial step. Now a popup delays the entrance
  rather than consuming it, and cancelling one hands it back.
- **The Sentinel and the Huntress had no splash.** Both shipped with their own
  launcher icons and the default gold splash behind them, because the splash's
  gem artwork was maintained by hand alongside the icon roster and nothing held
  the two together. They now have their own, and the roster is checked.
- **Restoring a backup could turn settings back on that you had turned off.**
  No preference was ever carried in a backup, so a restore reset each one to
  its default — and "match app icon to my royal" defaults on. Your own choices
  now ride along, and a backup made before this carries none, so it leaves your
  settings alone rather than resetting them.

### Changed

- **The Huntress somersaults once on the way out, not seven times.** Her
  entrance was unreadable, and the earlier attempts to fix it by giving her
  more room could not have worked: the tumble was never too fast, it was being
  restarted. Her traversal is a one-shot sequence — run-up, somersault, landing
  — but the parade drove it the way it drives a gallop, which loops. Across one
  crossing that is about seven somersaults, and seven more coming home. She now
  crosses once, pivots at the far end with her blades already up, and sprints
  home without a second tumble.
- **Her pacing is now the court's, not her own.** With the tumble no longer
  restarting, the room she had been given to compensate read as sluggishness
  instead — a 12s parade against the court's 5.6s. Every span of hers is now a
  whole number of the court's beat: one for the somersault, four for the
  signature because it is four separate moves. Her parade falls out at 8.4s
  rather than being picked.

## [1.75.0] — 2026-08-14

### Fixed

- **"Match app icon to my royal" did nothing until you saved an avatar.** The
  switch only recorded the preference; reconciling the launcher icon was left
  to the next avatar *save*. So turning it off and closing the sheet left the
  launcher wearing a royal the preference had already disowned — and re-picking
  the same royal could not fix it either, since that is not a change. The
  switch now reconciles the icon the moment you flip it, silently: no confirm
  and no restart, because being thrown out of the app for flicking a switch
  would be worse than the icon waiting for the launcher's next refresh.
- **The launcher icon never reconciled at startup.** It is the third OS surface
  that mirrors your equipped royal — after the app-wide theme dress and the
  notification skin — and the only one that did not re-sync on launch. Anything
  that changed the avatar by another route (restoring a backup, a royal being
  revoked) stranded the icon permanently. It now reconciles alongside the other
  two.

### Changed

- **The Huntress's entrance was too fast to follow.** The welcome parade ran
  for one flat 5600ms for the whole court, which quietly assumed every royal
  signs off with the same amount of *movement*. Six of them do — a salute, a
  curtsy, a roar are each one gesture. Hers is four (throw, sweep-kick, catch,
  present), and she is also the only royal who somersaults across the screen,
  so the shared timeline gave her under 200ms a beat: a flicker rather than
  choreography. Her parade now runs 9200ms with 2208ms of it on the signature —
  about 550ms a beat — and the somersault's airborne window widened from 44% to
  58% of the crossing, which is what actually slows the turn (it is one full
  rotation however long you give it). The Sentinel gains a smaller extension
  for the opposite reason: his signature is *holding still*, and stillness
  needs long enough to read as deliberate rather than as a stall. The other six
  are untouched.

## [1.74.0] — 2026-08-14

### Fixed

- **The Huntress's entrance was a giant rolling head.** Her launch traversal —
  the somersault she does instead of riding, since she is the only royal with
  no mount — drew the standing figure into the *wide* 150×96 ride box. The head
  is sized off box **width** (`w * 0.66` = 99px), so it came out taller than the
  frame it was in, and the body was buried underneath it. Every mounted royal
  already avoided this: the ride pipeline seats its rider in a `Size(h * 0.78,
  h)` sub-box, and the on-foot path was the one place that skipped the
  convention. It now follows it, and a test measures the drawn width rather
  than trusting anyone to notice by eye.
- **The Sentinel braced inside a ring of pink hearts.** His signature and the
  Huntress's somersault had no case in the action-accent switch, so both fell
  through to the generic *cheer* — stars and hearts popping around the head.
  The accents also switched on what a frame was *for* rather than what the body
  was doing, which is why the traversal (a `ride`) was decorated as a cheer even
  once the somersault had its own entry.

### Changed

- **The Sentinel carries a spear.** The shield alone read as a man holding a
  door — and the deeper problem was that the shield *was his weapon*, drawn out
  of the weapon hand, which laid it flat across his own breastplate and hid
  every piece of plate he owns. The spear takes the weapon hand; the shield
  moves to the free arm where a shield is actually worn. He now thrusts rather
  than borrowing the club's smash: the only royal in the court who strikes from
  behind cover, and the only attack with no arc in it. Mounted, the spear
  couches across the destrier's neck instead of standing upright, which is the
  difference between a charge and a commute.
- **The Sentinel had no detail layer at all**, which is why a man in full plate
  rendered as a smooth grey bell — every other royal has one. He gains
  pauldrons, a gorget, a sapphire surcoat, a guard's cloak and a swallow-tail
  pennon on the spear, and his shield's field is now sapphire over a steel rim
  rather than steel on steel. Colour on him has to come from cloth: every
  surface he owns wants to be metal.
- **The Huntress has three moves of her own** — she is the only royal with no
  mount to carry a personality for her, and she was borrowing the Sovereign's
  slash. Her entrance now signs off with a **dagger toss** (blade thrown up
  end-over-end, a low sweep-kick turning underneath it, caught reversed behind
  the back), she attacks with a **flying kick**, and her cameos are a **blade
  dance** — the only one of the three that fits in a standing box, which is
  where a cameo has to work. The somersault stays her traversal, and it now
  tucks: both knees folded up together rather than scissored apart, which is a
  stride however short you make it.
- **The Huntress reads bolder.** Her skin was being painted and then covered —
  the tank hem overpainted the bare shoulders it sat above, and the bottom four
  rows of her 16×16 portrait were a slate slab landing exactly where her
  shoulders and chest do on the full body. The torso is now drawn as skin and
  *dressed*, rather than dressed and then patched: bare shoulders and arms, a
  cropped top, an open midriff, long bare thigh above the boots, wrapped
  forearms, a buckled thigh strap with a spare blade in it.
- **Both new royals moved like nobody in particular** — neither had a motion
  personality, so both used the fallback. The Sentinel now carries the slowest
  breath in the court and almost no rock at all; the Huntress the fastest and
  the springiest stride.

## [1.73.0] — 2026-08-13

### Added

- **Two new royals: the Sentinel and the Huntress.** The court was six; it is
  now eight, and the two newcomers are deliberately not more princes.
  - **The Sentinel** is the crown's sworn guard, in steel and sapphire. He is
    the only royal with **no face** — an office rather than a person — which
    costs him a blink, so instead the glow in his visor slit dims when he
    blinks and slides along the slit when he glances. He carries a tower
    shield rather than a blade and is the only member of the court who attacks
    by *advancing*: a charge, a slam, and then a brace he holds. His signature
    is refusing to perform for you. He rides a barded grey destrier.
  - **The Huntress** is dispossessed nobility gone to the road: headband,
    mask, paired daggers, absinthe green. She is the only royal **without a
    mount** — where the others gallop across a page she sprints it and
    somersaults through the middle — and the only one with a heavy brow, which
    is what keeps her from reading as gentle like the rest of the court.
  - Both bring a full court: profile-card theme, app-wide dress in Light and
    Dark, launcher icon, notification colour, ambient cameo manner, and a
    signature move. Like the four before them they start locked, and the
    streak budget is unchanged at two picks — this adds royals to choose
    between, not more royals to earn.

### Changed

- **The Royal Medic is now the Apothecary.** Hers was the only name in the
  roster that was a job rather than a rank, and "medic" is modern military
  vocabulary standing in a medieval court — her own description already called
  her the court physician. Nothing else about her changes: same emerald court,
  same kit, same unlock. If you have her equipped she stays equipped.

### Fixed

- **A latent bug that would have changed twelve avatars' faces.** The boundary
  marking where the post-royal avatar block begins was being *calculated* from
  the length of the royal roster rather than recorded. It was correct for
  exactly as long as the court stayed at six. Adding a royal moved it, and
  every saved avatar from that boundary onward would have quietly resolved to
  different artwork — you would have opened the app as somebody else, with
  nothing on screen to explain it. Avatar slots are permanent, so the boundary
  is now a fixed value that cannot drift when the roster grows.

## [1.72.0] — 2026-08-13

### Changed

- **Every royal now dresses both Light and Dark.** Each court used to claim one
  mode and go quiet in the other: the Sovereign and the Empress coloured the
  Light theme, the other four coloured Dark, and switching modes stripped your
  royal back to plain gold everywhere but its own face. Equipping the Princess
  and reading in Light meant seeing none of her. A cosmetic earned with a
  24-day streak shouldn't depend on which mode you read in, so every royal now
  carries two shades of its court — the bright one for the dark canvas, a
  deeper one for ivory — and follows you between them. The Prince's bronze and
  the Royal Medic's emerald were deepened slightly to stay readable on the
  light canvas they can now reach; nothing else about any court changed, and
  the hand-tuned streak-reward themes are still left alone.
- **The court sheet says so, and lets you look.** The pill that named one theme
  ("Rules the Dark theme") now promises both, and the line beneath it — which
  used to nag you to switch modes before your royal would show up — confirms
  the court is live where you are and offers a one-tap look at it in the other
  mode. The sheet repaints along with the app when you take it, so you can
  compare the two without closing anything.

### Fixed

- **A credit limit changing is no longer logged as income.** ICICI's "The
  credit limit for your ICICI Bank Credit Card XX6528 has been changed from INR
  200000 to INR 60000" was landing in the ledger as ₹2,00,000 received. The
  notice arrives on the same transactional route as real alerts, "changed from
  INR 200000" reads exactly like money arriving, and the card number on the
  message was enough to make it look genuine. Budgetify already ignored limits
  being set or updated, but not when the card and its number sat between the
  word "limit" and the change itself. Spend alerts that quote the remaining
  limit are unaffected and still get logged.

## [1.71.0] — 2026-08-11

### Changed

- **The royals now behave like themselves in their small appearances too.** The
  four ambient cameos — strolling along the bottom of a page, galloping across
  it, peeking in from an edge, popping up for a tiny celebration — were one
  choreography each, played identically by all six. *Where* they appeared was
  already random; what they *did* once they got there was not. Each royal now
  carries its own manner through all four:
  - **The Empress never stops and never lands.** No walk, no pause, no wave —
    she passes through rather than visiting.
  - **The Sovereign crosses in bursts**, arriving and leaving almost between
    frames and holding perfectly still in between.
  - **The Dark Prince stalks**: slow to build speed, heavy on his feet, and he
    holds a long look instead of waving at anyone.
  - **The Princess flits** — quick little airborne hops, and her dash arcs
    across the screen rather than crossing it flat.
  - **The Prince and the Royal Medic keep the original manner**, on purpose:
    it's the baseline the others read against.

  A manner is deliberately the same across all four cameos. A royal that stalked
  when it strolled but flitted when it peeked would have no character at all.

## [1.70.2] — 2026-08-11

### Fixed

- **The app builds again on Flutter 3.44.** Two things broke underneath us when
  the toolchain moved, neither of them caused by any change we made: a
  page-transition class stopped being available from where it was imported,
  which stopped the whole app compiling, and a new framework assertion started
  firing whenever a royal's court sheet was opened. Both are fixed, and nothing
  looks any different.

## [1.70.0] — 2026-08-09

### Added

- **Budgetify asks for a Play Store rating, once, after you have had it four
  weeks.** The app has never asked, and it shows: a listing with no ratings
  has nothing to persuade the next person with, and rating count feeds Play's
  own search ranking. The clock runs from **first install**, not from first
  launch of the current data — it reuses the same anchor the free window
  does, so clearing app data or reinstalling neither hands you a fresh four
  weeks nor re-asks someone who already answered. There is no "Enjoying
  Budgetify?" dialog in front of it: Google's guidelines forbid filtering who
  gets asked by predicted sentiment, so the app asks everyone due or nobody.
  It also stays quiet until you have at least five transactions logged, waits
  for the guided tour to finish and for a moment when nothing else is on
  screen, and gives up entirely after three attempts spread over four months.
- **Settings → About → Rate Budgetify** opens the Play listing directly, for
  anyone who wants to say something without waiting to be asked. It uses the
  store listing rather than the in-app card on purpose: that card is
  quota-limited and may show nothing, which would make a deliberate tap look
  broken.

The rating flow adds **no network permission**. `com.google.android.play:review`
ships an empty manifest and talks to the Play Store app over IPC, exactly as
billing does; the merged release manifest was checked and still has no
`INTERNET`.

## [1.69.0] — 2026-08-08

### Fixed

- **Backing out of the "apply to similar" sheet no longer tags the
  transaction anyway.** Saving a tag wrote the row to the database *before*
  asking how far the tag should reach, so dismissing that sheet left the
  transaction tagged as though you had picked "Only this one" — the one
  gesture available for saying "actually, no" did the opposite. The scope is
  now asked first and nothing is written until it is answered, which is the
  contract clearing a tag has always had. The two are the same decision in
  opposite directions and now behave identically.
- **Changing the app icon to match your royal restarts the app instead of
  just closing it.** Android only shows new launcher artwork after a fresh
  start, and the app took that by shutting down and leaving you on your home
  screen to open it again — an errand for a cosmetic change made two taps
  earlier. It now comes straight back up on its own; closing remains the
  fallback if the platform can't relaunch.

- **The launch parade no longer gets stuck in the corner.** The entrance
  picked its far point as an absolute screen fraction rather than a distance
  from where the royal started. The Home profile circle sits in the top-right
  corner, so on any launch that set off rightwards the "far" point landed
  *inboard* of the start: the royal shuffled a few dozen pixels and came back.
  Roughly half of all launches, and worst for the Prince and the Empress,
  whose styles have no arc or burst to disguise it. The parade now measures the
  runway either side of the anchor, sets off toward the side that has one, and
  travels a real distance along it.

### Changed

- **Each royal signs off its entrance with a move only it could make.** All six
  used to end on the same wave. The Empress now conjures — a turning rune
  circle, her orbs winding in and bursting overhead, and a curtsy through the
  falling light. The Princess blows a kiss, the hearts growing as they come at
  you. The Dark Prince drives his club into the ground and holds a low guard
  while embers climb off the plate. The Sovereign stays in the saddle and his
  lion turns to roar down the lens, which rocks the screen. The Royal Medic
  snaps her kit open and takes your vitals: a heartbeat writes itself across
  the air beside her, healing plus-signs rise out of the glow, and a clean
  pulse ring signs you off — which in a budgeting app is barely a joke, since
  the Financial Health score is a vital sign already. The Prince salutes with
  his new sword: blade up to the vertical in front of his face, light running
  up the steel, then recovered to his side for a short sharp bow. They are
  deliberately not all the same KIND of move — two are theatre, two are
  affection, one is a threat and one is drill — because a court where everyone
  mugs at the camera the same way is six copies of one idea.
- **The Sovereign actually reads as fast now.** His dash conveyed speed with
  position alone, so a fully-drawn body appearing somewhere new looked like
  dropped frames rather than movement. During a burst the solid body now fades
  to almost nothing and a stretched trail of afterimages carries the motion —
  visible because he is too quick to see, not because he stuttered.
- **The Dark Prince rides armoured.** A visored great helm over the face, and
  a heater shield with his blood-red chevron strapped to the free arm. His war
  horse gained a spiked chanfron over its face, overlapping criniere plates
  down the neck and a spiked crupper, on top of the flank and chest plate it
  already wore — a barded body with a friendly horse head on the end of it was
  reading as a costume. He is a knight, not a monster: no horns, and a man's
  eyes behind the visor.
- **The Prince carries a sword.** The lance stood taller than he did and read
  as scaffolding he was leaning on. He now has an arming sword sized to him,
  with a winged crossguard and a ruby pommel, in both the pixel portrait and
  the full-body rig.
- **The Princess's pegasus has wings you can identify as wings**, ivory with
  accent-tinted tips instead of pink-on-pink, drawn as one swept silhouette
  with scalloped primaries rather than a fan of separate quills.

### Fixed (art)

- The full-body rig drew each royal's weapon TWICE — once properly in the hand,
  and once more as part of the head sprite, which carries the weapon in its
  left-hand columns. That is where the Prince's fat lance through his cheek and
  the Dark Prince's floating club head came from. The chibi head now renders
  without the sprite's weapon lane; the avatar circle still shows the whole
  portrait, weapon included.
- Mounts had missing or unconvincing legs: the pegasus flew as a legless swan
  and the roaring lion stood on nothing. Every mount's leg is now drawn as
  thigh plus cannon over a knee so it clears the belly, the flier canters
  through the air with its legs raked back, and a halted beast braces on all
  four.

## [1.68.0] — 2026-08-07

### Changed

- **Every royal now rides differently.** Four of the six shared one gallop and
  differed only by coat colour, a horn and a mane — which is why the Prince, the
  Dark Prince, the Princess and the Sovereign all looked like the same horse
  wearing different paint. Each now has its own gait:
  - **The Princess rides a pegasus.** Feathered wings, hooves tucked, and a
    smooth airborne rise-and-fall with no ground contact anywhere in it. She
    leaves motes of light where the others kick up dust.
  - **The Dark Prince's steed is armoured** — gunmetal plate over the flank and
    chest with accent rivets — and it *stomps*: it hangs at the top of the beat
    and slams down with both leg pairs together, throwing a shock ring and grit
    across the floor on every landing.
  - **The Sovereign zips.** His lion covers ground in long low bounds, trailing
    two smears of itself and a wash of arcane light, so he arrives faster than
    he should be able to.
  - **The Empress glides.** Her palanquin now moves on three different rhythms
    at once — a slow rise, an even slower sway, and a roll that trails the rise
    the way a boat's does — with silk streaming off the rear poles. Nothing
    about it is in a hurry.
  - **The Prince and the Royal Medic are untouched**, on purpose: the Prince's
    canter is the baseline the others are measured against, and the Medic's cart
    was already the most distinctive of the six.
- **The launch parade stopped being the same every morning.** Every royal used
  to hop out of the profile circle, ride left, turn, and ride back. The *style*
  is now per royal — the Dark Prince charges and halts, the Princess flies an
  arc that never touches the floor, the Sovereign crosses in bursts, the Empress
  drifts out and back without ever turning around — while the direction and how
  far they travel are picked fresh on each launch. Style stays fixed per royal
  on purpose: one that entered differently every time would have no signature at
  all.

## [1.67.0] — 2026-08-07

### Added

- **See a theme before you wear it.** Every swatch in Settings → Appearance now
  has a preview button, and tapping a locked theme opens the same still instead
  of a message telling you to come back later. The still shows the month card
  and the screen around it together, which is the part a two-colour swatch
  cannot describe: Vellum's swatch shows the right two tones but no way to tell
  that the parchment is a *card sitting on* the dark screen rather than a colour
  used on it. Six of the eight themes are locked on a fresh install, and until
  now the only thing you could learn about them was two rectangles and a number
  of days.

### Changed

- **A locked theme no longer dead-ends in a message.** Tapping one used to show
  "Reach a 60-day streak to unlock this theme" and nothing else — asking for two
  months of patience toward something you had never been shown. It now opens the
  preview, and says the same line underneath it.

## [1.66.0] — 2026-08-07

### Added

- **Vellum — a new theme, earned at a 60-day streak.** The Streak Reward Road
  now runs two months, and what waits at the end reads less like a recolour
  than like a different object. Vellum prints your figures in deep ink on
  parchment cards and lays them on near-black paper stock: warm, editorial,
  quiet. It is the first theme in the app whose cards run *lighter* than the
  screen behind them — everything else you see, the bank rows, the section
  rules, the nav bar, stays light-on-dark, so the cards read as pages on a desk
  rather than as a theme that couldn't decide. Like every road reward it unlocks
  against your *longest* streak, so a bad week never takes it back.
- **Two Streak Freezes at 52 days.** The climb from Midnight Indigo to Vellum is
  the longest stretch on the road, and the hardest; it now has a stop in the
  middle rather than a fortnight of nothing.

### Fixed

- **Figures on a marquee card now take their colours from the card, not the
  screen.** The savings-rate bar and the inline Financial Health score used to
  ask whether the *app* was in a dark theme and colour themselves from the
  screen's palette. That happened to work while every card matched its
  background, and would have painted screen-grey text onto Vellum's parchment.
  They now read the surface they are actually drawn on. The visible effects on
  existing themes are small and in the right direction: on a dark theme, an
  overspent savings bar on a normal card now uses the lifted red that is legible
  there instead of the dark-on-dark one, and on the light theme the SAVINGS RATE
  and FINANCIAL HEALTH labels now match the gold eyebrow already above them on
  the same card.

## [1.65.0] — 2026-08-06

### Added

- **A Sunday-morning tidy-up nudge that alternates.** One weekend it offers to
  help you tag the month's untagged spends; the next it points at the entries
  the reader wasn't sure about. Never both, and never when the week's queue is
  empty — a quiet fortnight is the point, not a gap. The review nudge also
  holds itself to a floor: it stays silent for one small uncertainty and speaks
  up for a handful of entries, or for a single one carrying real money. It
  names the rupee amount, because "₹10,240 of your August spending came from
  entries we weren't sure about" is a reason to open the app in a way that "3
  entries need a check" isn't. Tapping either goes straight to the matching
  queue.

### Changed

- **The tagging reminder now arrives on a weekend.** It used to fire on
  whatever weekday you happened to install the app, every week. It is now
  Sunday morning, every other Sunday.

### Fixed

- **Muting a reminder no longer mutes your transaction alerts.** Both weekend
  nudges used to post on the same Android notification channel as real
  transaction alerts, so anyone who turned off the weekly reminder in system
  settings also turned off the notifications the app exists to send. They now
  have their own **Tidy-up Reminders** channel, at a quieter importance, which
  you can silence on its own. If you muted transaction alerts to stop the old
  reminder, you may want to turn them back on.

## [1.64.0] — 2026-08-06

### Added

- **The month's total now carries its own doubt.** When some of your spending
  came from entries the reader wasn't sure about, the hero card says so
  directly under the figure — "Includes ₹10,240 to check" — and tapping it
  opens the tidy-up queue. The rupee amount is deliberate: a count can't tell
  you whether two flagged entries are ₹40 of noise or ₹10,240 that changes the
  picture, so it would send you to the queue just to find out. Entries waiting
  to be checked have always counted toward your totals, because a payment the
  reader mislabelled is still a payment; what was missing was any sign of that
  on the number itself. With nothing to check the line isn't there at all.

## [1.63.2] — 2026-08-06

### Fixed

- **Changing a bank limit is no longer logged as a spend.** Every bank
  confirms a new transfer, ATM or card cap by SMS — "Transfer Limit Updated!
  … Third Party Transfer limit is set to Rs. 10000" — and Budgetify was
  reading that cap as a ₹10,000 payment. It landed in *Needs review* rather
  than silently, but it should never have been picked up at all, and because
  people move their limits up and down routinely it came back on every change.
  Limit notices are now refused outright, in either wording order ("limit is
  set to", "we have updated your limit") and for every cap a bank names.
  A spend that happens to report the remaining limit in the same message is
  untouched — the rule only applies to messages with no completed payment in
  them.
- **Limit notices already in your history are removed on upgrade.** A parser
  fix only ever reaches messages read after it ships, so the pass added in
  1.62 runs again over every stored row: past limit changes, and anything else
  today's parser refuses, clear themselves out of your totals. Manual entries,
  imported statement rows, and anything you've split or filed under a tax
  section are left alone.

## [1.63.1] — 2026-08-06

### Changed

- **Picking a royal now changes your app icon.** Matching the home-screen icon
  to your royal existed already, but as a second switch that shipped off and
  sat inside the royal's own sheet — so most people who equipped the Princess
  never saw a silver anything. It is now on by default: equip a royal and the
  app offers its icon straight away. Nothing happens behind your back, because
  changing the icon closes the app — you are still asked first, and declining
  leaves the icon exactly as it was.
- **Alerts carry your royal's colour.** Every notification Budgetify posts —
  transaction and budget alerts, bill and investment reminders, streak nudges,
  goal celebrations, the tag reminder, including the ones posted by the
  background scan while the app is closed — is tinted with the equipped
  royal's gem, deepened so it reads against the notification shade: copper for
  the Sovereign, amber for the Prince, ruby for the Dark Prince, amethyst for
  the Empress, emerald for the Royal Medic, slate for the Princess. No two
  courts look alike. Whether it shows depends on the phone: up to Android 15
  the system paints the circle behind Budgetify's mark with it, while Android
  16 and later — and some manufacturer skins before that — draw the app icon
  there instead and ignore the colour. With no royal equipped, alerts look
  exactly as they did.

## [1.63.0] — 2026-08-05

### Changed

- **Tidy up now tells you what you just did.** Answering an entry swapped one
  card for another and nothing else moved — so with two ₹100 credits back to
  back, there was no way to tell a registered answer from an ignored tap, or
  which of the two you had actually answered. Every answer is now named on a
  strip above the next entry, against the entry it was given to: *"Kept as it
  was · +₹100 · KOTAKB · 5 Aug, 4:41 PM"*. A mis-tap costs one tap to fix —
  **Undo** puts the answer back and returns you to that entry, including
  taking back a direction correction the app had already learned from.
- **The screen reads at a glance.** The amount leads the card with its
  direction spelled out beside it, and the timestamp is no longer fine print:
  when two entries carry the same amount from the same sender, it is the only
  thing that tells them apart. Progress moved out of the app bar into a bar
  that visibly fills as you work, with how many are left.

No extra taps: answering is still one tap, and the three answers are still the
same three buttons.

## [1.62.0] — 2026-08-05

### Fixed

- **A credit card arriving is not money arriving.** "Your Credit Card ending
  with XX39 have a Credit Limit of INR 4,00,000 is Dispatched" was logged as
  ₹4,00,000 of income, and two Kotak "card of Limit Rs.3,55,000/- is approved"
  notices the same way — the figure in all three is the card's *limit*, and no
  money moved. They arrived on the banks' own trusted headers, so the
  promotional-route filter never saw them. The parser now refuses a card being
  approved or dispatched, while a card being *used* still parses even when the
  alert quotes the very same limit.
- **Old false positives clear themselves on upgrade.** A parser fix only ever
  applied to messages read after it shipped; anything already logged kept its
  original reading forever — two of the three card promos above were already
  unreadable by the parser and had simply never been re-read. This release goes
  back over stored transactions and removes the ones today's parser refuses, so
  years of "Not a transaction" tidying you'd otherwise do by hand is done for
  you. Manual entries, imported statements, and anything you've split or filed
  under a tax section are left untouched.

## [1.61.0] — 2026-08-05

### Added

- **Set each person's share of a split by hand.** Splitting a bill three ways
  only ever offered one answer: your share, and the rest divided equally —
  but the friend who ordered the wine owes more than the one who had soup.
  Every person's amount is now a field you can type into, and the people you
  haven't touched absorb the difference: on a ₹10,000 bill with ₹2,000 yours,
  putting ₹5,000 on one person leaves ₹3,000 on the other, with no arithmetic
  to do. Changing your own share realigns them the same way, and ↺ hands a
  row you set back to the automatic split. When the parts stop adding up, the
  sheet says by how much and offers a one-tap **Even it out** — then lets you
  save it anyway, because tracking a slice of a bill is a legitimate thing to
  want. The ledger records exactly what you entered.

### Fixed

- **The transaction list keeps your place when you come back to it.**
  Scrolling a long way down, opening a transaction and tagging it landed you
  back at the very top, with all that scrolling to do again. The list wasn't
  forgetting its position — it was being destroyed: every reload swapped the
  whole list out for a loading spinner, and the scroll position went with it.
  Refreshes that only update what's already on screen (coming back from a
  transaction or from Add, a delete, an undo, pull-to-refresh) now leave the
  list in place. Filter and search changes still start at the top, where a
  new result set belongs.
- **Settings shows the version you are actually running.** The About row read
  1.48.0 while the app shipped as 1.60.0 — it was a hand-maintained constant
  that release bumps kept forgetting. It is now checked against the real
  version by the test suite, so the two can't drift apart again.
- **The Clear action on a transaction's Category card sits at the right
  edge.** It had been floating well short of it.

## [1.60.0] — 2026-08-04

### Changed

- **The app no longer jumps to Budgets when you go over.** Being thrown onto
  a screen you didn't ask for reads as a malfunction, not as feedback. The
  reaction is simply *owed*: it waits, and plays the moment you open your
  budgets yourself — this launch or three launches later. The debt is
  remembered across restarts, so it can't quietly expire, and it's settled
  only when the animation actually plays.

### Fixed

- **Split bills now count as your share everywhere.** A ₹645 dinner split
  down to ₹145 was still being counted at the full ₹645 in **Daily
  Analysis** — its spend total, its category breakdown and the amount on each
  row. The same slip was in the **7-day chart on Home**, the **month totals
  above the transaction list**, the **merchant detail** totals (month, average
  and largest), and the **"large spend" coach tip**, which could flag a bill
  you only paid a fifth of. Every spending figure in the app now uses your
  own share, matching the headline on the transaction itself.

## [1.59.0] — 2026-08-04

### Fixed

- **The over-budget attack no longer hides behind a switch.** The full-body
  royal attack was gated behind **Enable Custom Animations** — an opt-in,
  default **off**, buried in the avatar picker. The flagship moment of
  Gamified Budgets was invisible to everyone who never found the toggle,
  which is nearly everyone. The attack is *feedback about your money*, not
  decoration, so it now plays whenever a royal is equipped and Gamified
  Budgets is on. The toggle keeps governing the decorations: the welcome
  parade, the ambient cameos, the cheers.
- **One gated attempt no longer silences the month.** The breach was marked
  "reacted to" the moment the reaction was *requested* — even if it was then
  dropped because the toggle was off or the royal hadn't finished loading.
  One swallowed attempt meant silence for the rest of the month. The record
  is now a picture of *which budgets were over at the last look*, and the
  reaction fires on every **crossing**: reopening on the same blown budget
  stays quiet, but going over → back under → over again fires each time —
  ₹790 of ₹800, close the app, spend ₹20, reopen: Budgets screen, ₹810,
  attack.
- **A scold can't outrun the royal any more.** On a cold start the
  over-budget verdict often arrived before the equipped royal had finished
  loading, and the reaction was silently discarded. It now waits for the
  royal, and — being feedback — jumps ahead of the welcome parade instead of
  queueing behind six seconds of pageantry.

## [1.58.0] — 2026-08-04

### Added

- **Blowing a budget takes you to it.** When you cross a limit, the app now
  opens the Budgets tab on the gauge that broke, instead of announcing it
  wherever you happen to be and leaving you to go find which budget it was.
  This happens on a cold start too: reopen the app after a charge pushed you
  over and you land on the Budgets screen showing the new total. Once per
  breach, so it never hijacks a launch twice for the same thing, and it works
  whether or not the royal animations are switched on.

### Fixed

- **Retagging a transaction now updates your budgets.** Tagging a spend and
  then moving it to **Self Transfer** or **Investments** takes it out of your
  spending — but the Budgets tab kept showing the old figure until the app was
  restarted. The screen was built once and never told the data underneath it
  had changed. It now refreshes whenever anything changes what's been spent:
  a retag, a new charge, a deletion.
- **Cutting a budget below what you've already spent counts as going over.**
  ₹1,000 budget with ₹900 spent, dropped to ₹800 — you are over, without
  spending another rupee, and the reaction now fires.
- **The over-budget animation waits for the gauge properly.** It was raised
  the moment the breach was noticed, which is usually a moment when the ring
  it attacks isn't on screen — mid-launch, or with the budget dialog still
  closing over it. It now waits for the gauge to actually be there (through a
  tab switch, a screen load and a dialog unwinding) and plays on it, falling
  back to playing wherever you are rather than being dropped.

  *Note: these full-body animations are opt-in — **Enable Custom Animations**
  in the avatar picker, with a royal equipped and Gamified Budgets on.*

## [1.57.0] — 2026-08-04

### Added

- **Subscriptions that add themselves.** When you set up autopay for anything
  — Google Play, Spotify, a Groww SIP — your bank registers a **UPI mandate**
  and texts you about it. Budgetify now reads those messages, so a new
  subscription appears on the Recurring screen the day you subscribe, with the
  exact amount and (where the bank states it) the first debit date. Until now
  the app could only *infer* a subscription from three look-alike charges, which
  meant three months of it being invisible. Suggestions only, as before:
  nothing is added to your subscriptions until you tap **Track** and save it,
  and each one can be dismissed on its own. Mandate suggestions carry an
  **AUTOPAY** badge, because "your bank told us" is a different claim from "we
  noticed a pattern". Registrations from ICICI, HDFC, BOI and SBI are read.

### Fixed

- **A mandate being *set up* is no longer logged as money moving.** No money
  changes hands when autopay is registered, but SBI's wording ("Your
  UPI-Mandate for Rs.1950.00 is successfully created towards Google Play from
  A/c No: X") read enough like a credit that it was landing as ₹1,950 of
  **income**. These messages are now recognised for what they are.
- **Autopay charges are counted again.** The reverse mistake: any message
  mentioning "AutoPay" was thrown away as a reminder — including the real
  debits autopay produces. An ICICI mandate charge ("Rs 3000.00 debited from
  ICICI Bank Savings Account XX197 … for UPI Mandate AutoPay Retrieval Ref
  No.X") never reached your spending at all. Genuine autopay debits are now
  logged, while the reminders that don't move money still aren't. Their payee
  reads as the merchant alone ("ICCL Groww Auto") rather than trailing the
  rail description, so repeat charges group together.
- **The over-budget animation now plays when you reopen the app.** The royal's
  attack on the budget gauge only fired if you crossed the limit while the app
  was already open — reopening it on a budget you blew yesterday showed
  nothing, because the app adopted "over budget" as the starting state and
  waited for a change that had already happened. It now reacts once per
  breach: reopening on the same blown budget stays quiet, going over a *new*
  budget, or a new month, gets its own reaction. A scold raised while you're
  elsewhere in the app waits a few seconds for you to reach the Budgets tab so
  it can land on the gauge itself, and plays wherever you are if you don't.
- **The Budgets screen reacts on its own.** Budget state was only ever checked
  from Home, so blowing a limit while sitting on Budgets — by editing the
  limit, or a charge arriving — went unremarked until the next visit to Home.

## [1.56.0] — 2026-08-03

### Added

- **Clearing a tag now reaches as far as tagging did.** Choosing **Apply to
  All** tags every matching transaction *and* writes a standing rule that keeps
  tagging the ones that arrive later. Taking that back was the problem: the
  only visible way out was deleting the tag itself. A transaction that carries
  a tag now shows a plain **Clear** next to the Category heading, and it asks
  how far to reach — **Only this one**, **All from this payee** (with the real
  count), or **All, and stop auto-tagging**, which is the true undo of Apply to
  All. Every one of them is undoable from the toast that follows.
- **An Auto-tag rules screen** (Settings → Data). The rules Apply to All
  creates used to be invisible — written in one tap, then permanent and
  unlistable. Now each one shows what it tags, in which direction, and how
  many transactions currently carry it. Pause a rule to stop it tagging new
  transactions while keeping what it already did, or delete it and choose
  whether the tags it applied go with it.
- **A "tagged automatically" note** on any transaction whose tag came from a
  rule rather than from you, so a tag that appears on its own explains itself
  — and links straight to the rule behind it.
- **Clear from N transactions** in Manage Tags, separate from Delete. Emptying
  a tag and destroying it are different intentions; only one of them was
  available before. Clearing also removes the auto-tag rules that write that
  tag, so it doesn't quietly come back on the next message.

### Improved

- **Canara Bank alerts are read properly.** An interest payout ("…CREDITED to
  your account … towards interest") is filed under **Bank Interest** instead of
  the literal word "interest", so every interest credit across accounts groups
  under one payee. A UPI debit names the person: Canara masks the UPI handle
  away at the "@", which no rule could read, so "pinkygala77@" used to collapse
  to the generic "UPI Transfer" placeholder.
- **ICICI ACH/NACH credits — dividends and interest warrants — name the
  remitter.** These carry the payer only inside a star-delimited narration
  ("Info ACH\*IRB INFRASTRUCTURE D\*164"), which no "from"/"to" rule matches,
  so every one of them arrived with no counterparty at all. Institutional
  remitters ("BANK OF BARODA") are read too, which the general-purpose rule
  deliberately refuses.
- **Money arriving from nobody now asks for a glance.** A UPI credit whose
  payer the bank never names keeps the honest "UPI Transfer" label but lands in
  **Needs review** — an unexplained incoming payment could be income, a refund
  or a friend settling up, and only you can say which. Outgoing payments are
  left alone: you know what you just paid for.
- **A payee can never be your own account.** As a final check on every parse,
  a counterparty that reads as the row's own account number is dropped and the
  transaction is flagged for review — the two sides of a transaction can never
  be the same party, so a row saying "Received from XX2278" directly above
  "Account XX2278" was always a misread. Stored transactions that no rule could
  name are re-read on upgrade, so the history you already have benefits from
  the new Canara and ICICI shapes rather than only new messages.

## [1.53.0] — 2026-07-29

### Added

- **Spending by bank.** Every bank alert arrives under a registered sender
  header — `HDFCBK`, `BOIIND`, `SBIUPI`, `ICICIB`, `AXISBK` — so your spending
  is now totalled per bank as well as per category. Each month lists **only
  the banks you actually used that month**: three accounts with one card in
  use reads as a single row, and the month a dormant account wakes up it
  appears on its own.
- **Banks on Home.** Right under the month's expenses, a strip of small bank
  pills shows each bank and what was spent from it. Tap one for that bank's
  transactions, or **See all** for the full Banks screen, which steps month by
  month.
- **A By bank card in Budgets → Overview**, on every month page, ranked by
  spend with the same drill-down.
- **Bank-wise filtering.** The transaction list gains a one-tap bank strip
  above the results — it shows the banks the *other* filters leave standing,
  with amounts for the period you're looking at, so switching accounts never
  dead-ends. The filter sheet gains a matching **Bank** section.
- **Bank-wise export.** The export sheet gains bank chips, so you can export
  one account's year rather than everything. Every format now carries the
  breakdown: Excel gets a **By Bank** sheet (period total plus a table per
  month), the PDF report a **By Bank** block, and the text report a **BY
  BANK** section per month. The **Bank** column in Excel and CSV now names the
  bank ("HDFC Bank") instead of the raw header ("HDFCBK").
- **1,525 sender headers mapped to 610 banks**, generated from the DLT
  registry in `list_of_banks.txt` by `tool/gen_bank_directory.py`, plus a
  curated supplement for headers the registry omits — including neobanks like
  Jupiter, Fi Money and Niyo, which file under their own header. This is what
  makes one bank one row: State Bank of India alone files under 273 headers.
  Statement imports merge into the bank their label names ("HDFC Savings"
  joins HDFC Bank), and manual entries keep their own bucket.
- **A header we can't name still counts.** An unrecognised sender keeps its
  raw header as its identity, so its spending is totalled, filtered and
  exported like any other bank — a co-operative bank outside the registry is
  never silently dropped from your totals. It is labelled **"<header> ·
  Unknown bank"** rather than passing itself off as a bank named "JUPITR".
- **Call your banks what you call them.** The pencil on any row of the Banks
  screen renames it: "HDFC Bank" can read **HDFC Salary**, and a header we
  couldn't name reads whatever that account is to you. The name is a label
  only — the transactions stay wired to the sender header they arrived under,
  so nothing moves between rows, future messages from that bank still land
  there, and one name covers every header the bank sends from (all 273 of
  SBI's). Clearing the field restores the detected name. Your names appear
  everywhere the bank does, exports included, and ride along in encrypted
  backups.

### Fixed

- **Exports no longer count transfers as spending.** The summary block in the
  Excel, PDF and text exports added self-transfers, investments and
  settlements into **Total Expenses**, so an exported report disagreed with
  every screen in the app — a ₹8,000 move between your own accounts read as
  ₹8,000 spent. Those now sit on their own **Moved (not counted)** line, and
  the text report lists them under a **MOVED, NOT COUNTED** heading so nothing
  vanishes. Split transactions count your share, as they do everywhere else.
- **The PDF footer no longer prints a tofu box.** The em-dash in
  "Budgetify — *motto*" has no glyph in the built-in Helvetica the report
  uses; it is now the middot the tax report already used.

## [1.49.0] — 2026-07-26

### Changed

- **Removing an entry now asks what kind of removal you meant.** Swiping a
  transaction away used to offer only *Delete*, which quietly tombstones that
  one message — so a recurring promo came back the next month with a new amount
  and had to be deleted again. The confirmation now offers **Not a
  transaction** (which also skips every future message matching that template
  from that sender) alongside **Just remove this one**, and each option says
  what it will do. The same choice appears from the detail screen, from bulk
  selection, and in Tidy up, so every route behaves identically.
- **Removals can be undone.** The toast after a removal carries **Undo**, which
  restores the entry — and lifts the mute if one was added. Undo survives an
  app restart: the deleted entry is kept whole until you move on.

### Added

- **Tidy up.** Entries the reader wasn't sure about are gathered into one
  short pass — **Looks right**, **change the direction**, or **Not a
  transaction** — with a plain finish when the queue is empty. A prompt appears
  on Home only when something is waiting, and disappears once it isn't.
- **Select several at once.** Long-press any transaction to start selecting,
  then remove the lot in one go. Long-press is also a non-gesture alternative
  to swiping, for anyone who can't swipe reliably.
- **Screen-reader support on the transaction list.** Each row is announced as a
  single sentence — direction, amount, payee, category, date — and removal is
  exposed as a proper accessibility action rather than being swipe-only.
- **Ignored messages shows how many.** Settings → Ignored messages now carries
  a count, so muting a message shape is visible after the fact and easy to
  reverse.

### Fixed

- **State badges no longer get cut off.** On narrower phones — and in Hindi,
  Marathi, Bengali, Telugu and Tamil — the "Check" badge could be clipped off
  the right edge of a card, which hid the one on-card pointer toward fixing a
  misread entry. Badges now wrap instead of overflowing, and a large amount at
  a big text size shrinks to fit rather than being clipped.
- **Attention badges follow the theme.** "Unclassified" and "Check" were fixed
  light-mode colours that painted unchanged on Dark, Onyx & Amber, Royal Indigo
  and Midnight Indigo. They now use the theme's own palette.
- **Dialogs scroll instead of overflowing** at large text sizes, where a long
  dialog could previously push its own buttons out of reach.

## [1.44.0] — 2026-07-24

### Added

- **Tax deductions (Phase 1).** A second, optional label on any transaction —
  its tax-deduction section — next to the spending category. Open a
  transaction → **Tax section** and file it under **80C**, **80CCD(1B)**,
  **80D**, **24(b)**, **HRA** or **80G**; a new **Settings → Data → Tax
  Deductions** screen totals each section for a financial year (Apr–Mar) so
  filing season isn't a scramble to reconstruct a year of insurance, ELSS,
  rent and donations.
  - **Fills toward the legal cap.** 80C/80CCD(1B)/80D/24(b) show a used-vs-cap
    bar and remaining headroom ("₹90,000 of ₹1,50,000 — ₹60,000 left"), so you
    can see before year-end whether investing a little more would still save
    tax. Caps are editable — statutory limits change.
  - **Honest about what it can't sum.** HRA and 80G are shown as *evidence*
    (total rent paid / total donations) with a plain note that the actual
    deductible figure depends on your salary or the charity — never presented
    as a settled deduction.
  - **Regime-aware.** A one-time regime setting (Old / New / Not sure); under
    the new regime — which disallows most of these — the screen shows a short
    explainer instead of buckets, so it never implies savings you can't claim.
  - **Suggests the section for you.** Budgetify recognises common payees —
    LIC and other life insurers → 80C, health insurers → 80D, NPS →
    80CCD(1B) — and offers a one-tap "Looks like Section 80D" chip
    (suggestion only; you always confirm). Tag one and choose **Apply to
    all** to tag every payment to that payee, now and in future.
  - **An organiser, not tax advice.** It totals only what you tag; your CA or
    the tax portal decides what's deductible. A standing disclaimer says so.
  - Fully on-device, included in encrypted backups, no new permissions.
    English/Hindi/Marathi UI (Bengali/Telugu/Tamil follow). *Coming next: a
    filing-season summary export and a Jan–Mar home reminder.*

## [1.22.0] — 2026-07-02

### Added

- **Brand identity everywhere it represents you.** The launcher icon's
  wallet-and-sprout mark is now drawn in-app as crisp vector line art
  (`lib/widgets/brand_logo.dart`) and carried, with the motto — *"The
  private, offline budget tracker that does the work for you."* — across
  every social and exportable surface:
  - **Splash** — the gold brand mark replaces the generic wallet glyph in
    the animated badge, with the motto under the wordmark.
  - **Notifications** — the status-bar icon is now the brand silhouette
    (wallet with clasp cut-out + sprout leaves), white-on-transparent as
    Android requires.
  - **PDF export** — a proper brand header (navy logo tile, wordmark,
    motto, generated date over a gold rule) and a footer on every page
    with the motto and page numbers. Excel and text exports carry the
    motto line too.
  - **Monthly Wrapped** — the shareable card's brand pill now shows the
    real mark instead of a generic sparkle.
  - **Gamified profile card** — footer upgraded to mark + wordmark +
    motto, so shared profiles carry the identity.
  - **Split summaries** — the WhatsApp one-liner is signed "tracked on
    Budgetify, the private offline budget tracker".
  All rendering stays on-device; nothing about the privacy model changes.

## [1.21.0] — 2026-07-02

### Added

- **Import bank statements (CSV / Excel).** Settings → **Import Data** →
  **Bank statement** brings in the history the SMS pipeline can't see —
  months from before Budgetify was installed, an account whose alerts land on
  another phone, or an export from another app. Works with any bank: the
  importer finds the header row under the preamble junk, guesses what each
  column means (HDFC/ICICI/SBI/Axis/Kotak spellings built in), understands
  Indian formats (`1,23,456.78`, `dd-MM-yy`, month-name dates, `Dr`/`Cr`
  markers, ₹/INR prefixes, trailing-minus and bracketed negatives), and asks
  you to confirm the mapping — confirmed once, it's remembered for that bank.
  - **No double counting.** Rows matching the amount and date (±1 day) of a
    transaction already on the device — usually the SMS copy of the same
    spend — are flagged as probable duplicates and excluded unless you tick
    them back in, with a note showing when SMS tracking began. Re-importing
    the same file is a no-op, and a deleted imported row stays deleted.
  - **Lands organised.** Payees are extracted from statement narrations
    (`UPI-SWIGGY LIMITED-…` → *Swiggy Limited*), the merchant-keyword table
    auto-categorises what it recognises, and your saved auto-tag rules run
    over the newcomers immediately.
  - **Balances ignored by design.** The balance column is recognised so
    detection works, but its values are never read or stored.
  - Old `.xls` and PDF statements are politely declined with guidance (PDF
    import is planned). Everything is parsed on-device from a file you pick —
    no new permissions, still no INTERNET. Localised in EN/HI/MR/BN.

## [1.10.0] — 2026-06-25

### Added

- **Recurring payments.** Track the money that goes out on a schedule —
  subscriptions (Netflix, Prime), rent, EMIs, insurance premiums, utilities,
  gym — and stop being surprised by it. Add a plan with an amount (or mark it
  **"amount varies"** for bills like electricity), a cadence (**weekly /
  monthly / quarterly / yearly**), a next-due date and an optional end date.
  - **See what's coming.** A new **Recurring Payments** screen (Settings → Data,
    or the bell from a reminder) lists everything by urgency — overdue first,
    then due-today, then upcoming — with one-tap **Mark paid** / **Skip**. A
    **Home card** surfaces the next bills due (overdue highlighted) and hides
    itself entirely if you track none.
  - **Auto-detect from SMS.** Budgetify links a matching bank-SMS debit to the
    cycle it pays (a ⚡ marks auto-detected ones) and can **suggest** recurring
    charges it spots in your history — suggestion only, never auto-created. A
    predicted bill is never counted as spend; only the real debit is, exactly
    once.
  - **Reminders.** A **Bill reminder** notification with **Paid / Skip** buttons
    fires before each due date (your choice of lead time) and again if it goes
    overdue — resolved straight from the notification, even in the background.
  - **It feeds the rest of the app.** Fixed-amount plans count toward Financial
    Health's **recurring-load** pillar, and **Safe-to-Spend** now reserves the
    bills you still have to pay this month, so "₹X/day safe" already sets aside
    the rent and EMIs.
  - **Track as recurring** from any transaction (pre-fills name, amount,
    category and day). Fully on-device, in all four themes, localised (EN/HI/MR),
    and included in encrypted backups.

## [1.9.2] — 2026-06-25

### Added

- **Settlements — repayments no longer count as income.** When you cover a
  group bill and friends pay you back, those incoming payments were being
  counted as income (inflating your savings rate and Financial Health). Open
  any transaction → **"This is a settlement"** and it's excluded from **both**
  income and spending — the same neutral treatment as Self Transfer. Optionally
  pick **who** paid you back to also clear their balance in the split ledger
  (settle-up). And when an incoming payment matches an outstanding debt,
  Budgetify proactively suggests *"Looks like Rohan settling up — mark as
  settlement?"* (suggestion only; real income is never reclassified for you).
  Works both ways — repaying a debt you owe also stays out of your spending.
  On-device, all four themes, localised (EN/HI/MR).

## [1.9.1] — 2026-06-25

### Added

- **Split a transaction.** Open any spend and tap **Split this transaction** to
  count only **your share** toward your budgets — no more deleting and
  re-entering when you pay for the group. Set your share directly or use the
  **quick equal-split** (÷2 / ÷3 / ÷4 / ÷5), and see live exactly what counts.
  Optionally flip on **"Track who owes you"** to record the rest in the split
  ledger so you can settle up later. A split transaction shows **your share as
  the headline** (with the full amount struck through) and a **Split** badge,
  and carries a "÷ your share" tag in transaction lists. Budgets, category
  budgets, the spending curve, the money coach and Financial Health all update
  instantly. Fully on-device, in all four themes, and localised (EN/HI/MR).

## [1.9.0] — 2026-06-22

### Added

- **Net worth projection.** The Net Worth screen now shows where your wealth is
  headed: pick a horizon (1/3/5/10 years) and optionally assume ~8% yearly
  growth, and see the projected figure plus "you'd reach ₹X in about Y years."
  Projects from your **typical monthly savings** (median of recent completed
  months) — an on-device estimate, clearly labelled, never financial advice.
- **You vs Past You.** A reflection card on the Insights screen comparing your
  most recent completed **month** (or **quarter**) with the one before —
  spending, income, savings and savings rate, each with a good/bad delta and a
  one-line verdict. Compares completed periods only, so it never pits a partial
  month against a full one.
- **Hindi language toggle.** Settings → Appearance → **Language** switches the
  app between English and हिन्दी, applied instantly and remembered. Built on a
  lightweight string table + `LocaleProvider`; navigation, the Appearance
  settings and the two new cards are translated, with more surfaces to follow.

## [1.8.0] — 2026-06-22

### Added

- **Streak-reward themes.** Two new app themes, unlocked by your daily streak and
  visualised on a new **Streak Reward Road**:
  - **Smoky Blue & Warm Ivory** — unlocked at a **3-day streak**.
  - **Soft Seashell & Dusty Mauve** — unlocked at a **7-day streak**.
  Both are full themes (background, cards, accents and text all recolour), joining
  the existing Light and Dark. Pick a theme from **Settings → Appearance**, where
  locked themes show how far away they are; tap **Streak Rewards** there (or the
  **Streaks** tab in the Rewards hub) to see the road and apply a theme. Unlocks
  are based on your **best** streak, so an earned theme never re-locks if a streak
  breaks. The road is built to grow as more streak rewards arrive.

## [1.7.0] — 2026-06-20

### Added

- **Savings Goals.** Set discrete targets ("Goa trip ₹40k by December"), each
  shown as a **savings jar** that fills as you contribute. Record contributions
  manually (amount + date); set an optional deadline and see a "₹X/month to stay
  on track" figure; edit, complete or delete. A **Goals card on Home** surfaces
  your top jars. When a goal is reached you get an in-app **celebration** and a
  **notification** — and completing goals unlocks the new **Goal Getter** trophy
  in Gamified Budgets. All on-device and **included in encrypted backups**.

## [1.6.3] — 2026-06-20

### Changed

- **Premium trophy frames.** Badges now use a consistent hexagonal shield +
  crown (Clash-Royale-mastery style) whose **metal colour and ornamentation**
  (crown gems, side ears, glow) escalate by tier — the icon stays the same,
  only the frame changes. Replaces the earlier per-tier star/octagon shapes.
- **Title progress bars.** Every title shows a live bar toward its goal (e.g.
  2 / 6 months). The rule is now "meet the threshold in N qualifying months" —
  not an average — and tapping a title shows its full requirement + progress.
- **Broke Spender** now needs 90 no-spend days (up from 60).
- **More pixel avatars** — 12 distinct male & female characters (added bob,
  mohawk and top-knot styles, plus more skin tones).
- **Investments grouped by type** on Net Worth — Fixed Deposits, Recurring
  Deposits, Mutual Funds, etc. are clubbed together under headers.

## [1.6.2] — 2026-06-20

### Changed

- **Gamified titles are clearer.** Tapping any title — earned or locked — opens
  a sheet with its **full requirement, including the time window** (e.g. "35%+
  of income on Food & Dining, averaged over the last 6 months"), so locked
  titles are no longer cryptic. Earned titles can be featured from there.
- **Better pixel avatars.** A set of **distinct male & female characters**
  (varied hair, headwear and skin tones) instead of recolours of one sprite.
  The accent picker no longer applies to pixel avatars (they carry their own
  colours).

## [1.6.1] — 2026-06-20

### Changed

- **Gamified Budgets polish.** Trophies now change **shape by rarity**
  (circle → hexagon → octagon → star) so higher tiers feel distinctly premium.
  Avatars are now real **pixel characters** (recoloured chibi sprites) instead
  of abstract art. **Titles** have a dedicated gallery on the profile (earned +
  locked, like trophies) and now appear on the shareable card. The **shareable
  card** is richer — a stats strip (streak · trophies · titles), earned-title
  chips, and labelled trophies. Featured badges on the card are capped at 4.

## [1.6.0] — 2026-06-20

### Added

- **Gamified Budgets (opt-in).** A separate, reward-driven layer you switch on
  from Settings → Intelligence. When off, the app is exactly as before — no nav
  or dashboard changes.
  - **Achievement badges** across many ladders — daily streak, money tracked,
    transactions, time tracked, fully-tagged months, Budget Hero, Super Saver,
    net worth, debt-free, no-spend days and category explorer — with
    rarity-tiered medallions (copper → diamond), animated flourishes, live
    progress to the next tier, and an "Achievement Unlocked!" moment.
  - **Earned titles** from your spending mix (Foodie, Bill Master, Investor,
    Money Magnet, …), earned over a sustained window — never given by default.
  - **A premium, shareable profile** — choose an emoji or procedural pixel
    avatar and accent, a username, a headline title, and up to five showcased
    badges, then share it as an image. Opened from a new avatar in the Home
    header.
  - Everything is computed on-device and **included in encrypted backups**, so
    your profile, streak and unlocks are never lost.

## [1.5.2] — 2026-06-19

### Added

- **Financial Health display toggle.** A new *Detailed Financial Health* switch
  under Settings → Intelligence. Off by default: only a compact score (e.g.
  `72/100`) shows on the balance card under your savings rate, keeping the
  dashboard uncluttered. Turn it on for the full breakdown card with the gauge
  and per-pillar detail. The ⓘ explainer is reachable from both views.

### Fixed

- **Financial Health refreshes live.** Editing a budget, a holding, or a
  recurring plan now updates the score immediately, instead of only after
  reopening the app from cold.
- **Correct version in Settings.** Settings → About now shows the real app
  version (it had been stuck at 1.4.0) and is driven from a single constant so
  it can't drift again.

## [1.5.1] — 2026-06-19

### Added

- **Financial Health Score.** A single 0–100 number on the home screen, right
  under your savings rate, giving an at-a-glance read on your money health
  (100 is excellent, 0 is poor). It blends up to four pillars — **savings rate**
  (35%), **budget adherence** (25%), **recurring load** (20%) and **net worth**
  (20%) — into an animated gauge with a per-pillar breakdown. Pillars without
  data yet (no budget set, no holdings) are skipped and the rest reweighted, so
  the score always reflects what's available. A tap on the ⓘ explains exactly
  how it's calculated. Computed entirely on-device.

## [1.5.0] — 2026-06-19

The biggest update yet: a private on-device money coach, a clearer
safe-to-spend, and a fully offline split ledger.

### Added

- **On-device money coach.** Proactive, private spending nudges computed
  entirely on your phone:
  - **Category running hot** — a category that's meaningfully above your own
    pace for this point in the month (compared day-for-day against prior
    months, so it's fair early in the month).
  - **Large transaction** — a single spend that's a real outlier versus your
    usual amount in that category.
  - **Pace vs your typical month** — a heads-up when you're tracking above (or
    comfortably below) your normal spend.
  - Heavily guarded against false alarms (robust median/MAD statistics, dual
    percentage-and-rupee thresholds, minimum history, absolute floors), and
    card-only so it never interrupts you. Available under AI Prediction Mode.
- **Safe-to-spend.** A clear "₹X/day safe to spend for the rest of the month"
  figure that now **works even without a budget** — it falls back to your
  typical month. Includes a spent-vs-pace bar, an honest "vs budget / vs
  typical" label, and over-target messaging.
- **Offline split ledger ("Splits").** Track shared expenses and who owes
  whom, entirely on your device — a Splitwise that never leaves your phone.
  - Three clear actions: **Split an expense**, **Someone owes me** (expect
    incoming cash), and **I owe someone**.
  - A live result line spells out exactly who ends up owing whom.
  - Per-person view with a balance, **settle-up**, and a shareable
    WhatsApp-friendly summary.
  - **My-share accounting:** when you pay for a group and link the split to a
    transaction, only your own share counts toward your spending totals.
  - Equal or exact splits with live reconciliation; people are just names —
    no accounts, nothing synced.

### Changed

- The **Insights** screen now leads with the safe-to-spend card; the forecast
  hero focuses on the month-end projection.
- **Premium ledger UI:** champagne-gold/initials avatars (no emoji), people-list
  rows now show the latest shared expense as a subtitle, and a clearer
  *Paid by / Split between* editor.

### Fixed

- **Restore now refreshes the dashboard.** Classified/unclassified counts and
  totals update immediately after restoring a backup — no manual scan needed.
- **Calmer scan errors.** A manual SMS scan no longer surfaces a raw platform
  error when the device's SMS provider returns a malformed message; it shows a
  brief message and still refreshes your data.
- Corrected a bias in the month-over-month insight that could make every
  category read as "down" early in the month.

## [1.4.1]

### Fixed

- Notification small icon rendered as a solid square on some devices; now uses
  a dedicated white-on-transparent status icon.
- Hardened startup so a notification-subsystem hiccup can never block the app
  from opening.

[1.7.0]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.7.0
[1.6.3]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.6.3
[1.6.2]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.6.2
[1.6.1]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.6.1
[1.6.0]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.6.0
[1.5.2]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.5.2
[1.5.1]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.5.1
[1.5.0]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.5.0
[1.4.1]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.4.1
