// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game/ads/banner_ad_view.dart';
import 'package:game/loading_screen.dart';

class PurchasesHistoryPage extends StatelessWidget {
  const PurchasesHistoryPage({super.key});

  // ---- نفس ستايل باقي الشاشات ----
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  Future<List<Map<String, dynamic>>> fetchPurchases() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('powerups')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();

        final num? costNum = data["cost"] as num?;
        final Timestamp? ts = data["date"] as Timestamp?;

        return {
          "name": (data["name"] ?? "غير معروف").toString(),
          "cost": (costNum ?? 0).toInt(),
          "date": ts?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      // جرّب بدون orderBy لو في مشكلة types/date
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('powerups')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final num? costNum = data["cost"] as num?;
        final Timestamp? ts = data["date"] as Timestamp?;
        return {
          "name": (data["name"] ?? "غير معروف").toString(),
          "cost": (costNum ?? 0).toInt(),
          "date": ts?.toDate() ?? DateTime.now(),
        };
      }).toList();
    }
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
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
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  IconData _purchaseIcon(String name) {
    if (name.contains("حذف إجابة واحدة")) return Icons.cancel_rounded;
    if (name.contains("حذف إجابتين")) return Icons.remove_circle_rounded;
    if (name.contains("حل")) return Icons.check_circle_rounded;
    if (name.contains("زيادة")) return Icons.timer_rounded;
    if (name.contains("مستوى") || name.contains("ترقية")) {
      return Icons.upgrade_rounded;
    }
    return Icons.shopping_bag_rounded;
  }

  Color _purchaseColor(String name) {
    if (name.contains("حذف إجابة واحدة")) return const Color(0xFFDC2626);
    if (name.contains("حذف إجابتين")) return const Color(0xFFF59E0B);
    if (name.contains("حل")) return const Color(0xFF16A34A);
    if (name.contains("زيادة")) return const Color(0xFF2563EB);
    if (name.contains("مستوى") || name.contains("ترقية")) {
      return const Color(0xFFF59E0B);
    }
    return _primary;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("سجل المشتريات"),
          centerTitle: true,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        // البانر الثابت في الأسفل
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
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchPurchases(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingScreen());
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Text("حدث خطأ أثناء تحميل البيانات"),
                );
              }

              final purchases = snapshot.data ?? [];
              if (purchases.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: _card(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 38,
                            color: _textMuted,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "لا توجد مشتريات حتى الآن",
                            style: TextStyle(
                              color: _textDark,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "عند شراء أي أداة ستظهر هنا في السجل",
                            style: TextStyle(
                              color: _textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: purchases.length,
                itemBuilder: (context, index) {
                  final item = purchases[index];
                  final String name = (item["name"] ?? "غير معروف").toString();
                  final int cost = (item["cost"] ?? 0) as int;
                  final DateTime date = item["date"] as DateTime;

                  final icon = _purchaseIcon(name);
                  final color = _purchaseColor(name);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _card(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: color.withOpacity(0.18),
                              ),
                            ),
                            child: Icon(icon, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _textDark,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _chip(
                                      "السعر: $cost XP",
                                      Icons.local_offer_rounded,
                                      _primary,
                                    ),
                                    _chip(
                                      _formatDate(date),
                                      Icons.schedule_rounded,
                                      _textMuted,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}
