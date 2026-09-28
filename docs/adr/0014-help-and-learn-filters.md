# ADR-0014 — Filtering Get help and Learn: nation, topics and search

**Status:** Accepted

## Context

Get help and Learn hold a lot of verified content, and someone under stress had to scroll past
help for other nations and other situations to find theirs. The screens can now be narrowed to
where the person is and what is happening. Narrowing a safety app's help is itself a risk: a
wrong filter hides the line someone needed. These are the rules that keep that from happening.

## Decision

- **The 999 routes and the Test Mode banner are never filtered.** `HelpContent` copies
  `emergencyRoutes` straight from the pack, above the filtered `services` and `reporting`; the
  Test Mode banner is rendered from the session, not the pack. `ContentFilter` never takes either
  as input, so nothing in the filter code can hide them.
- **The person chooses the nation; the app never does.** The default is "All of the UK" (`nation:
  Nation? = nil`). A nation Nearby detects is offered — `NationPreference.offer(detected:)` returns
  it only when it differs from the one chosen — and applied only by `choose(_:)`. When a saved
  nation differs from the detected one, perhaps because the person moved, `isStale(detected:)`
  flags it as a visible row on Get help, Learn and Refuges, not only inside the nation menu. It is
  never switched silently.
- **The chosen nation is remembered on this device**, in `UserDefaultsNationStore`
  (`Packages/SafetyServices`), and shared by Get help, Learn and Refuges through one
  `NationPreference` injected into the `Environment`. It is not stored in the Keychain: which of
  four UK nations someone chose is not sensitive, and it never leaves the device. The privacy
  manifest already declares UserDefaults for this app's own use (`CA92.1`). Topics and search live
  in each screen's own `ScreenFilter` and are not remembered.
- **The store saves the nation's id** (`Nation.rawValue`), because `Nation` belongs to
  `SafetyContent` and `SafetyServices` does not depend on it (ADR-0003). `UserDefaultsNationStore`
  reads back every write it makes and throws `NationStoreFailure.notSaved` when the value read back
  does not match; an id this version does not decode is read successfully by the store but rejected
  by `NationPreference.load()`, which reports it as `.couldNotRead` rather than guessing the
  nearest nation.
- **A store failure is shown, never absorbed.** `NationPreference.problem` is `.couldNotRead` or
  `.couldNotSave`; Get help and Learn read only `problem` and fall back to all of the UK, never an
  earlier nation or a guess. Refuges needs a nation to list anything, so on a save failure it keeps
  the person's pick for that screen through `NationPreference.unsavedChoice` and says it was not
  saved.
- **A failed pick is held for the session only, and a failed "All of the UK" is told apart from no
  failure.** `unsavedChoice` is typed `UnsavedChoice?`, not a plain `Nation?`: a failed choice can
  itself be "all of the UK" (`UnsavedChoice(nation: nil)`), which must not collapse to the same
  `nil` as "nothing failed". It is never persisted, and any later choice — saved or not — replaces
  it, so a stale failure can never reattach to an unrelated one. Refuges shows the refuges-specific
  "could not be saved, so it is used on this screen only" wording only when the nation actually
  listed is that unsaved pick (`RefugesScreen.NationShown.isUnsavedPick`); every other save
  failure — one made elsewhere, or a failed "all of the UK" that names no nation — shows the neutral
  `refugesCouldNotSaveElsewhere` note instead, which claims nothing about what is on screen. On
  Refuges, choosing a `nil` pick is ignored (`RefugesScreen.pick`): the nation picker there has no
  "all of the UK" entry, only a "Choose" placeholder (`refuges.nation.choose`) until a nation is
  shown, so choosing on this screen can never reset the nation Get help and Learn share back to all
  of the UK.
- **Nation filtering follows coverage.** `ContentFilter.serves(_:in:)` treats a `nil` coverage as
  showing everywhere ("when in doubt, show") and otherwise defers to `Coverage.includes(_:)`, where
  `london` counts as England. A rights topic shows when `ContentFilter.split` leaves at least one
  point for the chosen nation; the rest are returned as `elsewhere` and shown in `RightsTopicScreen`
  collapsed under "Different elsewhere in the UK" (`rights.elsewhere`) — hidden until opened, never
  removed.
- **Topic tags are content claims.** `Topic` is a fixed, `Codable` set of eight chips — domestic
  abuse, sexual violence, stalking & harassment, online abuse, forced marriage & FGM, housing &
  money, work, and reporting & victims' rights — plus `general`, which is not a chip: it marks help
  open to anyone in distress (Samaritans) and shows under every topic. Chips combine with OR
  (`ContentFilter.isAbout`). `ContentPack.validate()` rejects a service or reporting route with no
  topics, a reporting route or rights topic tagged `general`, a refuge route tagged at all, a
  duplicate tag on any item, and a nation with no refuge route; an id this version's `Topic` enum
  does not know fails to decode before validation ever runs. The whole tag table is pinned by
  `TopicTagTests.expected`, with the evidence for each tag beside it, so a change to any tag is a
  reviewed diff. The rule for a doubtful tag is to tag: chips are OR, so an extra tag only adds a
  row, and a missing tag hides help.
