import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import '../data/legal_service.dart';
import '../domain/legal_document.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.service});

  final LegalService service;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late Future<List<LegalDocument>> _documents;

  @override
  void initState() {
    super.initState();
    _documents = widget.service.listDocuments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenScaffold(
        title: 'Yasal Metinler',
        subtitle: 'KVKK, gizlilik, kullanım şartları ve sorumluluk reddi.',
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: FutureBuilder<List<LegalDocument>>(
          future: _documents,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final bySlug = {
              for (final document in snapshot.data!) document.slug: document
            };
            const items = [
              _LegalListItem(
                  label: 'KVKK Aydınlatma Metni', slug: 'kvkk-clarification'),
              _LegalListItem(
                  label: 'Açık Rıza Metni', slug: 'explicit-consent'),
              _LegalListItem(
                  label: 'Gizlilik Politikası', slug: 'privacy-policy'),
              _LegalListItem(label: 'Kullanım Şartları', slug: 'terms-of-use'),
              _LegalListItem(label: 'Sorumluluk Reddi', slug: 'disclaimer'),
              _LegalListItem(
                  label: 'Mesafeli Satış Sözleşmesi',
                  slug: 'distance-sales-agreement'),
              _LegalListItem(
                  label: 'İptal ve İade Politikası',
                  slug: 'cancellation-refund-policy'),
              _LegalListItem(label: 'Sıkça Sorulan Sorular', slug: 'faq'),
            ];

            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final document = bySlug[item.slug];
                return SoftCard(
                  onTap: () => _openDocument(item.slug),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.article_outlined,
                          color: EnisColors.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label,
                                style: Theme.of(context).textTheme.titleMedium),
                            if (document != null)
                              Text(
                                'Sürüm ${document.version}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDocument(String slug) async {
    final document = await widget.service.getDocument(slug);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDetailScreen(document: document)),
    );
  }
}

class LegalDetailScreen extends StatelessWidget {
  const LegalDetailScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenScaffold(
        title: document.title,
        subtitle: 'Sürüm ${document.version}',
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SoftCard(
          child: SingleChildScrollView(
            child: Text(document.content,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      ),
    );
  }
}

class _LegalListItem {
  const _LegalListItem({required this.label, required this.slug});

  final String label;
  final String slug;
}
