import 'package:flutter_test/flutter_test.dart';
import 'package:undercroft/services/estate_service.dart';

void main() {
  test('parses an enabled annual review schedule', () {
    final status = EstateOwnerReviewStatus.fromRow({
      'last_reviewed_at': '2026-11-13T09:00:00Z',
      'next_reminder_at': '2027-11-13T09:00:00Z',
      'reminders_enabled': true,
    });

    expect(status.lastReviewedAt, DateTime.utc(2026, 11, 13, 9));
    expect(status.nextReminderAt, DateTime.utc(2027, 11, 13, 9));
    expect(status.remindersEnabled, isTrue);
  });

  test('supports owners who have not confirmed a review yet', () {
    final status = EstateOwnerReviewStatus.fromRow({
      'last_reviewed_at': null,
      'next_reminder_at': '2027-11-13T09:00:00Z',
      'reminders_enabled': false,
    });

    expect(status.lastReviewedAt, isNull);
    expect(status.remindersEnabled, isFalse);
  });
}
