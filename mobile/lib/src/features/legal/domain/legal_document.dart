class LegalDocument {
  const LegalDocument({
    required this.slug,
    required this.title,
    required this.version,
    required this.updatedAt,
    required this.content,
  });

  final String slug;
  final String title;
  final String version;
  final String updatedAt;
  final String content;

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    final content = rawContent is List
        ? rawContent.map((item) => item.toString()).join('\n\n')
        : rawContent?.toString() ?? '';

    return LegalDocument(
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '',
      content: content,
    );
  }
}
