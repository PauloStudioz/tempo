import 'package:intl/intl.dart';

class DateFormatter {
  static final _monthDayFormat = DateFormat('MMM d');
  static final _hourMinuteFormat = DateFormat('HH:mm');
  static final _fullDateFormat = DateFormat('EEE, MMM d, yyyy');
  static final _weekdayFormat = DateFormat('EEE');

  static String formatMonthDay(DateTime? date) {
    if (date == null) return '';
    return _monthDayFormat.format(date);
  }

  static String formatWeekday(DateTime date) {
    return _weekdayFormat.format(date);
  }

  static String formatTime(DateTime time) {
    return _hourMinuteFormat.format(time);
  }

  static String formatFullDate(DateTime date) {
    return _fullDateFormat.format(date);
  }

  static String formatRange(DateTime start, DateTime end) {
    return '${formatTime(start)} - ${formatTime(end)}';
  }
}

