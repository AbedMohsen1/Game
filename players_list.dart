// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game/ads/banner_ad_view.dart';
import 'package:game/loading_screen.dart';

import 'player_profile_page.dart';

class PlayersList extends StatefulWidget {
  const PlayersList({super.key});

  @override
  State<PlayersList> createState() => _PlayersListState();
}

class _PlayersListState extends State<PlayersList> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final Map<String, Future<int>> _statusCache = {};

  Future<int> _friendStatusFuture(String userId) {
    return _statusCache.putIfAbsent(
      userId,
      () => _checkFriendRequestStatus(userId),
    );
  }

  Future<void> _removeFriend(String friendId, String friendName) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendId)
          .delete();

      // حدّث الكاش
      _statusCache[friendId] = Future.value(0);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              "تم إزالة $friendName من الأصدقاء",
              textAlign: TextAlign.center,
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        );
    } catch (e) {
      debugPrint("Remove friend error: $e");
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerProfilePage(userId: userId)),
    );
  }

  int selectedTab = 0; // 0: اللاعبين, 1: الأصدقاء, 2: طلبات الصداقة
  String searchQuery = "";

  // ---------- Theme Colors ----------
  static const Color _primary = Color(0xFF2563EB); // Blue
  static const Color _surface = Colors.white;
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("قائمة اللاعبين"),
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
            colors: [
              Color(0xFFEFF6FF), // light blue
              Color(0xFFF8FAFC), // near white
            ],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),

            /// Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildTabButton("اللاعبين", 0),
                  const SizedBox(width: 10),
                  _buildTabButton("الأصدقاء", 1),
                  const SizedBox(width: 10),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('friend_requests')
                        .where('toUserId', isEqualTo: currentUserId)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : 0;
                      return _buildTabButton(
                        "طلبات الصداقة",
                        2,
                        badgeCount: count,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            /// Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "ابحث بالاسم أو المعرف...",
                    hintStyle: const TextStyle(color: _textMuted),
                    prefixIcon: const Icon(Icons.search, color: _textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 10),

            /// Content
            Expanded(child: _buildSelectedTabContent()),
          ],
        ),
      ),
    );
  }

  // ---------------- UI Helpers ----------------

  Widget _buildTabButton(String title, int index, {int badgeCount = 0}) {
    final bool isSelected = selectedTab == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isSelected ? _primary : _surface,
            border: Border.all(color: isSelected ? _primary : _border),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: _primary.withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : _textDark,
                ),
              ),

              if (badgeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.55)
                          : Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    badgeCount > 99 ? "99+" : "$badgeCount",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerTile({
    required String name,
    required String id,
    required int level,
    required Widget trailing,
    IconData icon = Icons.person_rounded,
    Color iconColor = _primary,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
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
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: iconColor.withOpacity(0.12),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _textDark),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chip("ID: $id", Icons.badge_outlined, _textMuted),
              _chip(
                "Level $level",
                Icons.star_rounded,
                const Color(0xFFF59E0B),
              ),
            ],
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _chip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.6,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  int _asInt(dynamic v, [int fallback = 1]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  Widget _emptyState(String text, {IconData icon = Icons.inbox_rounded}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: _textMuted),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "جرّب البحث باسم مختلف أو تحقق من الاتصال.",
              style: TextStyle(color: _textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Tabs Content ----------------

  Widget _buildSelectedTabContent() {
    switch (selectedTab) {
      case 0:
        return _buildPlayersList();
      case 1:
        return _buildFriendsList();
      case 2:
        return _buildFriendRequests();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Tab 0: All Players
  Widget _buildPlayersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: LoadingScreen());
        }

        final players = snapshot.data!.docs
            .where((doc) => doc.id != currentUserId)
            .toList();

        final filteredPlayers = players.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final pid = (data['playerId'] ?? '').toString().toLowerCase();
          return name.contains(searchQuery) || pid.contains(searchQuery);
        }).toList();

        if (filteredPlayers.isEmpty) {
          return _emptyState("لا يوجد لاعبين");
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          itemCount: filteredPlayers.length,
          itemBuilder: (context, index) {
            final doc = filteredPlayers[index];
            final data = doc.data() as Map<String, dynamic>;
            final targetUserId = doc.id;

            final name = (data['name'] ?? "مجهول").toString();
            final id = (data['playerId'] ?? "غير متوفر").toString();
            final lvl = _asInt(data['level'], 1);

            return _playerTile(
              name: name,
              id: id,
              level: lvl,
              iconColor: _primary,
              onTap: () => _openProfile(targetUserId),

              trailing: FutureBuilder<int>(
                future: _friendStatusFuture(targetUserId), // ✅ (من الخطوة 2)
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  // ✅ لو في خطأ: اعتبره "مش مرسل" واعرض زر الإضافة بدل ما يضل لودينغ
                  if (snap.hasError) {
                    return IconButton(
                      tooltip: "إرسال طلب صداقة",
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: _primary,
                      ),
                      onPressed: () => _sendFriendRequest(targetUserId),
                    );
                  }

                  final status = snap.data ?? 0;

                  if (status == 2) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF16A34A).withOpacity(0.25),
                        ),
                      ),
                      child: const Text(
                        "صديق",
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  } else if (status == 1) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _textMuted.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _textMuted.withOpacity(0.20)),
                      ),
                      child: const Text(
                        "تم الإرسال",
                        style: TextStyle(
                          color: _textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  } else {
                    return IconButton(
                      tooltip: "إرسال طلب صداقة",
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: _primary,
                      ),
                      onPressed: () => _sendFriendRequest(targetUserId),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Check friendship/request status
  Future<int> _checkFriendRequestStatus(String toUserId) async {
    try {
      final friendDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(toUserId)
          .get();
      if (friendDoc.exists) return 2;

      final request = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (request.docs.isNotEmpty) return 1;

      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _sendFriendRequest(String toUserId) async {
    await FirebaseFirestore.instance.collection('friend_requests').add({
      "fromUserId": currentUserId,
      "toUserId": toUserId,
      "status": "pending",
      "timestamp": FieldValue.serverTimestamp(),
    });

    // ✅ حدّث الكاش فورًا: الحالة = تم الإرسال
    _statusCache[toUserId] = Future.value(1);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("تم إرسال طلب الصداقة", textAlign: TextAlign.center),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

    setState(() {}); // 🔄 إعادة بناء العنصر
  }

  /// Tab 1: Friends
  Widget _buildFriendsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .snapshots(),
      builder: (context, snapshot) {
        // ✅ لو في خطأ
        if (snapshot.hasError) {
          // اطبع الخطأ بالكونسول عشان نعرف السبب الحقيقي
          debugPrint("Friends stream error: ${snapshot.error}");
          return _emptyState(
            "تعذر تحميل الأصدقاء. تحقق من الصلاحيات أو الاتصال.",
            icon: Icons.error_outline_rounded,
          );
        }

        // ✅ لودينغ حقيقي
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = snapshot.data?.docs ?? [];
        if (friends.isEmpty) {
          return _emptyState("لا يوجد أصدقاء", icon: Icons.people_alt_rounded);
        }

        // ✅ كمل نفس الكود تبعك تحت
        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friendId = friends[index].id;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(friendId)
                  .get(),
              builder: (context, friendSnapshot) {
                if (friendSnapshot.hasError) {
                  debugPrint("Friend doc error: ${friendSnapshot.error}");
                  return const SizedBox.shrink();
                }
                if (friendSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }

                final raw = friendSnapshot.data?.data();
                if (raw == null) return const SizedBox.shrink();

                final data = raw as Map<String, dynamic>;
                final name = (data['name'] ?? "مجهول").toString();
                final id = (data['playerId'] ?? "غير متوفر").toString();
                final lvl = _asInt(data['level'], 1);

                // ... نفس trailing والـ _playerTile عندك
                return _playerTile(
                  name: name,
                  id: id,
                  level: lvl,
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFF16A34A),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () => _showUnfriendDialog(friendId, name),
                  ),
                  onTap: () => _openProfile(friendId),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showUnfriendDialog(String friendId, String friendName) async {
    final confirm = await showDialog<bool>(
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
            children: const [
              Icon(Icons.person_remove_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 10),
              Text("إزالة صديق", style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text(
            "هل أنت متأكد أنك تريد إزالة $friendName من قائمة أصدقائك؟",
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("إزالة"),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      await _removeFriend(friendId, friendName);
    }
  }

  /// Tab 2: Friend Requests
  Widget _buildFriendRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('toUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: LoadingScreen());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return _emptyState(
            "لا توجد طلبات صداقة",
            icon: Icons.mail_outline_rounded,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestDoc = requests[index];
            final data = requestDoc.data() as Map<String, dynamic>;
            final fromUserId = data['fromUserId'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(fromUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }

                final raw = userSnapshot.data!.data();
                if (raw == null) return const SizedBox.shrink();

                final userData = raw as Map<String, dynamic>;
                final name = (userData['name'] ?? "لاعب").toString();
                final id = (userData['playerId'] ?? "غير متوفر").toString();
                final lvl = _asInt(userData['level'], 1);

                if (searchQuery.isNotEmpty) {
                  final n = name.toLowerCase();
                  final pid = id.toLowerCase();
                  if (!n.contains(searchQuery) && !pid.contains(searchQuery)) {
                    return const SizedBox.shrink();
                  }
                }

                return _playerTile(
                  name: name,
                  id: id,
                  level: lvl,
                  icon: Icons.person_add_alt_1_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  onTap: () => _openProfile(fromUserId),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: "قبول",
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF16A34A),
                        ),
                        onPressed: () =>
                            _acceptFriendRequest(requestDoc.id, fromUserId),
                      ),
                      IconButton(
                        tooltip: "رفض",
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFFDC2626),
                        ),
                        onPressed: () => _rejectFriendRequest(requestDoc.id),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _acceptFriendRequest(String requestId, String fromUserId) async {
    final batch = FirebaseFirestore.instance.batch();

    final requestRef = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId);

    final myFriendRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(fromUserId);

    final hisFriendRef = FirebaseFirestore.instance
        .collection('users')
        .doc(fromUserId)
        .collection('friends')
        .doc(currentUserId);

    // ✅ احذف الطلب
    batch.delete(requestRef);

    // ✅ أضف الصداقة للطرفين
    batch.set(myFriendRef, {"friendId": fromUserId});
    batch.set(hisFriendRef, {"friendId": currentUserId});

    await batch.commit();

    // ✅ حدّث الكاش
    _statusCache[fromUserId] = Future.value(2);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("تم قبول طلب الصداقة", textAlign: TextAlign.center),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    final doc = await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId)
        .get();

    final data = doc.data();
    final fromUserId = data?['fromUserId'];

    await doc.reference.delete();

    // ✅ صفّر الحالة في الكاش
    if (fromUserId != null) {
      _statusCache[fromUserId] = Future.value(0);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("تم رفض طلب الصداقة", textAlign: TextAlign.center),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
  }
}
