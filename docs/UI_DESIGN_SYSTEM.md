# DiscipleTrack UI Design System

*Document Status:* MVP Baseline  
*Last Updated:* October 2026

Revision 2026-10-02: palette text aligned with the code (sections 6, 7);
monthly meeting view (20); navigation per role (21, 22); meeting
progress as a count, never a fraction (26, 31 to 34; ADR-011); attention
condition types (37); confirmation of lesson completion (45); the UX
architecture in sections 58 to 69, run as part of every slice's
pre-implementation review (decision A12).

Revision 2026-10-05: D Group gatherings and gathering attendance removed
(ADR-014): attendance summary and component examples (10, 15, 16), the
week / date strip withdrawn, monthly meeting view kept (20), Home and
Profile composition (23, 24, 26, 28), activity entries (34). One Journey
destination with My Journey and My Disciples replaces Progress and
Disciples (21, 22, 60, 61, 63; N8). Factual 12-segment Journey progress,
no percentages (30, 31, 64, 65, 67; decisions 8, 22). Monitoring wording:
one condition, consecutive recorded absences, Disciples only; no
"missed meeting" terms (25, 30, 33, 36, 37, 64, 68; ADR-014). Discipler
eligibility after confirmed Lesson 5 completion, replacing promotion
eligibility (27, 34, 64; ADR-012). Discipler progress visibility
relationship-scoped (62; N7). Pairing copy names the Leader or the
Coordinator (66).

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

Palette (tokens in `lib/core/theme/app_colors.dart`):

The palette is lime, white, black and greys only. The logo's forest green
(`#022306`) belongs to the launcher icon and store listing and is never
used inside the app. The only other colours are the semantic warning and
error colours of section 7.

Light mode: every page (including the welcome page and the splash) is
`#F2F3F4`, and every component on it (cards, fields, the dock, buttons,
round icon buttons) is `#FFFFFF`. Icons, back buttons and text are black;
sub text is grey. Dark
mode is pure black with charcoal cards and a brighter lime.