- **Search is offline and deterministic.** `SearchText` folds on a fixed `en_GB` locale — never the
  phone's — with `.caseInsensitive`, `.diacriticInsensitive` and `.widthInsensitive`, and then
  strips the straight apostrophe and every curly one the pack or iOS smart punctuation can produce
  (`\u{2018}`, `\u{2019}`, `\u{02BC}`), so a query typed with either finds "Women's Aid" however the
  pack itself spells it. `ContentFilter` requires every word to appear across an item's name or title,
  summary, audience, and its topics' search terms, and combines the result with the nation and topics
  by AND (`FilterCriteria`). A query of only spaces or punctuation folds to no words, so it is no
  search at all — `FilterCopy.summary` and the no-matches state both check
  `SearchText.isSearch(_:)`, not the raw string.
- **Search finds help by the words people type, not only the words an entry uses.** Each topic's
  search terms (`TopicCopy.searchTerms`) are its chip name plus a catalogue string of the other words
  people use for it (`topic.<id>.searchTerms`: "domestic violence, coercive control…" for Domestic
  abuse). They are passed in beside the criteria, as the chip names were, so `SafetyContent` stays
  free of localisation and the Kotlin port's JSON is unchanged. A rights topic is also searched by
  every point, not only the chosen nation's, and by "what you can do", where the law's own names
  are ("Clare's Law", "non-molestation order"); a match only in another nation's point still shows
  the topic, with that point under "Different elsewhere in the UK". Without these, "domestic
  violence" hid the National Domestic Abuse Helpline and Scotland's helpline while other rows still
  matched, so nothing said anything was missing. Search terms are content claims: each must name
  something the topic's help covers, and `SearchVocabularyTests` pins the searches that must work.
- **iPhone features answer only to search.** `ContentFilter.guides` takes no nation or topics: the
  guides are the same for every nation and every situation, so neither can hide one.
- **Filters are always visible.** `FilterCopy.summary` renders a line such as "Showing Scotland ·
  Stalking & harassment" whenever the nation, a topic or a search narrows anything, in chip order
  rather than tap order so the same filter always reads the same; it is `nil`, and the line is
  absent, only when nothing is narrowed. `ScreenFilter.clear()` resets topics and search and leaves
  the nation untouched — the nation is `NationPreference`'s, not `ScreenFilter`'s, to clear. When a
  screen's filtered content is empty, it shows a no-matches state with Clear: on Get help that is
  true even though the 999 routes are still there (`HelpContent.hasNoMatches` does not count them);
  on Learn it is true inside the rights section even while iPhone features are still listed
  (`NoMatchesScope.rights` has its own title and body). With a nation chosen, the no-matches text
  also says to choose All of the UK (`filter.noMatches.body.nation`): the nation may be why nothing
  matches, and Clear keeps it.
- **Refuges still show the nation found from the location until the person chooses**, labelled with
  a footer and not saved, as in ADR-0013. `RefugesScreen.nationShown` gives the saved nation first,
  then an unsaved pick that named a nation, then the detected one, and only then asks — a saved
  nation always wins.
- **The filter controls are a List section**, not an overlay: the nation menu, the topic chips
  (`ChipFlowLayout`, wrapping at any text size, each a `Button` at least `Design.minimumTapTarget`
  (44 pt) carrying `.isSelected` and a checkmark rather than colour alone) and the summary with
  Clear. It scrolls with the content, never covers it, and VoiceOver reaches it before the results;
  the result count is announced when it changes (`FilterCopy.resultCount`), and only while its
  screen is on screen (`ResultCountAnnouncement`): the nation is shared and visited tabs stay alive,
  so otherwise one tab could announce its count over another's.

## Consequences

- A wrong tag can still hide help under a chip. The mitigations are `general`, the always-visible
  summary, one-tap Clear, OR semantics, and a pinned tag table reviewed like any fact.
- There is no stalking or online-abuse specialist service in the pack today (Galop is LGBT+-specific
  and Victim Support is general), so the Stalking & harassment and Online abuse chips are thinner
  than the others, and the Revenge Porn Helpline has not been added. Both are content follow-ups,
  not filter defects: a service added later is tagged, not invented now.
- The detected-nation offer depends on Nearby having run. Someone who never opens Nearby is never
  offered a nation; the summary line still names the saved one.
- The saved nation sits in the app's preferences, which device backups include. It is the only
  thing stored, and it is one of four UK nations.
- The Kotlin port reads the same JSON, and `ContentFilter` is the specification it follows.
- UI tests keep their own saved nation (`nation.saved.uitest`) and clear it with
  `-kitty.resetNation`, so a nation one test chose never narrows another test's lists.
