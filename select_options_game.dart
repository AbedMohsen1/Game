// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:game/ads/banner_ad_view.dart';
import 'package:game/loading_screen.dart';
import 'package:game/screen/home/quiz_screen.dart';

class SelectOptionsGame extends StatefulWidget {
  const SelectOptionsGame({super.key});

  @override
  State<SelectOptionsGame> createState() => _SelectOptionsGameState();
}

class _SelectOptionsGameState extends State<SelectOptionsGame> {
  // --- نفس ستايل باقي الشاشات ---
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _warning = Color(0xFFF59E0B);

  List<String> categories = [];
  bool isLoading = true;
  Map<String, String> categoryBackgrounds = {};
  // لمنع فتح دايلوج أكثر من مرة لنفس الداتا
  bool _unlockDialogShowing = false;

  @override
  void initState() {
    super.initState();
    fetchOptions();
  }

  List<String> orderByUnlockedFirst({
    required List<String> orderedCategories,
    required List<String> unlockedCategories,
  }) {
    final unlockedSet = unlockedCategories.map(_norm).toSet();

    final hasRandom = orderedCategories.any((c) => _norm(c) == "عشوائية");
    final rest = orderedCategories.where((c) => _norm(c) != "عشوائية").toList();

    final unlocked = <String>[];
    final locked = <String>[];

    for (final c in rest) {
      if (unlockedSet.contains(_norm(c))) {
        unlocked.add(c);
      } else {
        locked.add(c);
      }
    }

    return [if (hasRandom) "عشوائية", ...unlocked, ...locked];
  }

  // final Map<String, String?> _bgUrlCache = {};
  String _norm(String s) {
    return s
        .replaceAll('\u200f', '') // RTL mark
        .replaceAll('\u200e', '') // LTR mark
        .replaceAll('\u202a', '')
        .replaceAll('\u202b', '')
        .replaceAll('\u202c', '')
        .trim();
  }

  Future<String?> _getBgUrl(String category) async {
    final key = _norm(category);

    // ✅ lookup ذكي: قارن بعد التنظيف
    String? path;
    for (final entry in categoryBackgrounds.entries) {
      if (_norm(entry.key) == key) {
        path = _norm(entry.value);
        break;
      }
    }

    debugPrint('BG key="$key" path="$path"');

    if (path == null || path.isEmpty) return null;

    try {
      return await FirebaseStorage.instance.ref(path).getDownloadURL();
    } catch (e) {
      debugPrint('BG ERROR key="$key" path="$path" => $e');
      return null;
    }
  }

  Future<void> fetchOptions() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('options')
          .get();

