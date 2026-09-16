# Pari — curator direction

Date: 16 September 2026

Baseline: `027c188`

Status: implemented design accepted after three reviews of the running app on 16 September 2026. See `curator-review.md` for corrections and verification limits.

## The idea: a private wine journal

Pari should feel like the record of a person who pays attention: the bottle, the occasion, what they thought, and what they would open with someone else. Its personality comes from considered typesetting and useful detail. The visual reference is a wine journal and a small restaurant's carefully written wine list. It is intimate, literate, and contemporary.

The present wine palette is worth keeping. The generic feeling comes from the repeated composition: centered identity inside a white rounded card, three equal icon tiles, card after card, a floating jewel-like central action, and a few sparkles. Changing only the colors would leave that structure intact.

Three recognizable choices carry the redesign:

1. Open, asymmetric page layouts with a strong left edge and real content near the top.
2. A consistent wine entry: quiet producer and vintage, an ink-colored serif name, a personal note, a discreet rating, and a date. Rules separate entries; boxes do not frame every thought.
3. Explicit, grounded actions: scan a label, read a wine list, choose together, remember a wine. A person should understand the interface without interpreting decorative icons.

No fabricated curator, editorial endorsement, tasting note, bottle image, or confidence claim should be introduced for visual effect.

## Foundation

### Palette

- Paper: warm off-white, approximately `#F7F3EA`; avoid pure-white cards scattered across it.
- Ink: warm near-black, approximately `#29251F`.
- Secondary ink: approximately `#746B60`; metadata still needs readable contrast.
- Oxblood: approximately `#652F34`, reserved for active controls and a few deliberate marks.
- Rule: approximately `#D9D0C1`.
- Dark paper: `#191815`, primary ink `#EEE7DB`, secondary ink at least `#B3A897`, rule `#403C35`, a soft ruby accent around `#DC9A9F`.

Existing semantic theme accessors may remain. Use typography and spacing for hierarchy before introducing additional surface colors. Maintain a legible, filled primary action in both schemes; a light accent color cannot take white label text without checking contrast.

Wine category colors may mark a small category dot, fine line, or label. They must not color entire wine names. Especially avoid the low-contrast gold text currently used for white and sparkling wine names.

### Type

- Page titles: system serif, 30–34 pt at normal content size, regular weight. This is the same typographic voice across light and dark mode.
- Wine names: system serif, 21–24 pt for normal entries; 28–32 pt for the detail page.
- Producer, notes, controls: system sans, 14–16 pt. Italic may distinguish an actual user's short note; avoid applying it indiscriminately to supporting copy.
- Small section labels: 11–12 pt, medium, restrained tracking. Use sparingly.
- Ratings: clear 22–26 pt figures, with an accessible and visually quieter “/10” label where space allows.
- Numeric quantities and dates should align consistently. Reserve monospaced digits for numbers; do not turn all copy into a technical log.

Honor Dynamic Type. New fonts should use text styles or scale relative to a text style. Do not solve long names by shrinking them to illegibility. Let important text wrap. Small, fixed-height horizontal arrangements must adapt at accessibility sizes.

### Layout and controls

- A 24 pt page gutter; 8/12/16/24/32 pt spacing rhythm.
- One 1 pt rule between major sections, and lighter rules between repeated entries.
- 4–6 pt corners for image crops and useful contained controls. Sheets and system controls keep native behavior.
- No shadows on profile identity, rows, placeholders, or ordinary actions.
- No large standalone sparkle, smiley, or wineglass used to occupy an empty screen.
- Buttons need at least a 44 pt hit target even when their visual treatment is just text and an arrow.
- Reuse one underline treatment for page subsections. Avoid mixing underlines, raised segmented pills, and rounded chips for the same level of navigation.
- A row may be tappable without a chevron when its presentation is consistent; give it a content shape and a good VoiceOver label.

## Navigation

