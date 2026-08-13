# Implementation Plan: History Edit UI

> Updates to [`history_view.dart`](file:///home/pyct/Workshop/my_shrine/my_shrine/lib/views/history_view.dart)

## Scope

Two UI features on the existing `logEntryCard`:
1. **Delete button** with confirmation dialog before soft-deleting the record.
2. **Tracked time editor** — roller wheels (hours, minutes, seconds) to change `seconds_tracked`.

---

## Pre-requisite: Convert `HistoryView` to `StatefulWidget`

Currently `HistoryView` is a `StatelessWidget` using `FutureBuilder`. It needs to become `StatefulWidget` so that:
- Deleting a record can remove it from the list without a full rebuild.
- Editing seconds can update the displayed value in-place.

Store `List<TimeLedger>` and `Map<String, String> shrineColors` in state. Load them once in `initState`, expose a `_reload()` method that re-fetches and calls `setState`.

---

## Change 1: Delete button on each card

**UI**: Add a trailing delete icon (`Icons.delete_outline`) to the existing `ListTile` in `logEntryCard`.

**Flow**:
1. User taps delete icon.
2. Show `showDialog` with an `AlertDialog` — title: "Delete record?", content: shrine name + formatted duration, actions: Cancel / Delete.
3. On confirm:
   - Call `SqliteHelpers.softDeleteLedgerRecord(id: record.id)`.
   - Call `FirestoreHelpers.softDeleteLedgerRecord(userId, shrineName, startTimestamp)`.
   - Remove the record from the local list and `setState`.

**Imports needed**: `SqliteHelpers`, `FirestoreHelpers`, `user_helpers.dart`, `cloud_firestore` (for `Timestamp`).

---

## Change 2: Tracked time editor (roller wheels)

**UI**: Add an edit icon button (`Icons.edit_outlined`) to the card (e.g. as part of a trailing `Row` alongside the delete icon). Tapping it opens a **top overlay banner** containing three `ListWheelScrollView` columns (Hours, Minutes, Seconds). The banner sits above the list content (e.g. using a `Stack` or `Column` above the `ListView`), without pushing the list down.

Reuse the `_buildWheel` pattern from [`TimestampPickerWidget`](file:///home/pyct/Workshop/my_shrine/my_shrine/lib/widgets/timestamp_picker_widget.dart#L214-L246):
- 3 wheels: hours (0–23), minutes (0–59), seconds (0–59).
- Pre-populated from `record.secondsTracked`.
- Confirm/Cancel buttons.

**Flow**:
1. User taps the edit icon on a card.
2. A `DurationEditorWidget` appears as an overlay banner at the top of the screen body (above the `ListView`), showing:
   - Title: shrine name + original duration.
   - Three roller wheels (H / M / S) initialized to current values.
   - Cancel + Save buttons.
3. On save:
   - Compute `newSeconds = h*3600 + m*60 + s`.
   - Call `SqliteHelpers.updateLedgerSeconds(shrineName, startTimestamp, newSeconds)`.
   - Call `FirestoreHelpers.updateLedgerSeconds(userId, shrineName, startTimestamp, newSeconds)`.
   - Update the record in the local list, dismiss the banner, and `setState`.

**Implementation**: Wrap the `Scaffold` body in a `Stack`. When editing, overlay a `Material` card/container at the top with the `DurationEditorWidget`. Track the currently-edited `TimeLedger?` in state — when non-null, the overlay is visible.

---

## Summary of changes

| File | Change |
|------|--------|
| [`history_view.dart`](file:///home/pyct/Workshop/my_shrine/my_shrine/lib/views/history_view.dart) | Convert to `StatefulWidget`. Add delete + edit icons to each card. Wrap body in `Stack` to host the top overlay editor. |
| `widgets/duration_editor_widget.dart` | **Create** — Roller-based HH:MM:SS editor widget (reuses `_buildWheel` pattern from `TimestampPickerWidget`). Accepts `initialSeconds`, returns new value via callback. |

No helper changes — `softDeleteLedgerRecord` and `updateLedgerSeconds` already exist in both `SqliteHelpers` and `FirestoreHelpers`.
