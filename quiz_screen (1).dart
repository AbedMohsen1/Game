// ignore_for_file: unnecessary_cast, use_build_context_synchronously, deprecated_member_use
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game/ads/banner_ad_view.dart';
import 'package:game/loading_screen.dart';
import 'package:game/screen/Game/sound_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class QuizScreen extends StatefulWidget {
  final String category;

  const QuizScreen({required this.category, super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with WidgetsBindingObserver {
  // ---- نفس ستايل باقي الشاشات ----
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);

  List<Map<String, dynamic>> questions = [];
  List<dynamic> visibleAnswers = [];

  bool isLoading = true;
  bool resumeLoaded = false;
  int currentQuestionIndex = 0;
  int xp = 0;
  int lives = 5;
  DateTime? nextLifeAt; // وقت رجوع "أقرب" فرصة
  Timer? _lifeTicker;
  static const int maxLives = 5;
  static const Duration lifeInterval = Duration(minutes: 2);
  bool _revealCorrect = false;
  int _pausedSeconds = 0;
  void _pauseTimerForAd() {
    if (_timer != null && _timer!.isActive) {
      _pausedSeconds = remainingSeconds;
      _timer?.cancel();
    }
  }

  Future<void> _logCheatAttempt() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'cheatCount': FieldValue.increment(1),
      'lastCheatAt': FieldValue.serverTimestamp(), // اختياري
    }, SetOptions(merge: true));
  }

  void _resumeTimerAfterAd() {
    if (lives <= 0) return;

    remainingSeconds = _pausedSeconds;
    _pausedSeconds = 0;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds <= 0) {
        timer.cancel();
        handleAnswer(false);
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  // الأدوات
  int deleteOne = 0;
  int deleteTwo = 0;
  int solve = 0;
  int addTime = 0;

  String? feedbackText;
  Color? feedbackColor;
  bool showFeedback = false;

  int remainingSeconds = 30;
  Timer? _timer;
  bool _isWatchingAd = false;
  bool _cheatHandled = false;

  // ================== Season (Leaderboard) ==================
  final DocumentReference _seasonRef = FirebaseFirestore.instance
      .collection('settings')
      .doc('leaderboard');

  DateTime? _seasonStart;
  // ==========================================================

  // ================== Rewarded Ad (Video +1) ==================
  RewardedAd? _rewardedAd;
  bool _loadingRewarded = false;

  String get _rewardedUnitId {
    // Test rewarded IDs (Google)
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
    return 'ca-app-pub-3940256099942544/5224354917';
  }
  // ============================================================

  @override
  void initState() {
    super.initState();
    loadInitialData();
    _loadRewardedAd(); // ✅ جهّز فيديو المكافأة من البداية
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> loadInitialData() async {
    // ✅ لو بدأ موسم جديد: صفّر التقدم (لكل الأقسام) وخلي ترتيب الأسئلة يتغير
    await _syncSeasonAndMaybeResetUserProgress();
    await loadXP();
    await fetchQuestions();
    await loadTools();
    await loadLives();

    if (mounted) {
      if (lives > 0) {
        startTimer();
      } else {
        _timer?.cancel();
      }
    }
  }

  // ================== Season Helpers ==================
  Future<DateTime> _getOrCreateSeasonStart() async {
    final snap = await _seasonRef.get();
    final data = snap.data() as Map<String, dynamic>?;
    final ts = data?['seasonStart'];

    if (ts is Timestamp) return ts.toDate();

    // لو ما في موسم (أول مرة) أنشئه
    await _seasonRef.set({
      'seasonStart': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final snap2 = await _seasonRef.get();
    final data2 = snap2.data() as Map<String, dynamic>?;
    final ts2 = data2?['seasonStart'];
    if (ts2 is Timestamp) return ts2.toDate();

    // fallback
    return DateTime.now();
  }

  String _tokenFromSeasonStart(DateTime d) =>
      d.millisecondsSinceEpoch.toString();

  // قائمة كل مفاتيح التقدم (حتى نصفرهم مع بداية أي موسم جديد)
  static const List<String> _allProgressKeys = [
    'islamic_last',
    'math_last',
    'political_last',
    'technology_last',
    'sports_last',
    'economic_last',
    'medical_last',
    'random_general_last',
    'general_last',
  ];

  Future<void> _syncSeasonAndMaybeResetUserProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final seasonStart = await _getOrCreateSeasonStart();
    final currentToken = _tokenFromSeasonStart(seasonStart);

    _seasonStart = seasonStart;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final userSnap = await userRef.get();
    final userData = userSnap.data() ?? {};

    final storedToken = (userData['seasonToken'] ?? '').toString();

    // ✅ موسم جديد → صفّر كل التقدم مرة واحدة فقط
    if (storedToken != currentToken) {
      final resetMap = <String, dynamic>{'seasonToken': currentToken};
      for (final k in _allProgressKeys) {
        resetMap[k] = 0;
      }

      await userRef.set(resetMap, SetOptions(merge: true));

      // كمان محلياً حتى ما يظل يشير لمؤشر قديم
      currentQuestionIndex = 0;
    }
  }

  int _fnv1a32(String input) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811C9DC5;
    for (final c in input.codeUnits) {
      hash ^= c;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    // خليه موجب
    return hash & 0x7FFFFFFF;
  }

  int _seasonShuffleSeed(String uid) {
    final start = _seasonStart ?? DateTime.now();
    final base = '$uid|${widget.category}|${start.millisecondsSinceEpoch}';
    return _fnv1a32(base);
  }
  // ====================================================

  String get progressKey {
    if (widget.category == "دينية") return "islamic_last";
    if (widget.category == "حسابية") return "math_last";
    if (widget.category == "سياسية") return "political_last";
    if (widget.category == "تكنولوجية") return "technology_last";
    if (widget.category == "رياضية") return "sports_last";
    if (widget.category == "اقتصادية") return "economic_last";
    if (widget.category == "طبية") return "medical_last";
    if (widget.category == "عشوائية") return "random_general_last";
    return "general_last";
  }

  Future<void> loadXP() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        xp = data['xp'] ?? 0;
        currentQuestionIndex = data[progressKey] ?? 0;
        resumeLoaded = true;
      });
    } else {
      setState(() => resumeLoaded = true);
    }
  }

  Future<void> _grantLifeFromAd() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ زيد فرصة محلياً
    setState(() {
      lives = (lives + 1).clamp(0, maxLives);

      // لو ما كان في عداد (نادراً) و لسه ناقص عن 5، ابدأه
      if (lives < maxLives && nextLifeAt == null) {
        nextLifeAt = DateTime.now().add(lifeInterval);
      }
    });

    // ✅ خزّن في Firestore
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'lives': lives,
      if (nextLifeAt == null) 'nextLifeAt': FieldValue.delete(),
      if (nextLifeAt != null) 'nextLifeAt': Timestamp.fromDate(nextLifeAt!),
    }, SetOptions(merge: true));

    // ✅ رجّع التايمر لو كان موقف
    if (mounted) startTimer();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("تمت إضافة فرصة  ✅", textAlign: TextAlign.center),
      ),
    );
  }

  Future<void> _showNoLivesDialog() async {
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "انتهت فرصك ❌",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            lifeCountdownText.isNotEmpty
                ? "تقدر تستنى $lifeCountdownText ليرجعلك فرصة، أو شاهد إعلان لتحصل على فرصة فوراً."
                : "تقدر تستنى دقيقتين ليرجعلك فرصة، أو شاهد إعلان لتحصل على فرصة فوراً.",
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("شاهد إعلان +1"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    // ✅ Loading صغير
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "جاري تجهيز الإعلان...",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final rewarded = await _showRewardedAd();

    // سكّر اللودينغ
    if (mounted) Navigator.pop(context);

    if (!rewarded) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "الإعلان غير جاهز الآن، جرّب مرة ثانية.",
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    // ✅ أعطه فرصة
    await _grantLifeFromAd();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // لو خرج من التطبيق
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // ❌ لو كان يشاهد إعلان → مسموح
      if (_isWatchingAd) return;

      // ❌ لو ما في سؤال شغال
      if (_timer == null || !_timer!.isActive) return;

      // منع التكرار
      if (_cheatHandled) return;
      _cheatHandled = true;

      _handleCheat();
    }
  }

  Future<void> _handleCheat() async {
    _timer?.cancel();
    SoundManager.stop();

    await _consumeLife();
    await updateXP(false);
    await _logCheatAttempt();

    if (!mounted) return;

    // ✅ Dialog احترافي بدل SnackBar
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: const [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                "تم اكتشاف غش",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: const Text(
            "لا يمكن الخروج من التطبيق أثناء السؤال.\nتم خصم فرصة واحدة.",
            style: TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("متابعة"),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (lives <= 0) {
      await _showNoLivesDialog();
      return;
    }

    goToNextQuestion();
  }

  Future<void> loadLives() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await docRef.get();
    final data = snap.data() ?? {};

    final storedLives = (data['lives'] ?? maxLives) as int;
    final ts = data['nextLifeAt'];
    final storedNext = (ts is Timestamp) ? ts.toDate() : null;

    lives = storedLives.clamp(0, maxLives);
    nextLifeAt = storedNext;

    // ✅ طبّق التعويض لو مر وقت والبرنامج كان مسكّر
    await _applyLifeRegenAndPersist();

    // ✅ ابدأ مؤقت تحديث العداد
    _startLifeTicker();

    if (mounted) setState(() {});
  }

  void _startLifeTicker() {
    _lifeTicker?.cancel();
    _lifeTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      // إذا وقت الرجوع وصل، رجّع فرص
      if (nextLifeAt != null && DateTime.now().isAfter(nextLifeAt!)) {
        await _applyLifeRegenAndPersist();
      } else {
        setState(() {}); // لتحديث UI للعدّاد (لو بدك تعرضه)
      }
    });
  }

  Future<void> _applyLifeRegenAndPersist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    bool changed = false;

    // لو ناقص فرص ومفيش nextLifeAt لأي سبب، اعمله
    if (lives < maxLives && nextLifeAt == null) {
      nextLifeAt = now.add(lifeInterval);
      changed = true;
    }

    // رجّع فرص طالما الوقت عدى
    while (lives < maxLives &&
        nextLifeAt != null &&
        !now.isBefore(nextLifeAt!)) {
      lives++;
      changed = true;

      if (lives >= maxLives) {
        nextLifeAt = null;
      } else {
        nextLifeAt = nextLifeAt!.add(lifeInterval);
      }
    }

    if (changed) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      await docRef.set({
        'lives': lives,
        if (nextLifeAt == null) 'nextLifeAt': FieldValue.delete(),
        if (nextLifeAt != null) 'nextLifeAt': Timestamp.fromDate(nextLifeAt!),
      }, SetOptions(merge: true));

      // لو كانت 0 وصارت 1، رجّع التايمر وخلي اللعب يرجع
      if (mounted && lives > 0 && (_timer == null || !(_timer!.isActive))) {
        startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("رجعتلك فرصة ✅", textAlign: TextAlign.center),
          ),
        );
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _consumeLife() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (lives <= 0) return;

    final now = DateTime.now();

    setState(() {
      lives--;

      if (lives < maxLives) {
        // ✅ أول ما تنقص من 5 -> ابدأ دقيقة
        if (nextLifeAt == null) {
          nextLifeAt = now.add(lifeInterval);
        } else {
          // ❌ كان عندك هيك (بيأخر أول فرصة غلط):
          // nextLifeAt = nextLifeAt!.add(lifeInterval);

          // ✅ الصحيح: لا تغيّر nextLifeAt لأنها تمثل "أقرب" فرصة راجعة
          // والفرص الثانية بتنحسب تلقائياً بعد ما ترجع الأولى
        }
      }

      if (lives <= 0) {
        _timer?.cancel(); // وقف وقت السؤال لأنه ممنوع يلعب
      }
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'lives': lives,
      if (nextLifeAt == null) 'nextLifeAt': FieldValue.delete(),
      if (nextLifeAt != null) 'nextLifeAt': Timestamp.fromDate(nextLifeAt!),
    }, SetOptions(merge: true));
  }

  String get lifeCountdownText {
    if (lives > 0 || nextLifeAt == null) return "";
    final left = nextLifeAt!.difference(DateTime.now());
    final sec = left.inSeconds.clamp(0, 9999);
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Future<void> saveLives() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'lives': lives,
    }, SetOptions(merge: true));
  }

  Future<void> resetLivesToFive() async {
    lives = 5;
    if (mounted) setState(() {});

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'lives': 5,
    }, SetOptions(merge: true));
  }

  Future<void> loadTools() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        deleteOne = data['tools']?['deleteOne'] ?? 0;
        deleteTwo = data['tools']?['deleteTwo'] ?? 0;
        solve = data['tools']?['solve'] ?? 0;
        addTime = data['tools']?['addTime'] ?? 0;
      });
    }
  }

  Future<void> updateTool(String tool, int value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'tools': {tool: value},
    }, SetOptions(merge: true));
  }

  Future<void> fetchQuestions() async {
    try {
      late String collection;
      if (widget.category == "دينية") {
        collection = 'islamic_questions';
      } else if (widget.category == "حسابية") {
        collection = 'math_questions';
      } else if (widget.category == "سياسية") {
        collection = 'political_questions';
      } else if (widget.category == "تكنولوجية") {
        collection = 'technology_questions';
      } else if (widget.category == "رياضية") {
        collection = 'sports_questions';
      } else if (widget.category == "اقتصادية") {
        collection = 'economic_questions';
      } else if (widget.category == "طبية") {
        collection = 'medical_questions';
      } else if (widget.category == "عشوائية") {
        collection = 'random_general_questions';
      } else {
        throw Exception("تصنيف غير معروف");
      }

      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .get();

      Set<String> seenQuestions =
          <String>{}; // مجموعة لتخزين الأسئلة التي تم رؤيتها
      List<Map<String, dynamic>> uniqueQuestions = []; // قائمة للأسئلة الفريدة

      for (var doc in snapshot.docs) {
        String question = doc['question'];

        if (seenQuestions.contains(question)) {
          // إذا كان السؤال مكررًا، احذفه
          await doc.reference.delete();
        } else {
          // إذا لم يكن مكررًا، أضفه للقائمة
          uniqueQuestions.add(doc.data() as Map<String, dynamic>);
          seenQuestions.add(question);
        }
      }

      // ✅ ترتيب أسئلة ثابت داخل نفس الموسم، ويتغير تلقائياً مع بداية موسم جديد
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        uniqueQuestions.shuffle(Random(_seasonShuffleSeed(user.uid)));
      } else {
        uniqueQuestions.shuffle();
      }

      setState(() {
        questions = uniqueQuestions;
        _revealCorrect = false;

        if (questions.isNotEmpty) {
          if (currentQuestionIndex >= questions.length) {
            currentQuestionIndex = 0;
          }
          visibleAnswers = List.from(
            questions[currentQuestionIndex]['answers'],
          );
        }

        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching questions: $e');
      }
      setState(() => isLoading = false);
    }
  }

  void startTimer() {
    // ✅ لو ما في فرص، ما تشغل التايمر
    if (lives <= 0) {
      _timer?.cancel();
      return;
    }
    _cheatHandled = false;
    _timer?.cancel();
    SoundManager.stop();

    setState(() {
      remainingSeconds = 30;
      _revealCorrect = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds <= 0) {
        timer.cancel();
        handleAnswer(false);
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  Future<void> updateXP(bool isCorrect) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    int newXP = isCorrect ? xp + 1 : xp - 3;
    newXP = newXP.clamp(0, 100);

    setState(() => xp = newXP);

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? {};

    int correct = data['correctAnswers'] ?? 0;
    int wrong = data['wrongAnswers'] ?? 0;

    if (isCorrect) {
      correct++;
    } else {
      wrong++;
    }

    await docRef.set({
      'xp': newXP,
      'correctAnswers': correct,
      'wrongAnswers': wrong,
    }, SetOptions(merge: true));
  }

  Future<void> saveProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      progressKey: currentQuestionIndex,
    }, SetOptions(merge: true));
  }

  void handleAnswer(bool isCorrect) async {
    // ✅ إذا خلصت الفرص لا تسمح بالإجابة
    if (lives <= 0) {
      await _showNoLivesDialog();
      return;
    }

    _timer?.cancel();
    SoundManager.stop();
    setState(() {
      _revealCorrect = true; // ✅ أظهر الإجابة الصحيحة بالأخضر
    });
    if (isCorrect) {
      SoundManager.playWin();

      // ✅ XP +1
      await updateXP(true);
    } else {
      SoundManager.playWrong();

      // ✅ خصم فرصة + تشغيل عداد الدقيقة + حفظ nextLifeAt
      await _consumeLife();

      // ✅ خصم XP -3 (عندك في updateXP)
      await updateXP(false);

      // ✅ لو خلصت الفرص: وقف اللعبة (لا يبدأ من جديد)
      if (lives <= 0) {
        await _showNoLivesDialog();
        return;
      }
    }

    // ✅ في حال لسه في فرص: كمل طبيعي
    setState(() {
      feedbackText = isCorrect ? "إجابة صحيحة 🎉" : "إجابة خاطئة ❌";
      feedbackColor = isCorrect ? _success : _danger;
      showFeedback = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() => showFeedback = false);
    goToNextQuestion();
  }

  void goToNextQuestion() async {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        _revealCorrect = false;
        currentQuestionIndex++;
        visibleAnswers = List.from(questions[currentQuestionIndex]['answers']);
      });
      await saveProgress();
      startTimer();
    } else {
      await saveProgress();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .set({progressKey: 0}, SetOptions(merge: true));

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("انتهى الاختبار"),
          content: Text("إجمالي الخبرة المكتسبة: $xp XP"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("تم"),
            ),
          ],
        ),
      );
    }
  }

  // ======== الأدوات ========
  void useDeleteOneAnswer() {
    if (deleteOne > 0) {
      setState(() {
        final wrongAnswers = visibleAnswers.where((a) => a['t'] != 1).toList();
        if (wrongAnswers.isNotEmpty) {
          visibleAnswers.remove(wrongAnswers.first);
        }
        deleteOne--;
      });
      updateTool("deleteOne", deleteOne);
    }
  }

  void useDeleteTwoAnswers() {
    if (deleteTwo > 0) {
      setState(() {
        final wrongAnswers = visibleAnswers.where((a) => a['t'] != 1).toList();
        for (int i = 0; i < 2 && i < wrongAnswers.length; i++) {
          visibleAnswers.remove(wrongAnswers[i]);
        }
        deleteTwo--;
      });
      updateTool("deleteTwo", deleteTwo);
    }
  }

  void useSolveQuestion() {
    if (solve > 0) {
      solve--;
      updateTool("solve", solve);
      handleAnswer(true);
    }
  }

  void useAddTime() {
    if (addTime > 0) {
      setState(() {
        remainingSeconds += 10;
        if (remainingSeconds > 30) remainingSeconds = 30;
      });
      addTime--;
      updateTool("addTime", addTime);
    }
  }

  // ================== Rewarded Ad Helpers ==================
  void _loadRewardedAd() {
    if (_loadingRewarded) return;
    _loadingRewarded = true;

    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (err) {
          _rewardedAd = null;
          _loadingRewarded = false;
        },
      ),
    );
  }

  Future<bool> _showRewardedAd() async {
    if (_rewardedAd == null) {
      _loadRewardedAd();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("الفيديو غير جاهز الآن، حاول مرة ثانية"),
          duration: Duration(seconds: 1),
        ),
      );
      return false;
    }

    final completer = Completer<bool>();
    bool earned = false;

    // مهم: نربط callbacks قبل show
    _pauseTimerForAd();
    _isWatchingAd = true;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isWatchingAd = false;
        _cheatHandled = false;
        _resumeTimerAfterAd();

        _loadRewardedAd(); // جهّز التالي
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewardedAd = null;
        _isWatchingAd = false;
        _resumeTimerAfterAd();
        _loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        earned = true; // ✅ هون فعلياً انمنحت المكافأة
      },
    );

    return completer.future;
  }

  Future<void> _watchAdForLife() async {
    // لو عنده فرص أصلاً ما بنحتاج إعلان
    if (lives > 0) return;

    // افتح إعلان Rewarded
    final ok = await _showRewardedAd();
    if (!ok || !mounted) return;

    // ✅ أعطه +1 فرصة
    final now = DateTime.now();
    setState(() {
      lives = 1;

      // خلي الريجين مكمل طبيعي (لو ما في nextLifeAt)
      if (nextLifeAt == null && lives < maxLives) {
        nextLifeAt = now.add(lifeInterval);
      }
    });

    // خزّن في Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'lives': lives,
      if (nextLifeAt == null) 'nextLifeAt': FieldValue.delete(),
      if (nextLifeAt != null) 'nextLifeAt': Timestamp.fromDate(nextLifeAt!),
    }, SetOptions(merge: true));

    // ✅ رجّع التايمر للّعب
    startTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("تم إضافة فرصة ✅", textAlign: TextAlign.center),
      ),
    );
  }

  Future<void> _grantTool(String toolKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (toolKey == "deleteOne") deleteOne++;
      if (toolKey == "deleteTwo") deleteTwo++;
      if (toolKey == "solve") solve++;
      if (toolKey == "addTime") addTime++;
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'tools': {toolKey: FieldValue.increment(1)},
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("تم إضافة +1 للأداة ✅", textAlign: TextAlign.center),
        duration: Duration(seconds: 1),
      ),
    );
  }
  // =========================================================

  @override
  void dispose() {
    _timer?.cancel();
    _lifeTicker?.cancel(); // ✅ إضافة
    SoundManager.stop();
    _rewardedAd?.dispose();
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  // ---------- UI Helpers ----------
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _chip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Color _timerColor() {
    if (remainingSeconds <= 10) return _danger;
    if (remainingSeconds <= 18) return _warning;
    return _success;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Builder(
        builder: (_) {
          if (isLoading || !resumeLoaded) {
            return const LoadingScreen();
          }
          if (questions.isEmpty) {
            return const Scaffold(body: Center(child: Text('لا توجد أسئلة')));
          }

          final question = questions[currentQuestionIndex];
          final progress = (currentQuestionIndex + 1) / questions.length;

          return Scaffold(
            appBar: AppBar(
              title: Text(widget.category),
              centerTitle: true,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),

            bottomNavigationBar: Platform.isAndroid
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: const BannerAdView(
                      adUnitId: 'ca-app-pub-5228897328353749/1447751878',
                    ),
                  )
                : null,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      children: [
                        // HUD (XP + progress + timer)
                        _card(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // CircleAvatar(
                              //   radius: 18,
                              //   backgroundColor: _primary.withOpacity(0.12),
                              //   child: const Icon(
                              //     Icons.bolt_rounded,
                              //     color: _primary,
                              //   ),
                              // ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // const Text(
                                        //   "XP",
                                        //   style: TextStyle(
                                        //     color: _textMuted,
                                        //     fontWeight: FontWeight.w900,
                                        //   ),
                                        // ),
                                        // const SizedBox(width: 6),
                                        // Text(
                                        //   "$xp",
                                        //   style: const TextStyle(
                                        //     color: _textDark,
                                        //     fontWeight: FontWeight.w900,
                                        //   ),
                                        // ),
                                        // const Spacer(),
                                        _chip(
                                          "${currentQuestionIndex + 1}/${questions.length}",
                                          Icons.quiz_rounded,
                                          _textMuted,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // ClipRRect(
                                    //   borderRadius: BorderRadius.circular(999),
                                    //   child: LinearProgressIndicator(
                                    //     value: xp / 100,
                                    //     minHeight: 8,
                                    //     backgroundColor: const Color(
                                    //       0xFFF1F5F9,
                                    //     ),
                                    //     valueColor:
                                    //         const AlwaysStoppedAnimation<Color>(
                                    //           _success,
                                    //         ),
                                    //   ),
                                    // ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ), // أصغر
                                decoration: BoxDecoration(
                                  color: _danger.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ), // أصغر
                                  border: Border.all(
                                    color: _danger.withOpacity(0.20),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.favorite,
                                      color: _danger,
                                      size: 16,
                                    ), // أصغر
                                    const SizedBox(width: 4),

                                    Text(
                                      "$lives/5",
                                      style: const TextStyle(
                                        color: _danger,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12.5, // أصغر
                                      ),
                                    ),

                                    // ✅ زر +1 أصغر
                                    // ✅ زر +1 أصغر
                                    if (lives <= 0) ...[
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: _watchAdForLife,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: _danger.withOpacity(0.25),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.play_circle_outline,
                                                size: 14,
                                                color: _danger,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                "+1",
                                                style: TextStyle(
                                                  color: _danger,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ✅ عدّاد رجوع الفرصة (mm:ss)
                                      if (lifeCountdownText.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _danger.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: _danger.withOpacity(0.18),
                                            ),
                                          ),
                                          child: Text(
                                            lifeCountdownText, // مثال: 01:59
                                            style: const TextStyle(
                                              color: _danger,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),

                              // Timer
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _timerColor().withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _timerColor().withOpacity(0.20),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_rounded,
                                      color: _timerColor(),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${remainingSeconds}s",
                                      style: TextStyle(
                                        color: _timerColor(),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Question Card
                        _card(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                question['question'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _textDark,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 7,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        _primary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Answers
                        Expanded(
                          child: ListView.builder(
                            itemCount: visibleAnswers.length,
                            padding: const EdgeInsets.only(bottom: 8),
                            itemBuilder: (context, index) {
                              final a = visibleAnswers[index];
                              final ansText = (a['answer'] ?? '').toString();
                              final isCorrectAnswer = (a['t'] == 1);

                              final highlightCorrect =
                                  _revealCorrect && isCorrectAnswer;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ElevatedButton(
                                  // ✅ اقفل الضغط أثناء إظهار الصحيح
                                  onPressed: (lives > 0 && !_revealCorrect)
                                      ? () => handleAnswer(a['t'] == 1)
                                      : null,

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: highlightCorrect
                                        ? _success.withOpacity(0.12)
                                        : Colors.white,
                                    foregroundColor: highlightCorrect
                                        ? _success
                                        : _textDark,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: highlightCorrect
                                            ? _success
                                            : _border,
                                        width: highlightCorrect ? 1.6 : 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: highlightCorrect
                                            ? _success.withOpacity(0.18)
                                            : _primary.withOpacity(0.10),
                                        child: Text(
                                          String.fromCharCode(0x41 + index),
                                          style: TextStyle(
                                            color: highlightCorrect
                                                ? _success
                                                : _primary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          ansText,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: highlightCorrect
                                                ? _success
                                                : _textDark,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        size: 16,
                                        color: highlightCorrect
                                            ? _success
                                            : _textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Tools bar
                        _card(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _toolPill(
                                  toolKey: "deleteOne", // ✅ مهم
                                  icon: Icons.cancel_rounded,
                                  color: _danger,
                                  tooltip: "حذف إجابة واحدة خاطئة",
                                  count: deleteOne,
                                  onTap: useDeleteOneAnswer,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _toolPill(
                                  toolKey: "deleteTwo", // ✅ مهم
                                  icon: Icons.remove_circle_rounded,
                                  color: _warning,
                                  tooltip: "حذف إجابتين خاطئتين",
                                  count: deleteTwo,
                                  onTap: useDeleteTwoAnswers,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _toolPill(
                                  toolKey: "solve", // ✅ مهم
                                  icon: Icons.check_circle_rounded,
                                  color: _success,
                                  tooltip: "حل السؤال تلقائيًا",
                                  count: solve,
                                  onTap: useSolveQuestion,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _toolPill(
                                  toolKey: "addTime", // ✅ مهم
                                  icon: Icons.timer_rounded,
                                  color: _primary,
                                  tooltip: "إضافة 10 ثواني للوقت",
                                  count: addTime,
                                  onTap: useAddTime,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (showFeedback)
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: (feedbackColor ?? Colors.black54).withOpacity(
                            0.95,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Text(
                          feedbackText ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _toolPill({
    required String toolKey, // ✅ جديد: اسم الأداة في Firestore
    required IconData icon,
    required Color color,
    required String tooltip,
    required int count,
    required VoidCallback onTap,
  }) {
    final enabled = count > 0;

    Future<void> handlePress() async {
      if (enabled) {
        onTap(); // ✅ نفّذ الأداة
        return;
      }

      // ✅ Dialog احترافي لطلب مشاهدة فيديو
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(
                    Icons.play_circle_outline_rounded,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "الأداة غير متوفرة",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            content: const Text(
              "شاهد فيديو قصير لتحصل على +1 لهذه الأداة فوراً.",
              style: TextStyle(color: _textMuted, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("إلغاء"),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text("مشاهدة الفيديو"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (ok != true || !mounted) return;

      // ✅ Loading صغير أثناء فتح الفيديو
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            content: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "جاري تجهيز الفيديو...",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // ✅ شغّل Rewarded Ad
      final rewarded = await _showRewardedAd();

      // سكّر اللودينغ
      if (mounted) Navigator.pop(context);

      if (!rewarded) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("الفيديو غير جاهز الآن، جرّب مرة ثانية."),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }

      // ✅ زِد الأداة +1 محلياً وFirestore
      await _grantTool(toolKey);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تمت إضافة +1 للأداة ✅", textAlign: TextAlign.center),
          duration: Duration(seconds: 1),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => handlePress(),
        child: Opacity(
          opacity: enabled ? 1 : 0.60, // خففنا شوي مش يصير “ميت”
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.16)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),

                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withOpacity(0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      "$count",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: -6,
                  left: -6,
                  child: Tooltip(
                    message: tooltip,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _textMuted.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: _textMuted,
                      ),
                    ),
                  ),
                ),

                // ✅ علامة فيديو صغيرة لما تكون 0 (شكلها احترافي)
                if (!enabled)
                  Positioned(
                    bottom: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.play_circle_outline,
                            size: 14,
                            color: _textMuted,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "فيديو +1",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
