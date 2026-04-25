import 'package:flutter/material.dart';

/// Hand-rolled localization (no codegen) for English + Hindi.
class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const _strings = <String, Map<String, String>>{
    'en': {
      'app_title': 'Milk Delivery',
      'login_title': 'Sign in',
      'phone_hint': 'Phone number',
      'send_otp': 'Send OTP',
      'otp_hint': 'Enter OTP (123456)',
      'verify': 'Verify',
      'select_role': 'Continue as',
      'role_milkman': 'Milkman',
      'role_subscriber': 'Subscriber',
      'name_hint': 'Your name',
      'milkman_home': 'Today\'s Route',
      'societies': 'Societies',
      'inbox': 'Inbox',
      'billing': 'Billing',
      'add_society': 'Add Society',
      'society_name': 'Society name',
      'society_address': 'Address',
      'add_flat': 'Add Flat',
      'flat_number': 'Flat number',
      'owner_name': 'Owner name',
      'owner_phone': 'Owner phone',
      'has_app': 'Subscriber has the app',
      'default_quantity': 'Default daily quantity (L)',
      'price_per_litre': 'Price per litre',
      'delivered': 'Delivered',
      'skipped': 'Skipped',
      'paused': 'Paused',
      'custom': 'Custom',
      'mark_delivered': 'Mark Delivered',
      'mark_custom': 'Custom Qty',
      'mark_skipped': 'Skip',
      'change_qty_dialog': 'Quantity (litres)',
      'reason_optional': 'Reason (optional)',
      'save': 'Save',
      'cancel': 'Cancel',
      'whatsapp_notify': 'Notify via WhatsApp',
      'change_requests': 'Change Requests',
      'no_requests': 'No pending requests.',
      'apply': 'Apply',
      'subscriber_today': 'Today',
      'subscriber_history': 'History',
      'subscriber_bill': 'My Bill',
      'pause_today': 'Pause today',
      'pause_tomorrow': 'Pause tomorrow',
      'pause_range': 'Pause date range',
      'change_quantity': 'Change quantity',
      'litres': 'L',
      'total_litres': 'Total litres',
      'total_amount': 'Total amount',
      'days_skipped': 'Days skipped',
      'days_custom': 'Days with custom qty',
      'export_pdf': 'Export PDF',
      'share': 'Share',
      'audit_log': 'Audit log',
      'no_flats': 'No flats yet. Tap + to add one.',
      'no_societies': 'No societies yet. Tap + to add one.',
      'logout': 'Logout',
      'language': 'Language',
      'pending': 'Pending',
      'applied': 'Applied',
      'pause': 'Pause',
      'quantity_change': 'Quantity change',
      'from': 'From',
      'to': 'To',
      'select_dates': 'Select dates',
      'request_submitted': 'Request submitted',
      'no_history': 'No deliveries yet.',
      'monthly_summary': 'Monthly Summary',
      'flat_detail': 'Flat detail',
      'logged_in_as': 'Signed in as',
      'unlinked_subscriber': 'No flat linked yet. Ask your milkman to register your flat with this phone number.',
      'today_label': 'Today',
      'yesterday_label': 'Yesterday',
      'no_deliveries_today': 'No deliveries scheduled for today.',
      'qty_label': 'Qty',
      'mark_all_done': 'Mark all default',
      'old': 'Old',
      'new': 'New',
      'by': 'By',
    },
    'hi': {
      'app_title': 'दूध डिलीवरी',
      'login_title': 'साइन इन करें',
      'phone_hint': 'फ़ोन नंबर',
      'send_otp': 'OTP भेजें',
      'otp_hint': 'OTP दर्ज करें (123456)',
      'verify': 'सत्यापित करें',
      'select_role': 'जारी रखें',
      'role_milkman': 'दूधवाला',
      'role_subscriber': 'ग्राहक',
      'name_hint': 'आपका नाम',
      'milkman_home': 'आज का रूट',
      'societies': 'सोसाइटी',
      'inbox': 'इनबॉक्स',
      'billing': 'बिल',
      'add_society': 'सोसाइटी जोड़ें',
      'society_name': 'सोसाइटी का नाम',
      'society_address': 'पता',
      'add_flat': 'फ्लैट जोड़ें',
      'flat_number': 'फ्लैट नंबर',
      'owner_name': 'मालिक का नाम',
      'owner_phone': 'मालिक का फ़ोन',
      'has_app': 'ग्राहक के पास ऐप है',
      'default_quantity': 'रोज़ की डिफ़ॉल्ट मात्रा (लीटर)',
      'price_per_litre': 'प्रति लीटर मूल्य',
      'delivered': 'डिलीवर हुआ',
      'skipped': 'छोड़ा गया',
      'paused': 'रुका हुआ',
      'custom': 'अलग मात्रा',
      'mark_delivered': 'डिलीवर्ड',
      'mark_custom': 'अलग मात्रा',
      'mark_skipped': 'छोड़ें',
      'change_qty_dialog': 'मात्रा (लीटर)',
      'reason_optional': 'कारण (वैकल्पिक)',
      'save': 'सेव करें',
      'cancel': 'रद्द करें',
      'whatsapp_notify': 'WhatsApp पर सूचित करें',
      'change_requests': 'बदलाव अनुरोध',
      'no_requests': 'कोई अनुरोध नहीं है।',
      'apply': 'लागू करें',
      'subscriber_today': 'आज',
      'subscriber_history': 'इतिहास',
      'subscriber_bill': 'मेरा बिल',
      'pause_today': 'आज रोकें',
      'pause_tomorrow': 'कल रोकें',
      'pause_range': 'तारीख़ रेंज में रोकें',
      'change_quantity': 'मात्रा बदलें',
      'litres': 'ली',
      'total_litres': 'कुल लीटर',
      'total_amount': 'कुल राशि',
      'days_skipped': 'छोड़े गए दिन',
      'days_custom': 'अलग मात्रा वाले दिन',
      'export_pdf': 'PDF एक्सपोर्ट',
      'share': 'शेयर',
      'audit_log': 'ऑडिट लॉग',
      'no_flats': 'अभी कोई फ्लैट नहीं। + दबाकर जोड़ें।',
      'no_societies': 'अभी कोई सोसाइटी नहीं। + दबाकर जोड़ें।',
      'logout': 'लॉगआउट',
      'language': 'भाषा',
      'pending': 'लंबित',
      'applied': 'लागू',
      'pause': 'रोकें',
      'quantity_change': 'मात्रा बदलाव',
      'from': 'से',
      'to': 'तक',
      'select_dates': 'तारीख़ चुनें',
      'request_submitted': 'अनुरोध भेजा गया',
      'no_history': 'अभी कोई डिलीवरी नहीं।',
      'monthly_summary': 'महीने का सारांश',
      'flat_detail': 'फ्लैट विवरण',
      'logged_in_as': 'साइन इन',
      'unlinked_subscriber': 'अभी कोई फ्लैट लिंक नहीं है। कृपया अपने दूधवाले से इस नंबर पर फ्लैट रजिस्टर कराएँ।',
      'today_label': 'आज',
      'yesterday_label': 'कल',
      'no_deliveries_today': 'आज कोई डिलीवरी नहीं है।',
      'qty_label': 'मात्रा',
      'mark_all_done': 'सब डिफ़ॉल्ट मार्क करें',
      'old': 'पुराना',
      'new': 'नया',
      'by': 'द्वारा',
    },
  };

  String t(String key) => _strings[locale.languageCode]?[key] ?? key;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocExt on BuildContext {
  String tr(String key) => AppLocalizations.of(this).t(key);
}
