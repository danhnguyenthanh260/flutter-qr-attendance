import 'package:flutter/material.dart';

import '../app/widgets/workspace_navigation.dart';
import '../core/theme/app_theme.dart';
import '../core/ui/notice_card.dart';

void main() =>
    runApp(MaterialApp(theme: AppTheme.light, home: const ComponentGallery()));

/// Separate development entrypoint: never routed from the production app.
class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});
  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  int selected = 0;
  NoticeKind kind = NoticeKind.empty;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: [
        WorkspaceNavigation(
          selectedIndex: selected,
          onSelected: (value) => setState(() => selected = value),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Component gallery',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  for (final value in NoticeKind.values)
                    ChoiceChip(
                      label: Text(value.name),
                      selected: kind == value,
                      onSelected: (_) => setState(() => kind = value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              NoticeCard(
                kind: kind,
                message: switch (kind) {
                  NoticeKind.loading => 'Đang tải danh sách lớp…',
                  NoticeKind.empty =>
                    'Chưa có dữ liệu lớp. Chọn file để xem trước danh sách.',
                  NoticeKind.error =>
                    'Chưa kết nối được máy chủ. Dữ liệu đang xem được giữ lại.',
                  NoticeKind.info => 'Chọn lớp và ca học để bắt đầu điểm danh.',
                },
                onRetry: kind == NoticeKind.error
                    ? () => setState(() => kind = NoticeKind.loading)
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {},
                child: const Text('Bắt đầu phiên điểm danh'),
              ),
              const SizedBox(height: 12),
              const FilledButton(
                onPressed: null,
                child: Text('Đang xác minh phiên…'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
