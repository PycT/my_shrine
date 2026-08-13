# Implementation Plan: History record management

Add soft-delete and update-seconds methods for ledger records to the existing helper classes.

---

## SqliteHelpers — add `softDeleteLedgerRecord`

> [`sqlite_helpers.dart`](file:///home/pyct/Workshop/my_shrine/my_shrine/lib/helpers/sqlite_helpers.dart)

```
static Future<void> softDeleteLedgerRecord({required int id}) async
```

- Sets `is_deleted = 1` on the `time_ledger` row where `id = ?`.
- Throws `StateError` if no row matched.
- Calls `_stampLastUpdate()`.
- Follows the same pattern as [`softDeleteShrine()`](file:///home/pyct/Workshop/my_shrine/my_shrine/lib/helpers/sqlite_helpers.dart#L242-L258).

> **`updateLedgerSeconds` already exists** — no changes needed for the update case.

---

## FirestoreHelpers — add `softDeleteLedgerRecord`

> [`firestore_helpers.dart`](file:///home/pyct/Workshop/my_shrine/my_shrine/lib/helpers/firestore_helpers.dart)

```
static Future<void> softDeleteLedgerRecord({
  required String userId,
  required String shrineName,
  required Timestamp startTimestamp,
}) async
```

- Queries `user_time_ledger` by `shrine_name + start_timestamp`.
- Sets `is_deleted: true` on the matching document.
- Throws `StateError` if no document matched.
- Calls `_stampUserDoc(userId)`.

> **`updateLedgerSeconds` already exists** — no changes needed for the update case.

---

## Summary

| File | Change |
|------|--------|
| [`sqlite_helpers.dart`](file:///home/pyct/Workshop/my_shrine/my_shrine/lib/helpers/sqlite_helpers.dart) | Add `softDeleteLedgerRecord({required int id})` |
| [`firestore_helpers.dart`](file:///home/pyct/Workshop/my_shrine/my_shrine/lib/helpers/firestore_helpers.dart) | Add `softDeleteLedgerRecord({required String userId, required String shrineName, required Timestamp startTimestamp})` |

No new files. No schema changes.