Remove the heavy, shadowed, gold grape button sitting above the tab bar. It overlaps content and visually dominates the useful information.

Preferred implementation: a restrained, flat footer set into the safe area, with a top rule, labeled destinations, and a compact integrated Scan action. Keep the existing four destinations and their navigation state. “Scan” is a modal action, not a fake destination. “Discover”, “Cellar”, “Activity”, and “Profile” are understandable destination labels. The scan action should be clearly distinguishable through a modest filled or outlined treatment, without floating over rows.

A native tab implementation is acceptable if all destinations have labels and the scan action is explicit and never overlaps scroll content. Custom navigation must preserve accessibility selection, safe-area behavior, modal presentation, and retained tab state.

## Profile: the opening page of a personal journal

This is the highest priority, because it currently has the most template-like composition.

- Replace the centered profile card with an open left-aligned identity block. Name on the left, a 52–60 pt avatar on the right; no enclosing card and no avatar shadow.
- Do not repeat the full name in both the navigation header and the identity block. The own profile can use “Your journal” as a quiet navigation context; the actual identity remains prominent in the content.
- Username below the name; bio, if present, follows naturally. A blank bio does not reserve space.
- Keep the three functional counts, but present them as typographic statistics in one ruled row: clear number above its small label. Counts remain tappable. “Tastings” is more precise than “Rated”.
- Replace the three white icon tiles with a concise unboxed palate annotation. Use words such as “Loves”, “Passes on”, and “In the mood for” with the actual stored preference. No heart/thumb/smiley trio. The annotation must still open editing on the own profile, with a clear Edit cue or accessibility hint.
- Keep Recent / Taste / Reserve List functionality. Underlined tabs should share the same dimensions and type as the rest of the app.
- On the own profile, repeated tiny “D” avatars add no information to every personal tasting. Replace that left gutter with a date or remove it. Show producer, wine, actual note, and date as a memory entry. Retain cheers and all navigations.
- Target: at normal text size on iPhone 17 Pro, the first complete tasting is visible without scrolling. The identity and preferences should not consume most of the page.
- Retain the newly repaired independent loading/error/retry states. Do not turn an error into “no tastings”.

The taste profile should be quiet data typography and ruled ranked rows. The share action must use an understandable label/icon such as “Share palate”, rather than a sparkle implying a magic function.

## Discover and feed: useful choices before a stream

- Give the page a clear identity and title. A small Pari wordmark and a serif “For your next bottle” or similarly concise functional title are appropriate. Avoid stacking several slogans above the real content.
- Preserve For You / Global / Following behavior. Consider “Everyone” only if a copy-only rename makes the existing meaning clearer.
- Wine list and The table should read as two deliberate service links, separated by a rule or a small column gap. They may be two compact text blocks with a title and a single concrete supporting line, not identical colored icon chips.
- Own bottles remain ahead of recommendations. Do not move a purchase-like discovery list above what the person already owns.
- Recommendations: producer, wine name, region, and actual explanation. Prefer a compact typographic marker or the actual image to repeated beige wineglass placeholders. A slim category marker or a numbered position can provide rhythm without invented bottle art.
- Scores and explanations must remain honest. A 20% affinity is not a strong endorsement. “Worth exploring” or “From your palate” is safer than new copy promising a perfect match; do not hide or inflate the underlying score for aesthetic reasons.
- Feed: flatten the white cards into open entries with fine rules. Keep a compact person/date line, then the wine and rating, followed by the person's note and real photo when available. A photo is evidence of the memory, not a decorative thumbnail in a circular crop.
- Keep social actions quiet and usable. One action row per entry; no new gamification, streaks, or arbitrary badges.
- No invented “editor's pick”, no fake issue numbers, and no random inspirational text inserted into the stream.

## Cellar: a working ledger

