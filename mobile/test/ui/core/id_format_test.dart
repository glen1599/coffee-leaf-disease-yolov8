import 'package:cek_daun_kopi/ui/core/format/id_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 17, 9, 12);

  test('clock time uses a full stop and two digits', () {
    expect(formatClock(DateTime(2026, 11, 17, 9, 5)), '09.05');
    expect(formatClock(DateTime(2026, 11, 17, 16, 30)), '16.30');
  });

  test('dates name the month and mention the year only when it differs', () {
    expect(formatDate(DateTime(2026, 11, 24), now: now), '24 November');
    expect(formatDate(DateTime(2025, 8, 3), now: now), '3 Agustus 2025');
  });

  test('today and yesterday are named, older days are dated', () {
    expect(formatDay(DateTime(2026, 11, 17, 0, 1), now: now), 'Hari ini');
    expect(formatDay(DateTime(2026, 11, 16, 23, 59), now: now), 'Kemarin');
    expect(formatDay(DateTime(2026, 11, 15, 12), now: now), '15 November');
    expect(formatDayAndClock(now, now: now), 'Hari ini, 09.12');
  });

  test('calendar days ignore the time of day', () {
    expect(
      calendarDaysBetween(
        DateTime(2026, 11, 16, 23, 59),
        DateTime(2026, 11, 17),
      ),
      1,
    );
    expect(
      calendarDaysBetween(
        DateTime(2026, 11, 17, 1),
        DateTime(2026, 11, 17, 23),
      ),
      0,
    );
  });

  test('percentages use a decimal comma', () {
    expect(formatPercent(86.3), '86%');
    expect(formatPercent(96.99, decimals: 2), '96,99%');
  });

  test('a reminder fires at seven in the morning, days later', () {
    expect(reminderMoment(now, 7), DateTime(2026, 11, 24, 7));
    // Crossing the end of a month.
    expect(
      reminderMoment(DateTime(2026, 11, 28, 22), 3),
      DateTime(2026, 12, 1, 7),
    );
    expect(
      formatDateAndClock(reminderMoment(now, 7), now: now),
      '24 November, pukul 07.00',
    );
  });
}
