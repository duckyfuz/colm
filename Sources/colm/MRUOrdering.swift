/// Most-recently-used ordering for any hashable key.
///
/// Pure value type — no system deps, no Foundation. Feed `touch(_:)` whenever
/// a window or app becomes focused; call `order(among:)` to get a snapshot
/// list filtered to keys still present in the world.
///
/// Unknown keys (never touched) sort after known ones, in the order they
/// appear in the input — so a freshly-discovered window doesn't jump ahead
/// of windows the user has actually interacted with.
struct MRUOrdering<Key: Hashable> {
    /// Touch sequence numbers — higher = more recent.
    private var sequence: [Key: Int] = [:]
    private var counter: Int = 0

    /// Record that `key` was the focused window/app.
    mutating func touch(_ key: Key) {
        counter += 1
        sequence[key] = counter
    }

    /// Filter and sort `keys` by most-recent-first.
    /// Untouched keys retain their relative input order at the tail.
    func order(among keys: [Key]) -> [Key] {
        let known = keys.filter { sequence[$0] != nil }
        let unknown = keys.filter { sequence[$0] == nil }
        let sortedKnown = known.sorted { (sequence[$0] ?? 0) > (sequence[$1] ?? 0) }
        return sortedKnown + unknown
    }

    /// Seed from an existing ordering (e.g. CGWindowList z-order on first launch).
    /// `keys[0]` is treated as most recent.
    mutating func seed(from keys: [Key]) {
        for key in keys.reversed() { touch(key) }
    }

    /// Drop entries no longer present — call periodically to bound memory.
    mutating func prune(keeping keys: Set<Key>) {
        sequence = sequence.filter { keys.contains($0.key) }
    }
}
