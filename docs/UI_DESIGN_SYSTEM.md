# DiscipleTrack UI Design System

*Document Status:* MVP Baseline  
*Last Updated:* September 2026

---

## 1. Purpose

This document defines the visual and interaction principles for the
DiscipleTrack Flutter mobile application.

The goal is to keep the application:

- modern
- clean
- calm
- polished
- informative
- highly functional
- consistent
- mobile-native
- human-centered

This document is the visual source of truth for new DiscipleTrack screens.

AI agents and developers should follow the established design language
rather than independently inventing a new style for each feature.

---

## 2. Core Design Principle

DiscipleTrack is an information and action-oriented application.

Modern and aesthetic does not mean decorative.

Every major component should have at least one clear purpose:

- communicate information
- communicate status
- enable an action
- provide navigation
- show progression
- provide context

Avoid decorative dashboard elements that do not help the user understand
or accomplish something.

---

## 3. Product Experience

The application should feel like a modern consumer mobile application,
not a traditional administrative system.

Avoid the appearance of:

- ERP software
- spreadsheet-style management systems
- desktop dashboards compressed into mobile screens
- generic admin templates

The experience should instead feel personal and contextual.

The application should emphasize people, progress, activity and
responsibility.

---

## 4. Information Hierarchy

Every screen should answer a clear user question.

Examples:

### Disciple

"Where am I in my discipleship journey?"

### Discipler

"Who am I responsible for and who needs my attention?"

### D Group Leader

"How is my D Group doing?"

### Coordinator

"How is the discipleship ministry doing?"

Information should be ordered according to these responsibilities.

Do not simply display the same dashboard with different numbers for
every role.

---

## 5. Visual Direction

DiscipleTrack should use:

- clean backgrounds
- restrained use of color
- strong typography
- generous but efficient spacing
- soft borders
- subtle elevation
- rounded surfaces
- clear information hierarchy
- meaningful progress visualization
- contextual actions

The interface should feel visually smooth without becoming overly soft,
playful or decorative.

---

## 6. Base Theme

The initial design direction uses a light theme.

Preferred surface hierarchy:

Background
→ soft neutral/off-white

Primary Surface
→ white or slightly elevated neutral surface

Primary Text
→ near-black

Secondary Text
→ muted neutral

Brand Accent
→ one primary DiscipleTrack brand color

Semantic Colors
→ success
→ warning
→ attention
→ error
→ informational

Exact design tokens will be finalized during Flutter theme
implementation.

Avoid using many unrelated accent colors.

---

## 7. Color Usage

Color should communicate meaning.

Examples:

Primary brand color:
- primary actions
- active navigation
- selected controls
- important progress indicators

Success:
- completed lessons
- resolved follow-ups
- positive states

Warning/Attention:
- members requiring attention
- overdue actions
- declining participation

Error:
- destructive actions
- validation failures
- critical errors

Neutral:
- secondary information
- inactive elements
- metadata

Do not use semantic warning/error colors merely as decoration.

---

## 8. Typography

Typography should provide strong hierarchy without requiring excessive
font sizes.

Typical hierarchy:

Display / Greeting
Page Title
Section Title
Card Title
Body
Supporting Text
Metadata / Caption

Prefer weight, spacing and contrast before dramatically increasing font
size.

Avoid excessive bold text.

Long informational screens should remain easy to scan.

---

## 9. Spacing

Spacing should feel deliberate and consistent.

Use a shared spacing scale rather than arbitrary values throughout the
application.

The layout should provide:

- comfortable outer page padding
- clear section separation
- consistent internal component padding
- compact spacing between strongly related information
- larger spacing between unrelated sections

Whitespace is part of the hierarchy.

Do not fill empty space simply because it exists.

---

## 10. Surfaces and Cards

Most meaningful grouped information should use reusable components.

However, not every piece of content should be placed inside a card.

Cards are appropriate when content:

- forms a meaningful group
- has its own interaction
- represents a domain object
- communicates an important state
- requires visual separation

