import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/checklist_item.dart';
import '../../repositories/sections_repository.dart';

final checklistItemsProvider = FutureProvider.autoDispose
    .family<List<ChecklistItem>, String>((ref, sectionId) async {
  final repo = ref.watch(sectionsRepositoryProvider);
  return repo.fetchChecklistItems(sectionId);
});

class ChecklistSection extends ConsumerStatefulWidget {
  final String sectionId;
  final bool isOwner;

  const ChecklistSection({
    super.key,
    required this.sectionId,
    required this.isOwner,
  });

  @override
  ConsumerState<ChecklistSection> createState() => _ChecklistSectionState();
}

class _ChecklistSectionState extends ConsumerState<ChecklistSection> {
  final _newItemController = TextEditingController();

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  Future<void> _toggleItem(ChecklistItem item) async {
    final repo = ref.read(sectionsRepositoryProvider);
    final updated = item.copyWith(isCompleted: !item.isCompleted);
    try {
      await repo.updateChecklistItem(updated);
      ref.refresh(checklistItemsProvider(widget.sectionId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update item')),
        );
      }
    }
  }

  Future<void> _addItem() async {
    final text = _newItemController.text.trim();
    if (text.isEmpty) return;

    final repo = ref.read(sectionsRepositoryProvider);
    final items =
        ref.read(checklistItemsProvider(widget.sectionId)).valueOrNull ?? [];
    final nextOrder = (items
            .map((e) => e.orderIndex)
            .fold<int>(-1, (a, b) => a > b ? a : b)) +
        1;

    try {
      await repo.addChecklistItem(
        sectionId: widget.sectionId,
        text: text,
        orderIndex: nextOrder,
      );
      if (mounted) {
        _newItemController.clear();
        setState(() {});
        ref.refresh(checklistItemsProvider(widget.sectionId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add item: $e')),
        );
      }
    }
  }

  Future<void> _renameItem(ChecklistItem item) async {
    final controller = TextEditingController(text: item.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Item text'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null &&
        result.trim().isNotEmpty &&
        result.trim() != item.text) {
      final repo = ref.read(sectionsRepositoryProvider);
      try {
        await repo.updateChecklistItem(item.copyWith(text: result.trim()));
        ref.refresh(checklistItemsProvider(widget.sectionId));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to rename item')),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(ChecklistItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(sectionsRepositoryProvider);
      try {
        await repo.deleteChecklistItem(item.id);
        ref.refresh(checklistItemsProvider(widget.sectionId));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete item')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(checklistItemsProvider(widget.sectionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.checklist, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Checklist',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C2C2E),
              ),
            ),
            // Both owners and executors can tick items off, so the section
            // is never read-only. Only add/rename/delete are owner-only.
            const Spacer(),
            asyncItems.maybeWhen(
              data: (items) {
                final completed = items.where((e) => e.isCompleted).length;
                return Text(
                  '$completed/${items.length}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        asyncItems.when(
          loading: () => const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )),
          error: (error, _) =>
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
          data: (items) {
            if (items.isEmpty && !widget.isOwner) {
              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No checklist items yet.'),
                  ),
                ),
              );
            }
            return Column(
              children: [
                ...items.map((item) => _buildItemRow(item)),
                if (widget.isOwner) _buildAddRow(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildItemRow(ChecklistItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _toggleItem(item),
            child: Icon(
              item.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: item.isCompleted ? Colors.green : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: item.isCompleted ? Colors.grey : const Color(0xFF2C2C2E),
                decoration:
                    item.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (widget.isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'rename') _renameItem(item);
                if (value == 'delete') _deleteItem(item);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAddRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _newItemController,
              decoration: const InputDecoration(
                hintText: 'Add a new item...',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _addItem(),
            ),
          ),
          IconButton(
            onPressed: _addItem,
            icon: const Icon(Icons.add_circle, color: Color(0xFF3A8D5A)),
          ),
        ],
      ),
    );
  }
}
