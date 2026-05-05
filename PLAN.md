# Widgets, replacement thresholds & smart alerts

Three upgrades that bring Tread to feature-parity with the top shoe trackers, before we tackle the AI wear scan.

## 1. Home & Lock Screen widgets
- [x] Small widget — active pair photo, name, progress ring, km remaining
- [x] Medium widget — active pair + top 2 rotation pairs with mini bars
- [x] Lock Screen circular + rectangular + inline complications
- [x] Auto-recolor green → amber → red as goal approaches
- [x] Deep link from widget tap to shoe detail (`tread://shoe/{id}`)

## 2. Per-shoe replacement goals
- [x] `ReplacementGoalPreset` model (Trainers / Daily Walker / Hiker / Casual / Heavy Duty / Custom)
- [x] `GoalPresetPicker` chips + custom slider in Add & Edit Footwear
- [x] Per-shoe progress ring on detail view
- [x] "km left" stat on Collection card
- [x] Color-coded warning when nearing/past goal

## 3. Smart notifications
- [x] `NotificationService` with permission, scheduling, and 80% warning logic
- [x] Permission priming screen in Settings → Notifications
- [x] 80% replacement warning (one-shot per shoe)
- [x] Weekly wear summary (Sundays 7pm)
- [x] Monthly condition check-in (1st of month, 10am)
- [x] Master toggle + individual switches

## Next up
- AI outsole wear scan (flagship differentiator).
