# ADR-0009 — The name "Kitty G", with the trade mark risk accepted

**Status:** Accepted — knowingly, with the risk documented

## Context

Trade mark searches found two live registrations covering the software classes:

| Mark | Owner | Classes | Expiry |
|---|---|---|---|
| KITTY | Sanrio | Nice class 9, among 23 | 2033 (EUTM 003466372 / UK00903466372) |
| KITTY | Roast Group Ltd | 9, 35, 38, 42 | 2034 (UK00003084000) |
| HELLO KITTY | Sanrio | All 45 | Actively enforced |

There are also roughly 185 "kitty" software results on the UK App Store, almost all Hello Kitty
titles and cat games, and an established open-source terminal emulator of the same name.

"Kitty G" was chosen as closer to Catherine Susan Genovese. It **solves discoverability** — a rare
search string that escapes the cat-game swamp and reads as a person's name. It **reduces but does not
remove** trade mark risk: adding one letter does not usually defeat a likelihood-of-confusion finding
where the goods are identical, though it does create distance from *Hello Kitty* specifically, which
is where active enforcement concentrates.

## Decision

Ship as **Kitty G**. The residual risk is accepted knowingly by the project owner, who was shown the
registrations and the alternatives.

## Consequences

- The realistic failure mode is not App Review. It is a notice or an App Name Dispute months after
  launch, forcing a rename and the loss of ranking and reviews.
- **Hedge 1: the bundle identifier carries no product name.** A bundle identifier can never change
  after release, but the App Store name and display name can — so a forced rename stays a metadata
  change rather than a new listing.
- **Hedge 2: the mark must be distinctly non-Sanrio.** Geometric, line-art or a monogram. Never a
  round white kitten face with a bow. Note the tension: "Kitty G" reads as a person, so a literal cat
  both undercuts the memorial and keeps the adjacency.
- **Hedge 3:** a clearance search on "Kitty G" specifically before any marketing commits to it, and a
  fallback name agreed in advance.
- Worth pursuing: the precedent that works in this category — Hollie Guard — is published by the
  Hollie Gazzard Trust. Family or charity backing would give the memorial standing and supply a
  content-review partner.
