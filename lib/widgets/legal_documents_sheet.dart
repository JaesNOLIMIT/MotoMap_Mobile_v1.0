import 'package:flutter/material.dart';

import '../models/legal_document.dart';
import '../services/auth_service.dart';
import '../theme/motomap_colors.dart';

Future<void> showLegalDocumentsSheet(
  BuildContext context, {
  LegalDocumentType initialType = LegalDocumentType.eula,
  List<LegalDocument>? documents,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => LegalDocumentsSheet(
      initialType: initialType,
      initialDocuments: documents,
    ),
  );
}

class LegalDocumentsSheet extends StatefulWidget {
  const LegalDocumentsSheet({
    super.key,
    this.initialType = LegalDocumentType.eula,
    this.initialDocuments,
  });

  final LegalDocumentType initialType;
  final List<LegalDocument>? initialDocuments;

  @override
  State<LegalDocumentsSheet> createState() => _LegalDocumentsSheetState();
}

class _LegalDocumentsSheetState extends State<LegalDocumentsSheet> {
  late Future<List<LegalDocument>> _documents;

  @override
  void initState() {
    super.initState();
    _documents = widget.initialDocuments == null
        ? AuthService.instance.fetchActiveLegalDocuments()
        : Future.value(widget.initialDocuments);
  }

  void _retry() {
    setState(() {
      _documents = AuthService.instance.fetchActiveLegalDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Material(
        color: MotoMapColors.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: DefaultTabController(
          length: LegalDocumentType.values.length,
          initialIndex: widget.initialType.index,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MotoMapColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Legal documents', style: MotoMapText.title),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              TabBar(
                indicatorColor: MotoMapColors.primary,
                labelColor: MotoMapColors.primary,
                unselectedLabelColor: MotoMapColors.onSurfaceVariant,
                tabs: [
                  for (final type in LegalDocumentType.values)
                    Tab(text: type.tabLabel),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<LegalDocument>>(
                  future: _documents,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _LegalLoadError(onRetry: _retry);
                    }

                    final documents = snapshot.data ?? const [];
                    return TabBarView(
                      children: [
                        for (final type in LegalDocumentType.values)
                          _LegalDocumentBody(
                            type: type,
                            document: _findDocument(documents, type),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LegalDocument? _findDocument(
    List<LegalDocument> documents,
    LegalDocumentType type,
  ) {
    for (final document in documents) {
      if (document.type == type) return document;
    }
    return null;
  }
}

class _LegalDocumentBody extends StatelessWidget {
  const _LegalDocumentBody({required this.type, required this.document});

  final LegalDocumentType type;
  final LegalDocument? document;

  @override
  Widget build(BuildContext context) {
    if (document == null) {
      return Center(
        child: Text(
          '${type.fallbackTitle} is unavailable.',
          style: MotoMapText.bodyMd.copyWith(
            color: MotoMapColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document!.title, style: MotoMapText.headlineMd),
            const SizedBox(height: 6),
            Text(
              'Version ${document!.version}',
              style: MotoMapText.labelCaps.copyWith(
                color: MotoMapColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              document!.content,
              style: MotoMapText.bodyMd.copyWith(
                color: MotoMapColors.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalLoadError extends StatelessWidget {
  const _LegalLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: MotoMapColors.error,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text('Legal documents unavailable', style: MotoMapText.title),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: MotoMapText.bodyMd.copyWith(
                color: MotoMapColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
