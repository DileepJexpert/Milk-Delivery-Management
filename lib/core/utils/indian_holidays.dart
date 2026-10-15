/// Hardcoded list of major Indian holidays that warrant auto-pause for milk
/// delivery — covers fixed-date national holidays plus the biggest
/// religious ones for 2024–2027. A real production app would back this with
/// a per-region calendar, but a static map keeps the offline-first guarantee.
class IndianHolidays {
  static const Map<String, String> _holidays = {
    // 2024
    '2024-01-26': 'Republic Day',
    '2024-03-25': 'Holi',
    '2024-04-10': 'Eid al-Fitr',
    '2024-08-15': 'Independence Day',
    '2024-08-26': 'Janmashtami',
    '2024-10-12': 'Dussehra',
    '2024-10-31': 'Diwali',
    '2024-11-01': 'Govardhan Puja',
    '2024-12-25': 'Christmas',

    // 2025
    '2025-01-26': 'Republic Day',
    '2025-03-14': 'Holi',
    '2025-03-31': 'Eid al-Fitr',
    '2025-08-15': 'Independence Day',
    '2025-08-16': 'Janmashtami',
    '2025-10-02': 'Dussehra',
    '2025-10-20': 'Diwali',
    '2025-10-21': 'Govardhan Puja',
    '2025-12-25': 'Christmas',

    // 2026
    '2026-01-26': 'Republic Day',
    '2026-03-04': 'Holi',
    '2026-03-20': 'Eid al-Fitr',
    '2026-08-15': 'Independence Day',
    '2026-09-05': 'Janmashtami',
    '2026-09-21': 'Dussehra',
    '2026-11-09': 'Diwali',
    '2026-11-10': 'Govardhan Puja',
    '2026-12-25': 'Christmas',

    // 2027
    '2027-01-26': 'Republic Day',
    '2027-03-22': 'Holi',
    '2027-08-15': 'Independence Day',
    '2027-10-29': 'Diwali',
    '2027-12-25': 'Christmas',
  };

  static bool isHoliday(String dateKey) => _holidays.containsKey(dateKey);

  static String? nameFor(String dateKey) => _holidays[dateKey];

  /// All holidays in `[from, to]` (both inclusive, yyyy-MM-dd compare).
  static List<MapEntry<String, String>> between(String from, String to) {
    return _holidays.entries
        .where((e) => e.key.compareTo(from) >= 0 && e.key.compareTo(to) <= 0)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }
}
