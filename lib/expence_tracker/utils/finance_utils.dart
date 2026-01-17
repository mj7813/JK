class FinanceUtils {
  /// Returns remaining days until next credit card due date
  static int getRemainingDueDays({
    required int dueDay,
  }) {
    final now = DateTime.now();

    DateTime dueDate = DateTime(now.year, now.month, dueDay);

    // If due date already passed, move to next month
    if (dueDate.isBefore(now)) {
      dueDate = DateTime(now.year, now.month + 1, dueDay);
    }

    return dueDate.difference(now).inDays;
  }

  /// Returns formatted due date (for UI)
  static String getNextDueDate({
    required int dueDay,
  }) {
    final now = DateTime.now();

    DateTime dueDate = DateTime(now.year, now.month, dueDay);

    if (dueDate.isBefore(now)) {
      dueDate = DateTime(now.year, now.month + 1, dueDay);
    }

    return "${dueDate.day}-${dueDate.month}-${dueDate.year}";
  }
}
