# Phase 1: Foundation & Onboarding - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 01-foundation-onboarding
**Areas discussed:** Onboarding tone & content, Permission denial handling, Post-permission destination, App personality & brand feel

---

## Onboarding tone & content

| Option | Description | Selected |
|--------|-------------|----------|
| Motivational coach | "Take back your focus" — empowering, action-oriented. Like Opal/one sec. | |
| Straight shooter | Minimal, factual, no fluff. Respects user's time. | |
| Playful / irreverent | "Your phone is winning. Let's fix that." — self-aware humor, lighter touch. | ✓ |

**User's choice:** Playful / irreverent
**Notes:** Matches the DeluluDetox brand name energy.

| Option | Description | Selected |
|--------|-------------|----------|
| Single screen | One explanation screen with WHY + Grant Access button. Minimal friction. | ✓ |
| 2–3 screen walkthrough | Swipeable intro: what → why → grant. More context but slower. | |
| You decide | Claude picks. | |

**User's choice:** Single screen

| Option | Description | Selected |
|--------|-------------|----------|
| SF Symbol + bold text | Large SF Symbol with punchy headline + brief explanation. Ships fast. | ✓ |
| Custom illustration | Branded illustration. More personality but requires design work. | |
| You decide | Claude picks. | |

**User's choice:** SF Symbol + bold text

---

## Permission denial handling

| Option | Description | Selected |
|--------|-------------|----------|
| Hard gate with retry | App unusable without permission. Witty fallback screen with Retry button. | ✓ |
| Soft gate with limited access | Let user browse app shell but block all blocking features. | |
| Explain + redirect to Settings | Deep link to Settings > Screen Time. | |

**User's choice:** Hard gate with retry

| Option | Description | Selected |
|--------|-------------|----------|
| Always visible, can't dismiss | Denial screen IS the app until permission granted. | ✓ |
| Dismissible with reminder | Can dismiss but reminded every launch. | |
| You decide | Claude picks. | |

**User's choice:** Always visible, can't dismiss

---

## Post-permission destination

| Option | Description | Selected |
|--------|-------------|----------|
| Home screen (empty state) | "No apps blocked yet" + prominent button. Sets up the hub. | ✓ |
| Straight to app selection | Skip home, go directly to FamilyActivityPicker. | |
| Success / welcome moment | Brief celebration screen before home. | |

**User's choice:** Home screen (empty state)

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle transition | Quick fade/slide to home screen. Permission grant is the reward. | ✓ |
| Celebration moment | Quick confetti/checkmark + witty line. | |
| You decide | Claude picks. | |

**User's choice:** Subtle transition

---

## App personality & brand feel

| Option | Description | Selected |
|--------|-------------|----------|
| Dark + neon accent | Dark background with vibrant accent. Modern, edgy. | |
| Clean white + bold accent | Light/white background with one strong brand color. Premium, minimal. | ✓ |
| Warm + earthy | Warm neutrals with terracotta/sage. Calm, grounded. | |
| You decide | Claude picks. | |

**User's choice:** Clean white + bold accent
**Notes:** User added (in Polish): "try to make it so that in the future (some future phase) we can introduce a design system and easily change the theme" — centralize colors from the start.

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal + punchy copy | Clean iOS-native layouts, personality from the words not the widgets. | ✓ |
| Bold + expressive | Larger type, bolder colors, custom button styles. Opinionated UI. | |
| You decide | Claude picks. | |

**User's choice:** Minimal + punchy copy

| Option | Description | Selected |
|--------|-------------|----------|
| You decide | Claude picks a bold accent for white + playful tone. | ✓ |
| Electric purple | Vibrant purple, modern. | |
| Coral / hot pink | Warm, energetic. | |
| Electric blue | Sharp, techy. | |

**User's choice:** You decide (Claude's discretion)

---

## Claude's Discretion

- Accent color selection
- SF Symbol choice for onboarding
- Exact copy / microcopy
- Home screen empty state layout
- Architecture folder structure
- Extension target naming

## Deferred Ideas

None — discussion stayed within phase scope.
