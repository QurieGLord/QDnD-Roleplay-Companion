/// Keeps selection order so a new choice replaces the earliest active choice
/// when all places are occupied. Callers still enforce rule eligibility.
Set<T> toggleAdvancementSelection<T>(Set<T> selected, T value, int limit) {
  final next = Set<T>.of(selected);
  if (next.remove(value)) return next;
  if (limit <= 0) return next;
  while (next.length >= limit) {
    next.remove(next.first);
  }
  next.add(value);
  return next;
}
