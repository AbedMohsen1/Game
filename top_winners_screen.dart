// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TopWinnersScreen extends StatefulWidget {
  const TopWinnersScreen({super.key});

  @override
  State<TopWinnersScreen> createState() => _TopWinnersScreenState();
}

class _TopWinnersScreenState extends State<TopWinnersScreen> {
  // ✅ الموسم ثابت 10 أيام
  static const int _seasonDays = 10;

  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _border = Color(0xFFE2E8F0);

  int _rev = 0; // لإعادة المحاولة بشكل نظيف

  @override
  Widget build(BuildContext context) {
    final seasonRef = FirebaseFirestore.instance
        .collection('settings')
        .doc('leaderboard');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: StreamBuilder<DocumentSnapshot>(
          key: ValueKey(_rev),
          stream: seasonRef.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _StateView(
                icon: Icons.wifi_off_rounded,
                title: "تعذر تحميل الفائزين",
                subtitle: "تحقق من الاتصال وحاول مرة أخرى",
                action: _RetryButton(onTap: () => setState(() => _rev++)),
              );
            }

            if (!snap.hasData) {
              return const _LoadingView();
            }

            final data = snap.data!.data() as Map<String, dynamic>?;
            final last = (data?['lastWinners'] as Map?)
                ?.cast<String, dynamic>();
            final winnersRaw = ((last?['winners'] as List?) ?? [])
                .cast<dynamic>();

            if (winnersRaw.isEmpty) {
              return const _StateView(
                icon: Icons.emoji_events_outlined,
                title: "لا يوجد فائزين محفوظين بعد",
                subtitle: "سيتم حفظ أفضل 5 فائزين عند انتهاء الموسم",
              );
            }

            final seasonLabel = (last?['seasonLabel'] ?? "الموسم السابق")
                .toString();

            DateTime? start = _toDate(last?['seasonStart'] ?? last?['start']);
            DateTime? end = _toDate(last?['seasonEnd'] ?? last?['end']);

            // ✅ لو عندك start فقط → احسب end تلقائياً (10 أيام)
            if (start != null && end == null) {
              end = start.add(const Duration(days: _seasonDays));
            }
            // ✅ لو عندك end فقط → احسب start تلقائياً (10 أيام)
            if (start == null && end != null) {
              start = end.subtract(const Duration(days: _seasonDays));
            }

            // Parse + sort by rank (احتياطي)
            final parsed = winnersRaw
                .map((e) => (e as Map).cast<String, dynamic>())
                .toList();

            parsed.sort((a, b) {
              final ra = (a['rank'] is num) ? (a['rank'] as num).toInt() : 999;
              final rb = (b['rank'] is num) ? (b['rank'] as num).toInt() : 999;
              return ra.compareTo(rb);
            });

            final top3 = parsed.take(3).toList();
            final rest = parsed.length > 3
                ? parsed.sublist(3)
                : <Map<String, dynamic>>[];

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 220,
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  title: const Text("فائزين الموسم السابق"),
                  centerTitle: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 58, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.25),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.history_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            "نتائج الموسم السابق",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.emoji_events_rounded,
                                      color: Colors.amber,
                                      size: 26,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  seasonLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (start != null || end != null)
                                      ? _seasonRangeText(start, end)
                                      : "تم حفظ أفضل 5 فائزين عند انتهاء الموسم",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.92),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                    ),
                                  ),
                                  child: const Text(
                                    "مدة الموسم: 10 أيام",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _SeasonInfoCard(
                          title: "ملخص النتائج",
                          subtitle: "أفضل 5 لاعبين من الموسم السابق",
                          leftChip: "عدد الفائزين: ${parsed.length}",
                          rightChip: "مدة الموسم: $_seasonDays أيام",
                        ),
                        const SizedBox(height: 12),

                        if (top3.isNotEmpty) _Podium(top3: top3),
                        if (top3.isNotEmpty) const SizedBox(height: 12),

                        if (rest.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.list_alt_rounded,
                                      color: _primary,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "باقي الفائزين",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: _textDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...rest.map((w) => _WinnerTile(w: w)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static String _fmt(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

  static String _seasonRangeText(DateTime? start, DateTime? end) {
    if (start != null && end != null) return "${_fmt(start)}  →  ${_fmt(end)}";
    if (start != null) return "بدأ: ${_fmt(start)}";
    if (end != null) return "انتهى: ${_fmt(end)}";
    return "";
  }
}

// =======================
// Widgets
// =======================

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _StateView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, size: 36, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RetryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text(
        "إعادة المحاولة",
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SeasonInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String leftChip;
  final String rightChip;

  const _SeasonInfoCard({
    required this.title,
    required this.subtitle,
    required this.leftChip,
    required this.rightChip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.insights_rounded, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _smallChip(leftChip, Icons.group_rounded),
                    _smallChip(rightChip, Icons.calendar_month_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _smallChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> top3;
  const _Podium({required this.top3});

  static const Color _primary = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? w1 = top3.isNotEmpty ? top3[0] : null;
    Map<String, dynamic>? w2 = top3.length > 1 ? top3[1] : null;
    Map<String, dynamic>? w3 = top3.length > 2 ? top3[2] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                "المنصّة (Top 3)",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _podiumCard(
                  w: w2,
                  label: "المركز الثاني",
                  medal: "🥈",
                  lift: 10,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _podiumCard(
                  w: w1,
                  label: "المركز الأول",
                  medal: "🥇",
                  lift: 0,
                  highlight: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _podiumCard(
                  w: w3,
                  label: "المركز الثالث",
                  medal: "🥉",
                  lift: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _podiumCard({
    required Map<String, dynamic>? w,
    required String label,
    required String medal,
    required double lift,
    bool highlight = false,
  }) {
    final name = (w?['name'] ?? 'لاعب').toString();
    final level = (w?['level'] ?? 1).toString();
    final xp = (w?['xp'] ?? 0).toString();
    final rank = (w?['rank'] ?? '').toString();

    return Transform.translate(
      offset: Offset(0, -lift),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? _primary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight
                ? _primary.withOpacity(0.25)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(medal, style: const TextStyle(fontSize: 18)),
                const Spacer(),
                if (rank.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "#$rank",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: _primary.withOpacity(0.12),
              child: const Icon(Icons.person_rounded, color: _primary),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _miniChip("L$level", Icons.star_rounded),
                _miniChip("XP $xp", Icons.bolt_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _miniChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerTile extends StatelessWidget {
  final Map<String, dynamic> w;
  const _WinnerTile({required this.w});

  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final rank = (w['rank'] ?? '').toString();
    final name = (w['name'] ?? 'لاعب').toString();
    final pid = (w['playerId'] ?? '').toString();
    final level = (w['level'] ?? 1).toString();
    final xp = (w['xp'] ?? 0).toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primary.withOpacity(0.12),
            child: Text(
              rank.isNotEmpty ? "#$rank" : "#",
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (pid.isNotEmpty) _chip("ID: $pid", Icons.badge_outlined),
                    _chip("L$level", Icons.star_rounded),
                    _chip("XP $xp", Icons.bolt_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _textMuted),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _textMuted,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
