import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/legal_document.dart';

class LegalService {
  LegalService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<LegalDocument>> listDocuments() async {
    try {
      final json = await _apiClient.getJson('/api/legal');
      final documents = json['documents'];
      if (documents is List) {
        return documents
            .whereType<Map<String, dynamic>>()
            .map(LegalDocument.fromJson)
            .toList();
      }
      if (AppConfig.allowMockFallback) return fallbackLegalDocuments;
      throw const ApiException('Legal documents unavailable');
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return fallbackLegalDocuments;
    }
  }

  Future<LegalDocument> getDocument(String slug) async {
    try {
      final json = await _apiClient.getJson('/api/legal/$slug');
      return LegalDocument.fromJson(json);
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return fallbackLegalDocuments.firstWhere(
        (document) => document.slug == slug,
        orElse: () => fallbackLegalDocuments.first,
      );
    }
  }
}

const fallbackLegalDocuments = [
  LegalDocument(
    slug: 'kvkk-clarification',
    title: 'KVKK',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content: 'Enis is for wellness and emotional support only. It is not psychotherapy, diagnosis, or treatment.',
  ),
  LegalDocument(
    slug: 'privacy-policy',
    title: 'Privacy',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content: 'EQ Bilişim processes account and app data to provide the Enis experience.',
  ),
  LegalDocument(
    slug: 'terms-of-use',
    title: 'Terms',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content: 'Use Enis as a wellness support app. In crisis situations contact emergency services or qualified professionals.',
  ),
  LegalDocument(
    slug: 'disclaimer',
    title: 'Disclaimer',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content: 'Enis does not diagnose or treat. AI responses are for wellness and emotional support only.',
  ),
  LegalDocument(
    slug: 'distance-sales-agreement',
    title: 'Distance sales',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content: 'Premium purchase details are shown before checkout.',
  ),
  LegalDocument(
    slug: 'cancellation-refund-policy',
    title: 'Refund policy',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content: 'Cancellation and refund terms are shown before checkout.',
  ),
  LegalDocument(
    slug: 'faq',
    title: 'FAQ',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content: 'Enis is a supportive AI wellness companion app owned by EQ Bilişim.',
  ),
];
