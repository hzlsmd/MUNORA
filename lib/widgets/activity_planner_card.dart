import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import '../services/activity_planner.dart';
import '../services/planner_preferences.dart';
import '../services/weather_insights.dart';
import '../services/rain_model.dart';
import '../theme.dart';
import 'atmosphere.dart';
import 'ai_rain_plan_advice.dart';

class ActivityPlannerCard extends StatefulWidget {
  final String city;
  final WeatherInsights? insights;
  final WeatherSnapshot? weather;
  final RainModelLoader? rainModelLoader;
  const ActivityPlannerCard({
    super.key,
    required this.city,
    required this.insights,
    this.weather,
    this.rainModelLoader,
  });
  @override
  State<ActivityPlannerCard> createState() => _ActivityPlannerCardState();
}

class _ActivityPlannerCardState extends State<ActivityPlannerCard> {
  final store = PlannerPreferences();
  Activity activity = Activity.walk;
  late DateTime start;
  int duration = 1, revision = 0;
  bool touched = false, checked = false, busy = false;
  ActivityRoutine? routine;
  String? previousSummary, error;
  Future<void> writes = Future.value();
  DateTime get now => DateTime.now().toUtc();
  DateTime nextHour(DateTime time) {
    final hour = DateTime.utc(time.year, time.month, time.day, time.hour);
    return hour.isBefore(time) ? hour.add(const Duration(hours: 1)) : hour;
  }

  String get planKey => '${activity.name}:${start.toIso8601String()}:$duration';
  @override
  void initState() {
    super.initState();
    start = nextHour(now);
    loadRoutine();
  }

  Future<void> loadRoutine() async {
    try {
      final saved = await store.loadRoutine(widget.city);
      if (!mounted || touched) return;
      if (saved != null) {
        setState(() {
          routine = saved;
          activity = saved.activity;
          duration = saved.durationHours;
          start = saved.nextStart(now);
        });
        await check();
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Saved preferences could not be loaded.');
      }
    }
  }

  @override
  void didUpdateWidget(covariant ActivityPlannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insights != widget.insights && checked) check();
  }

  void change(VoidCallback action) {
    touched = true;
    revision++;
    setState(() {
      action();
      checked = false;
      previousSummary = null;
      error = null;
    });
  }

  Future<void> check() async {
    final id = ++revision, key = planKey, city = widget.city;
    final result = assessActivity(
      widget.insights,
      activity,
      start,
      duration,
      now,
    );
    setState(() {
      checked = true;
      previousSummary = null;
    });
    try {
      await writes;
      final previous = await store.lastAssessment(city);
      if (!mounted || id != revision) return;
      if (previous?['plan'] == key &&
          previous?['summary'] is String &&
          previous!['summary'] != result.summary) {
        setState(() => previousSummary = previous['summary'] as String);
      }
      // An outage is not a forecast change and must not erase the last valid comparison.
      if (result.status != PlanStatus.unavailable) {
        writes = writes
            .then((_) => store.saveAssessment(city, key, result.summary))
            .catchError((Object _) {
              if (mounted) {
                setState(
                  () => error = 'Previous assessment could not be saved.',
                );
              }
            });
        await writes;
      }
    } catch (_) {
      if (mounted && id == revision) {
        setState(() => error = 'Previous assessment could not be loaded.');
      }
    }
  }

  Future<void> save(bool remove) async {
    touched = true;
    final city = widget.city;
    final next = remove
        ? null
        : ActivityRoutine(
            activity: activity,
            hour: manilaTime(start).hour,
            durationHours: duration,
          );
    setState(() => busy = true);
    try {
      await store.saveRoutine(city, next);
      if (mounted) {
        setState(() {
          routine = next;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Routine could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = now;
    final first = nextHour(current);
    final choices = List.generate(
      36,
      (i) => first.add(Duration(hours: i)),
    ).where((h) => !h.isAfter(current.add(const Duration(hours: 36)))).toList();
    if (!choices.contains(start)) choices.insert(0, start);
    final result = assessActivity(
      widget.insights,
      activity,
      start,
      duration,
      current,
    );
    final better = checked
        ? findBetterWindow(widget.insights, activity, start, duration, current)
        : null;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Plan My Activity',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          routine == null
              ? 'Personalized, forecast-based guidance'
              : 'Daily ${routine!.activity.label.toLowerCase()} · ${routine!.hour.toString().padLeft(2, '0')}:00 PHT',
          style: const TextStyle(fontSize: 12, color: AppColors.indigo),
        ),
        children: [
          const Text(
            'Choose your activity and a time in the next 36 hours. All times use Philippine time.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: Activity.values
                .map(
                  (a) => ChoiceChip(
                    label: Text(a.label),
                    selected: activity == a,
                    onSelected: (_) => change(() => activity = a),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Start time (PHT)'),
          ),
          DropdownButton<DateTime>(
            value: start,
            isExpanded: true,
            items: choices
                .map(
                  (at) => DropdownMenuItem(
                    value: at,
                    child: Text(
                      '${at.isBefore(current) ? 'Expired: ' : ''}${weatherTime(at)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: (at) {
              if (at != null) change(() => start = at);
            },
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final hours in [1, 2, 3])
                ChoiceChip(
                  label: Text('$hours ${hours == 1 ? 'hour' : 'hours'}'),
                  selected: duration == hours,
                  onSelected: (_) => change(() => duration = hours),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: check, child: const Text('Check this plan')),
          if (checked) ...[
            const SizedBox(height: 12),
            Text(
              result.status.label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              '${weatherTime(start)} – ${weatherTime(start.add(Duration(hours: duration)))}',
              style: const TextStyle(fontSize: 12),
            ),
            if (previousSummary != null &&
                result.status != PlanStatus.unavailable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Forecast changed since your last check. Previously: $previousSummary',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            for (final reason in result.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(reason, style: const TextStyle(fontSize: 13)),
              ),
            for (final precaution in result.precautions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  precaution,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (widget.weather != null) ...[
              const SizedBox(height: 8),
              AIRainPlanAdvice(
                weather: widget.weather!,
                activity: activity,
                start: start,
                durationHours: duration,
                loader: widget.rainModelLoader,
              ),
              const SizedBox(height: 8),
            ],
            if (better != null) ...[
              const SizedBox(height: 8),
              const Text(
                'A better forecast window',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${weatherTime(better.start)} – ${weatherTime(better.start.add(Duration(hours: duration)))}',
                style: const TextStyle(fontSize: 13),
              ),
              for (final reason in better.reasons)
                Text(reason, style: const TextStyle(fontSize: 12)),
              TextButton(
                onPressed: () => change(() => start = better.start),
                child: const Text('Use this time'),
              ),
            ] else
              const Text(
                'No better daytime window with complete data was found.',
                style: TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            const Text(
              'Planning guidance, not a safety guarantee. Recheck conditions and official advisories before leaving.',
              style: TextStyle(fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : () => save(false),
                child: Text(
                  routine == null
                      ? 'Save daily routine'
                      : 'Update daily routine',
                ),
              ),
              if (routine != null)
                TextButton(
                  onPressed: busy ? null : () => save(true),
                  child: const Text('Remove routine'),
                ),
            ],
          ),
          const Text(
            'Optional routine saved on this device for this city. It checks the next occurrence when you open Tips; it does not schedule notifications.',
            style: TextStyle(fontSize: 11),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