      final data = doc.data();
      if (data == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final list = List<String>.from(data['categories'] ?? []);

      final rawBg = data['categoryBackgrounds'];
      final Map<String, dynamic> bgDynamic = (rawBg is Map)
          ? Map<String, dynamic>.from(rawBg)
          : {};

      String clean(String s) => s.trim().replaceAll('"', '');

      final bgMap = <String, String>{};
      bgDynamic.forEach((k, v) {
        final key = clean(k);
        final val = clean('$v');
        if (key.isNotEmpty && val.isNotEmpty) bgMap[key] = val;
      });

      debugPrint('BG MAP keys cleaned: ${bgMap.keys.toList()}');

      if (!mounted) return;
      setState(() {
        categories = list.map((e) => clean(e)).toList();
        categoryBackgrounds = bgMap;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('fetchOptions error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<String> getUnlockedCategoriesFromUserDoc(Map<String, dynamic> userData) {
    final raw = userData['unlockedCategories'];
    final list = <String>[];

    if (raw is List) {
      for (final item in raw) {
        if (item != null) list.add(_norm(item.toString()));
      }
    }

    // عشوائية دائماً موجودة
    if (!list.map(_norm).contains("عشوائية")) list.insert(0, "عشوائية");
    // إزالة تكرارات مع الحفاظ على الترتيب
    final seen = <String>{};
    final unique = <String>[];
    for (final c in list) {
      final t = _norm(c);
      if (t.isEmpty) continue;
      if (seen.add(t)) unique.add(t);
    }
    return unique;
  }

  int _asInt(dynamic v, [int fallback = 1]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  /// ترتيب العرض في الواجهة:
  /// - عشوائية أولاً (إذا موجودة في Firestore)
  /// - ثم باقي التصنيفات حسب ترتيبها في Firestore
  List<String> getOrderedCategoriesForUI() {
    if (categories.isEmpty) return [];

    final clean = categories.map(_norm).toList();

    final other = clean.where((c) => c != "عشوائية").toList();
    final hasRandom = clean.any((c) => c == "عشوائية");

    return [if (hasRandom) "عشوائية", ...other];
  }

  /// التصنيفات التي يمكن اختيارها الآن للفتح (غير مفتوحة + ليست عشوائية)
  List<String> _availableToUnlock(
    List<String> orderedCategories,
    List<String> unlockedCategories,
  ) {
    final unlockedSet = unlockedCategories.map(_norm).toSet();
    return orderedCategories
        .where((c) => _norm(c) != "عشوائية" && !unlockedSet.contains(_norm(c)))
        .toList();
  }

  /// هل المستخدم يحتاج يختار فتح تصنيف جديد؟
  bool _needsUnlockSelection({
    required int level,
    required int lastUnlockLevel,
    required List<String> unlockedCategories,
  }) {
    // المسموح (مع عشوائية) = level
    // مثال: level 1 => 1 عنصر (عشوائية)
    // level 2 => 2 عناصر ...
    final allowed = level.clamp(1, 999999);

    // إذا كان عنده أقل من المسموح => لازم يختار
    final needCount = unlockedCategories.length < allowed;

    // كمان نستخدم lastUnlockLevel كحماية إضافية (اختياري)
    // إذا lastUnlockLevel >= level غالباً يعني أنه اختار لهذا المستوى
    final notDoneForThisLevel = lastUnlockLevel < level;

    return needCount && notDoneForThisLevel;
  }

  Future<void> _showUnlockDialog({
    required BuildContext context,
    required User user,
    required int userLevel,
    required int lastUnlockLevel,
    required List<String> orderedCategories,
    required List<String> unlockedCategories,
  }) async {
    if (_unlockDialogShowing) return;

    final available = _availableToUnlock(orderedCategories, unlockedCategories);
    if (available.isEmpty) return;

    _unlockDialogShowing = true;

    String? selected;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _border.withOpacity(0.9)),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              _primary.withOpacity(0.12),
                              const Color(0xFFEFF6FF),
                            ],
                          ),
                          border: Border(
                            bottom: BorderSide(color: _border.withOpacity(0.8)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _primary.withOpacity(0.18),
                                ),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "مبروك! فتحت اختيار جديد",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: _textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "أنت الآن Level $userLevel — اختر تصنيف واحد لفتحه",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _textMuted.withOpacity(0.95),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: "إغلاق",
                              onPressed: () {
                                // ممنوع الإغلاق بدون اختيار (حسب طلبك) — إذا بدك تسمح، شيل return
                                // Navigator.pop(ctx);
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                color: _textMuted.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Body list
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(10),
                              itemCount: available.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final c = available[i];
                                final isSelected =
                                    selected != null &&
                                    _norm(selected!) == _norm(c);

                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setLocal(() => selected = c),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _primary.withOpacity(0.10)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? _primary.withOpacity(0.35)
                                            : _border.withOpacity(0.9),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(
                                            isSelected ? 0.06 : 0.03,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color:
                                                (isSelected
                                                        ? _primary
                                                        : _textMuted)
                                                    .withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            _iconForCategory(c),
                                            color: isSelected
                                                ? _primary
                                                : _textMuted,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            c,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14.5,
                                              color: isSelected
                                                  ? _textDark
                                                  : _textDark.withOpacity(0.92),
                                            ),
                                          ),
                                        ),
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _primary
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? _primary
                                                  : _border,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Footer buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    null, // خليها null إذا بدك تمنع الإلغاء
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: BorderSide(color: _border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  "لاحقًا",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _textMuted.withOpacity(0.65),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: selected == null
                                    ? null
                                    : () async {
                                        final docRef = FirebaseFirestore
                                            .instance
                                            .collection('users')
                                            .doc(user.uid);

                                        await docRef.set({
                                          'unlockedCategories':
                                              FieldValue.arrayUnion([
                                                _norm(selected!),
                                              ]),
                                          'lastUnlockLevel': userLevel,
                                        }, SetOptions(merge: true));

                                        if (ctx.mounted) Navigator.pop(ctx);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_open_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      "فتح الآن",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    _unlockDialogShowing = false;
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

  Widget _categoryTile({required String category, required bool isUnlocked}) {
    final statusText = isUnlocked ? "جاهز للعب" : "مقفل — ارفع مستواك لفتحه";
    final statusColor = isUnlocked
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (!isUnlocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "هذا النوع مقفل — ارفع مستواك لفتحه",
                textAlign: TextAlign.center,
              ),
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuizScreen(category: category)),
        );
      },
      child: Container(
        height: 82,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // ===== مربع الصورة (الصورة كاملة بدون قص) =====
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primary.withOpacity(0.12)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FutureBuilder<String?>(
                  future: _getBgUrl(category),
                  builder: (context, snap) {
                    final url = snap.data;
                    if (url == null || url.isEmpty) {
                      return Icon(
                        _iconForCategory(category),
                        color: _primary,
                        size: 28,
                      );
                    }

                    // ✅ contain => الصورة كلها بتظهر
                    return Image.network(
                      url,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, _, _) => Icon(
                        _iconForCategory(category),
                        color: _primary,
                        size: 28,
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ===== النصوص =====
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 7),

                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w700,
                            color: _textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ===== يمين: زر صغير (Play/Lock) =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (isUnlocked ? _primary : _textMuted).withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: (isUnlocked ? _primary : _textMuted).withOpacity(0.16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUnlocked ? Icons.play_arrow_rounded : Icons.lock_rounded,
                    size: 18,
                    color: isUnlocked ? _primary : _textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isUnlocked ? "ابدأ" : "مقفل",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: isUnlocked ? _primary : _textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  IconData _iconForCategory(String c) {
    final s = c.toLowerCase();
    if (s.contains('اسلام') || s.contains('دين')) return Icons.mosque_rounded;
    if (s.contains('رياض') || s.contains('sport')) {
      return Icons.sports_soccer_rounded;
    }
    if (s.contains('تاريخ')) return Icons.history_edu_rounded;
    if (s.contains('جغراف')) return Icons.public_rounded;
    if (s.contains('تقن') || s.contains('برمج')) return Icons.memory_rounded;
    if (s.contains('عشو')) return Icons.shuffle_rounded;
    return Icons.quiz_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("اختر نوع الأسئلة"),
          centerTitle: true,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: const BannerAdView(
            adUnitId: 'ca-app-pub-5228897328353749/1447751878',
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
            ),
          ),
          child: isLoading || user == null
              ? const Center(child: LoadingScreen())
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(
                        child: Text("جاري تحميل البيانات..."),
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final int userLevel = _asInt(data['level'], 1);
                    final int lastUnlockLevel = _asInt(
                      data['lastUnlockLevel'],
                      0,
                    );

                    final unlockedCategories = getUnlockedCategoriesFromUserDoc(
                      data,
                    );

                    final orderedCategories = orderByUnlockedFirst(
                      orderedCategories: getOrderedCategoriesForUI(),
                      unlockedCategories: unlockedCategories,
                    );
                    final unlockedSet = unlockedCategories.map(_norm).toSet();

                    // إذا يحتاج اختيار فتح جديد: اعرض الديالوج بعد بناء الفريم
                    final needUnlock = _needsUnlockSelection(
                      level: userLevel,
                      lastUnlockLevel: lastUnlockLevel,
                      unlockedCategories: unlockedCategories,
                    );

                    if (needUnlock &&
                        orderedCategories.isNotEmpty &&
                        !_unlockDialogShowing) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _showUnlockDialog(
                          context: context,
                          user: user,
                          userLevel: userLevel,
                          lastUnlockLevel: lastUnlockLevel,
                          orderedCategories: orderedCategories,
                          unlockedCategories: unlockedCategories,
                        );
                      });
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _card(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: _primary.withOpacity(0.12),
                                  child: const Icon(
                                    Icons.star_rounded,
                                    color: _primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "مستواك الحالي: Level $userLevel",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: _textDark,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "اختر تصنيف مفتوح أو ارفع المستوى لفتح المزيد",
                                        style: TextStyle(
                                          color: _textMuted.withOpacity(0.95),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _chip(
                                  "${unlockedCategories.length} مفتوح",
                                  Icons.lock_open_rounded,
                                  _warning,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: orderedCategories.isEmpty
                                ? const Center(
                                    child: Text("لا توجد تصنيفات حالياً"),
                                  )
                                // : GridView.builder(
                                //     itemCount: orderedCategories.length,
                                //     gridDelegate:
                                //         const SliverGridDelegateWithFixedCrossAxisCount(
                                //           crossAxisCount: 2,
                                //           crossAxisSpacing: 12,
                                //           mainAxisSpacing: 12,
                                //           childAspectRatio: 1.25,
                                //         ),
                                //     itemBuilder: (context, index) {
                                //       final category = orderedCategories[index];
                                //       final isUnlocked = unlockedCategories
                                //           .contains(category);
                                //       return InkWell(
                                //         borderRadius: BorderRadius.circular(16),
                                //         onTap: () {
                                //           if (!isUnlocked) {
                                //             ScaffoldMessenger.of(
                                //               context,
                                //             ).showSnackBar(
                                //               const SnackBar(
                                //                 content: Text(
                                //                   'هذا النوع مقفل. افتحه بالوصول إلى مستوى أعلى!',
                                //                   textAlign: TextAlign.center,
                                //                 ),
                                //               ),
                                //             );
                                //             return;
                                //           }
                                //           Navigator.push(
                                //             context,
                                //             MaterialPageRoute(
                                //               builder: (_) => QuizScreen(
                                //                 category: category,
                                //               ),
                                //             ),
                                //           );
                                //         },
                                //         child: AnimatedContainer(
                                //           duration: const Duration(
                                //             milliseconds: 180,
                                //           ),
                                //           padding: const EdgeInsets.all(12),
                                //           decoration: BoxDecoration(
                                //             color: isUnlocked
                                //                 ? Colors.white
                                //                 : const Color(0xFFF1F5F9),
                                //             borderRadius: BorderRadius.circular(
                                //               16,
                                //             ),
                                //             border: Border.all(
                                //               color: isUnlocked
                                //                   ? _primary.withOpacity(0.25)
                                //                   : _border,
                                //             ),
                                //             boxShadow: isUnlocked
                                //                 ? [
                                //                     BoxShadow(
                                //                       color: Colors.black
                                //                           .withOpacity(0.05),
                                //                       blurRadius: 12,
                                //                       offset: const Offset(
                                //                         0,
                                //                         6,
                                //                       ),
                                //                     ),
                                //                   ]
                                //                 : [],
                                //           ),
                                //           child: Column(
                                //             crossAxisAlignment:
                                //                 CrossAxisAlignment.stretch,
                                //             children: [
                                //               // ===== الصورة + الأيقونة داخلها =====
                                //               Expanded(
                                //                 child: ClipRRect(
                                //                   borderRadius:
                                //                       BorderRadius.circular(14),
                                //                   child: Stack(
                                //                     children: [
                                //                       Positioned.fill(
                                //                         child: FutureBuilder<String?>(
                                //                           future: _getBgUrl(
                                //                             category,
                                //                           ),
                                //                           builder: (context, snap) {
                                //                             if (snap.connectionState !=
                                //                                 ConnectionState
                                //                                     .done) {
                                //                               return Container(
                                //                                 color:
                                //                                     const Color(
                                //                                       0xFFF1F5F9,
                                //                                     ),
                                //                               );
                                //                             }
                                //                             final url =
                                //                                 snap.data;
                                //                             if (url == null ||
                                //                                 url.isEmpty) {
                                //                               return Container(
                                //                                 color:
                                //                                     const Color(
                                //                                       0xFFF1F5F9,
                                //                                     ),
                                //                               );
                                //                             }
                                //                             return Image.network(
                                //                               url,
                                //                               fit: BoxFit.cover,
                                //                               alignment:
                                //                                   Alignment
                                //                                       .center,
                                //                               errorBuilder:
                                //                                   (
                                //                                     _,
                                //                                     __,
                                //                                     ___,
                                //                                   ) => Container(
                                //                                     color: const Color(
                                //                                       0xFFF1F5F9,
                                //                                     ),
                                //                                   ),
                                //                             );
                                //                           },
                                //                         ),
                                //                       ),
                                //                       // Overlay خفيف عشان الأيقونة تبين
                                //                       Positioned.fill(
                                //                         child: Container(
                                //                           decoration: BoxDecoration(
                                //                             gradient: LinearGradient(
                                //                               begin: Alignment
                                //                                   .topCenter,
                                //                               end: Alignment
                                //                                   .bottomCenter,
                                //                               colors: [
                                //                                 Colors.black
                                //                                     .withOpacity(
                                //                                       0.10,
                                //                                     ),
                                //                                 Colors.black
                                //                                     .withOpacity(
                                //                                       0.35,
                                //                                     ),
                                //                               ],
                                //                             ),
                                //                           ),
                                //                         ),
                                //                       ),
                                //                       // Top row داخل الصورة (أيقونة + badge فقط)
                                //                       Positioned(
                                //                         top: 10,
                                //                         left: 10,
                                //                         right: 10,
                                //                         child: Row(
                                //                           children: [
                                //                             CircleAvatar(
                                //                               radius: 18,
                                //                               backgroundColor:
                                //                                   Colors.white
                                //                                       .withOpacity(
                                //                                         0.85,
                                //                                       ),
                                //                               child: Icon(
                                //                                 _iconForCategory(
                                //                                   category,
                                //                                 ),
                                //                                 color: _primary,
                                //                                 size: 20,
                                //                               ),
                                //                             ),
                                //                             const Spacer(),
                                //                             _statusBadge(
                                //                               isUnlocked,
                                //                             ), // من الدالة اللي عندك
                                //                           ],
                                //                         ),
                                //                       ),
                                //                     ],
                                //                   ),
                                //                 ),
                                //               ),
                                //               const SizedBox(height: 10),
                                //               // ===== النصوص برا الصورة (تحت) =====
                                //               Column(
                                //                 crossAxisAlignment:
                                //                     CrossAxisAlignment.start,
                                //                 children: [
                                //                   Text(
                                //                     category,
                                //                     maxLines: 1,
                                //                     overflow:
                                //                         TextOverflow.ellipsis,
                                //                     style: const TextStyle(
                                //                       fontSize: 15.5,
                                //                       fontWeight:
                                //                           FontWeight.w900,
                                //                       color: _textDark,
                                //                     ),
                                //                   ),
                                //                   const SizedBox(height: 6),
                                //                   Row(
                                //                     children: [
                                //                       Container(
                                //                         width: 8,
                                //                         height: 8,
                                //                         decoration:
                                //                             BoxDecoration(
                                //                               color:
                                //                                   _statusColor(
                                //                                     isUnlocked,
                                //                                   ),
                                //                               shape: BoxShape
                                //                                   .circle,
                                //                             ),
                                //                       ),
                                //                       const SizedBox(width: 8),
                                //                       Expanded(
                                //                         child: Text(
                                //                           _statusText(
                                //                             isUnlocked,
                                //                           ),
                                //                           maxLines: 1,
                                //                           overflow: TextOverflow
                                //                               .ellipsis,
                                //                           style: TextStyle(
                                //                             fontSize: 12.5,
                                //                             fontWeight:
                                //                                 FontWeight.w700,
                                //                             color: _textMuted
                                //                                 .withOpacity(
                                //                                   0.95,
                                //                                 ),
                                //                           ),
                                //                         ),
                                //                       ),
                                //                     ],
                                //                   ),
                                //                 ],
                                //               ),
                                //             ],
                                //           ),
                                //         ),
                                //       );
                                //     },
                                //   ),
                                : ListView.separated(
                                    itemCount: orderedCategories.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final category = orderedCategories[index];
                                      final isUnlocked = unlockedSet.contains(
                                        _norm(category),
                                      );

                                      return _categoryTile(
                                        category: category,
                                        isUnlocked: isUnlocked,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  // Widget _categoryWatermark(String category, {required bool isUnlocked}) {
  //   final icon = _bgIconForCategory(category);

  //   return Positioned(
  //     right: -10,
  //     bottom: -18,
  //     child: Transform.rotate(
  //       angle: -0.12, // ميلان خفيف
  //       child: Icon(
  //         icon,
  //         size: 96,
  //         color: (isUnlocked ? _primary : _textMuted).withOpacity(0.10),
  //       ),
  //     ),
  //   );
  // }
}
