// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:game/ads/banner_ad_view.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _danger = Color(0xFFDC2626);

  // ✅ عدّلهم لقيمك الحقيقية
  static const String instagramUsername = "jawib_app"; // بدون @
  static const String supportEmail = "jawibapp@gmail.com";
  static const String whatsappNumber = "+970598063779"; // مع كود الدولة

  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  // ---------- UI ----------
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

  void _snack(String text, {Color? bg, int seconds = 2}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        duration: Duration(seconds: seconds),
        backgroundColor: bg,
        content: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    _snack("تم نسخ $label ✅", seconds: 1);
  }

  // ---------- Links ----------
  Future<void> _launchUri(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack("تعذر فتح الرابط.", seconds: 1);
  }

  Future<void> _openInstagram() async {
    // نحاول نفتح التطبيق أولاً
    final appUri = Uri.parse("instagram://user?username=$instagramUsername");
    final webUri = Uri.parse("https://instagram.com/$instagramUsername");

    if (await canLaunchUrl(appUri)) {
      await _launchUri(appUri);
    } else {
      await _launchUri(webUri);
    }
  }

  Future<void> _openEmail() async {
    final uri = Uri.parse("mailto:$supportEmail?subject=Support%20-%20Jawib");
    await _launchUri(uri);
  }

  Future<void> _openWhatsApp() async {
    final clean = whatsappNumber.replaceAll("+", "");
    final msg = Uri.encodeComponent("مرحبا هل يمكنك مساعدتي ! ");
    final uri = Uri.parse("https://wa.me/$clean?text=$msg");
    await _launchUri(uri);
  }

  // ---------- Send Ticket ----------
  Future<void> _sendTicket() async {
    if (_sending) return;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    setState(() => _sending = true);

    try {
      String? phone;

      // ✅ حاول نجيب رقم الهاتف من users/{uid}
      if (user != null) {
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (uDoc.exists) {
          final data = uDoc.data() as Map<String, dynamic>;
          phone = (data['phone'] ?? data['phoneNumber'] ?? data['mobile'])
              ?.toString();
        }
      }

      final countersRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('support_tickets');

      // ✅ رح نخزن رقم التذكرة هنا
      int newTicketNo = 0;

      // ✅ Transaction: يزيد العداد ويعمل تذكرة برقم متسلسل
      final ticketDocRef = FirebaseFirestore.instance
          .collection('support_tickets')
          .doc();

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final counterSnap = await tx.get(countersRef);

        int last = 0;
        if (counterSnap.exists) {
          final data = counterSnap.data() as Map<String, dynamic>;
          last = (data['last'] ?? 0) as int;
        } else {
          // لو مش موجود (احتياط)
          tx.set(countersRef, {"last": 0});
          last = 0;
        }

        newTicketNo = last + 1;

        // تحديث العداد
        tx.set(countersRef, {"last": newTicketNo}, SetOptions(merge: true));

        // إنشاء التذكرة مع رقمها
        tx.set(ticketDocRef, {
          "ticketNo": newTicketNo, // ✅ رقم يبدأ من 1
          "uid": user?.uid,
          "name": user?.displayName ?? "مستخدم",
          "email": user?.email,
          "phone": phone,
          "message": _messageCtrl.text.trim(),
          "status": "open",
          "createdAt": FieldValue.serverTimestamp(),
          "app": "Jawib",
        });
      });

      _messageCtrl.clear();

      if (!mounted) return;

      // مثال: #000001

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 4),
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "شكرًا لك 🙏 تم استلام رسالتك بنجاح",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                // Text(
                //   "رقم التذكرة: $ticketLabel",
                //   style: const TextStyle(fontWeight: FontWeight.w800),
                // ),
                // const SizedBox(height: 4),
                const Text(
                  "سيتواصل معك الدعم الفني قريبًا إن شاء الله.",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          // action: SnackBarAction(
          //   label: "نسخ الرقم",
          //   onPressed: () =>
          //       Clipboard.setData(ClipboardData(text: ticketLabel)),
          // ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
          content: Text("حدث خطأ: $e", textAlign: TextAlign.center),
          backgroundColor: _danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _contactRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onOpen,
    Color? iconColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (iconColor ?? _primary).withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Icon(icon, color: iconColor ?? _primary, size: 20),
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
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: _textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: "نسخ",
              onPressed: () => _copy(value, title),
              icon: const Icon(Icons.copy_rounded, color: _textMuted),
            ),
            IconButton(
              tooltip: "فتح",
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("الدعم الفني"),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                _card(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "نحن هنا لمساعدتك 👋",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _textDark,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "أرسل مشكلتك أو تواصل معنا مباشرة.",
                              style: TextStyle(
                                color: _textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // نموذج إرسال رسالة
                _card(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "إرسال رسالة",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _messageCtrl,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: "اكتب مشكلتك أو اقتراحك هنا...",
                            hintStyle: const TextStyle(color: _textMuted),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: _border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: _border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: _primary),
                            ),
                          ),
                          validator: (v) {
                            final text = (v ?? "").trim();
                            if (text.isEmpty) return "اكتب رسالة أولاً.";
                            if (text.length < 10) return "الرسالة قصيرة جدًا.";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _sending ? null : _sendTicket,
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _sending ? "جارِ الإرسال..." : "إرسال",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // معلومات التواصل
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "تواصل معنا",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _contactRow(
                        icon: FontAwesomeIcons.instagram,
                        title: "إنستغرام",
                        value: "@$instagramUsername",
                        iconColor: const Color(0xFFE1306C),
                        onOpen: _openInstagram,
                      ),

                      _contactRow(
                        icon: Icons.mail_outline_rounded,
                        title: "البريد الإلكتروني",
                        value: supportEmail,
                        iconColor: const Color(0xFF2563EB),
                        onOpen: _openEmail,
                      ),

                      _contactRow(
                        icon: FontAwesomeIcons.whatsapp,
                        title: "واتساب",
                        value: whatsappNumber,
                        iconColor: const Color(0xFF25D366),
                        onOpen: _openWhatsApp,
                      ),
                    ],
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
