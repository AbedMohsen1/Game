// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game/ads/banner_ad_view.dart';
import 'package:game/ads/interstitial_ad_service.dart';
import 'package:game/screen/Game/waiting_room_screen.dart';
import 'package:game/screen/auth/login_screen.dart';
import 'package:game/screen/home/chat/admin_chat_screen.dart';
import 'package:game/screen/home/how_to_play.dart';
import 'package:game/screen/home/select_options_game.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game/screen/home/support_screen.dart';
import 'package:game/screen/home/top_winners_screen.dart';
import 'package:game/screen/settings/settings_page.dart';
// import 'package:game/screen/quiz_questions.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _support = Color(0xFF16A34A); // أخضر
  static const Color _learn = Color(0xFF7C3AED); // بنفسجي
  static const Color _adminChat = Color(0xFF1E3A8A);

  User? user;
  Timer? _interstitialTimer;

  @override
  void initState() {
    super.initState();

    InterstitialAdService.instance.preload();
    loadUser();
    _checkExpiredInvites();

    if (Platform.isAndroid || Platform.isIOS) {
      InterstitialAdService.instance.preload();
      _interstitialTimer = Timer.periodic(const Duration(minutes: 5), (
        _,
      ) async {
        if (!mounted) return;
        await InterstitialAdService.instance.showIfReady(context);
      });
    }
  }

  @override
  void dispose() {
    _interstitialTimer?.cancel();
    InterstitialAdService.instance.dispose();
    super.dispose();
  }

  Future<void> loadUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (!mounted) return;
    setState(() {
      user = FirebaseAuth.instance.currentUser;
    });
  }

  Future<void> _checkExpiredInvites() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final invites = await FirebaseFirestore.instance
        .collection('game_invites')
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    final now = DateTime.now();
    for (final doc in invites.docs) {
      final data = doc.data();
      final ts = data['timestamp'];
      if (ts is! Timestamp) continue;

      final timestamp = ts.toDate();
      final diff = now.difference(timestamp).inSeconds;

      // 120 ثانية = 2 دقيقة
      if (diff >= 120) {
        await doc.reference.update({'status': 'expired'});
      }
    }
  }

  Future<void> _acceptInvite(
    String inviteId,
    Map<String, dynamic> inviteData,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final roomId = inviteData['roomId'];
    if (roomId == null) return;

    // تحقق من وجود الغرفة
    final roomDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .get();

    if (!roomDoc.exists) {
      await FirebaseFirestore.instance
          .collection('game_invites')
          .doc(inviteId)
          .update({'status': 'expired'});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "المباراة لم تعد متاحة (المضيف خرج).",
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    // قبول الدعوة
    await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
      'guestId': currentUser.uid,
      'guestName': currentUser.displayName ?? 'ضيف',
    });

    await FirebaseFirestore.instance
        .collection('game_invites')
        .doc(inviteId)
        .update({'status': 'accepted'});

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaitingRoomScreen(roomId: roomId, isHost: false),
      ),
    );
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

  // ignore: unused_element
  Widget _secondaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color, // ✅ جديد
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Ink(
        padding: const EdgeInsets.all(14),
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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.18)),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                    softWrap: true,
                    maxLines: 2, // ✅ خليها 2 (أو شيلها نهائيًا)
                    overflow: TextOverflow.visible, // ✅ بدون ...
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _textMuted,
                    ),
                    softWrap: true,
                    maxLines: 3, // ✅ 3 أسطر (أو شيلها)
                    overflow: TextOverflow.visible, // ✅ بدون ...
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_left_rounded, color: _textMuted),
          ],
        ),
      ),
    );
  }

  Widget _heroHeader(String displayName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_primary.withOpacity(0.12), const Color(0xFFFFFFFF)],
        ),
        border: Border.all(color: _border),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primary.withOpacity(0.18)),
            ),
            child: const Icon(Icons.person_rounded, color: _primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "اهلا بعودتك $displayName 👋",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "اختر وضع اللعب أو راجع طريقة اللعب",
                  style: TextStyle(
                    color: _textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _primary.withOpacity(0.18)),
            ),
            child: const Row(
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: _primary),
                SizedBox(width: 6),
                Text(
                  "جاهز",
                  style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Invites UI ----------
  Widget _buildInvitesList() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('game_invites')
          .where('toUserId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final allInvites = snapshot.data!.docs;

        // نخفي الدعوات المقبولة/المرفوضة/المنتهية إذا بدك، أو خليها تظهر. هون بنخليها تظهر لكن شكلها يتغير.
        if (allInvites.isEmpty) {
          return _card(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _primary.withOpacity(0.12),
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "لا توجد دعوات حالياً",
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return _card(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _primary.withOpacity(0.12),
                    child: const Icon(
                      Icons.mail_outline_rounded,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "دعوات الأصدقاء",
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...allInvites.map((doc) {
                final inviteData = doc.data() as Map<String, dynamic>;
                final fromUserId = inviteData['fromUserId'];
                final status = (inviteData['status'] ?? 'pending').toString();
                final roomId = (inviteData['roomId'] ?? '').toString();

                // شكل الحالة
                Color statusColor = _textMuted;
                String statusText = "قيد الانتظار";
                IconData statusIcon = Icons.hourglass_bottom_rounded;

                if (status == 'expired') {
                  statusColor = _danger;
                  statusText = "انتهت";
                  statusIcon = Icons.timer_off_rounded;
                } else if (status == 'accepted') {
                  statusColor = _success;
                  statusText = "مقبولة";
                  statusIcon = Icons.check_circle_rounded;
                } else if (status == 'rejected') {
                  statusColor = _danger;
                  statusText = "مرفوضة";
                  statusIcon = Icons.cancel_rounded;
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(fromUserId)
                      .get(),
                  builder: (context, userSnapshot) {
                    final userData =
                        userSnapshot.data?.data() as Map<String, dynamic>?;
                    final fromUserName = (userData?['name'] ?? 'لاعب')
                        .toString();
                    final fromPid = (userData?['playerId'] ?? '').toString();

                    return Dismissible(
                      key: ValueKey(doc.id),
                      direction: DismissDirection.horizontal,
                      confirmDismiss: (_) async {
                        HapticFeedback.selectionClick();
                        return await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("حذف الدعوة؟"),
                                content: const Text(
                                  "هل أنت متأكد أنك تريد حذف هذه الدعوة؟",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text("إلغاء"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text("حذف"),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _danger.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: _danger,
                        ),
                      ),
                      secondaryBackground: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _danger.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: _danger,
                        ),
                      ),
                      onDismissed: (_) async {
                        final deleted = doc;
                        await FirebaseFirestore.instance
                            .collection('game_invites')
                            .doc(doc.id)
                            .delete();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("تم حذف الدعوة"),
                            action: SnackBarAction(
                              label: "تراجع",
                              onPressed: () async {
                                // إعادة إنشاء الدعوة كما كانت (Undo)
                                final data =
                                    deleted.data()
                                        as Map<
                                          String,
                                          dynamic
                                        >?; // نفس البيانات
                                if (data == null) return;
                                await FirebaseFirestore.instance
                                    .collection('game_invites')
                                    .doc(deleted.id)
                                    .set(data);
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: statusColor.withOpacity(0.12),
                              child: Icon(
                                statusIcon,
                                color: statusColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fromUserName,
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
                                      if (fromPid.isNotEmpty)
                                        _chip(
                                          "ID: $fromPid",
                                          Icons.badge_outlined,
                                          _textMuted,
                                        ),
                                      _chip(
                                        "Room: $roomId",
                                        Icons.meeting_room_outlined,
                                        _primary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (status == 'pending')
                              SizedBox(
                                height: 38,
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _acceptInvite(doc.id, inviteData),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                  ),
                                  child: const Text(
                                    "قبول",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? 'مستخدم';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          title: const Text(
            "Jawib ~ جَاوِب",
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: _primary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,

          // ✅ يسار: الإعدادات
          leading: IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
            tooltip: 'الإعدادات',
          ),

          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                HapticFeedback.lightImpact();
                await FirebaseAuth.instance.signOut();

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(width: 6),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: (Platform.isAndroid || Platform.isIOS)
                  ? 85
                  : 12, // 70 تقريباً ارتفاع البانر
            ),
            child: _GameStartCTA(
              primary: _primary,
              border: _border,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectOptionsGame()),
                );
              },
            ),
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
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ✅ Header احترافي (بدون حذف الكارد القديم، بس استبدلناه بواحد أجمل)
                        _heroHeader(displayName),

                        const SizedBox(height: 14),

                        // ✅ زر رئيسي
                        // _primaryButton(
                        //   text: "ابدأ اللعب",
                        //   icon: Icons.play_arrow_rounded,
                        //   onPressed: () {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (_) => const SelectOptionsGame(),
                        //       ),
                        //     );
                        //   },
                        // ),
                        const SizedBox(height: 14),

                        // ✅ بدل عمود طويل: Grid (مظهر احترافي)
                        GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.35,
                              ),
                          children: [
                            _actionTile(
                              title: "الفائزين بالدوريات",
                              subtitle: "عرض أفضل اللاعبين",
                              icon: Icons.emoji_events_rounded,
                              color: const Color(0xFFF59E0B),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TopWinnersScreen(),
                                  ),
                                );
                              },
                            ),
                            _actionTile(
                              title: "تسليم الجوائز",
                              subtitle: "تواصل مع الإدارة",
                              icon: Icons.campaign_rounded,
                              color: _adminChat,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminChatScreen(),
                                  ),
                                );
                              },
                            ),
                            _actionTile(
                              title: "الدعم الفني",
                              subtitle: "تواصل معنا للمساعدة",
                              icon: Icons.support_agent_rounded,
                              color: _support,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SupportScreen(),
                                  ),
                                );
                              },
                            ),
                            _actionTile(
                              title: "تعلم كيفية اللعب",
                              subtitle: "شرح سريع للقوانين",
                              icon: Icons.help_outline_rounded,
                              color: _learn,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HowToPlayScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ✅ نفس دعوتك كما هي + تحسين Empty + ConfirmDismiss + Undo
                        _buildInvitesList(),
                      ],
                    ),
                  ),
                ),
                if (Platform.isAndroid || Platform.isIOS)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: const BannerAdView(
                      adUnitId: 'ca-app-pub-5228897328353749/1447751878',
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

class _GameStartCTA extends StatefulWidget {
  final VoidCallback onTap;
  final Color primary;
  final Color border;

  const _GameStartCTA({
    required this.onTap,
    required this.primary,
    required this.border,
  });

  @override
  State<_GameStartCTA> createState() => _GameStartCTAState();
}

class _GameStartCTAState extends State<_GameStartCTA> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.primary;

    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      scale: _down ? 0.985 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.border),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [p, Color.lerp(p, Colors.black, 0.20)!],
              ),
              boxShadow: [
                BoxShadow(
                  color: p.withOpacity(0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // لمعة خفيفة (Game feel)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.18),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                Row(
                  children: [
                    // كبسولة الأيقونة
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.20),
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // نصين زي الألعاب
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "ابدأ اللعب",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "جاهز للتحدّي؟ اضغط للبدء الآن",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // سهم + نقطة إشعار صغيرة
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white.withOpacity(0.95),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD54F),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFFD54F,
                                  ).withOpacity(0.35),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