| Token | Light | Dark | Use |
|---|---|---|---|
| background | `#F2F3F4` | `#000000` | page |
| surface | `#FFFFFF` | `#1C1C1E` | cards, fields, dock, icon buttons |
| border | `#E5E7EB` | `#2C2C2E` | separates surfaces |
| brand / lime | `#9BFC28` | `#9BFC28` | the one lime (the icon logo's): primary action, active dock item, active pills, highlights, the 10% |
| brandPressed | `#8BE324` | `#8BE324` | the same lime one step darker, only while pressed |
| dock | `#FFFFFF` | `#1C1C1E` | the floating dock, a white pill on the grey page |
| dockActive | `#EEEFF1` | `#3A3A3C` | the active destination's soft grey pill |
| mint, pastel | `#FFFFFF` | `#1C1C1E` | role names for component fills; both are the plain surface (no lime tints, no tinted cards) |
| muted | `#6B7178` | `#8E8E93` | supporting text and inactive icons |
| ink, textPrimary | `#0A0A0A` | `#FFFFFF` | text and high-emphasis neutrals |

There is exactly one lime in the app, the icon logo's `#9BFC28`, in both
modes; no other green shade or lime tint is used. Lime always carries
black text.

Light mode is the default. A signed-in person switches to dark mode
with the toggle beside the profile avatar in the top-right corner; the
device setting is not followed. The choice is remembered on the device,
so the app (from the welcome page on) opens in it and it survives
signing out. Widgets read colours from the active palette
(`context.palette`), never from the raw token constants, so every
screen works in both modes.

The profile placeholder is a person icon on the neutral surface, not
initials, so it blends into the page in either mode.

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

Proportion follows 60-30-10:

These are design proportions of colour on screen, not a progress or
attendance metric (section 65).

- 60%: the neutral surfaces: the `#F2F3F4` page with white components
  on it (pure black page with charcoal components in dark mode)
- 30%: black and greys: text, icons, soft outlines and the active dock
  pill
- 10%: lime `#9BFC28`, reserved for the primary action, the active
  state and small highlights

Lime is never a large card fill, so the primary action stays the most
prominent element on every screen.

Interactive states are mobile states; there is no hover. Active is the
resting colour, pressed is one shade step darker (`brandPressed` for the
primary action), and disabled is the muted grey of `surfaceAlt` with
`disabled` text.

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
- Journey progress (12 segments, section 31)

There is no attendance summary card: attendance exists only as each
Disciple's outcome inside a recorded discipleship meeting (ADR-014).

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

There is no fixed per-screen card arrangement. Whether a screen uses
cards, which fills they carry and how many there are is decided by
that screen's content and the question it answers (section 4). Flat
page sections, grouped rows, timelines and tabs are all valid
structures.

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
OutcomeSelector (a Disciple's meeting outcome, section 67)
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

Primary screens should use a consistent header system. The signed-in
header is: the avatar on the left, then two lines beside it (the
person's name, bold and larger, over the church name, lighter, smaller and
thinner), and round white icon buttons on the right. The time-of-day
greeting ("Good morning, James") is the title of the Home body, not part
of the header. Home shows no membership badge.

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

## 20. Monthly Meeting View

### Week / date strip

Withdrawn (ADR-014, decision 10). Its only purpose was showing D Group
gatherings, which are removed from the MVP. The monthly meeting view
below is the only date view.

### Monthly meeting view

A read-only month view of recorded discipleship meetings is approved
(decision A4). It answers "When did this discipleship actually meet?"
It is history, not a calendar feature (MVP section 33, BR-031a), and
DiscipleTrack does not schedule discipleship meetings.

Entry paths (decision 11):

- Disciple: Journey, My Journey, monthly meeting view.
- Discipler: Journey, My Disciples, select a Disciple, monthly meeting
  view.

- It is derived only from the occurred_at of meetings already recorded,
  with each record's outcome. Nothing is entered on it.
- It never shows a planned meeting, never offers to create a meeting for
  a date, and has no event creation, scheduling or gathering
  attendance.
- A date without a record is plain. It is never marked missed, overdue
  or empty in a warning style. Only a recorded Absent outcome appears as
  an absence, worded "Recorded absence".
- Scope: a Disciple sees their own history; a Discipler sees it only
  for a Disciple currently assigned to them (N7); a Leader or
  Coordinator sees it only inside one Disciple's journey. It is never a
  group-wide or church-wide calendar, there is no Leader group-wide
  calendar, and it is never a Leader's primary view.
- Empty month: "No meetings recorded in September."

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
Five is the hard limit.

A destination earns a dock slot only if its role uses it in most
sessions and it is not already one tap away from another dock item
(section 63).

Example Disciple navigation:

Home
Journey
D Group
Profile

There is no Attendance destination (ADR-014).

Navigation may differ by responsibility while maintaining the same
visual language.

---

## 22. Role-Aware Navigation

Navigation should reflect what each person actually needs.

Do not expose irrelevant destinations simply because another role uses
them.

Approved per role (decisions A5, A6, A10; amended by N8). Destinations
appear only once the screens behind them exist.

### Journey

One relationship-aware Journey destination replaces the separate
Progress and Disciples destinations (N8). It appears for anyone with a
discipleship relationship, and what it shows is derived from that
person's relationships, never from a global role-mode switch:

| The person is | Journey shows |
|---|---|
| A Disciple only | My Journey directly, no tab bar |
| A Disciple and the assigned Discipler of at least one Disciple | Tabs: My Journey, My Disciples |
| A Discipler only | My Disciples directly |

My Journey is the journey in which the person is the Disciple. My
Disciples lists the Disciples for whom the person is the currently
assigned Discipler (N7), each opening that Disciple's journey. A
Discipler with no Disciples assigned yet and no own journey sees the My
Disciples empty state; a person with their own journey and no assigned
Disciples sees My Journey without tabs, and the My Disciples tab appears
once a Disciple is paired. There is never an empty tab. The default tab
when both exist is open (D11; proposed default My Journey, remembered
per device).

### Disciple

Home
Journey
D Group
Profile

### Discipler

Home
Journey
D Group
Profile

A person who is both Disciple and Discipler has the same dock; Journey
carries both contexts (N8).

### D Group Leader

Home
D Group
Profile

"D Group" is the Leader's one group destination: its members, their
progress, lessons awaiting confirmation, attention states and the group
context. "Members" is a section inside it, never a separate
destination. A Leader who also disciples adds Journey, which shows My
Disciples:

Home
D Group
Journey
Profile

### Coordinator

Home
D Groups
Profile

with Journey added when the Coordinator has a discipleship
relationship, and D Group reached through D Groups (or the Home entry)
when they also lead one.

### Admin without Coordinator

Home
Profile

### Membership requests

Pending membership requests are a Home attention tile ("2 people waiting
to join") for Admin and Coordinator, not a permanent dock destination.
Revisit only if usage shows it deserves primary navigation.

### Labels

"D Group" names the domain group everywhere, including the dock (not
"My Group"). "Members" names only a collection or section of people.

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

Home is composed from the person's relationships, not from a single
role: a Disciple block when they have their own journey, a Disciples
block when they are the assigned Discipler of at least one Disciple,
and Leader and Coordinator tiles when they hold those responsibilities.
Blocks are ordered by the more frequent responsibility (section 62) and
link into Journey rather than duplicating it (section 63; N8).

---

## 24. Disciple Home

The Disciple Home should emphasize:

- current discipleship journey
- current lesson
- meeting progress
- meeting history, with each recorded outcome
- D Group
- Discipler
- announcements
- recent relevant activity

Example priority:

Greeting
→ Current Journey
→ Announcement
→ Journey progress (12 segments)
→ Recent Activity

There is no gathering attendance block (ADR-014).

---

## 25. Discipler Home

The Discipler experience is action-oriented. The Discipler Home should
emphasize:

- assigned Disciples, each with current lesson and meeting progress
- Record Meeting
- members requiring attention
- follow-ups
- recent activity
- D Group context
- announcements

The screen should help answer:

"Who needs me today?"

Workflow:

Journey
→ My Disciples
→ Disciple Detail
→ Current Lesson
→ Record Meeting
→ Meeting History
→ Progress

Record Meeting records what happened after a meetup the Discipler and
Disciple arranged themselves. It is not a scheduling or calendar
feature. Do not expose database terminology.

Recording is lesson-centred (decision C):

Journey
→ selected discipleship (My Disciples, then the Disciple)
→ current lesson
→ Record Meeting
→ date it took place (default today, never in the future)
→ each expected Disciple's outcome (Present, Late, Absent or Excused)
→ optional shared notes
→ a one-line review above the button
→ record

The lesson is fixed by the journey it was opened from; it is shown, not
chosen. The record shows each Disciple's recorded outcome; no "held"
or "missed" label is asked for or derived (ADR-014 decision 8). A
"Nobody came" shortcut may preset every outcome to Absent, which the
Discipler can change before recording. Present
and Late add to the lesson's count; Absent and Excused never do, and the
form says so beside the outcome choice. The pattern is a dedicated task
screen with progressive disclosure (section 60).

Use "Record Meeting" as the primary action, not "Add Attendance".
Record Meeting is the only place attendance is entered: each Disciple's
outcome in a discipleship meeting (ADR-014).

Finishing a lesson is a separate action on the lesson, not part of the
form: "Mark Lesson 4 as finished", with the line "Use this when you
have finished covering the material together. Your Leader then confirms
it." A meeting is never what finishes a lesson, and no meeting count
completes one automatically (ADR-011). Whether a minimum number of
credited meetings applies is still open (ADR-011).

---

## 26. D Group Leader Home

The D Group Leader experience is oversight-oriented. It is not an
attendance-entry workspace. It should emphasize:

- D Group health
- discipleship progress per Disciple
- meeting history as facts: last recorded meeting, recorded absences
- Disciplers, and when their Disciples' meetings were last recorded
- members requiring attention
- lessons awaiting confirmation
- follow-ups
- recent discipleship activity

There is no gathering attendance on Leader Home (ADR-014).

Leader Home leads with what needs the Leader: lessons submitted and
awaiting their confirmation, then attention states, then factual
progress per Disciple and recent meaningful activity, with drill-down
to any authorized member. It has no scheduling control and never
compares Disciplers, Disciples or groups. Inviting a member is
occasional and secondary; it never dominates D Group detail (decision
A8).

Example Disciple summary:

Juan Dela Cruz
Lesson 4 · 3 meetings recorded
Last recorded meeting Sep 20
1 recorded absence
Awaiting your confirmation (when submitted)

Attention lines ("Needs attention") appear only once the monitoring
slice produces conditions. Before then, no attention state is shown,
because no data supports one.

Workflow:

Dashboard / D Group
→ Progress overview
→ Meeting history
→ Needs attention
→ Member detail
  → Journey
  → Current Lesson
  → Meeting History
  → Follow-up / care

Fallback meeting recording, where a Leader records on behalf of a
Discipler, belongs inside Member detail, not on the dashboard.

When a Discipler submits a lesson as finished, it appears for the Leader
as "Lesson 4 submitted by Mark Reyes · Awaiting your confirmation".
Confirming opens a dialog (section 45).

---

## 27. Coordinator Home

The Coordinator experience should emphasize:

- ministry overview
- D Groups
- members requiring attention
- unresolved/overdue follow-ups
- unassigned members
- discipleship progress and meeting history, as facts
- Discipler eligibility: confirmed Lesson 5 completion (ADR-012). Shown
  to the Coordinator, who appoints directly; derived on read, never a
  stored flag, never automatic. The eligibility lesson comes from one
  database policy function (D2)
- announcements

Workflow:

Oversight
→ Groups / people needing attention
→ Progress
→ Follow-ups

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
Meeting history (recorded discipleship meeting outcomes)
Recent Activity

The exact composition may differ according to responsibility and viewer
authorization. Like Home (section 23), a profile is composed from the
person's relationships: their own journey if they are a Disciple, their
assigned Disciples if they are a Discipler. There is no gathering
attendance section (ADR-014).

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
- meetings recorded for the current lesson
- lessons not started
- lesson submitted as finished, awaiting confirmation ("Lesson 6
  awaiting confirmation")
- journey progress as a factual 12-segment visualization ("Lesson 6 of
  12", "5 of 12 completed"; section 31)

Only a lesson with confirmed COMPLETED status counts as completed; a
lesson awaiting confirmation does not. The meeting count never
determines progress, and recorded absences are meeting history, not
progress (decision 22). The total comes from the active curriculum,
never a literal.

Never show progress as a percentage, and never use a label that
evaluates the person ("behind", "advanced", a score) (decision 8).

Users should be able to understand exactly where they are in the
journey.

---

## 31. Horizontal Progress

Horizontal progress may be used for compact summaries.

Suitable locations include:

- Home
- Profile
- summary cards

The compact journey form is the factual 12-segment visualization
(decision 22):

Lesson 6 of 12
✓ ✓ ✓ ✓ ✓ ● ○ ○ ○ ○ ○ ○
5 of 12 completed

Segments are completed (✓, confirmed COMPLETED only), current (●) and
upcoming (○). The number of segments is the active curriculum's lesson
count. Segments are compact marks, not labelled steps, so all lessons
fit; where width does not allow even that, show the two text lines
without the segments. No percentage, no evaluative label.

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
│ 3 meetings recorded
│
○ Lesson 4
│ Not Started
│
○ Lesson 5
  Not Started

The timeline should make the journey feel sequential and understandable.

---

## 33. Meeting Progress

Meeting progress is a count of credited meetings, shown with one
consistent component. A lesson has no fixed number of meetings
(ADR-011), so the component never shows a total, empty "remaining"
markers or a fraction.

Example:

Lesson 4 · 5 meetings recorded

Where the meeting policy defines a typical number, it may be added as
guidance:

Lesson 4 · 5 meetings recorded · Typical: 4

Exceeding the typical number is never styled as a warning, an error or
an achievement. The component reads its values (count, and a typical
number or none) from the database; it never reads required_meetings or
a literal.

The lesson's state follows the count as a separate line:

- In progress: "5 meetings recorded"
- Submitted: "Finished, awaiting Leader confirmation"
- Completed: "Completed Sep 12 · confirmed by Lea Santos"

Recorded absences are not progress. They never add to the count. Show
them in meeting history, for example:

Lesson 1
Meeting 1          Present   Counted
Meeting 2          Present   Counted
Recorded absence   Absent    Not counted
Meeting 3          Present   Counted
Meeting 4       Present   Counted

More meetings may be recorded while the lesson awaits confirmation. Do
not display counts such as "5/4". Prefer:

6 meetings recorded
Finished, awaiting Leader confirmation

The same component should be reused wherever meeting progress appears.

---

## 34. Activity Timeline

Activity timelines are an important DiscipleTrack pattern.

They may represent events such as:

- lesson meeting recorded
- recorded absence (an Absent outcome in a recorded meeting)
- lesson completed
- follow-up created
- follow-up resolved
- assignment changed
- Discipler appointment (ADR-012)

There are no D Group attendance entries (ADR-014).

Example:

Today
● Lesson 6 — Meeting 3 recorded
│
Sep 21
● Lesson 6 — Recorded absence
│
Sep 20
● Follow-up resolved
│
Sep 18
● Lesson 5 completed · confirmed by Lea Santos

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
3 consecutive recorded absences

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

The one MVP condition type (ADR-009 as amended by ADR-014):

- consecutive recorded absences (CONSECUTIVE_ABSENCE), for Disciples
  only: consecutive explicitly recorded Absent outcomes in recorded
  discipleship meetings, within the current Discipler assignment, up to
  the church's threshold. Present and Late break the streak; Excused
  breaks it and is never an absence.

It arrives with the monitoring slice. There is no gathering-based
condition and no automated "missed meeting" condition (ADR-014).
Leaders and Disciplers have no automated monitoring in the MVP; their
care is human oversight only. A person who is both Disciple and
Discipler is monitored as a Disciple only (ADR-012). Do not invent
additional stored condition types. New types require an intentional
scope decision.

Monitoring sees only what was recorded. No record is not an absence.
Never show elapsed time, inactivity or a date without a record as an
absence or as missed. Use "2 recorded absences", "2 consecutive
recorded absences" or "Last recorded meeting Sep 12".

### Derived Attention Indicators

Computed by query. No stored row, no follow-up.

Examples:

- unassigned Disciple
- lesson submitted as finished, awaiting Leader confirmation
- overdue follow-up

Both may use the same components and semantic styling. Only the first
category represents a monitoring condition.

Attention UI should communicate:

- who/what needs attention
- why
- what action is available

Where a follow-up is still open but its underlying condition has already
resolved, for example a later recorded Present outcome broke the
streak, the UI should
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
Awaiting confirmation (READY_FOR_COMPLETION)
Completed
Voided
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

The primary button is a lime pill with a near-black label in both modes.
Every button is fully rounded (pill). The dock is a small pill centred at
the bottom: white in light mode, charcoal in dark. The active destination
is a soft grey pill holding its filled icon and name (a lighter charcoal
in dark mode); the others are thin grey outline icons. Its width is fixed: each
destination has a fixed slot and the active one a fixed wider slot, so
switching only glides the pill across while the names cross-fade. Home uses a rounded house glyph.

Cards are white with a soft, faint outline and a low, wide shadow, so
they lift off the grey page without hard lines. Home components are full width:
church figures are stacked stat tiles, each an icon chip, its label over
the figure, and a chevron.
It replaces the earlier ink-filled primary button. Where a screen has a
main action, it is placed before the content it acts on, so it is the
first thing seen.

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

Placeholders show the expected format, for example "e.g. Young Adults
A", alongside the label rather than instead of it.

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
- void a meeting or outcome
- reopen a completed lesson
- confirm lesson completion, because only the Coordinator can reopen it
  (decision A7): "Confirm Lesson 4 for Juan? This marks it completed and
  opens Lesson 5. Only the Coordinator can reopen it."

Confirmation always uses the one shared dialog (section 67), with a
confirm label that names the action ("Confirm Lesson 4", "Void
meeting"), never "OK".

Routine actions should not be burdened with unnecessary confirmation
dialogs.

Keep popups few. An action that is undone simply by doing it again,
such as withdrawing an invitation that can be re-sent, runs immediately
without a dialog.

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

The slice-level UX review in section 69 runs before each slice is
implemented and again before it is called done.

---

## 55. Core DiscipleTrack Visual Identity

DiscipleTrack should ultimately feel:

**Calm enough for ministry.  
Clear enough for daily use.  
Informative enough for leadership.  
Personal enough for discipleship.  
Consistent enough to feel professionally engineered.**

---

## 56. Launch, Welcome and Sign-in

- **Splash.** The lime logo and the "DiscipleTrack" wordmark on the page
  colour. The logo springs in with a slight overshoot and turn while one
  soft lime ring ripples out behind it; then the wordmark writes itself in
  letter by letter, each letter fading up into place. It starts just after the first frame, plays once per launch,
  and not at all with reduced motion. The native launch screens are white
  with the lime mark.
- **Welcome.** On the page colour like every screen: the illustration
  (`assets/brand/login_icon.png`) centred just above a large left-aligned
  hero line, a short supporting line, then Sign up (outlined pill) and Log
  in (lime pill) side by side.
- **Login and Sign up.** Full-screen pages with a back arrow to the welcome
  page: the bare lime logo, a centred title and subtitle, then the form,
  centred vertically when it fits. Fields are pills with a leading icon and
  a label that floats inside the field, so a visible label is kept
  (section 41). Third-party sign-in is not offered.


---

## 57. The Standard: Welcome and Login

The welcome page and the login and sign-up pages set the standard for
every screen:

- **Page and components.** The page colour (`#F2F3F4` light, black dark)
  with white components (charcoal in dark mode) that have a soft outline
  and a low, wide shadow.
- **Type.** Large, tightly tracked bold titles; grey supporting text
  underneath; black body text.
- **Fields.** Pills with a leading icon and a label that sits inside the
  field and floats above the text when typing starts. Labels are in
  sentence case. This is the default for every text field.
- **Buttons.** Pills. The one primary action is lime with black text;
  secondary actions are white pills with a soft outline.
- **Structure.** One clear title, centred forms on focused tasks, the
  primary action last, and a back arrow on every page reached by
  navigating.

Light or dark is the person's choice, remembered on the device: the app
opens in it, from the welcome page on, and it survives signing out.


---

# Part II. UX Architecture

Sections 58 to 69 record the approved UX decision framework (decision
A12, from the UI/UX architecture audit of 2026-10-02). They govern how
a screen is decided; sections 1 to 57 govern how it looks. They add a
procedure, not new authority: each step names the document that already
governs its subject (ADR-008). There is no separate UX document.

---

## 58. UX Decision Framework

Every screen and interaction is decided in this order:

| Step | Question | Governing source |
|---|---|---|
| 1. Domain and workflow | Which MVP workflow step is this? What real event does it record or reveal? | MVP_SPEC section 2, BUSINESS_RULES |
| 2. Affected role | Which responsibility uses it (Disciple, Discipler, Leader, Coordinator, Admin, Member without a group, Pending)? Who else sees its effects? | MVP_SPEC sections 5 to 10; RBAC sections 1, 2 |
| 3. Intent | Consume, follow, conduct and record, observe and confirm, organise, or administer? | section 4 |
| 4. Information | What must the person know? What may they not see? | RBAC sections 2, 2a, 2b, 5; DATABASE_CONSTRAINTS section 11 |
| 5. Actions | Which actions does RBAC grant this role on this record? Never add one it does not. | RBAC sections 2, 10 |
| 6. Frequency, risk, complexity | Daily, weekly or rare? Re-doable, or protected? How many inputs? | BUSINESS_RULES; section 45 |
| 7. Hierarchy | What is first, what is a section, what is a drill-down? | sections 4, 18, 23 |
| 8. Pattern | Choose from section 60. | section 60 |
| 9. Components | Reuse, then extend, and create only for a domain concept. | sections 15, 16, 49, 67 |
| 10. Navigation | Primary destination, drill-down, contextual task or settings? | section 63 |
| 11. States | Loading, empty, error, offline, restricted, disabled, in progress, success. | section 66 |

Two tests apply at every step:

- **Chore test.** Does this remove friction from real discipleship, or
  add a chore? A screen, field or prompt that exists only so the app is
  used more fails. DiscipleTrack does not manufacture engagement: no
  streak badges, no nudges to open the app, no points.
- **Derivation test.** Could this value be computed from records that
  already exist? If so, it is displayed, never entered (section 64).

---

## 59. Page Archetypes

| Archetype | Purpose | Default patterns |
|---|---|---|
| Dashboard / Overview (Home) | The person's current ministry context: what matters now, what changed, what needs attention, what to do next. | Attention items first (each a count with a reason and a drill-down), then at most one contextual primary action, then compact summaries. No management actions inline beyond the role's single most frequent action. |
| Collection / Browse | Find one item among many of one type (D Groups, Disciples, Members, requests). | Compact rows for people, cards only for few rich domain objects. A factual secondary line per row. Sorted by a stated factual key. Filter chips only when the list needs them. |
| Entity Detail | Everything one role may know and do about one entity (a D Group, a Disciple). | Identity and status header, the one primary action, sections in order of consumption, contextual actions beside the facts they change, overflow for secondary and destructive actions. |
| Task / Action | Complete one bounded operation (Record Meeting, New group, Edit profile). | Pushed screen with a back arrow, smart defaults, inline validation, the form kept on error, the primary action last. A stepper only when later steps depend on earlier answers. |
| Monitoring / Oversight | Show an accountable person where care is owed across a scope. | Factual figures, an attention queue, then drill-down: group, person, journey, record. Each level answers one question. No rankings. |
| Timeline / Activity | Show what happened in order. | Vertical timeline on the page background, grouped by lesson (journey) or by date (activity), recorded facts only, voided entries greyed with who voided them. |
| Reading / Content | Read lesson material with continuity (ADR-010). | Single column, headings from the source, a persistent lesson context, next lesson only where eligible, no buttons competing with the text. Reading records nothing. |
| Settings / Administration | Rare, audited configuration. | Grouped rows, one setting per pushed screen or sheet, confirmation for anything that affects other people. Never in the dock. |

---

## 60. Interaction-Pattern Matrix

| Pattern | Use when | Do not use when | Examples |
|---|---|---|---|
| Inline action (text link) | One tap, re-doable, effect visible in place | The action is protected or irreversibly affects someone else | Withdraw invitation, Invite again, Show all |
| Inline expansion | Detail belongs to a row and is short | The detail has its own actions or is long | A lesson's meetings in the journey; a history row's shared notes |
| Bottom sheet | A single choice or one to three short inputs in context | Long keyboard input, or input that must survive an error and retry | Invite role, Pair, choosing which Disciple to record for |
| Dedicated task screen | Several inputs, keyboard use, server validation with recoverable errors | A single choice | Record Meeting, New group, Edit profile |
| Full-screen modal | A focused mode that leaves the dock | Ordinary forms (use a pushed page) | Possibly the lesson reader's focus mode |
| Dialog | Confirming a destructive or hard-to-reverse action, saying what changes | Routine or re-doable actions, choices, errors | Remove, Unpair, Change Leader, Decline request, Void, Reopen, Confirm lesson completion |
| Stepper | Later steps depend on earlier answers or a server check | Independent fields that can be shown together | Join church; not Record Meeting |
| Progressive disclosure | Optional or rare inputs; long histories | Required information | Notes in Record Meeting; older meetings; voided rows |
| Tabs | Local or contextual only: two long views used separately, shown only when both contexts exist (N8) | Content consumed together; primary navigation; a tab that would be empty | Journey: My Journey and My Disciples, only for a person who is both a Disciple and an assigned Discipler |
| Sections | Content consumed together | | D Group detail, Disciple detail |
| Accordion | A long ordered set where one or two items matter now | Short lists | The 12-lesson journey with the current lesson open |
| Timeline | Chronological or sequential facts | Unordered sets | Lesson timeline, activity, meeting history |
| Compact rows | Large homogeneous collections | Few rich objects | Members, Disciples, requests, meeting history |
| Cards | A domain object with its own state (section 10) | Every list row; card in card | Current lesson, invitation, D Group summary |
| Chips / segmented control | Small mutually exclusive option sets | More than about five options | Present / Late / Absent / Excused; list filters |
| Overflow menu | Secondary or destructive row actions | The row's primary action | Remove from group, Void, Reopen |
| FAB | Never: the dock holds the bottom centre and the main action comes first (section 40) | | None |
| Drill-down | From a figure to the records behind it, one level per question | Skipping levels, or landing where the counted records are not shown | Coordinator: D Groups → group → person → journey → record |

Record Meeting is a dedicated task screen with progressive disclosure.
Its inputs (date, one or more outcomes, optional notes) and its server
refusals do not fit a sheet, which a swipe would dismiss with the notes,
and nothing in it depends on an earlier answer, so a stepper would only
add taps. The review is a one-line summary above the button ("Records a
Lesson 2 meeting on Oct 1 · counts for Diana"), not a second screen,
because records are corrected by void and re-record.

---

## 61. CTA Hierarchy

| Level | Visual | Rule |
|---|---|---|
| Primary | Lime pill, black label, one per screen | The role's most consequential recurring action for the entity on screen. Before the content on content pages, last on focused forms. A screen where nothing is the viewer's responsibility has no primary and says it is read-only. |
| Secondary | White pill with a soft outline | Alternatives of similar scope. |
| Tertiary / navigation | Text link or row chevron | Drill-down and inline row actions. |
| Destructive | Overflow item, then the shared dialog with a named confirm label | Never lime, never the primary. |

An action is offered only when RBAC grants it to this viewer. An action
that exists but is unavailable now is shown disabled with its reason
when the person would look for it (offline, lesson not yet submitted,
Disciple on another lesson).

Primary action by page:

| Page | Viewer | Primary |
|---|---|---|
| Home | Disciple | None (later: read the current lesson) |
| Home | Discipler | Record Meeting |
| Home | Leader | None; the confirmation tile leads |
| Home | Coordinator, Admin | None; attention tiles lead |
| Journey, My Journey | Disciple | None, stated |
| Journey, My Disciples | Discipler | Record Meeting |
| Disciple detail | Discipler | Record Meeting; "Mark Lesson n as finished" is secondary on the lesson card |
| Disciple detail | Leader | Confirm Lesson n when submitted; otherwise none. Fallback recording is secondary |
| Disciple detail | Coordinator | None; Confirm as secondary when submitted; Reopen in overflow |
| D Group detail | Leader | None as a lime button; the Awaiting confirmation section leads. Invite a member is secondary (decision A8) |
| D Group detail | Coordinator | Invite a member, or none |
| D Groups | Coordinator | New group |
| Record Meeting | Recorder | Record meeting |

---

## 62. Role Experience Principles

| | Disciple | Discipler | Leader | Coordinator | Admin only |
|---|---|---|---|---|---|
| Intent | Follow own journey | Conduct and record | Observe, confirm, care | Oversee and organise | Administer access |
| Home leads with | Current lesson and its factual state | Their Disciples and Record Meeting | Lessons awaiting confirmation, then progress per Disciple | Attention tiles (requests, unplaced members), then church figures | Requests |
| Drill-down | Journey, lesson, own history | Disciple, journey, record | Group, person, journey, record | Groups, group, person, journey, record | Requests only |
| Never shown | Others' outcomes or progress; follow-up notes | Progress and meeting rows of Disciples not currently assigned to them, including others in their D Group (N7; RBAC section 2) | Other groups | | Meeting outcomes, progress, attention, follow-ups, D Group data (ADR-004) |

Combined responsibilities compose, ordered by the more frequent one,
without duplicating a destination. A Member without a group sees the
not-placed notice and, once it exists, the lesson material. A Pending
member sees onboarding only. Do not add actions to a role to make its
screens look complete; a Disciple's screens are read-only by design and
say so.

---

## 63. Navigation Rules

| Class | Definition | Placement |
|---|---|---|
| Primary destination | Used most sessions by the role and answers its section 4 question | Dock |
| Drill-down | Reached from a destination or a Home figure | Pushed, with a back arrow |
| Contextual task | Started from an entity | Pushed from the entity, returns to it |
| Settings / administration | Rare configuration | Profile or a settings row, never the dock |

- A feature does not earn a dock slot by existing (section 21).
- No two destinations, and no Home entry and a destination, lead to the
  same content.
- A drill-down from a figure lands on the records the figure counts.
- The journey has one home, the Journey destination (N8): My Journey
  for the person's own journey, and Disciple detail reached from My
  Disciples for a Disciple they are assigned to. Home and Profile
  summarise and link to it; Disciple detail reuses the same components.
- A deep link that the viewer may not open shows a restricted state
  that does not confirm the record exists.

---

## 64. Derived Versus Manual

If a value can be computed from records that already exist, the UI
displays it and offers no input for it (ADR-003).

| Element | Source | Never |
|---|---|---|
| Lesson meeting count, ordinal ("Meeting 3") | Credited participations | A manual "counted" control |
| Each Disciple's meeting outcome | The recorded participant row | A derived "held" or "missed" label, or a stored or chosen "missed" flag (ADR-014 decision 8) |
| Lesson status | disciple_lesson_progress, changed only by controlled operations | Client recomputation |
| Journey progress ("Lesson 6 of 12", 12 segments, "5 of 12 completed") | Confirmed COMPLETED progress rows; total from the active curriculum | A percentage, stored or displayed; a literal total |
| Monthly meeting view | occurred_at of recorded meetings | Planned dates, or a blank date shown as missed |
| Recent activity | Domain records the viewer may already read | Reading audit_events for display (RBAC section 9) |
| Group figures ("6 Disciples · 5 paired · 2 awaiting confirmation") | Memberships, assignments, progress | Manually entered group health |
| Active Discipleships | Active discipler assignments (DATABASE_CONSTRAINTS section 11) | A stored counter |
| Last recorded meeting, time since | last_recorded_meeting_date (DC section 11) | Stored; an attention state from elapsed time (ADR-014) |
| Attention states | Server conditions or derived indicators | Client-side monitoring |
| Discipler eligibility, shown to the Coordinator | Confirmed COMPLETED of Lesson 5 of the active curriculum (ADR-012; the lesson comes from one database policy function, D2) | A stored flag; automatic appointment |

The one deliberate manual step in progress is the Discipler's
submission that a lesson's material is finished (ADR-011). It records a
judgement no record can derive.

Chores to avoid: asking a Disciple to confirm meetings, asking a
Discipler to pick a lesson the context already fixes, asking for a date
the app already knows, asking a Leader to "mark reviewed" without a
domain effect.

---

## 65. Factual States, Not Rankings

Progress and meeting history are shown as concrete facts:

- "Lesson 4 · 5 meetings recorded"
- "5 of 12 lessons completed"
- "Lesson 6 current"
- "Lesson 6 awaiting confirmation"
- "Last recorded meeting Sep 25"
- "2 consecutive recorded absences"
- "Awaiting Leader confirmation"

Never: advanced or behind, best group, top Discipler, rankings,
leaderboards, consistency scores or ratios, attendance or progress
percentages, any evaluative percentage (decision 8), or a count above a
typical number styled as a problem or an achievement. Sorting a list by
a factual key ("longest since last recorded meeting first") is allowed
and is labelled as an order, not a ranking.

---

## 66. State Standards

| State | Standard |
|---|---|
| Loading | First load: a skeleton or a spinner in the content area. Refresh after an action keeps the previous content. In a button: an inline spinner of the same size. |
| Empty | Says what the absence means and what happens next, names who acts if not the viewer ("Your Leader or the Coordinator pairs Disciples with you."), and offers an action only if this viewer can take it. |
| Load error | "We couldn't load {subject}. Check your connection and try again." with Try again. Never exception text, never a database code. |
| Action error | Inline beside what it concerns, the form kept, one mapped sentence per refusal reason. |
| Offline | The banner on every page; device data where it exists; screens without it say "This needs a connection" instead of an error. Write actions are disabled and explain themselves on tap: "You're offline. Connect to record this meeting." |
| Restricted | Says the screen is for another role, without revealing data or whether the record exists. |
| Disabled | Disabled with its reason where the person would look for the action. |
| In progress | Duplicate submission prevented; other row actions wait. |
| Success | One snackbar naming the change ("Meeting recorded for Diana Cruz"), then the new state on screen. No success dialogs. |

Every screen states its purpose in one line under its title, in the
person's words.

---

## 67. Component Strategy

Shared primitives belong in `lib/core/widgets/`, not in a feature
folder. Before the Discipleship Meeting + Progress slice adds screens:

- SectionHeading, PersonRow, dividedRows and the shared date formatting
  move from the ministry feature into core.
- One EmptyState primitive (title, body, an optional authorised action,
  a restricted variant) replaces the hand-built empty and restricted
  cards.
- One confirmation pattern: the shared confirmation dialog (moved to
  core) for every destructive or hard-to-reverse action, including
  confirm lesson completion. No confirmation sheets and no per-page
  dialogs.
- ErrorState takes the subject it failed to load and fixed wording, and
  never displays an exception's text.
- AppButton and AppTextLink explain themselves on tap when disabled
  offline.
- StatTile may carry a text value and a supporting line, so factual
  states use the same tile as figures.

Domain components, created because they represent a DiscipleTrack
concept used in several places:

| Component | Concept | Built on |
|---|---|---|
| MeetingCount | "Lesson 4 · 5 meetings recorded", with an optional typical number from the database | text, no fixed-total markers |
| LessonStatusLine | One wording for lesson state across roles | StatusPill |
| LessonTimeline | The journey, with completed, current, submitted and locked lessons | StepList, extended |
| JourneyProgress | "Lesson 6 of 12", 12 segments, "5 of 12 completed" (section 31); total from the active curriculum | text and segment marks, no percentage |
| DiscipleProgressRow | Name, lesson, count, last recorded meeting | PersonRow |
| MeetingHistoryRow | Outcome, counted or not, recorder, voided state, Void where allowed | PersonRow layout |
| OutcomeSelector | Present, Late, Absent, Excused, with the counting hint | a segmented control |
| MonthMeetingView | Recorded meetings by month (section 20) | added only with that view |

Not yet justified: an activity timeline component until two activity
sources exist, an attention card until monitoring exists, a lesson
content view until the material has been inspected, and any generic
dashboard container.

---

## 68. Copy Rules

- Use the person's words, not database terms: "Meeting recorded",
  "Recorded absence", "Awaiting Leader confirmation", "Mark Lesson 4 as
  finished".
- "D Group" names the group; "Members" names a set of people.
- Counts are counts: never "5/4".
- "Missed meeting" is not a DiscipleTrack term (ADR-014). An Absent
  outcome is a "Recorded absence"; time without a record is a date
  ("Last recorded meeting Sep 12"), never an absence.
- Each refusal reason the database can return has one plain sentence
  saying what happened and what to do.

---

## 69. Slice UX Review

Every vertical slice runs this review in its plan's UX section before
implementation, then the walkthrough again before the slice is called
done (AGENTS.md).

### Architecture review, before implementation

1. Domain and workflow: which MVP step, which real event, which rules.
2. Roles: every role and state affected, including combined
   responsibilities, Member without a group, Pending and Admin only.
3. Real-world flow: what happens in the church before, during and
   after; the app records it rather than replacing it (no scheduling,
   no manufactured steps).
4. Information per role: needed, permitted (cite the RBAC section),
   never shown.
5. Actions: each with its RBAC cell, frequency, reversibility and who
   else is affected.
6. Derived values: each has a DATABASE_CONSTRAINTS section 11
   definition, or one is added; nothing derivable is editable.
7. States: each of section 66, with its sentence.
8. Patterns: chosen from section 60, with any tab, stepper, sheet or
   dialog justified.
9. Pages and navigation: archetype and destination class per page; does
   anything earn a dock slot; does anything duplicate a destination.
10. Components: reused, extended or new, and why.
11. Cross-role effects: what every other role now sees differently.
12. Chore and ranking tests (sections 58, 65).
13. Contradictions with ADRs, RBAC, DATABASE_CONSTRAINTS, the DBML or
    MVP scope, reported, not resolved.
14. Implementation order: shared primitives first, then screens.

### Role walkthrough, before done

For each role, write the walkthrough in the first person against the
seeded data: "I sign in as a Discipler. Home shows... I tap... I can...
I cannot... Offline, I see...". Check for:

- fragmented tasks split across unrelated screens;
- a role facing a screen with nothing for it and no explanation;
- duplicated destinations;
- actions RBAC does not grant, or the role never needs;
- whether the person can answer their section 4 question from Home at a
  glance;
- drill-downs that skip a level or land away from the counted records;
- what each other role sees on the same deep link;
- what every screen shows offline, and whether every disabled action
  explains itself;
- consistent words (section 68).
