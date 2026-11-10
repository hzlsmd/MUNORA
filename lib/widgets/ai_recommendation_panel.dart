import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import '../services/ai_service.dart';
import '../theme.dart';

/// AI supplements the fixed assessment above it; never replaces hazard rules.
class AiRecommendationPanel extends StatefulWidget {
  final AiPlan? plan;
  final AiService? service;
  final DateTime Function()? now;
  const AiRecommendationPanel({
    super.key,
    required this.plan,
    required this.service,
    this.now,
  });
  @override
  State<AiRecommendationPanel> createState() => _AiRecommendationPanelState();
}

class _AiRecommendationPanelState extends State<AiRecommendationPanel>
    with WidgetsBindingObserver {
  DateTime get now => widget.now?.call().toUtc() ?? DateTime.now().toUtc();
  AiRecommendation? advice;
  String? error;
  bool busy = false;
  int revision = 0;
  Timer? expiry;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleExpiry();
  }

  void expire() {
    if (!mounted) return;
    revision++;
    setState(() {
      advice = null;
      busy = false;
      error = 'This recommendation has expired. Check your plan again.';
    });
  }

  void scheduleExpiry() {
    expiry?.cancel();
    final plan = widget.plan;
    if (plan == null) return;
    final at = advice != null && advice!.expiresAt.isBefore(plan.validUntil)
        ? advice!.expiresAt
        : plan.validUntil;
    final delay = at.difference(now);
    expiry = Timer(delay.isNegative ? Duration.zero : delay, expire);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.plan != null &&
          (!widget.plan!.isFresh(now) ||
              advice != null && !advice!.isFresh(now))) {
        expiry?.cancel();
        expire();
      } else {
        scheduleExpiry();
      }
    }
  }

  @override
  void didUpdateWidget(covariant AiRecommendationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.plan?.key != oldWidget.plan?.key ||
        widget.service != oldWidget.service) {
      revision++;
      advice = null;
      error = null;
      busy = false;
      scheduleExpiry();
    }
  }

  @override
  void dispose() {
    revision++;
    expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> generate() async {
    final plan = widget.plan, service = widget.service;
    if (busy || plan == null || service == null) return;
    final id = ++revision;
    setState(() {
      busy = true;
      error = null;
      advice = null;
    });
    try {
      final result = await service.recommend(plan);
      if (mounted &&
          revision == id &&
          widget.plan?.key == plan.key &&
          plan.isFresh(now) &&
          result.isFresh(now)) {
        setState(() => advice = result);
        scheduleExpiry();
      }
    } catch (e) {
      if (mounted && revision == id) {
        setState(
          () => error = e is AiException ? e.message : 'AI advice is unavailable. Rule-based guidance remains available.',
        );
      }
    } finally {
      if (mounted && revision == id) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final available =
        plan != null && plan.isFresh(now) && widget.service?.configured == true;
    final visibleAdvice = available && advice?.isFresh(now) == true
        ? advice
        : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x99FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x557161E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI weather recommendations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.indigo,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Optional: share this city, activity, time window and forecast with Google Gemini through MUNORA to personalize your preparation advice. No name or precise location is sent. Google may use free-tier requests to improve its products.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
          if (plan != null) ...[
            const SizedBox(height: 8),
            Text(
              'Rule-based hazards: ${plan.hazards.isEmpty ? 'no configured triggers; recheck conditions' : plan.hazards.join(', ')}.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              'Forecast updated ${weatherTime(DateTime.parse(plan.payload['forecastUpdatedAt']))}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          if (!available)
            const Text(
              'AI advice is currently unavailable. Rule-based guidance remains available. Use a fresh, complete forecast to check your plan.',
              style: TextStyle(fontSize: 12),
            )
          else ...[
            FilledButton.icon(
              onPressed: busy ? null : generate,
              icon: const Icon(Icons.auto_awesome, size: 17),
              label: Text(
                busy
                    ? 'Preparing your recommendation…'
                    : 'Generate AI recommendation',
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: const TextStyle(fontSize: 12)),
            ),
          if (visibleAdvice != null) ...[
            const SizedBox(height: 12),
            const Text(
              'AI-generated recommendation',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.indigo,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              visibleAdvice.summary,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 8),
            for (final preparation in visibleAdvice.preparations)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '• $preparation',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            Text(
              'Why: ${visibleAdvice.reason}',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 6),
            Text(
              'Generated ${weatherTime(visibleAdvice.generatedAt)}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'AI can make mistakes. Follow the rule-based precautions above and check official PAGASA advisories. This is planning guidance, not an official warning.',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}
