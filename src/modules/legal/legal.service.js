import { ApiError } from "../../utils/http.js";

export const enisCompany = {
  brand: "Enis",
  owner: "EQ Bilişim",
  legalName: "EQ Bilişim Teknolojileri Ltd. Şti.",
  address:
    "Fatih Sultan Mehmet Mah. Poligon Cad. Buyaka 2 Sitesi No:8C/1 P.K. 34771 Ümraniye / İstanbul / Türkiye",
  taxOffice: "Alemdağ V.D.",
  taxNumber: "3290486809",
  email: "info@eqbilisim.com.tr",
  phone: "+90 216 225 66 19",
  mobile: "+90 532 384 82 64"
};

export const enisIdentityCopy =
  "Enis, duygusal destek ve farkındalık amacıyla geliştirilmiş yapay zeka destekli bir iyi oluş uygulamasıdır.";

const legalVersion = "2026-04-29";
const updatedAt = "2026-04-29";

const wellnessDisclaimer = [
  enisIdentityCopy,
  "Enis psikoterapi hizmeti değildir.",
  "Enis tanı, tedavi veya tıbbi yönlendirme yapmaz.",
  "Yapay zeka yanıtları yalnızca duygusal destek ve farkındalık amaçlıdır.",
  "Acil durumlarda 112, sağlık kuruluşları veya yetkin uzmanlarla iletişime geçilmelidir."
].join("\n");

const companyInfo = [
  "EQ Bilişim Teknolojileri Ltd. Şti.",
  "Fatih Sultan Mehmet Mah. Poligon Cad. Buyaka 2 Sitesi No:8C/1 P.K. 34771 Ümraniye / İstanbul / Türkiye",
  "Alemdağ V.D. – 3290486809",
  "info@eqbilisim.com.tr",
  "+90 216 225 66 19",
  "+90 532 384 82 64"
].join("\n");

function documentContent(...sections) {
  return [wellnessDisclaimer, companyInfo, ...sections].join("\n\n");
}

