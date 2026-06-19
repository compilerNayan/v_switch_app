import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/models/presence_activity.dart';
import '../../core/providers/device_presence_activity_provider.dart';
import '../../shared/widgets/device_scaffold_actions.dart';

class PresenceActivityScreen extends ConsumerStatefulWidget {
  const PresenceActivityScreen({super.key});

  @override
  ConsumerState<PresenceActivityScreen> createState() =>
      _PresenceActivityScreenState();
}

class _PresenceActivityScreenState extends ConsumerState<PresenceActivityScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _selectToday() {
    setState(() => _selectedDate = DateTime.now());
  }

  void _selectYesterday() {
    setState(() => _selectedDate = DateTime.now().subtract(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(presenceActivityProvider);
    final selectedKey = presenceDateKey(_selectedDate);
    final dateLabel = DateFormat.yMMMd().format(_selectedDate);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: const DeviceBackButton(),
            title: const DeviceScreenTitle(fallback: 'Activity'),
            actions: [
              IconButton(
                tooltip: 'Pick date',
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Today'),
                    selected: presenceDateKey(DateTime.now()) == selectedKey,
                    onSelected: (_) => _selectToday(),
                  ),
                  ChoiceChip(
                    label: const Text('Yesterday'),
                    selected: presenceDateKey(
                          DateTime.now().subtract(const Duration(days: 1)),
                        ) ==
                        selectedKey,
                    onSelected: (_) => _selectYesterday(),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.event, size: 18),
                    label: Text(dateLabel),
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),
          ),
          activityAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error is ApiException
                        ? error.error.message
                        : 'Failed to load activity: $error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            data: (response) {
              final day = presenceDayForDate(response, _selectedDate);
              if (day == null) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No activity recorded for this day.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      day.summaryLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (day.segments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No online/offline transitions recorded.'),
                    )
                  else
                    ...day.segments.map((segment) => _SegmentTile(segment: segment)),
                  const SizedBox(height: 24),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({required this.segment});

  final PresenceSegment segment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (segment.isBoot) {
      return ListTile(
        leading: Icon(Icons.restart_alt, color: Colors.orange.shade700, size: 20),
        title: const Text('Restarted'),
        subtitle: Text('Restarted at ${segment.bootTimeLabel}'),
      );
    }

    final color = segment.isOnline ? Colors.green.shade600 : colorScheme.outline;
    final label = segment.isOnline ? 'Online' : 'Offline';
    final duration = formatPresenceDuration(segment.durationSeconds);

    return ListTile(
      leading: Icon(Icons.circle, color: color, size: 14),
      title: Text(label),
      subtitle: Text(
        '$label for $duration (${segment.timeRangeLabel})',
      ),
    );
  }
}
