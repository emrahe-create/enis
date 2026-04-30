import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../auth/data/auth_service.dart';
import '../../chat/data/chat_service.dart';
import '../../legal/data/legal_service.dart';
import '../../premium/data/premium_service.dart';
import '../../profile/data/user_service.dart';

class AppServices {
  AppServices._({
    required this.tokenStorage,
    required this.apiClient,
    required this.auth,
    required this.user,
    required this.chat,
    required this.premium,
    required this.legal,
  });

  final TokenStorage tokenStorage;
  final ApiClient apiClient;
  final AuthService auth;
  final UserService user;
  final ChatService chat;
  final PremiumService premium;
  final LegalService legal;

  factory AppServices.create() {
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    return AppServices._(
      tokenStorage: tokenStorage,
      apiClient: apiClient,
      auth: AuthService(apiClient: apiClient, tokenStorage: tokenStorage),
      user: UserService(apiClient: apiClient),
      chat: ChatService(apiClient: apiClient),
      premium: PremiumService(apiClient: apiClient),
      legal: LegalService(apiClient: apiClient),
    );
  }
}
