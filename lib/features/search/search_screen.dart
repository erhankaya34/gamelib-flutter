import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: const Padding(
        padding: EdgeInsets.all(pagePadding),
        child: Center(
          child: Text('Search coming soon'),
        ),
      ),
    );
  }
}
