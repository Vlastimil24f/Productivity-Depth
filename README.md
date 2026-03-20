# Productivity Depth

A habit-tracking app built in Flutter that turns your daily productivity into an ocean journey. Every action you log moves you closer to the surface or deeper into the abyss.

---

## Concept

Your position in the ocean reflects how productive you've been. The surface is The Island — earned through consistent effort. The deeper you sink, the further you drift from your goals. Log your actions every day, earn Corals, and fight your way back to the light.

---

## Ocean Layers

There are 11 layers, each with its own atmosphere and meaning.

| Layer | Name | Threshold |
|---|---|---|
| 0 | The Island | 1100+ Corals |
| 1 | Clear Shallows | 1000+ |
| 2 | Coral Reef | 900+ |
| 3 | Fish Schools | 800+ |
| 4 | Neutral Zone | 700+ |
| 5 | Jellyfish Drift | 600+ |
| 6 | The Shipwreck | 500+ |
| 7 | Shark Waters | 400+ |
| 8 | Deep Ocean | 300+ |
| 9 | Anglerfish Lair | 200+ |
| 10 | The Abyss | 0+ |

Your layer is determined entirely by your Coral count — no manual input, no shortcuts.

---

## Core Mechanic

Each day you log actions and earn or lose **Corals** based on your output. Actions have a priority weight that converts them into points.

### Priority System

| Priority | Points |
|---|---|
| Low | 1 pt |
| Mid | 2 pts |
| High | 3 pts |

### Daily Outcomes

| Points | Result |
|---|---|
| 8+ | Rise (coral gain) |
| 6 | Hold position |
| 2–5 | Sink (coral loss) |
| 0–1 | Deep Sink (heavy loss) |

---

## Features

### Momentum Streaks
Consecutive productive days build momentum. At 3 days your corals double once. At 7 days there's a random chance to double again. At 14 days, one coral loss becomes zero.

### The Storm
Three stagnant days in a row trigger a storm — a fixed −50 coral penalty. Consistency is the only protection.

### Rescue Buoy
Once every 7 days, a buoy activates automatically if you would lose corals. It converts the loss to zero — a guilt-free rest day. It never triggers on a good day.

### Weekly Summary
Every 7 logs, a full summary screen shows your depth chart, net movement, coral gain or loss, activity breakdown, and a day-by-day log.

### Layer Map
A scrollable map of all 11 layers with descriptions and personas. Tap any layer to read what it means — and see exactly where you stand.

### One Log Per Day
Logging is limited to once per day to keep the mechanic honest. A toggle (`kEnforceDailyLimit`) is available in the code for development and testing.

---

## Getting Started

```bash
git clone <your-repo>
cd productivity_depth
flutter pub get
flutter run
```

**Requirements:** Flutter 3.x, Dart 3.x, `shared_preferences` package.

---

## Tech Stack

- **Flutter** — UI and animations
- **Dart** — application logic
- **SharedPreferences** — local persistence
- **CustomPainter** — all ocean background animations

---

## Project Structure

The entire app lives in a single file — `lib/main.dart` — organised into clearly separated sections:

- Data model (`LayerData`, `kLayers`, `kLayerThresholds`)
- Ocean background painter (`OceanPainter`)
- Main screen (`OceanScreen`)
- Log sheet (`LogActionsSheet`)
- Settings and actions management (`SettingsSheet`, `ActionsScreen`)
- Weekly summary (`WeeklySummaryScreen`)
- Layer map (`LayerMapScreen`)

---

## License

Copyright © 2025. All rights reserved.

This project and its source code are proprietary. No part of this codebase may be copied, modified, distributed, or used — in whole or in part — without explicit written permission from the owner.