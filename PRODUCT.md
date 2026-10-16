# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

BioPulse is for people interested in understanding or improving their health or physical performance. The product must use clear language and must not assume physiology expertise.

## Product Purpose

BioPulse helps users understand wellbeing, recovery, sleep, HRV, activity, and trends using personal context alongside available Apple Health data.

## Positioning

The product emphasizes real data, provenance, coverage, and context instead of turning isolated measurements into unsupported conclusions. Its main experience combines physiological signals with user-entered daily context.

## Capabilities and Constraints

- CONFIRMED: iOS-native app; iOS 17 minimum; Apple Health/Apple Watch is the prioritized source; CSV is a complementary input.
- CONFIRMED: an authenticated account is required to use the app. Login does not imply permission to sync.
- CONFIRMED: HealthKit original samples stay on-device by default. Cloud sync is optional and consent is separate by category; the iOS sync transport is not implemented yet.
- CONFIRMED: the Coach is informational, Spanish-first, non-diagnostic, and requires explicit consent before sending permitted derived context; no original HealthKit samples are sent.
- CONFIRMED: no clinical prediction model is validated or active. ML research work is not a released feature.
- UNKNOWN: App Store availability, launch date, pricing, support contact, public waitlist destination, and final privacy/legal copy.
- PROPOSED for the landing-page implementation only: plain static HTML/CSS/JS, kept isolated under `landing/` so it can be replaced without changing the iOS app or Admin panel.

## Brand Commitments

- CONFIRMED: BioPulse name; Spanish at launch; neutral, technically simple, easy-to-understand voice.
- CONFIRMED: the app's visual language is dark/night-oriented with forest imagery and mint accents. The existing forest image is at `BioPulse/Resources/Assets.xcassets/ForestNight.imageset/forest-night.png`.

## Evidence on Hand

- CONFIRMED: existing iOS app source, product specification, roadmap, cloud-sync contract, and ML research notes are in this repository.
- UNKNOWN: validated user outcomes, testimonials, customer count, clinical validation, predictive performance, public app listing, and commercial terms. Do not fabricate them.

## Product Principles

- Preserve user control and make each data source and consent boundary understandable.
- Distinguish observed, derived, estimated, and predicted information.
- Never invent biometric data, validated outcomes, or clinical claims.
- Keep health guidance informational; do not diagnose or recommend medical treatment.