Examples:

- Disciple summary
- Follow-up requiring attention
- Current lesson
- Announcement
- Attendance summary

Content that may remain directly on the page background includes:

- greeting
- page title
- section heading
- contextual date
- simple supporting text
- activity timeline
- some progress indicators

Avoid "card inside card" layouts unless there is a strong structural
reason.

---

## 11. Borders

Use soft, low-contrast borders.

Borders should define structure without dominating the interface.

Avoid:

- dark outlines
- thick borders
- borders around every element
- excessive divider lines

Spacing should often provide separation before another border is added.

---

## 12. Corner Radius

DiscipleTrack should use consistent rounded corners.

Rounded surfaces should feel modern and soft without becoming excessively
pill-shaped.

Different component categories may use different standardized radii, but
developers must use shared design tokens rather than arbitrary radius
values.

---

## 13. Shadows and Elevation

Use elevation sparingly.

Prefer:

1. spacing
2. surface contrast
3. soft borders

before adding shadows.

Shadows should be subtle and primarily used when physical separation is
meaningful, such as the floating navigation dock.

Avoid large, dark or dramatic shadows.

---

## 14. Component-First Flutter Design

DiscipleTrack should be built from reusable, domain-oriented Flutter
components.

Pages should primarily compose existing components rather than repeatedly
implementing the same visual pattern.

Conceptually:

AppScaffold
├── AppHeader
├── Page Content
│   ├── SectionHeader
│   ├── Domain Components
│   ├── Activity Components
│   └── Contextual Actions
└── FloatingNavDock

Component extraction should be based on meaning and reuse.

---

## 15. When to Create a Component

Create a reusable component when it represents:

- a reusable design pattern
- a domain concept
- a repeated interaction
- a sufficiently complex isolated UI
- a consistent application-level structure

Examples:

MemberCard
AttendanceSummary
LessonProgress
MeetingProgress
FollowUpCard
AttentionCard
AnnouncementCard
ActivityTimeline
FloatingNavDock

Do not extract components merely to reduce the number of lines in a
screen.

Avoid meaningless components such as:

GreetingText
TinySpacer
GenericNameText

unless they eventually represent an actual reusable design-system
primitive.

---

## 16. Domain-Oriented Components

Prefer domain-oriented component names and APIs.

Good:

MemberCard
DiscipleProgressCard
AttendanceStatus
FollowUpCard
LessonTimeline

Avoid excessively generic abstractions such as:

GenericInfoBox
DataContainer
ContentWidget

when the component actually represents a known DiscipleTrack concept.

This makes the UI architecture easier to understand and maintain.

---

## 17. Shared Design Primitives

Some lower-level primitives should still exist where useful.

Examples:

AppScaffold
AppButton
AppTextField
AppCard
AppAvatar
AppBadge
AppBottomSheet
AppDialog
SectionHeader
EmptyState
ErrorState

These primitives should enforce common visual behavior.

Domain components may compose these primitives.

---

## 18. Page Background Composition

Pages should remain visually breathable.

A preferred structure is:

Background

Greeting / Header

Optional Context Control

Section Title

Card / Component

Section Title

Card / Component

Activity / Timeline

Floating Navigation

Do not wrap every section in another large container.

---

## 19. Headers

Primary screens should use a consistent header system.

A Home header may contain:

- greeting
- user name
- contextual subtitle
- notification action

Example:

Good evening, Mark

Young Adults D Group                     [Notification]

Other screens may use:

Back
Page Title
Contextual Action

Headers should remain compact enough for mobile usage.

---

## 20. Week / Date Strip

A compact weekly date selector may be used when dates provide meaningful
interaction.

Example:

SUN  MON  TUE  WED  THU  FRI  SAT
20   21   22   23   24   25   26

The selected day may display:

- gatherings
- discipleship meetings
- activity
- relevant scheduled items

Do not display a date strip merely because it is visually attractive.

