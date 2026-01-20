// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:game/ads/banner_ad_view.dart';
import 'package:game/loading_screen.dart';

class PlayerProfilePage extends StatelessWidget {
  final String userId;
  const PlayerProfilePage({super.key, required this.userId});

  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  int _asInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  String _formatDate(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} "
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  Future<List<Map<String, dynamic>>> _fetchPlayerSeasonHistory(
    String uid,
  ) async {
    // جيب آخر 50 موسم (عدل العدد حسب ما بدك)
    final seasonsSnap = await FirebaseFirestore.instance
        .collection('settings')
        .doc('leaderboard')
        .collection('seasons')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final history = <Map<String, dynamic>>[];

    for (final doc in seasonsSnap.docs) {
      final data = doc.data();

      final winners = (data['winners'] as List?) ?? [];
      Map<String, dynamic>? me;

      for (final w in winners) {
        if (w is Map && w['uid'] == uid) {
          me = Map<String, dynamic>.from(w);
          break;
        }
      }

      if (me != null) {
        // تاريخ الموسم (الأفضل seasonEnd أو createdAt)
        DateTime? seasonEnd;
        final endRaw = data['seasonEnd'];
        if (endRaw is Timestamp) seasonEnd = endRaw.toDate();

        DateTime? createdAt;
        final createdRaw = data['createdAt'];
        if (createdRaw is Timestamp) createdAt = createdRaw.toDate();

        history.add({
          'rank': me['rank'],
          'prize': me['prize'],
          'seasonEnd': seasonEnd,
          'createdAt': createdAt,
          'seasonDays': data['seasonDays'],
        });
      }
    }

    return history;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("الملف الشخصي"),
          centerTitle: true,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBar: Platform.isAndroid
            ? const BannerAdView(
                adUnitId: 'ca-app-pub-5228897328353749/1447751878',
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
          child: FutureBuilder<List<dynamic>>(
            future: Future.wait([
              FirebaseFirestore.instance.collection('users').doc(userId).get(),
              _fetchPlayerSeasonHistory(userId),
            ]),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingScreen());
              }
              if (!snap.hasData) {
                return const Center(child: LoadingScreen());
              }

              final userDoc = snap.data![0] as DocumentSnapshot;
              final history = (snap.data![1] as List)
                  .cast<Map<String, dynamic>>();

              if (!userDoc.exists) {
                return const Center(child: Text("اللاعب غير موجود"));
              }

              final data = userDoc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? "لاعب").toString();
              final playerId = (data['playerId'] ?? "غير متوفر").toString();
              final level = _asInt(data['level'], 1);
              final xp = _asInt(data['xp'], 0);
              final correct = _asInt(data['correctAnswers'], 0);
              final wrong = _asInt(data['wrongAnswers'], 0);
              final photoUrl = (data['photoURL'] ?? "").toString();

              DateTime? createdAt;
              final createdRaw = data['createdAt'];
              if (createdRaw is Timestamp) createdAt = createdRaw.toDate();

              Widget card({required Widget child}) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
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