- Keep “Cellar” as the page title; a short real count can sit alongside or below.
- Tastings / Bottles should use the shared underlined navigation rather than a raised system segmented pill. Category filtering remains a smaller, secondary strip.
- Tasting rows sit directly on paper. A small date/category or vintage line, producer, ink-colored wine name, note, rating aligned to the right. Use sufficient room for long blends. The existing white card gutters should disappear.
- Bottle inventory follows the same wine-entry grammar. Quantity should be immediately legible; location and vintage are metadata. “Opened one” is an explicit action on a lower control line, not a barely differentiated full-row tap.
- Empty inventory: left-aligned “Room for a first bottle.” followed by one practical sentence and an Add bottles button. An understated ruled blank entry can provide structure, but no large decorative icon or fictional inventory.
- Preserve filters, search, swipe actions, idempotent inventory updates, and all retry/confirmation states.

## Wine detail: the bottle's page

- Do not start with a large empty wineglass square. When a real label photo exists, give it a modest 72–96 pt column; otherwise use a compact type/category mark and let the title carry the page.
- Producer first in quiet sans, wine name prominently in serif, then region/grape/category details on readable lines.
- Give the person's own rating and note priority over general ratings. Keep “Your rating”, twin evidence, and community numbers semantically separate.
- Use ruled sections for Your tasting, From people you follow, and Other tastings. The user's own note should look like a note, not a dashboard KPI.
- Reserve-list save action must be explicit and retain its accessible selected state.
- Keep edit/delete/share/moderation controls and all privacy behavior. A redesign must not conceal destructive controls or change how they work.

## Capture and forms: a place to write

- Carry the paper, ink, serif title, and useful rules into label scan, wine list scan, and tasting entry.
- Replace oversized generic symbols with a concise opening instruction and the real camera/photo/manual-search controls. Keep camera permission and unavailable-camera states clear.
- The capture flow should say what happens: “Keep this bottle” or “Record a tasting”, then label/photo selection. The save action names its result.
- Structure tasting entry as recognizable sections: Your rating, What stayed with you, Details, and Who can see this. These labels can be adjusted to fit actual current fields; do not imply new data capture.
- Buttons, form fields, category selections, and rating interactions remain native where that helps usability. Reduce unnecessary capsules and duplicate backgrounds.
- Success and error views should be short, useful, and visibly from the same app. Keep real retry and manual fallback actions.

## Implementation order

1. Theme/type helpers, one rule/section/navigation vocabulary, and root navigation.
2. Profile identity, palate annotation, and recent tasting entries.
3. Cellar ledger and bottle empty/filled states.
4. Discover and feed; wine detail.
5. Scan and tasting entry, then any visually discordant secondary screens encountered through those routes.

This is a visual redesign. Backend/API behavior, auth, routing destinations, privacy logic, and stored user data should be preserved.

## Curator acceptance

Review actual Simulator screenshots after implementation. Code alone is insufficient. At minimum review: populated profile, cellar tastings, bottle inventory empty state, discovery, one social feed entry, wine detail, scan start, and tasting form. Also review one populated screen in dark mode and at an accessibility text size.

The redesign is acceptable when:

1. Those screens visibly belong to one product, without a mixture of the old white-card template and the new journal language.
2. The profile shows a complete first memory above the fold at normal size; important copy is not clipped.
3. The footer is labeled, touchable, and never obscures rows or primary actions. All original destinations and capture remain reachable.
4. Wine names are legible ink-colored text in both appearances, including long names and white/sparkling wines.
5. Personal notes, vintages, dates, quantity, and actual evidence have hierarchy over decorative symbols.
6. No unsupported curator claims, new fake content, or overstated match percentages were added.
7. There is no reliance on 10–12 pt text for essential controls, and larger text reflows without overlap.
8. Loading, errors, empty data, and retry states remain truthful and useful.
9. Core navigation and data mutations still work; existing tests/build pass after relevant changes.

Review should call out concrete remaining defects and iterate. Acceptance does not mean every future design problem is solved; it means this implementation coherently satisfies the brief and is ready for the user's judgment.
