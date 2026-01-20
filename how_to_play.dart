// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:game/ads/banner_ad_view.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  // نفس ألوان باقي الشاشات
  static const Color _primary = Color(0xFF2563EB);
  static const Color _surface = Colors.white;
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _purple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("كيف تلعب؟"),
          centerTitle: true,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBar: (Platform.isAndroid || Platform.isIOS)
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              children: [
                _headerCard(),
                const SizedBox(height: 12),

                _sectionTitle("الفكرة العامة"),
                const SizedBox(height: 8),
                _infoCard(
                  icon: Icons.quiz_rounded,
                  iconColor: _primary,
                  title: "أسئلة اختيار من متعدد",
                  body:
                      "اللعبة عبارة عن أسئلة اختيار من متعدد. كل إجابة صحيحة بتزيد نقاطك (XP) وبتساعدك ترفع المستوى (Level).",
                ),
                const SizedBox(height: 10),

                _sectionTitle("طريقة اللعب خطوة بخطوة"),
                const SizedBox(height: 8),
                _stepsCard([
                  _step(
                    icon: Icons.play_arrow_rounded,
                    color: _primary,
                    title: "ابدأ اللعب",
                    body:
                        "اضغط زر (ابدأ اللعب) ثم اختر الخيارات/المستوى حسب الشاشة اللي بتظهر لك. بالبداية مستواك يكون (Level 1) وبيكون المتاح فقط قسم الأسئلة العشوائية، وكل ما تتقدم بالمستوى بينفتح إلك نوع جديد من الأسئلة.",
                  ),
                  _step(
                    icon: Icons.lock_open_rounded,
                    color: _primary,
                    title: "فتح أقسام جديدة من الأسئلة",
                    body:
                        "بعض أنواع الأسئلة تكون مقفلة في البداية. "
                        "لفتح خيارات وأقسام جديدة، لازم ترفع مستواك (Level).\n\n"
                        "رفع المستوى يتم باستخدام نقاط الخبرة (XP) التي تجمعها من اللعب. "
                        "كما يمكنك استخدام XP من خلال المتجر داخل ملفك الشخصي لرفع مستواك بشكل أسرع.",
                  ),
                  _step(
                    icon: Icons.timer_outlined,
                    color: _warning,
                    title: "جاوب ضمن الوقت",
                    body:
                        "كل سؤال إله وقت محدد، ومعك 30 ثانية للإجابة. حاول تجاوب بسرعة قبل ما يخلص الوقت.",
                  ),
                  _step(
                    icon: Icons.check_circle_rounded,
                    color: _success,
                    title: "إجابة صحيحة = XP",
                    body:
                        "لما تجاوب صح بتاخد نقاط خبرة (XP)، وكل سؤال بتجاوب عليه صح بيزيدلك الخبرة +1، ومع تجميعها بتزيد مستوياتك.",
                  ),
                  _step(
                    icon: Icons.cancel_rounded,
                    color: _danger,
                    title: "إجابة خطأ",
                    body:
                        "الإجابة الخطأ ما بتزيد XP، وبتنحسب بإحصائياتك عشان تتابع تقدمك. كمان كل إجابة خاطئة بتخصم 3 من الخبرة (XP -3).",
                  ),
                  _step(
                    icon: Icons.trending_up_rounded,
                    color: _primary,
                    title: "رفع المستوى من المتجر",
                    body:
                        "بتقدر كمان ترفع مستواك من خلال شراء نقاط الخبرة (XP) من قائمة المشتريات داخل اللعبة، عشان تفتح أقسام جديدة أسرع وتنافس على الترتيب.",
                  ),
                ]),
                const SizedBox(height: 10),

                _sectionTitle("شات الإدارة (إعلانات)"),
                const SizedBox(height: 8),
                _infoCard(
                  icon: Icons.campaign_rounded,
                  iconColor: _warning,
                  title: "إعلانات الإدارة للجميع",
                  body:
                      "هذا الشات مخصص لإعلانات الإدارة فقط. اللاعب يقدر يقرأ الرسائل ويشوف الصور، لكن ما بقدر يرسل رسائل. ستظهر الرسالة مع اسم الإدارة والوقت.",
                ),
                const SizedBox(height: 10),

                _sectionTitle("اللعب ضد صديق (دعوات)"),
                const SizedBox(height: 8),
                _infoCard(
                  icon: Icons.group_rounded,
                  iconColor: _purple,
                  title: "دعوات المباراة",
                  body:
                      "تقدر تستقبل دعوة من لاعب آخر. الدعوة بتظهر في الرئيسية ضمن (دعوات الأصدقاء). إذا ما تم قبولها خلال وقت قصير، ممكن تنتهي تلقائيًا.",
                ),
                const SizedBox(height: 10),

                _sectionTitle("الأصدقاء وطلبات الصداقة"),
                const SizedBox(height: 8),
                _infoCard(
                  icon: Icons.people_alt_rounded,
                  iconColor: _primary,
                  title: "أضف أصحابك بسهولة",
                  body:
                      "من (قائمة اللاعبين) بتقدر ترسل طلب صداقة. بعد القبول بصير صديق عندك وتقدر تتفاعلوا داخل اللعبة.",
                ),
                const SizedBox(height: 10),

                _sectionTitle("النقاط (XP) والمستويات"),
                const SizedBox(height: 8),
                _infoCard(
                  icon: Icons.bolt_rounded,
                  iconColor: _primary,
                  title: "شو يعني XP وليفل؟",
                  body:
                      "XP هي نقاط خبرة بتجمعها من الإجابات الصحيحة. كل ما تزيد XP بتترقى Level وبتصير بمركز أقوى في الترتيب.",
                ),
                const SizedBox(height: 10),

                _sectionTitle("الإعلانات والأدوات داخل اللعبة"),
                const SizedBox(height: 8),
                _infoCard(
                  icon: Icons.celebration_rounded,
                  iconColor: _success,
                  title: "احصل على مزايا إضافية",
                  body:
                      "تقدر تشاهد إعلانات داخل اللعبة وتستفيد منها حسب نظام التطبيق، وتقدر تستخدم/تجمع أدوات مساعدة (مثل زيادة وقت أو حذف خيارات… حسب المتاح عندك).",
                ),
                const SizedBox(height: 10),
                _sectionTitle("سياسة اللعب النظيف"),
                const SizedBox(height: 8),
                _infoCard(
                  icon: Icons.warning_amber_rounded,
                  iconColor: _danger,
                  title: "الغش والعقوبات",
                  body:
                      "اللعبة تعتمد على اللعب النظيف. يتم تسجيل كل محاولة غش تلقائيًا "
                      "في حساب اللاعب.\n\n"
                      "⚠️ كلما زاد عدد محاولات الغش، يتم استبعاد اللاعب من المنافسة على "
                      "الجوائز والمكافآت، حتى لو كان ترتيبه متقدم.\n\n"
                      "الهدف هو ضمان العدالة بين جميع اللاعبين.",
                ),
                const SizedBox(height: 10),
                _sectionTitle("الترتيب والفائزين"),
                const SizedBox(height: 8),
                _infoCard(
                  icon: Icons.emoji_events_rounded,
                  iconColor: _warning,
                  title: "نافس الناس على الترتيب",
                  body:
                      "في شاشة (الفائزين بالدوريات) بتشوف أفضل اللاعبين. ترتيب اللاعبين عادة يعتمد على Level ثم XP. يتم إعلان الفائزين مع نهاية كل دوري/موسم، وبعدها فريق الإدارة بيتواصل مع الفائزين لتسليم الجوائز حسب الطرق المتاحة والمتفق عليها بين الطرفين.",
                ),
                const SizedBox(height: 10),

                _sectionTitle("الدعم الفني"),
                const SizedBox(height: 8),
                _infoCard(
                  icon: Icons.support_agent_rounded,
                  iconColor: _success,
                  title: "تواصل معنا إذا واجهتك مشكلة",
                  body:
                      "إذا واجهتك أي مشكلة أو عندك استفسار، تقدر ترسل (تذكرة) مباشرة من داخل التطبيق عبر شاشة (الدعم الفني). "
                      "وكمان متاح التواصل خارج التطبيق من خلال الروابط والمواقع المعروضة داخل قائمة الدعم الفني، حسب الوسيلة الأنسب لك.",
                ),
                const SizedBox(height: 10),

                _sectionTitle("ملفك الشخصي"),
                const SizedBox(height: 8),
                _infoCard(
                  icon: Icons.person_rounded,
                  iconColor: _primary,
                  title: "تابع تقدمك وإحصائياتك",
                  body:
                      "في ملفك بتشوف: الاسم، الإيميل، Player ID، المستوى، XP، عدد الفوز ضد الأصدقاء (إن وجد)، وإحصائياتك وأدواتك.",
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _outlineButton(
                        context,
                        text: "رجوع",
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
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

  // ---------- UI Pieces ----------

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _primary.withOpacity(0.12),
            child: const Icon(Icons.info_outline_rounded, color: _primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "مرحبًا 👋",
                  style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "هنا شرح سريع وبسيط لكل شيء داخل اللعبة.",
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
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: const TextStyle(
          color: _textDark,
          fontWeight: FontWeight.w900,
          fontSize: 14.5,
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: iconColor.withOpacity(0.12),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: _textMuted,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepsCard(List<Widget> steps) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            steps[i],
            if (i != steps.length - 1) ...[
              const SizedBox(height: 10),
              Divider(color: _border.withOpacity(0.85)),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  Widget _step({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                body,
                style: const TextStyle(
                  color: _textMuted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _outlineButton(
    BuildContext context, {
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _textDark,
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
