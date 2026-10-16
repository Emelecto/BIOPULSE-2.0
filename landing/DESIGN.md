# BioPulse Landing Design

This describes the implemented landing-page surface, not a final company-wide web system.

## World

- Night-forest atmosphere inherited from the iOS product, grounded by the existing forest image at `BioPulse/Resources/Assets.xcassets/ForestNight.imageset/forest-night.png`.
- Deep ink backgrounds with mint as the primary action/signal color; lavender is reserved for sleep-related details.
- Manrope headings and DM Sans body text. Controls use square-cornered, thin-line surfaces rather than generic rounded-card grids.
- Content is arranged as large editorial statements, open signal diagrams, and quiet horizontal rules.

## Motion and interaction

- A short hero image reveal and signal-story entrance establish the scene once.
- Signal buttons update their label state, explanatory sentence, and corresponding route emphasis; no numerical values are displayed.
- The public narrative includes explicitly illustrative scenarios, visual privacy boundaries, an accurate now/in-development/future roadmap, a science-and-safety FAQ, and a disabled beta CTA with no email collection.
- Orbit and pulse movement are decorative, slow, and disabled under `prefers-reduced-motion`.
- Mobile navigation opens inline and exposes its expanded state accessibly.

## Accessibility and truth

- Spanish language metadata, skip link, semantic sections, keyboard-focus styling, pressed state, live explanation, responsive layout, and reduced-motion support.
- Illustrative geometry never represents a user's health reading. Beta collection is not enabled. Launch/status and privacy copy must be reviewed before publication.
- Browser review covered a 1440×900 desktop and 390×844 mobile viewport; the story controls, FAQ details, and mobile navigation were exercised. No public deployment or beta sign-up is configured.