If changing the date has no meaningful effect, the control should not be
present.

---

## 21. Floating Navigation Dock

Primary mobile navigation should use a floating bottom dock.

The dock should:

- float above the bottom safe area
- use a soft elevated surface
- have clear active/inactive states
- contain only high-value destinations
- remain visually consistent across primary screens

Avoid overcrowding the dock.

Approximately four primary destinations are preferred where practical.

Example Disciple navigation:

Home
D Group
Progress
Profile

Navigation may differ by responsibility while maintaining the same
visual language.

---

## 22. Role-Aware Navigation

Navigation should reflect what each person actually needs.

Do not expose irrelevant destinations simply because another role uses
them.

Examples:

### Disciple

Home
D Group
Progress
Profile

### Discipler

Home
Disciples
D Group
Profile

### D Group Leader

Home
D Group
Members
Profile

Coordinator navigation will prioritize ministry-level operations.

Exact navigation structures will be finalized during screen and
information-architecture design.

---

## 23. Home Screen

Home is not a generic statistics dashboard.

It is the user's current ministry context.

Information should prioritize:

- what matters now
- what changed
- what requires attention
- what action should happen next

Avoid filling Home with unrelated statistic cards.

---

## 24. Disciple Home

The Disciple Home should emphasize:

- current discipleship journey
- current lesson
- meeting progress
- attendance
- D Group
- Discipler
- announcements
- recent relevant activity

Example priority:

Greeting
→ Current Journey
→ Announcement
→ Progress
→ Attendance
→ Recent Activity

---

## 25. Discipler Home

The Discipler Home should emphasize:

- assigned Disciples
- members requiring attention
- current lesson progress
- follow-ups
- recent activity
- D Group context
- announcements

The screen should help answer:

"Who needs me today?"

---

## 26. D Group Leader Home

The D Group Leader experience should emphasize:

- D Group health
- Disciplers
- Disciples
- attendance
- members requiring attention
- lessons awaiting confirmation
- follow-ups
- recent activity

---

## 27. Coordinator Home

The Coordinator experience should emphasize:

- ministry overview
- D Groups
- members requiring attention
- unresolved/overdue follow-ups
- unassigned members
- discipleship progress
- promotion eligibility
- announcements

Avoid turning the Coordinator screen into a dense desktop-style
analytics dashboard.

---

## 28. Profiles

Every registered user has an informative profile.

Profiles should emphasize the person's ministry context and journey
rather than behaving only as contact-information pages.

Possible sections include:

Identity
Responsibility
D Group
Discipler / Assigned Disciples
Discipleship Progress
Attendance
Recent Activity

The exact composition may differ according to responsibility and viewer
authorization.

---

## 29. Profile Flexibility

The profile layout does not need to be rigidly predetermined.

Developers and AI agents may compose the profile using established
DiscipleTrack components and design principles.

Any generated profile must remain:

- clean
- informative
- visually balanced
- consistent with the rest of DiscipleTrack
- authorization-aware

New visual patterns should only be introduced when existing patterns
cannot appropriately represent the information.

---

## 30. Discipleship Progress

Discipleship progression is one of the application's primary visual
concepts.

Progress must clearly communicate:

- lessons completed
- current lesson
- meetings completed
- lessons not started
- lesson ready for completion
- overall journey progress

Do not rely solely on percentages.

Users should be able to understand exactly where they are in the
journey.

---

## 31. Horizontal Progress

Horizontal progress may be used for compact summaries.

Suitable locations include:

- Home
- Profile
- summary cards

Example:

✓ ─── ✓ ─── ✓ ─── ◉ ─── ○

Current:
Lesson 4
Meeting 3/4

Do not attempt to display all 12 lessons horizontally if doing so harms
readability.

A condensed representation may be used.

---

## 32. Vertical Progress Timeline

Detailed Progress screens should favor a vertical timeline where
appropriate.

Example:

● Lesson 1
│ Completed
│
● Lesson 2
│ Completed
│
◉ Lesson 3
│ Meeting 3/4
│
○ Lesson 4
│ Not Started
│
○ Lesson 5
  Not Started

The timeline should make the journey feel sequential and understandable.

---

## 33. Meeting Progress

The four required meetings should use a consistent visual component.

Example:

● ● ● ○

Meeting 3 of 4

States should be visually distinguishable:

Completed
Current
Remaining

The same component should be reused wherever meeting progress appears.

---

## 34. Activity Timeline

Activity timelines are an important DiscipleTrack pattern.

They may represent events such as:

- lesson meeting recorded
- lesson completed
- D Group attendance
- follow-up created
- follow-up resolved
- assignment changed
- promotion

Example:

Today
● Lesson 6 — Meeting 3/4 recorded
│
Sep 20
● Follow-up resolved
│
Sep 18
● D Group attendance — Present

Timelines may appear directly on the page background rather than always
inside a card.

---

## 35. Lists

Lists should provide useful context.

Avoid:

Avatar
Name
Arrow

when additional useful information is available.

A Disciple list item may contain:

Avatar
Name
Current Lesson
Meeting Progress
Attention State

A D Group list item may contain:

Group Name
Leader
Member Count
Relevant Health/Activity Information

Information density should remain appropriate for mobile.

---

## 36. Contextual Actions

Actions should appear close to the information they affect.

Example:

James Santos
3 consecutive absences

[Follow Up]

is preferable to hiding the primary action inside an unrelated global
menu.

Secondary/destructive actions may use overflow menus where appropriate.

---

## 37. Attention States

DiscipleTrack should visually distinguish items requiring human
attention.

Two different things share this visual treatment, and they must not be
confused in code.

### Stored Attention Conditions

Detected by server-side monitoring and persisted as records. They drive
follow-up creation and have their own lifecycle.

MVP condition type:

- consecutive absences

Do not invent additional stored condition types. New types require an
intentional scope decision.

### Derived Attention Indicators

Computed by query. No stored row, no follow-up.

Examples:

- unassigned Disciple
- lesson awaiting Leader confirmation
- overdue follow-up

Both may use the same components and semantic styling. Only the first
category represents a monitoring condition.

Attention UI should communicate:

- who/what needs attention
- why
- what action is available

Where a follow-up is still open but its underlying condition has already
resolved, for example the member has resumed attending, the UI should
show that distinction rather than presenting it identically to an
actively deteriorating case. The care action is still owed.

Avoid alarming visual treatment for routine ministry follow-up.

---

## 38. Announcements

Announcements should be lightweight and readable.

An announcement component may show:

- scope
- title
- short message
- author/context
- date

Church and D Group announcements should be visually distinguishable
without requiring dramatically different component styles.

---

## 39. Status Indicators

Statuses should use consistent components.

Examples:

Active
Inactive
Present
Absent
Late
Excused
In Progress
Ready for Completion
Completed
Open
Overdue
Resolved

Do not create a new badge style for every feature.

Semantic status styling should be centralized.

---

## 40. Buttons

Use clear action hierarchy.

Primary Button
→ primary action on the current screen

Secondary Button
→ alternative action

Text/Ghost Action
→ lightweight action

Destructive Action
→ deletion/revocation where applicable

Avoid screens containing several equally prominent primary buttons.

---

## 41. Forms

Forms should:

- use clear labels
- provide appropriate input types
- provide immediate understandable validation
- group related fields
- avoid unnecessarily long single-page forms

Use progressive disclosure or sections when appropriate.

Do not rely only on placeholder text as a field label.

---

## 42. Empty States

Empty states should explain what the absence of data means.

Bad:

"No data."

Better:

"No disciples have been assigned to you yet."

Where appropriate, provide an authorized next action.

Empty states should not invent actions the current user cannot perform.

---

## 43. Loading States

Avoid disruptive loading experiences.

Use appropriate:

- skeletons
- progress indicators
- preserved previous state

depending on context.

