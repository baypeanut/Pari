# Pari — curator review

## Iteration 1 — 16 September 2026

Reviewed the running authenticated app in iPhone 17 Pro Simulator: populated profile, Discover recommendations, Global feed, Cellar tastings, empty bottle inventory, a populated wine detail, and the Edit Rating sheet. Opened and canceled capture; it immediately presented the native camera. No user content or saved preferences were changed.

**Decision: direction is successful; not yet accepted as complete.**

The new navigation, unboxed identity, date gutter, and ledger entries make the app recognizably more personal. The paper/ink palette is effective. A complete first memory now fits on the profile without scrolling. The bottom navigation is explicit and does not overlap content. White/sparkling wine names are now legible ink. The bottle empty state is calm and useful.

### Required corrections

1. **Finish the wine-detail language.** “Your thoughts” is still displayed in the old white rectangular box, and read-only Cherry/Blackberry notes retain decorative outlined pills. Use an open personal note and simple inline tasting-note text, or a restrained typographic list. Interactive note choices in the edit form may retain their selected-control treatment.
2. **Give the person's rating priority.** The detail currently gives equal space and emphasis to Your rating, an empty Twins dash, and Global. Lead with the person's own rating. Show twin evidence when it exists; empty evidence should not occupy a third of the main ratings block. Label the bare global count “1 tasting” or its plural, rather than leaving an unexplained number beneath the score.
3. **Use the paper theme inside the edit sheet.** The Edit Rating presentation is stark white while the surrounding app uses warm paper. Apply the theme at the actual presenting/navigation container; changing the inner sections alone is insufficient.
4. **Repair the small profile copy.** “Less of Very tannic” reads as assembled fragments. Stable labels such as Loves / Avoids / Mood work with the existing stored options. Rename Rated to Tastings. Prefer Recent to Recently for the tab label.
5. **Keep the profile year with the date.** The year is currently stranded under the note in the main content column. Put it in the date gutter or use one coherent full date. This also reduces the blank vertical gap before the next tasting.
6. **Remove the extra Discover slogan.** “A TASTE FOR DISCOVERY” adds a third marketing line above recommendations without adding meaning. The serif title and actual supporting explanation are enough.
7. **Make photo copy truthful.** The edit sheet says “Capture Now — optional · appears in feed”, even though tasting visibility can be private. Use a label such as Moment photo, an explicit Add a photo action, and supporting copy that follows the selected tasting visibility. Preserve the existing privacy implementation.
8. **Bring transitional and alternate routes into the system.** Profile loading still visibly uses the old centered avatar/card skeleton. The implementer also identified the alternate SocialWineDetail header and intermittent Discover navigation-title issue; address these before final acceptance.

### Small refinement

The Global feed's bare, tiny glass action is difficult to interpret on first use. A quiet “Cheers” text label next to the icon can improve understanding while preserving the generous hit target. This should not become a prominent filled button.

### Evidence still needed

- A populated dark-mode screen, with readable secondary copy and appropriately contrasted primary actions.
- A populated profile and a long wine name at accessibility text size, including the footer and tabs.
- The corrected wine detail and edit sheet.
- An alternate social wine detail route and a clear capture fallback state.

The design does not need another conceptual direction. The next pass should resolve these specific inconsistencies and show the result running.

## Iteration 2 — 16 September 2026

Reviewed the rebuilt app in dark mode with accessibility-large content, then restored the original Simulator configuration: light appearance and large content size. Reviewed populated profile, a long wine name in Global feed, the corrected personal wine detail, Edit Rating sheet, and the alternate Global-to-wine detail. Opened and canceled the photo camera; no image was taken and no edit was saved.

**Decision: most corrections accepted; two concrete blockers remain.**

### Accepted corrections

- Profile preference labels, Tastings/Recent naming, and coherent date gutter. At accessibility sizes the date becomes a readable full-date line.
- New loading skeleton matches the journal layout.
- Personal wine detail gives the user's rating priority, labels community evidence, and presents the actual note as open text. The old white note box and display-only tag pills are gone.
- The edit sheet uses paper consistently, and the Moment photo text correctly reflects tasting visibility.
- Dark primary/secondary hierarchy is coherent. Long wine names remain visible and wrap without truncation. The footer stays legible and clear.
- Normal-size profile shows the first full entry and much of the second, with no footer overlap.

### Remaining blockers

1. **Discover subsection tabs fragment words at accessibility-large.** Global renders as “Glob- / al” and Following as “Fol- / lowing”. Use a content-sized horizontal scrolling strip or another adaptive arrangement at accessibility sizes. Keep labels whole; do not cap the content's accessibility font size to hide the layout problem. Apply the solution consistently to subsection navigation.
2. **The alternate social detail still contains the previous visual system below its new header.** Global → wine displays equal Your rating / empty Twins / Global columns, an unlabeled “1”, display-only Cherry/Blackberry pills, and a floating gray Cheers pill. Use the corrected personal-detail hierarchy for ratings and evidence, retain the social host's identity, render tags as readable text, and give Cheers a quiet integrated action location that does not float over the page.

### Camera verification limit

This Simulator currently reports camera availability and opens the native camera from Add a photo. The proposed unavailable-camera alert therefore did not appear and cannot be claimed as visually verified in this environment. Camera presentation and cancel worked; physical photo capture was not tested.

The final review can be focused on the two blockers above. There is no reason to restart the concept or introduce new decorative features.

## Iteration 3 — 16 September 2026

**Decision: accepted. The implemented visual redesign satisfies this brief.**

Reviewed the final build on iPhone 17 Pro, focusing on the two remaining blockers:

- At accessibility-large, Discover's For You / Global / Following labels now remain whole on one line in the adaptive scrolling strip. The previous in-word fragmentation is gone. Long wine names continue to wrap legibly, and the footer stays clear.
- Global → wine now uses the same journal hierarchy as the personal wine page: the user's own rating leads, peer/community evidence has explicit labels and counts, the actual host remains identified, and tasting notes are inline text. Cheers is an integrated action after the host review, without a floating pill or content overlap.
- The social wine page was checked at accessibility-large and in both normal-size light and dark appearance. The typography, rules, and palette remain coherent.

Across the three review passes, the redesigned profile, discovery/feed, cellar, wine detail, and tasting form now read as one personal wine journal. The result has a specific visual character while keeping the app's information and actions understandable. No further design blocker was found in the reviewed scope.

Simulator configuration was restored to light appearance and large content size, then the app was returned to Profile. No user record, photo, or saved preference was changed during review.

### Scope of this approval

This is visual and interaction-layout acceptance of the reviewed implementation, not a claim that every device, localization, or future data combination has been exhaustively tested. The implementer separately reported the final build and 63 XCTest passing. The camera-unavailable branch was not exercised: this Simulator reported availability and presented the native camera, which was canceled without capture. Physical photography remains outside this review.
