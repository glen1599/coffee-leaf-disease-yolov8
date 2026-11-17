/// Dates and numbers written the Indonesian way, without a locale database.
library;

const _months = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _two(int value) => value.toString().padLeft(2, '0');

DateTime _dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// Whole days from [from] to [to], counting calendar days, not 24-hour spans.
int calendarDaysBetween(DateTime from, DateTime to) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

/// `09.12`: Indonesian clock time uses a full stop.
String formatClock(DateTime moment) =>
    '${_two(moment.hour)}.${_two(moment.minute)}';

/// `24 November`, with the year only when it is not the year of [now].
String formatDate(DateTime date, {required DateTime now}) {
  final text = '${date.day} ${_months[date.month - 1]}';
  return date.year == now.year ? text : '$text ${date.year}';
}

/// `Hari ini`, `Kemarin`, or the date.
String formatDay(DateTime date, {required DateTime now}) =>
    switch (calendarDaysBetween(date, now)) {
      0 => 'Hari ini',
      1 => 'Kemarin',
      _ => formatDate(date, now: now),
    };

/// `Hari ini, 09.12`.
String formatDayAndClock(DateTime moment, {required DateTime now}) =>
    '${formatDay(moment, now: now)}, ${formatClock(moment)}';

/// `24 November, pukul 07.00`.
String formatDateAndClock(DateTime moment, {required DateTime now}) =>
    '${formatDate(moment, now: now)}, pukul ${formatClock(moment)}';

/// `86%`, or `96,99%` with [decimals]: Indonesian uses a decimal comma.
String formatPercent(double value, {int decimals = 0}) =>
    '${value.toStringAsFixed(decimals).replaceAll('.', ',')}%';

/// 07.00 on the day [days] days after [from], when a reminder should fire.
DateTime reminderMoment(DateTime from, int days) {
  final day = _dayOf(from);
  return DateTime(day.year, day.month, day.day + days, 7);
}
