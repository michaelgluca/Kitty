# ADR-0002 — No backend, and what that forecloses

**Status:** Accepted

## Context

The project requires zero data collection and no developer-operated backend, so that the App Store
privacy label honestly reads "Data Not Collected".

Research established a hard platform rule that follows from this. Apple's MessageUI documentation
states that `MFMessageComposeViewController` "only lets you construct the initial message and present
it for a person's approval", and the delegate fires only "when the user taps the buttons to send the
message or cancel the interface". **An iOS app cannot transmit a message programmatically.**

The alternatives were examined and rejected: CloudKit is a container under our team ID and requires
the *recipient* to have the app and an Apple Account, which fails when a UK user's contacts are on
Android; Live Activities render only on the user's own device; Find My and Check In have no public
API; a `maps.apple.com` link is a static snapshot, because a self-updating link is by definition a
server request.

## Decision

No backend, in any form, including CloudKit. **Continuous location sharing to a contact is therefore
out of scope permanently**, not deferred. v1.0 sends one accurate location snapshot in a message the
user reviews and sends. The app additionally teaches Apple's Check In, which is free, first-party,
end-to-end encrypted and performs the automatic escalation no third-party app can.

## Consequences

- The manual Send tap is a design constraint to optimise around, not a defect to engineer away. It is
  also an honest consent affordance.
- The app must never imply that contacts will be alerted automatically.
- Routing users to a better first-party tool is a stronger product than imitating it badly.
- This decision alone removed background location, the Always authorization prompt, alarms and
  background execution from v1.0.
