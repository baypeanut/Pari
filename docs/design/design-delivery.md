# Pari — personal wine journal

The repaired baseline is `027c188`, already published on `main` before design
work began. The redesign follows the [curator's brief](curator-direction.md);
the independent visual reviews are recorded in [curator-review.md](curator-review.md).

## What changed

Pari now uses a quiet wine-journal composition: warm paper, dark ink, Georgia
titles, oxblood selections and ruled entries. The identity comes from actual
dates, vintages, notes and ratings. No fictional curator, photography or endorsement
was added.

- Four labeled destinations and an integrated Scan action replace the overlapping
  gold grape button. Existing tab navigation and modal scanning remain.
- The profile is an open identity block with a small avatar, functional counts,
  a taste annotation and dated memories. Loading, empty history and retry remain
  separate; the repaired data behavior is preserved.
- Discover uses explicit Wine list / The table service links and ordered wine
  entries. Real explanations and affinity values remain visible.
- Cellar uses the same ruled entry language, with shared section tabs and a useful
  empty inventory state. Search, filters, delete, stock actions and replay handling
  retain their existing behavior.
- Wine detail prioritizes the person's rating and note. Peer/community evidence
  is labeled, and absent evidence is a quiet sentence instead of an empty KPI.
- Capture, tasting entry, group entry, search and alternate social detail share
  the typography and palette. Photo copy follows tasting visibility. Devices
  without a camera receive an explanatory message when adding a moment photo.

## Accessibility and review

Content uses scalable serif/text styles. At accessibility sizes, date information
moves into the entry and subsection tabs scroll horizontally instead of splitting
words. The compact persistent footer limits growth to the standard xxxLarge
range; page content continues to follow the accessibility size.

The dark theme separates text accent from button fill. Calculated solid-color
contrast against the actual canvas is 7.28:1 for dark accent text, 6.83:1 for dark
annotations and 4.52:1 for light annotations. White on the dark-theme primary
button fill is 5.05:1. These are token-level calculations, not a claim of a
complete accessibility audit.

The curator reviews the actual authenticated iPhone 17 Pro simulator, including
populated content, long names, light/dark appearances, accessibility-large text,
detail/edit routes and native capture presentation/cancellation. The unavailable-camera
branch was inspected in code; the simulator reported an available camera. Review changes are implemented
before the next pass. Test settings are restored to their original values afterward.

No production database, account data or API configuration is changed by this
design delivery. Visual testing opens and cancels forms without saving user data.
Physical camera capture and a full VoiceOver audit remain outside this visual pass.

## Validation

- Final sources built successfully with Xcode for the iOS 26.2 simulator.
- XCTest: **63 passed, 0 failed, 0 skipped**, on iPhone 17 / iOS 26.2.
- Visual review uses iPhone 17 Pro with the actual authenticated backend session.
- `git diff --check` passes.
- No backend migrations or RPC changes are part of this redesign; database tests
  from the preceding repair were not rerun for these presentation changes.

The curator **accepted the running design after three review rounds**. The final
review found no remaining visual blocker within the reviewed scope. Simulator
appearance and text size were restored to light / large, and the app was left on
the authenticated profile. See the review record for evidence and limits.
