import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../controllers/lifecycle_controller.dart';

/// The coach's approval queue for AI-drafted automated messages. Reuses the
/// Stage-1 approve pattern: each draft is fully editable; nothing is delivered
/// until the coach taps Approve & send.
class LifecycleApprovalsScreen extends StatefulWidget {
  const LifecycleApprovalsScreen({super.key});

  @override
  State<LifecycleApprovalsScreen> createState() =>
      _LifecycleApprovalsScreenState();
}

class _LifecycleApprovalsScreenState extends State<LifecycleApprovalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LifecycleController>().loadDrafts(),
    );
  }

  String _label(String type) {
    final match = kLifecycleEvents.where((e) => e.type == type);
    return match.isNotEmpty ? match.first.label : type;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LifecycleController>();
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SporveIconButton(Icons.arrow_back, onTap: () => Get.back()),
        ),
        title: Text(
          'Approval queue',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ctrl.loadingDrafts
          ? const Center(
              child: SkeletonList(),
            )
          : ctrl.drafts.isEmpty
          ? Center(
              child: Text(
                'No drafts waiting for approval.',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Review and edit each message, then send. Nothing is delivered '
                  'until you tap Approve & send.',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                for (final d in ctrl.drafts)
                  _DraftCard(
                    key: ValueKey(d['id']),
                    id: d['id'].toString(),
                    eventLabel: _label(d['eventType']?.toString() ?? ''),
                    initialBody: d['body']?.toString() ?? '',
                  ),
              ],
            ),
    );
  }
}

class _DraftCard extends StatefulWidget {
  final String id;
  final String eventLabel;
  final String initialBody;
  const _DraftCard({
    super.key,
    required this.id,
    required this.eventLabel,
    required this.initialBody,
  });

  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  late final TextEditingController _body = TextEditingController(
    text: widget.initialBody,
  );
  bool _sending = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    final text = _body.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final err = await context.read<LifecycleController>().approveAndSend(
      widget.id,
      text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    Get.snackbar(
      err == null ? 'Sent' : 'Could not send',
      err ?? 'Your message was sent.',
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinePill(widget.eventLabel),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.hairline),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: _body,
              minLines: 2,
              maxLines: 6,
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
              cursorColor: AppColors.slateText,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _sending ? null : _approve,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.slate,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_sending)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onSlate,
                        ),
                      )
                    else
                      const Icon(
                        Icons.send,
                        size: 15,
                        color: AppColors.onSlate,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _sending ? 'Sending…' : 'Approve & send',
                      style: AppTypography.font(
                        color: AppColors.onSlate,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
