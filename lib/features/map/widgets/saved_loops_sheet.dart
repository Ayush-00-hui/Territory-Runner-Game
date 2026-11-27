import 'package:flutter/material.dart';

import '../../../models/saved_loop.dart';
import '../../../services/saved_loop_service.dart';
import '../../../ui/ui.dart';

/// Sheet displaying saved loops with stats (distance, area, runs, PB)
/// and a one-tap action to follow the route on the map.
class SavedLoopsSheet extends StatefulWidget {
  final SavedLoopService? loopService;
  final ValueChanged<SavedLoop> onStartLoop;

  const SavedLoopsSheet({
    super.key,
    this.loopService,
    required this.onStartLoop,
  });

  static Future<void> show({
    required BuildContext context,
    SavedLoopService? loopService,
    required ValueChanged<SavedLoop> onStartLoop,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          SavedLoopsSheet(loopService: loopService, onStartLoop: onStartLoop),
    );
  }

  @override
  State<SavedLoopsSheet> createState() => _SavedLoopsSheetState();
}

class _SavedLoopsSheetState extends State<SavedLoopsSheet> {
  late final SavedLoopService _service;
  List<SavedLoop>? _loops;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.loopService ?? SavedLoopService();
    _loadLoops();
  }

  Future<void> _loadLoops() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final loops = await _service.getSavedLoops();
    if (mounted) {
      setState(() {
        _loops = loops;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLoop(SavedLoop loop) async {
    await _service.deleteLoop(loop.id);
    _loadLoops();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Saved Loops',
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.s32),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          : (_loops == null || _loops!.isEmpty)
          ? _buildEmptyState()
          : _buildLoopList(),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alt_route_rounded,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'No saved loops yet',
            style: AppText.heading3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'After finishing a run or planning a claim, tap "Save loop" to re-run your favourite routes anytime.',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s24),
        ],
      ),
    );
  }

  Widget _buildLoopList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _loops!.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
      itemBuilder: (context, index) {
        final loop = _loops![index];
        final distKm = (loop.distanceMeters / 1000.0).toStringAsFixed(2);
        final areaSqM = loop.areaSqMeters.toStringAsFixed(0);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      loop.name,
                      style: AppText.heading4.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => _deleteLoop(loop),
                    tooltip: 'Delete loop',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  _statChip(Icons.straighten_rounded, '$distKm km'),
                  const SizedBox(width: AppSpacing.s12),
                  _statChip(Icons.crop_square_rounded, '$areaSqM m²'),
                  const SizedBox(width: AppSpacing.s12),
                  _statChip(Icons.repeat_rounded, '${loop.runCount} runs'),
                ],
              ),
              if (loop.bestTimeSeconds != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Best time: ${_formatDuration(loop.bestTimeSeconds!)}',
                  style: AppText.micro.copyWith(color: AppColors.accent),
                ),
              ],
              const SizedBox(height: AppSpacing.s12),
              PrimaryButton(
                label: 'Run this loop',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onStartLoop(loop);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.s4),
        Text(
          text,
          style: AppText.label.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
