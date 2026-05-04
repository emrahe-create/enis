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
      throw const ApiException('Yasal metinlere ulaşılamıyor');
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

const _fallbackCompanyInfo = '''
EQ Bilişim Teknolojileri Ltd. Şti.
Fatih Sultan Mehmet Mah. Poligon Cad. Buyaka 2 Sitesi No:8C/1 P.K. 34771 Ümraniye / İstanbul / Türkiye
Alemdağ V.D. – 3290486809
info@eqbilisim.com.tr
+90 216 225 66 19
+90 532 384 82 64''';

const _fallbackWellnessDisclaimer = '''
Enis psikoterapi hizmeti değildir.
Enis tanı, tedavi veya tıbbi yönlendirme yapmaz.
Yapay zeka yanıtları yalnızca duygusal destek ve farkındalık amaçlıdır.
Acil durumlarda 112, sağlık kuruluşları veya yetkin uzmanlarla iletişime geçilmelidir.''';

const fallbackLegalDocuments = [
  LegalDocument(
    slug: 'kvkk-clarification',
    title: 'KVKK Aydınlatma Metni',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content:
        '$_fallbackWellnessDisclaimer\n\n$_fallbackCompanyInfo\n\nVeri sorumlusu EQ Bilişim Teknolojileri Ltd. Şti.’dir. Kişisel veriler hesap oluşturma, uygulama güvenliği, abonelik takibi, destek talepleri ve onay kayıtlarının tutulması amacıyla işlenir. Kullanıcılar KVKK kapsamındaki talepleri için EQ Bilişim ile iletişime geçebilir.',
  ),
  LegalDocument(
    slug: 'explicit-consent',
    title: 'Açık Rıza Metni',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content:
        '$_fallbackWellnessDisclaimer\n\n$_fallbackCompanyInfo\n\nAçık rıza, zorunlu kayıt onaylarından ayrıdır. Kullanıcı isteğe bağlı kişiselleştirme, ürün geliştirme ve iletişim tercihleri için açık rıza verebilir; isteğe bağlı rızalar geri alınabilir.',
  ),
  LegalDocument(
    slug: 'privacy-policy',
    title: 'Gizlilik Politikası',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content:
        '$_fallbackWellnessDisclaimer\n\n$_fallbackCompanyInfo\n\nEQ Bilişim, Enis deneyimini sunmak için hesap, profil, abonelik, sohbet, onay ve kullanım verilerini işler. Pazarlama izni isteğe bağlıdır ve temel hesap kullanımını engellemez.',
  ),
  LegalDocument(
    slug: 'terms-of-use',
    title: 'Kullanım Şartları',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content:
        '$_fallbackWellnessDisclaimer\n\n$_fallbackCompanyInfo\n\nKullanıcılar Enis’i yalnızca iyi oluş ve duygusal destek amaçlı kullanmayı kabul eder. Enis acil kararlar, profesyonel değerlendirme veya düzenlenmiş sağlık hizmetleri için kullanılmamalıdır.',
  ),
  LegalDocument(
    slug: 'disclaimer',
    title: 'Sorumluluk Reddi',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content:
        '$_fallbackWellnessDisclaimer\n\n$_fallbackCompanyInfo\n\nEnis günlük duygu durumunu fark etmeye yardımcı olabilecek destekleyici yanıtlar üretir. Yapay zeka bağlamı veya aciliyeti yanlış anlayabilir; güvenli hissettirmeyen durumlarda dış destek alınmalıdır.',
  ),
  LegalDocument(
    slug: 'distance-sales-agreement',
    title: 'Mesafeli Satış Sözleşmesi',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content:
        '$_fallbackWellnessDisclaimer\n\n$_fallbackCompanyInfo\n\nPremium abonelik dijital hizmet olarak sunulur. Satın alma öncesinde fiyat, dönem, yenileme ve iptal bilgileri ödeme akışında gösterilir. Kullanıcı satın alma öncesi aktif sözleşme sürümünü kabul eder.',
  ),
  LegalDocument(
    slug: 'cancellation-refund-policy',
    title: 'İptal ve İade Politikası',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content:
        '$_fallbackWellnessDisclaimer\n\n$_fallbackCompanyInfo\n\nPremium abonelik yenilemesi kullanılan ödeme sağlayıcı akışı üzerinden iptal edilebilir. İade talepleri yürürlükteki mevzuat, ödeme sağlayıcı kuralları ve satın alma sırasında gösterilen dijital abonelik koşullarına göre değerlendirilir.',
  ),
  LegalDocument(
    slug: 'faq',
    title: 'Sıkça Sorulan Sorular',
    version: 'fallback',
    updatedAt: '2026-04-29',
    content:
        '$_fallbackWellnessDisclaimer\n\n$_fallbackCompanyInfo\n\nEnis nedir? EQ Bilişim tarafından geliştirilen yapay zeka destekli iyi oluş uygulamasıdır. Profesyonel desteğin yerine geçer mi? Hayır. Kriz mesajlarında ne olur? Normal sohbet durur ve dış yardım önerilir.',
  ),
];
