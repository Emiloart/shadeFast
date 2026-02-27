import 'package:go_router/go_router.dart';

import '../../features/engagement/presentation/challenges_screen.dart';
import '../../features/engagement/presentation/polls_screen.dart';
import '../../features/feed/presentation/community_feed_screen.dart';
import '../../features/feed/presentation/global_feed_screen.dart';
import '../../features/communities/presentation/join_link_screen.dart';
import '../../features/legal/presentation/legal_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/private_chats/presentation/private_chat_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/global',
      name: 'globalFeed',
      builder: (_, __) => const GlobalFeedScreen(),
    ),
    GoRoute(
      path: '/community/:id',
      name: 'communityFeed',
      builder: (_, GoRouterState state) {
        final communityId = state.pathParameters['id'] ?? '';
        return CommunityFeedScreen(communityId: communityId);
      },
    ),
    GoRoute(
      path: '/join/:code',
      name: 'joinByCode',
      builder: (_, GoRouterState state) {
        final code = (state.pathParameters['code'] ?? '').toUpperCase();
        return JoinLinkScreen(joinCode: code);
      },
    ),
    GoRoute(
      path: '/chat/:token',
      name: 'privateChat',
      builder: (_, GoRouterState state) {
        final token = (state.pathParameters['token'] ?? '').toUpperCase();
        return PrivateChatScreen(token: token);
      },
    ),
    GoRoute(
      path: '/legal',
      name: 'legal',
      builder: (_, __) => const LegalScreen(),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (_, __) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/premium',
      name: 'premium',
      builder: (_, __) => const PremiumScreen(),
    ),
    GoRoute(
      path: '/polls',
      name: 'polls',
      builder: (_, GoRouterState state) {
        final communityId = state.uri.queryParameters['communityId'];
        return PollsScreen(communityId: communityId);
      },
    ),
    GoRoute(
      path: '/challenges',
      name: 'challenges',
      builder: (_, __) => const ChallengesScreen(),
    ),
  ],
);
