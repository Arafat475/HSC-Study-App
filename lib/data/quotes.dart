import 'dart:math';

/// Short, playful contextual messages shown for specific situations --
/// not just generic motivational quotes, but reactions tied to what the
/// user just did (set a tiny goal, an enormous goal, broke their streak).
/// Each entry is (bn, en); one is picked at random per occasion so it
/// doesn't feel like the same canned line every time.
class Quotes {
  static final _random = Random();

  static const List<(String, String)> shortGoal = [
    ('৫ মিনিটে দুনিয়া জয় করবে নাকি? 😏', "Conquering the syllabus in 5 minutes? Bold move."),
    ('এটা তো ওয়ার্ম-আপও না, স্ট্রেচিংও না! 🤏', "That's barely a warm-up, let alone a study session."),
    ('তুমি কি সত্যিই এই সময়ে কিছু শিখবে, নাকি শুধু টাইমার দেখবে? ⏱️', "Blink and you'll miss the whole session."),
    ('ছোট লক্ষ্য, ছোট ফলাফল। বড় করে ভাবো! 🎯', "Small goal, small results. Aim a little higher."),
  ];

  static const List<(String, String)> longGoal = [
    ('এত লম্বা সময়? তুমি কি মানুষ নাকি রোবট? 🤖', "That long? Are you human or a robot?"),
    ('বিরতি ছাড়া এত সময় পড়লে মাথা গরম হয়ে যাবে! 🔥', "Studying that long without a break will fry your brain."),
    ('উচ্চাকাঙ্ক্ষা ভালো, কিন্তু নিজের যত্নও নাও 💙', "Ambition is great, but remember to take care of yourself too."),
    ('এত বড় লক্ষ্য রাখছো, মাঝে মাঝে বিরতি নিতে ভুলো না! ☕', "Big goal set — just don't forget to actually take breaks."),
  ];

  static const List<(String, String)> streakBroken = [
    ('ধারাবাহিকতা ভেঙে গেছে... আবার শুরু করো, আজই! 💪', "Your streak broke — no big deal, restart it today."),
    ('গতকাল মিস হয়েছে, তো কী? আজ থেকেই আবার লেগে পড়ো। 🔁', "Yesterday slipped by. Today's a fresh start."),
    ('প্রতিটা নতুন দিন একটা নতুন সুযোগ। শুরু করো! 🌅', "Every new day is a new chance to get back on track."),
    ('একদিন miss করা মানেই সব শেষ না — চালিয়ে যাও! 🚀', "Missing a day doesn't erase your progress — keep going."),
  ];

  static const List<(String, String)> general = [
    ('আজকের পরিশ্রম আগামীকালের ফলাফল। 🌱', "Today's effort is tomorrow's result."),
    ('ছোট ছোট পদক্ষেপই একদিন বড় লক্ষ্যে পৌঁছে দেয়। 👣', "Small steps every day add up to something big."),
    ('তুমি যতটা ভাবছো, তার চেয়ে অনেক বেশি সক্ষম। 💪', "You're capable of more than you think."),
    ('কঠিন সময়গুলোই তোমাকে শক্তিশালী করে তোলে। 🔥', "The hard days are what make you stronger."),
    ('নিজের সাথে প্রতিযোগিতা করো, গতকালের চেয়ে ভালো করো। 📈', "Compete with yesterday's version of yourself."),
    ('একবারে সব শেষ করতে হবে না — ধারাবাহিক থাকো। 🐢', "You don't have to finish it all today — just stay consistent."),
    ('প্রতিটি অধ্যায় শেষ করা মানে লক্ষ্যের আরেকটু কাছে যাওয়া। ✅', "Every chapter you finish is one step closer to your goal."),
    ('বিরতি নেওয়া মানে হাল ছেড়ে দেওয়া নয়। 🌿', "Resting isn't quitting — it's part of the process."),
    ('তোমার ভবিষ্যৎ তুমি আজ যা করছো তার উপর নির্ভর করে। ⏳', "Your future is shaped by what you do today."),
    ('পরীক্ষার নম্বর তোমার মূল্য নির্ধারণ করে না, কিন্তু প্রস্তুতি তোমাকে সাহায্য করবে। 📚', "A score doesn't define you, but preparation will help you."),
    ('আজ যা কঠিন লাগছে, কাল তা সহজ মনে হবে। 🌤️', "What feels hard today will feel easy tomorrow."),
    ('তুমি একা নও — প্রতিটা স্টুডেন্টই এই পথ দিয়ে গেছে। 🤝', "You're not alone — every student has walked this same road."),
  ];

  static (String, String) random(List<(String, String)> category) {
    return category[_random.nextInt(category.length)];
  }

  /// Same quote all day (changes at midnight) rather than a new one on
  /// every rebuild -- for a "quote of the day" style banner.
  static (String, String) ofTheDay() {
    final now = DateTime.now();
    final dayNumber = now.difference(DateTime(2025, 1, 1)).inDays;
    return general[dayNumber % general.length];
  }
}