export const legalDocuments = {
  "privacy-policy": {
    slug: "privacy-policy",
    title: "Gizlilik Politikası",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "EQ Bilişim; hesap, profil, abonelik, sohbet, onay ve kullanım verilerini Enis deneyimini sunmak, güvenliği sağlamak, destek taleplerini yanıtlamak ve yasal yükümlülükleri yerine getirmek amacıyla işler.",
      "Kullanıcılar verilerine erişme, verilerini dışa aktarma, düzeltme veya hesap silme taleplerini uygulama içindeki hesap uç noktaları ya da EQ Bilişim iletişim kanalları üzerinden iletebilir.",
      "Pazarlama iletişimi isteğe bağlıdır. Pazarlama izninin verilmemesi temel hesap erişimini engellemez."
    )
  },
  "kvkk-clarification": {
    slug: "kvkk-clarification",
    title: "KVKK Aydınlatma Metni",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Veri sorumlusu EQ Bilişim Teknolojileri Ltd. Şti.’dir. Kişisel veriler hesap oluşturma, uygulama güvenliği, abonelik takibi, kullanıcı desteği, onay kayıtları ve hizmetin iyileştirilmesi amaçlarıyla işlenir.",
      "İşlenen veriler e-posta, profil bilgileri, abonelik bilgileri, sohbet içerikleri, kullanım kayıtları ve kullanıcı tarafından verilen onay kayıtlarını içerebilir.",
      "Onay kayıtları onay türü, sürüm, kabul zamanı, IP adresi ve kullanıcı aracısı bilgisini içerebilir. Kullanıcılar KVKK kapsamındaki taleplerini EQ Bilişim’e iletebilir."
    )
  },
  "explicit-consent": {
    slug: "explicit-consent",
    title: "Açık Rıza Metni",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Açık rıza, zorunlu kayıt bilgilendirmelerinden ayrıdır ve yalnızca isteğe bağlı işleme faaliyetleri için talep edilir.",
      "Kullanıcılar ürün geliştirme, kişiselleştirme ve isteğe bağlı iletişim tercihleri kapsamında açık rıza verebilir. Açık rıza verilmemesi temel hesap erişimini engellemez.",
      "Kullanıcılar isteğe bağlı rıza tercihlerini hesap ayarları veya EQ Bilişim iletişim kanalları üzerinden güncelleyebilir ya da geri alabilir."
    )
  },
  "terms-of-use": {
    slug: "terms-of-use",
    title: "Kullanım Şartları",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Kullanıcılar Enis’i yalnızca iyi oluş, duygusal destek ve farkındalık amacıyla kullanmayı kabul eder.",
      "Enis acil kararlar, profesyonel değerlendirme, sağlık hizmeti, hukuki danışmanlık veya benzeri düzenlenmiş hizmetler için kullanılmamalıdır.",
      "EQ Bilişim; uygulama özelliklerini, abonelik kurallarını, güvenlik akışlarını ve yasal metinleri ürün geliştikçe güncelleyebilir."
    )
  },
  "distance-sales-agreement": {
    slug: "distance-sales-agreement",
    title: "Mesafeli Satış Sözleşmesi",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Premium abonelik satın alımları Enis uygulaması kapsamında EQ Bilişim tarafından dijital hizmet olarak sunulur.",
      "Premium satın alma başlatılmadan önce kullanıcı aktif Mesafeli Satış Sözleşmesi sürümünü kabul etmelidir.",
      "Abonelik ücreti, fatura dönemi, yenileme bilgileri, iptal seçenekleri ve satın almaya ilişkin temel bilgiler ödeme akışında kullanıcıya gösterilir."
    )
  },
  "cancellation-refund-policy": {
    slug: "cancellation-refund-policy",
    title: "İptal ve İade Politikası",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Kullanıcılar Premium abonelik yenilemesini satın alma sırasında kullanılan ödeme sağlayıcı akışı üzerinden iptal edebilir.",
      "İade talepleri yürürlükteki mevzuat, ödeme sağlayıcı kuralları ve satın alma öncesinde gösterilen dijital abonelik koşulları dikkate alınarak değerlendirilir.",
      "Premium satın alma başlatılmadan önce kullanıcı aktif İptal ve İade Politikası sürümünü kabul etmelidir."
    )
  },
  disclaimer: {
    slug: "disclaimer",
    title: "Sorumluluk Reddi",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Enis günlük duyguları fark etmeye yardımcı olabilecek destekleyici ve yansıtıcı yanıtlar üretir.",
      "Yapay zeka bağlamı, tonu, aciliyeti veya kişisel koşulları yanlış anlayabilir. Bu nedenle Enis yanıtları kesin yönlendirme veya profesyonel değerlendirme olarak kabul edilmemelidir.",
      "Kullanıcı kendini güvende hissetmediğinde, durum acil olduğunda veya uygulama tabanlı desteğin ötesine geçtiğinde uygun dış desteğe başvurmalıdır."
    )
  },
  faq: {
    slug: "faq",
    title: "Sıkça Sorulan Sorular",
    version: legalVersion,
    updatedAt,
    company: enisCompany,
    content: documentContent(
      "Enis nedir? Enis, EQ Bilişim tarafından geliştirilen yapay zeka destekli bir iyi oluş uygulamasıdır.",
      "Enis profesyonel desteğin yerine geçer mi? Hayır. Enis yalnızca duygusal destek ve farkındalık amacıyla kullanılmalıdır.",
      "Enis insan ilişkilerinin yerini alır mı? Hayır. Enis dijital bir iyi oluş aracıdır ve güvenilen kişilerden veya yetkin uzmanlardan alınabilecek desteğin yerine geçmez.",
      "Kriz mesajlarında ne olur? Enis normal sohbet akışını durdurur ve kullanıcıyı dış yardım almaya yönlendirir."
    )
  }
};

export function getLegalDocument(slug) {
  const document = legalDocuments[slug];
  if (!document) throw new ApiError(404, "Yasal metin bulunamadı");
  return document;
}

export function listLegalDocuments() {
  return Object.values(legalDocuments);
}
