import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: const Padding(
        padding: EdgeInsets.all(pagePadding),
        child: Center(
          child: Text('Library coming soon'),
        ),
      ),
    );
  }
}
