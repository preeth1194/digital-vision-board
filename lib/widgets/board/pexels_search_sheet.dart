import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/stock_images_service.dart';

Future<String?> showPexelsSearchSheet(
  BuildContext context, {
  String? initialQuery,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _PexelsSearchSheet(initialQuery: initialQuery),
  );
}

class _PexelsSearchSheet extends StatefulWidget {
  final String? initialQuery;
  const _PexelsSearchSheet({required this.initialQuery});

  @override
  State<_PexelsSearchSheet> createState() => _PexelsSearchSheetState();
}

class _PexelsSearchSheetState extends State<_PexelsSearchSheet> {
  late final TextEditingController _qC;
  bool _loading = false;
  String? _error;
  List<String> _urls = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _qC = TextEditingController(text: (widget.initialQuery ?? '').trim());
    // First load (if query present).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_qC.text.trim().isNotEmpty) _search();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qC.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final q = _qC.text.trim();
    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
        _urls = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final urls = await StockImagesService.searchPexelsUrls(query: q, perPage: 24);
      if (!mounted) return;
      setState(() {
        _urls = urls;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load images.';
        _urls = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Search from web (Pexels)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _qC,
              textInputAction: TextInputAction.search,
              onChanged: (_) => _scheduleSearch(),
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search (e.g., “Mindfulness minimal calm”)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_error ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            else if (_urls.isEmpty && _qC.text.trim().isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No results. Try another search.'),
              )
            else
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _urls.length,
                  itemBuilder: (ctx, i) {
                    final url = _urls[i];
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