Do not display a full-screen spinner for every small data refresh.

---

## 44. Error States

Errors should explain what happened in understandable language and,
where possible, what the user can do.

Examples:

Unable to load your D Group.
[Try Again]

Avoid exposing raw Supabase/PostgreSQL exceptions to users.

---

## 45. Destructive Actions

Destructive or difficult-to-reverse actions require clear confirmation.

Examples:

- revoke access
- archive member
- remove assignment
- regenerate church join code

Routine actions should not be burdened with unnecessary confirmation
dialogs.

---

## 46. Interaction Feedback

Interactive elements should provide immediate feedback.

Examples:

- pressed state
- loading state
- success confirmation
- error feedback
- disabled state

Prevent accidental duplicate submissions when an operation is already in
progress.

---

## 47. Accessibility

The design must consider:

- readable text sizes
- sufficient contrast
- adequate touch targets
- screen-reader semantics
- clear labels
- not relying exclusively on color
- scalable text where practical

A polished interface that is difficult to use is not considered a good
DiscipleTrack interface.

---

## 48. Responsive Mobile Layout

The MVP is mobile-first.

Layouts must work across realistic Android and iOS phone sizes.

Avoid fixed dimensions that assume one specific device.

Respect:

- SafeArea
- keyboard insets
- bottom navigation
- dynamic text
- varying screen heights

Tablet-specific layouts may be introduced later where justified.

---

## 49. Reuse Before Reinvention

Before creating a new component, developers and AI agents should check
whether an existing DiscipleTrack component already represents the
required pattern.

Prefer:

Existing Component
→ optional extension/variant

over:

New nearly-identical component

This prevents visual fragmentation.

---

## 50. Avoid Premature Generic Components

Do not create a universal component simply because two screens initially
look similar.

First establish repeated patterns.

Then extract stable abstractions.

Domain clarity is more important than maximizing component reuse.

---

## 51. AI Implementation Rules

When an AI agent implements UI, it must:

1. Read this document before implementation.
2. Inspect existing shared components.
3. Reuse established design tokens.
4. Reuse existing components where appropriate.
5. Preserve the established information hierarchy.
6. Follow role/context authorization.
7. Implement loading, empty and error states.
8. Avoid introducing arbitrary colors, spacing or radii.
9. Avoid adding decorative components without purpose.
10. Avoid redesigning unrelated screens.

Generated UI must fit DiscipleTrack rather than simply looking
generically "modern."

---

## 52. Patterns to Avoid

DiscipleTrack should avoid:

- excessive gradients
- excessive shadows
- excessive glassmorphism
- excessive cards
- excessive badges
- excessive animations
- giant headings wasting mobile space
- unrelated accent colors
- dense desktop-style tables
- decorative charts without meaningful information
- card-inside-card nesting
- inconsistent corner radii
- inconsistent spacing
- arbitrary one-off components
- hiding important actions unnecessarily
- duplicating information simply to fill space

---

## 53. Motion

Motion should communicate state or spatial relationships.

Suitable examples:

- bottom-sheet transitions
- progress updates
- navigation transitions
- expanding details
- subtle list changes

Avoid animation purely for spectacle.

Motion must never delay important actions.

---

## 54. Design Review Checklist

Before considering a screen complete, verify:

- What question does this screen answer?
- What is the most important information?
- What is the primary action?
- Is anything present only for decoration?
- Are existing components reused?
- Is information grouped logically?
- Are cards being overused?
- Is spacing consistent?
- Are states understandable without relying only on color?
- Does the screen work for its intended role?
- Are loading, empty and error states handled?
- Does authorization match what is displayed?
- Does it feel consistent with the rest of DiscipleTrack?

---

## 55. Core DiscipleTrack Visual Identity

DiscipleTrack should ultimately feel:

**Calm enough for ministry.  
Clear enough for daily use.  
Informative enough for leadership.  
Personal enough for discipleship.  
Consistent enough to feel professionally engineered.**