import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../providers/catalogue_controller.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../utils/product_filters.dart';
import '../widgets/product_card.dart';
import '../widgets/status_panel.dart';
import 'product_detail_screen.dart';

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({
    super.key,
    required this.service,
    required this.onCart,
  });
  final ProductService service;
  final VoidCallback onCart;
  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  late final CatalogueController catalogue;
  final scroll = ScrollController();
  final search = TextEditingController();
  Timer? debounce;
  List<ProductCategory> categories = [];
  String? categoryError;
  bool categoriesLoading = true;
  @override
  void initState() {
    super.initState();
    catalogue = CatalogueController(widget.service)
      ..addListener(update)
      ..refresh();
    loadCategories();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 600) catalogue.loadMore();
    });
  }

  void update() {
    if (mounted) setState(() {});
  }

  Future<void> loadCategories() async {
    setState(() {
      categoriesLoading = true;
      categoryError = null;
    });
    try {
      final data = await widget.service.fetchCategories();
      if (mounted) setState(() => categories = data);
    } catch (_) {
      if (mounted) setState(() => categoryError = 'Could not load categories.');
    } finally {
      if (mounted) setState(() => categoriesLoading = false);
    }
  }

  void apply() {
    debounce?.cancel();
    catalogue.query = search.text;
    if (scroll.hasClients) scroll.jumpTo(0);
    catalogue.refresh();
  }

  void reset() {
    debounce?.cancel();
    search.clear();
    catalogue.reset();
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> selectCategories() async {
    final selection = {...catalogue.categories};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, sheetState) => FractionallySizedBox(
          heightFactor: .78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Shop by category',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => sheetState(selection.clear),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: categories
                      .map(
                        (c) => CheckboxListTile(
                          title: Text(c.name),
                          value: selection.contains(c.slug),
                          onChanged: (checked) => sheetState(() {
                            if (checked == true) {
                              selection.add(c.slug);
                            } else {
                              selection.remove(c.slug);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, selection),
                    child: const Text('Apply categories'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      catalogue.categories = result;
      apply();
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    scroll.dispose();
    catalogue.removeListener(update);
    catalogue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = catalogue.products;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: CustomScrollView(
          controller: scroll,
          key: const PageStorageKey('catalogue'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THE EVERYDAY, ELEVATED',
                      style: TextStyle(
                        color: AppTheme.emerald,
                        letterSpacing: 2,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Find your next\ngreat thing.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Thoughtful finds. A little everyday delight.',
                      style: TextStyle(color: AppTheme.slate),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: search,
                      onChanged: (_) {
                        setState(() {});
                        debounce?.cancel();
                        debounce = Timer(
                          const Duration(milliseconds: 350),
                          apply,
                        );
                      },
                      onSubmitted: (_) => apply(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search products',
                        labelText: 'Search products',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  search.clear();
                                  apply();
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: categoriesLoading
                              ? null
                              : categoryError != null
                              ? loadCategories
                              : selectCategories,
                          icon: const Icon(Icons.tune, size: 18),
                          label: Text(
                            categoriesLoading
                                ? 'Loading categories…'
                                : categoryError != null
                                ? 'Retry categories'
                                : catalogue.categories.isEmpty
                                ? 'Categories'
                                : 'Categories (${catalogue.categories.length})',
                          ),
                        ),
                        PopupMenuButton<ProductSort>(
                          tooltip: 'Sort products',
                          initialValue: catalogue.sort,
                          onSelected: (value) {
                            catalogue.sort = value;
                            apply();
                          },
                          itemBuilder: (_) => ProductSort.values
                              .map(
                                (s) => PopupMenuItem(
                                  value: s,
                                  child: Text(s.label),
                                ),
                              )
                              .toList(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sort, size: 20),
                                const SizedBox(width: 8),
                                Text(catalogue.sort.label),
                                const Icon(Icons.expand_more),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (categoryError != null)
                      Text(
                        categoryError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: PriceBand.values
                            .map(
                              (band) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(band.label),
                                  selected: catalogue.price == band,
                                  onSelected: (_) {
                                    catalogue.price = band;
                                    apply();
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (catalogue.isGlobal)
                      TextButton.icon(
                        onPressed: reset,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset Filters'),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            catalogue.isGlobal
                                ? 'Your selection'
                                : 'Discover the collection',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (!catalogue.loading && catalogue.error == null)
                          Text(
                            '${catalogue.resultCount} finds',
                            style: const TextStyle(color: AppTheme.slate),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (catalogue.loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (catalogue.error != null)
              SliverToBoxAdapter(
                child: StatusPanel(
                  icon: Icons.cloud_off_outlined,
                  title: 'Let’s try that again',
                  message: catalogue.error!,
                  action: 'Retry',
                  onAction: catalogue.refresh,
                ),
              )
            else if (products.isEmpty)
              SliverToBoxAdapter(
                child: StatusPanel(
                  icon: Icons.search_off,
                  title: 'No finds just yet',
                  message: 'Try a different search or open up your filters.',
                  action: 'Reset Filters',
                  onAction: reset,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) => ProductCard(
                    product: products[index],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductDetailScreen(
                          productId: products[index].id,
                          service: widget.service,
                          onCart: widget.onCart,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (catalogue.loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (catalogue.pageError != null)
              SliverToBoxAdapter(
                child: StatusPanel(
                  icon: Icons.wifi_off,
                  title: 'A little connection hiccup',
                  message: catalogue.pageError!,
                  action: 'Retry more products',
                  onAction: catalogue.retryMore,
                ),
              )
            else if (!catalogue.loading &&
                catalogue.error == null &&
                catalogue.hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextButton(
                    onPressed: catalogue.loadMore,
                    child: const Text('Load more'),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}
