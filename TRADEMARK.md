# Trade mark and brand policy

The source code of this project is open under the Apache License 2.0. **The brand is not.**

Apache-2.0 §6 grants no licence to the licensor's trade names, trade marks, service marks or product
names. This document says plainly what that means in practice, because for a personal safety app the
distinction matters more than it does for most software.

## Why this exists

If someone publishes a modified build of this app under the same name and icon, a person in danger
cannot tell the difference. A fork that quietly removes the offline path, breaks the 999
confirmation, adds an analytics SDK, or transmits location to a server would look identical to this
app on a store listing — and the people most likely to be harmed are the people least able to
investigate. That is a physical safety problem, not an intellectual property grievance.

So: **take the code, and change the name.**

## What is not covered by the Apache License

- The name **Kitty G**, and confusingly similar variants.
- The app icon and all icon variants.
- App Store and Google Play listing assets: screenshots, preview videos, promotional artwork.
- The visual identity: the mark, the colour palette as applied to the brand, and the wordmark.

## What you may do

- Fork, modify, build and run the code for any purpose, including commercially.
- Say truthfully that your project "is based on Kitty G" or "is a fork of Kitty G", in ordinary
  descriptive prose. This is nominative use and it is welcome.
- Reproduce the `NOTICE` file, as Apache-2.0 requires.
- Submit changes back. Please do.

## What you must not do

- Publish a build to the App Store, Google Play, TestFlight, or any other distribution channel under
  the name **Kitty G** or a confusingly similar name.
- Use the icon, the wordmark or the listing assets on a distributed build.
- Use the name in your app's name, bundle identifier, domain name, social handle or repository in a
  way that suggests it is the official app.
- Imply endorsement by, or affiliation with, this project or its maintainer.
- Present a modified build in a way that could lead a user in distress to believe they are using the
  official app.

## Before you publish a fork

Change all of the following:

1. The app name, everywhere it is user-visible.
2. The bundle identifier.
3. The app icon and every icon variant.
4. The store listing assets and screenshots.
5. Any in-app reference to this project as the publisher.

Then make it clear in your own listing and README that your build is not this project.

## Reporting misuse

Open a private report through GitHub's security advisory form on this repository, or a public issue
if the misuse is already public. If a fork is endangering users — for example by presenting itself
as this app while breaking a safety-critical path — say so explicitly; that is treated as urgent
rather than as a routine trade mark matter.

## A note on the name

"Kitty G" refers to Catherine Susan Genovese. The name carries an obligation to the person it
honours, which is a further reason it is not available for reuse on a distributed build.
