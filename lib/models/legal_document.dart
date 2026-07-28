enum LegalDocumentType {
  eula,
  terms,
  privacy;

  String get databaseValue => name;

  String get tabLabel => switch (this) {
    eula => 'EULA',
    terms => 'Terms',
    privacy => 'Privacy',
  };

  String get fallbackTitle => switch (this) {
    eula => 'End-User License Agreement',
    terms => 'Terms of Service',
    privacy => 'Privacy Policy',
  };
}

class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.type,
    required this.version,
    required this.title,
    required this.content,
    required this.effectiveAt,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    final rawType = json['document_type'] as String;
    return LegalDocument(
      id: json['document_id'] as int,
      type: LegalDocumentType.values.byName(rawType),
      version: json['version'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
    );
  }

  final int id;
  final LegalDocumentType type;
  final String version;
  final String title;
  final String content;
  final DateTime effectiveAt;
}