              Widget miniStat({
                required IconData icon,
                required Color color,
                required String label,
                required String value,
              }) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    card(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 54,
                            backgroundColor: _primary.withOpacity(0.12),
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name.characters.first.toUpperCase()
                                        : "?",
                                    style: const TextStyle(
                                      fontSize: 40,
                                      color: _primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _textDark,
                            ),
                          ),
                          // const SizedBox(height: 6),
                          // Text(
                          //   email,
                          //   style: const TextStyle(
                          //     color: _textMuted,
                          //     fontWeight: FontWeight.w700,
                          //   ),
                          // ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _pill("ID: $playerId"),
                              _pill("Level: $level"),
                              _pill("XP: $xp"),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    card(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: miniStat(
                                  icon: Icons.check_circle_rounded,
                                  color: const Color(0xFF16A34A),
                                  label: "إجابات صحيحة",
                                  value: "$correct",
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: miniStat(
                                  icon: Icons.cancel_rounded,
                                  color: const Color(0xFFDC2626),
                                  label: "إجابات خاطئة",
                                  value: "$wrong",
                                ),
                              ),
                            ],
                          ),
                          if (createdAt != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _textMuted.withOpacity(0.10),
                                  child: const Icon(
                                    Icons.calendar_month_rounded,
                                    color: _textMuted,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "تاريخ إنشاء الحساب",
                                    style: TextStyle(
                                      color: _textDark,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDate(createdAt),
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),

                          // ===== Header: سجل اللاعب =====
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _primary.withOpacity(0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _primary.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.history_rounded,
                                    color: _primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "سجل اللاعب",
                                    style: TextStyle(
                                      color: _textDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Text(
                                    "${history.length} موسم",
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          if (history.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _textMuted.withOpacity(0.10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.info_outline_rounded,
                                      color: _textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      "لا يوجد سجل مواسم لهذا اللاعب حتى الآن.",
                                      style: TextStyle(
                                        color: _textMuted,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            // ===== Summary Card =====
                            Builder(
                              builder: (_) {
                                num totalPrize = 0;
                                int wins = 0;
                                for (final h in history) {
                                  final p = h['prize'];
                                  if (p is num && p > 0) {
                                    totalPrize += p;
                                    wins++;
                                  }
                                }

                                Widget statChip({
                                  required IconData icon,
                                  required String label,
                                  required String value,
                                  required Color color,
                                }) {
                                  return Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: color.withOpacity(0.14),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(icon, color: color, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            value,
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return Row(
                                  children: [
                                    statChip(
                                      icon: Icons.event_repeat_rounded,
                                      label: "مواسم",
                                      value: "${history.length}",
                                      color: _primary,
                                    ),
                                    const SizedBox(width: 10),
                                    statChip(
                                      icon: Icons.emoji_events_rounded,
                                      label: "فاز",
                                      value: "$wins",
                                      color: const Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 10),
                                    statChip(
                                      icon: Icons.monetization_on_rounded,
                                      label: "المجموع",
                                      value: "${totalPrize.toString()} \$",
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 10),

                            // ===== Seasons List =====
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: history.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final h = history[i];
                                final rank = h['rank'] ?? '-';
                                final prize = h['prize'];

                                final end = h['seasonEnd'] as DateTime?;
                                final created = h['createdAt'] as DateTime?;
                                final date = end ?? created;
                                final dateText = date == null
                                    ? "—"
                                    : _formatDate(date);

                                final bool hasPrize =
                                    (prize is num) && prize > 0;

                                // badges
                                Widget badge({
                                  required String text,
                                  required Color color,
                                  required IconData icon,
                                }) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: color.withOpacity(0.18),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 16, color: color),
                                        const SizedBox(width: 6),
                                        Text(
                                          text,
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                // rank colors (gold/silver/bronze for top 3)
                                Color rankColor;
                                if (rank == 1 || rank == "1") {
                                  rankColor = const Color(0xFFF59E0B);
                                } else if (rank == 2 || rank == "2") {
                                  rankColor = const Color(0xFF9CA3AF);
                                } else if (rank == 3 || rank == "3") {
                                  rankColor = const Color(0xFF8D6E63);
                                } else {
                                  rankColor = _primary;
                                }

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _border),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // left icon
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color:
                                              (hasPrize
                                                      ? const Color(0xFFF59E0B)
                                                      : _primary)
                                                  .withOpacity(0.10),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                (hasPrize
                                                        ? const Color(
                                                            0xFFF59E0B,
                                                          )
                                                        : _primary)
                                                    .withOpacity(0.18),
                                          ),
                                        ),
                                        child: Icon(
                                          hasPrize
                                              ? Icons.emoji_events_rounded
                                              : Icons.leaderboard_rounded,
                                          color: hasPrize
                                              ? const Color(0xFFF59E0B)
                                              : _primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "موسم بتاريخ",
                                              style: TextStyle(
                                                color: _textMuted,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              dateText,
                                              style: const TextStyle(
                                                color: _textDark,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          badge(
                                            text: "#$rank",
                                            color: rankColor,
                                            icon:
                                                Icons.workspace_premium_rounded,
                                          ),
                                          if (hasPrize) ...[
                                            const SizedBox(height: 6),
                                            badge(
                                              text: "${prize.toString()} \$",
                                              color: const Color(0xFF16A34A),
                                              icon:
                                                  Icons.monetization_on_rounded,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
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

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _textMuted.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _textMuted.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.6,
          color: _textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
