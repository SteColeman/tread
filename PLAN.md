# AI Outsole Wear Scanner — flagship differentiator

## What it is
A guided photo flow that analyses the bottom of a shoe and tells the user how worn it is, where it's worn, how their foot strikes the ground, and what that means for injury risk. Each scan is saved so you can watch wear progress over the life of the shoe.

## How it works for the user

### The capture flow
- Tap **"Scan wear"** on any shoe (button on the shoe detail screen, plus a milestone prompt at 50% and 80% of replacement goal).
- A polished camera screen walks through **3 guided shots**: heel, midfoot, forefoot — each with a translucent outline that turns green when the angle and framing look right.
- Live tips: "Move closer", "Reduce glare", "Hold steady". Auto-capture when aligned, or tap to shoot.
- Bright, even light is encouraged with a quick tip card before the first shot.
- Optional **baseline scan** offered when a new shoe is added — used to make future scans more accurate, but not required.

### The result screen
After processing (a few seconds with a slick animated progress ring) the user sees:
- **Wear score 0–100** with a color band (green / amber / red) and a one-line verdict like *"Moderate heel wear — about 180 km of life left"*.
- **Heatmap overlay** painted onto their actual photo, glowing red where rubber is most worn and cool blue where it's intact. Pinch to zoom, swipe between the three shots.
- **Gait & strike pattern**: heel / midfoot / forefoot striker, plus pronation hint (neutral / over / under) inferred from wear asymmetry.
- **Injury-risk callouts**: friendly cards like *"Uneven outer-heel wear can stress the IT band — consider a stability shoe next."*
- **Miles remaining** estimate that updates the shoe's replacement goal automatically.
- **Share / save** — export a clean result card image.

### Wear-over-time timeline
- New **Wear** tab on the shoe detail screen showing every past scan as a row with thumbnail, date, score, and km at time of scan.
- A sparkline at the top plots score vs. km — users see the curve of their shoe dying.
- Tap any past scan to revisit the heatmap and verdict.
- Compare slider: drag between the latest scan and any previous one to see the heatmap morph.

### Milestone prompts
- Gentle notification at 50% and 80% of the replacement goal: *"Time for a wear scan on your Pegasus 41?"*
- Also surfaced as a soft banner on the home screen and shoe detail.

## Design
- Camera screen: full-bleed black, white outline guide, subtle haptic tick on alignment, shutter button with spring animation.
- Processing screen: animated radial scan line sweeping over the captured photo, soft particle shimmer, smooth fade to results.
- Result card: hero photo with heatmap, big score number with the color band ring around it, verdict line, then stacked info cards for gait, injury notes, and miles remaining.
- Heatmap: warm gradient (amber → red) with soft blur so it feels organic, not technical.
- Timeline: clean list with monochrome thumbnails so the colored heat patches pop.
- Consistent with the existing 2026 Apple-inspired layout — generous spacing, rounded cards, glass effect on iOS 26.

## Screens
- **Scan intro** — explains the 3-shot flow with an animated illustration and a "Got it" button.
- **Guided camera** — three sequential shots with live alignment feedback.
- **Processing** — animated analysis screen.
- **Results** — score, heatmap viewer, gait, injury callouts, miles remaining, save/share.
- **Wear timeline tab** — list of past scans with sparkline and compare slider.
- **Baseline capture** (optional) — offered after adding a new shoe.

## Behind the scenes (high level)
- Photos are uploaded to a cloud vision model via Rork's AI gateway, which returns the score, heatmap mask, gait classification, and verdict text.
- Scans are stored in the user's account so they sync across devices alongside everything else.
- Images stored privately per user; heatmap overlay generated locally from the returned mask so we don't re-download large images.
- Milestone prompts hook into the existing notifications system (just one extra trigger type).

## Out of scope for v1
- Live AR scanning / depth sensing.
- Brand-specific recall or recommendation engine ("buy these next").
- Forensic-grade tread depth in mm.

These are natural follow-ups once the core scanner is loved.
