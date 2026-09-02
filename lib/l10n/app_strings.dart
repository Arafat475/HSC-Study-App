/// Lightweight bilingual string table -- not full Flutter intl/ARB, just a
/// simple key -> {bn, en} map, since the app only needs two languages.
class AppStrings {
  static const Map<String, Map<String, String>> _strings = {
    // Nav
    'nav_timer': {'bn': 'টাইমার', 'en': 'Timer'},
    'nav_routine': {'bn': 'রুটিন', 'en': 'Routine'},
    'nav_progress': {'bn': 'অগ্রগতি', 'en': 'Progress'},
    'nav_analytics': {'bn': 'অ্যানালিটিক্স', 'en': 'Analytics'},

    // Timer screen
    'study_timer': {'bn': 'স্টাডি টাইমার', 'en': 'STUDY TIMER'},
    'study': {'bn': 'পড়া', 'en': 'Study'},
    'revision': {'bn': 'রিভিশন', 'en': 'Revision'},
    'subject': {'bn': 'বিষয়', 'en': 'Subject'},
    'chapter': {'bn': 'অধ্যায়', 'en': 'Chapter'},
    'no_specific_chapter': {'bn': 'নির্দিষ্ট অধ্যায় নেই', 'en': 'No specific chapter'},
    'goal': {'bn': 'লক্ষ্য', 'en': 'Goal'},
    'none': {'bn': 'নেই', 'en': 'None'},
    'custom': {'bn': 'কাস্টম', 'en': 'Custom'},
    'ready': {'bn': 'প্রস্তুত', 'en': 'READY'},
    'studying': {'bn': 'পড়া চলছে', 'en': 'STUDYING'},
    'start': {'bn': 'শুরু', 'en': 'Start'},
    'pause': {'bn': 'বিরতি', 'en': 'Pause'},
    'stop_save': {'bn': 'থামান ও সংরক্ষণ', 'en': 'Stop & save'},
    'alert_settings': {'bn': 'অ্যালার্ট সেটিংস', 'en': 'Alert Settings'},
    'sound_alert': {'bn': 'সাউন্ড অ্যালার্ট', 'en': 'Sound Alert'},
    'vibration_alert': {'bn': 'ভাইব্রেশন অ্যালার্ট', 'en': 'Vibration Alert'},
    'set_exam_date': {'bn': 'পরীক্ষার তারিখ সেট করুন', 'en': 'Set your exam date'},
    'days': {'bn': 'দিন', 'en': 'DAYS'},
    'hours': {'bn': 'ঘণ্টা', 'en': 'HRS'},
    'minutes': {'bn': 'মিনিট', 'en': 'MINS'},
    'seconds': {'bn': 'সেকেন্ড', 'en': 'SECS'},

    // Routine screen
    'daily_routine': {'bn': 'দৈনিক রুটিন', 'en': 'Daily routine'},
    'add_task': {'bn': 'কাজ যোগ করুন', 'en': 'Add task'},
    'today': {'bn': 'আজ', 'en': 'Today'},
    'new_task': {'bn': 'নতুন কাজ', 'en': 'New task'},

    // Progress / Subjects screen
    'syllabus': {'bn': 'সিলেবাস', 'en': 'Syllabus'},
    'completed': {'bn': 'সম্পন্ন', 'en': 'Completed'},
    'remaining': {'bn': 'বাকি', 'en': 'Remaining'},
    'chapter_studied': {'bn': 'অধ্যায় পড়া হয়েছে', 'en': 'Chapter studied'},
    'revision_done': {'bn': 'রিভিশন সম্পন্ন', 'en': 'Revision done'},

    // Analytics
    'analytics': {'bn': 'অ্যানালিটিক্স', 'en': 'Analytics'},
    'daily': {'bn': 'দৈনিক', 'en': 'Daily'},
    'weekly': {'bn': 'সাপ্তাহিক', 'en': 'Weekly'},
    'monthly': {'bn': 'মাসিক', 'en': 'Monthly'},
    'total_study_time': {'bn': 'মোট পড়ার সময়', 'en': 'Total study time'},
    'time_by_subject': {'bn': 'বিষয়ভিত্তিক সময়', 'en': 'Time by subject'},

    // Language
    'language': {'bn': 'ভাষা', 'en': 'Language'},
    'bangla': {'bn': 'বাংলা', 'en': 'Bangla'},
    'english': {'bn': 'ইংরেজি', 'en': 'English'},
  };

  static String t(String key, String locale) {
    return _strings[key]?[locale] ?? _strings[key]?['en'] ?? key;
  }
}
