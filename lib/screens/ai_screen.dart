import 'dart:math';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';

class AIScreen extends StatefulWidget {
  final ValueChanged<AppScreen> navigate;
  const AIScreen({super.key, required this.navigate});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  bool chatOpen = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: AppColors.bg,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        decoration: const BoxDecoration(gradient: AppColors.indigoGradient),
                        child: SafeArea(
                          bottom: false,
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => widget.navigate(AppScreen.home),
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0x33FFFFFF),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0x4DFFFFFF)),
                                  ),
                                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('MUNORA AI', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                                  SizedBox(height: 2),
                                  Text('Personalized for your location', style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12)),
                                ],
                              ),
                              const Spacer(),
                              const Text('✨', style: TextStyle(fontSize: 28)),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          children: [
                            // AI insight
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: cardDecoration(
                                color: const Color(0xFFF5F3FF),
                                border: Border.all(color: const Color(0xFFE0E7FF), width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Text('✨', style: TextStyle(fontSize: 18)),
                                      SizedBox(width: 8),
                                      Text("Today's MUNORA Insight",
                                          style: TextStyle(color: AppColors.indigo, fontSize: 13, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '"Rain is likely later this afternoon. Consider bringing an umbrella and avoid low-lying areas if rainfall becomes heavy."',
                                    style: TextStyle(color: Color(0xFF374151), fontSize: 14, height: 1.6),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDE9FE),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: const Color(0xFFC4B5FD)),
                                    ),
                                    child: const Text('✨ AI-Generated Insight',
                                        style: TextStyle(color: AppColors.indigo, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Recommendations
                            ...aiRecommendations.map((r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: cardDecoration(),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(color: const Color(0xFFEEF6FF), borderRadius: BorderRadius.circular(14)),
                                          alignment: Alignment.center,
                                          child: Text(r['emoji']!, style: const TextStyle(fontSize: 22)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(r['title']!, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 2),
                                              Text(r['desc']!, style: const TextStyle(color: AppColors.textGray, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                            // Confidence
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: cardDecoration(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Prediction Confidence', style: TextStyle(color: AppColors.textBody, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(99),
                                          child: Container(
                                            height: 8,
                                            color: const Color(0xFFE5E7EB),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: 0.85,
                                              child: Container(decoration: const BoxDecoration(gradient: AppColors.indigoGradient)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('85%', style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Based on current weather data and recent weather patterns.',
                                      style: TextStyle(color: AppColors.textGray, fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // CTA
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => setState(() => chatOpen = true),
                                icon: const Icon(Icons.add_box_outlined, size: 16, color: Colors.white),
                                label: const Text("Ask AI About Today's Weather ›", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 4,
                                  shadowColor: const Color(0x596366F1),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              BottomNav(active: AppScreen.ai, onNavigate: widget.navigate),
            ],
          ),
        ),
        if (chatOpen) _ChatModal(onClose: () => setState(() => chatOpen = false)),
      ],
    );
  }
}

class _ChatMessage {
  final bool fromUser;
  final String text;
  const _ChatMessage(this.fromUser, this.text);
}

class _ChatModal extends StatefulWidget {
  final VoidCallback onClose;
  const _ChatModal({required this.onClose});

  @override
  State<_ChatModal> createState() => _ChatModalState();
}

class _ChatModalState extends State<_ChatModal> {
  final List<_ChatMessage> messages = [];
  final TextEditingController controller = TextEditingController();
  bool typing = false;
  final rand = Random();

  void sendMessage() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(_ChatMessage(true, text));
      controller.clear();
      typing = true;
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        messages.add(_ChatMessage(false, aiResponses[rand.nextInt(aiResponses.length)]));
        typing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: const Color(0x66142850),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              color: Colors.white,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(12)),
                              alignment: Alignment.center,
                              child: const Text('✨', style: TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ask MUNORA AI', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w700)),
                                Text('Powered by weather intelligence', style: TextStyle(color: AppColors.textGray, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: widget.onClose,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(color: AppColors.divider, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 16, color: Color(0xFF555555)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 200),
                      padding: const EdgeInsets.all(16),
                      child: messages.isEmpty && !typing
                          ? const Center(
                              child: Text("Ask me anything about today's weather…",
                                  style: TextStyle(color: AppColors.textGray, fontSize: 13)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: messages.length + (typing ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                if (i == messages.length) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(16)),
                                      child: const Text('···', style: TextStyle(color: AppColors.textGray, fontSize: 18, letterSpacing: 4)),
                                    ),
                                  );
                                }
                                final m = messages[i];
                                return Align(
                                  alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: m.fromUser ? AppColors.indigo : AppColors.divider,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!m.fromUser)
                                          const Padding(
                                            padding: EdgeInsets.only(bottom: 4),
                                            child: Text('✨ MUNORA AI', style: TextStyle(fontSize: 11, color: AppColors.indigo, fontWeight: FontWeight.w600)),
                                          ),
                                        Text(m.text,
                                            style: TextStyle(
                                                color: m.fromUser ? Colors.white : AppColors.textDark, fontSize: 13, height: 1.5)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            onSubmitted: (_) => sendMessage(),
                            decoration: InputDecoration(
                              hintText: "Ask about today's weather…",
                              hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF5F7FA),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: sendMessage,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: AppColors.indigo, borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.send, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
