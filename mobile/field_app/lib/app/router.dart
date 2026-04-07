import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/blocked_screen.dart';
import '../features/auth/citizen_registration_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/official_login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/citizen/screens/ai_detection_result_screen.dart';
import '../features/citizen/screens/citizen_home_screen.dart';
import '../features/citizen/screens/complaint_tracker_screen.dart';
import '../features/citizen/screens/my_complaints_screen.dart';
import '../features/citizen/screens/profile_screen.dart';
import '../features/citizen/screens/report_damage_screen.dart';
import '../features/citizen/screens/submission_confirmation_screen.dart';
import '../features/contractor/screens/contractor_home_screen.dart';
import '../features/contractor/screens/contractor_job_detail_screen.dart';
import '../features/contractor/screens/contractor_in_progress_screen.dart';
import '../features/contractor/screens/contractor_ghost_camera_screen.dart';
import '../features/contractor/screens/contractor_issue_screen.dart';
import '../features/contractor/screens/contractor_submission_complete_screen.dart';
import '../features/contractor/screens/contractor_profile_screen.dart';
import '../features/handoff/web_handoff_screen.dart';
import '../features/je/screens/je_executor_assignment_screen.dart';
import '../features/je/screens/je_home_screen.dart';
import '../features/je/screens/je_measure_estimate_screen.dart';
import '../features/je/screens/je_profile_screen.dart';
import '../features/je/screens/je_site_checkin_screen.dart';
import '../features/je/screens/je_ticket_detail_screen.dart';
import '../features/mukadam/screens/mukadam_home_screen.dart';
import '../features/mukadam/screens/mukadam_work_order_detail_screen.dart';
import '../features/mukadam/screens/mukadam_in_progress_screen.dart';
import '../features/mukadam/screens/mukadam_proof_camera_screen.dart';
import '../features/mukadam/screens/mukadam_issue_screen.dart';
import '../features/mukadam/screens/mukadam_submission_complete_screen.dart';
import '../features/mukadam/screens/mukadam_profile_screen.dart';
import 'router_refresh.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefresh(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final path = state.uri.path;
      if (session == null) {
        if (path == '/login' ||
            path == '/official-login' ||
            path == '/otp' ||
            path == '/splash') {
          return null;
        }
        return '/login';
      }
      if (path == '/login' || path == '/official-login') {
        return '/splash';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/official-login',
        builder: (_, __) => const OfficialLoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.extra as String?;
          if (phone == null || phone.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Missing phone — go back to login.')),
            );
          }
          return OtpScreen(phoneE164: phone);
        },
      ),
      GoRoute(
        path: '/register/details',
        builder: (context, state) {
          final fromExtra = state.extra as String?;
          final fromQuery = state.uri.queryParameters['phone'];
          final phone = (fromExtra != null && fromExtra.isNotEmpty)
              ? fromExtra
              : (fromQuery ?? '');
          if (phone.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Missing phone — start from login.')),
            );
          }
          return CitizenRegistrationScreen(phoneE164: phone);
        },
      ),
      GoRoute(
        path: '/blocked',
        builder: (context, state) =>
            BlockedScreen(message: state.extra as String?),
      ),
      GoRoute(
        path: '/handoff',
        builder: (_, __) => const WebHandoffScreen(),
      ),
      GoRoute(
        path: '/citizen',
        redirect: (_, __) => '/citizen/home',
      ),
      GoRoute(
        path: '/citizen/home',
        builder: (_, __) => const CitizenHomeScreen(),
      ),
      GoRoute(
        path: '/citizen/report',
        builder: (_, __) => const ReportDamageScreen(),
      ),
      GoRoute(
        path: '/citizen/ai-result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          File? imageFile;
          Position? gpsPosition;
          if (extra != null) {
            imageFile = extra['imageFile'] as File?;
            gpsPosition = extra['gpsPosition'] as Position?;
          }

          // Fallback for route restoration / app resume where `extra` may be dropped.
          if (imageFile == null || gpsPosition == null) {
            final qp = state.uri.queryParameters;
            final path = qp['path'];
            final lat = double.tryParse(qp['lat'] ?? '');
            final lng = double.tryParse(qp['lng'] ?? '');
            if (path != null && lat != null && lng != null) {
              final decodedPath = Uri.decodeComponent(path);
              imageFile = File(decodedPath);
              gpsPosition = Position(
                longitude: lng,
                latitude: lat,
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                altitudeAccuracy: 0,
                heading: 0,
                headingAccuracy: 0,
                speed: 0,
                speedAccuracy: 0,
              );
            }
          }

          if (imageFile == null || gpsPosition == null) {
            return const Scaffold(
              body: Center(child: Text('Missing capture data. Please retake photo.')),
            );
          }
          return AIDetectionResultScreen(
            imageFile: imageFile,
            gpsPosition: gpsPosition,
          );
        },
      ),
      GoRoute(
        path: '/citizen/confirmation',
        builder: (context, state) {
          final ticket = state.extra as Map<String, dynamic>?;
          if (ticket == null) {
            return const Scaffold(body: Center(child: Text('Missing ticket.')));
          }
          return SubmissionConfirmationScreen(ticket: ticket);
        },
      ),
      GoRoute(
        path: '/citizen/my-complaints',
        builder: (_, __) => const MyComplaintsScreen(),
      ),
      GoRoute(
        path: '/citizen/tracker',
        builder: (context, state) {
          final ticketId = state.uri.queryParameters['ticketId'];
          if (ticketId == null || ticketId.isEmpty) {
            return const Scaffold(body: Center(child: Text('Missing ticket id.')));
          }
          return ComplaintTrackerScreen(ticketId: ticketId);
        },
      ),
      GoRoute(
        path: '/citizen/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/je',
        redirect: (_, __) => '/je/home',
      ),
      GoRoute(
        path: '/je/home',
        builder: (_, __) => const JeHomeScreen(),
      ),
      GoRoute(
        path: '/je/profile',
        builder: (_, __) => const JeProfileScreen(),
      ),
      GoRoute(
        path: '/je/ticket/:ticketId',
        builder: (_, state) => JeTicketDetailScreen(
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: '/je/checkin/:ticketId',
        builder: (_, state) => JeSiteCheckInScreen(
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: '/je/measure/:ticketId',
        builder: (_, state) => JeMeasureEstimateScreen(
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: '/je/assign/:ticketId',
        builder: (_, state) => JeExecutorAssignmentScreen(
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: '/mukadam/home',
        builder: (_, __) => const MukadamHomeScreen(),
      ),
      GoRoute(
        path: '/mukadam/detail/:ticketId',
        builder: (_, state) => MukadamWorkOrderDetailScreen(
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: '/mukadam/inprogress/:ticketId',
        builder: (_, state) => MukadamInProgressScreen(
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: '/mukadam/camera/:ticketId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MukadamProofCameraScreen(
            ticketId: state.pathParameters['ticketId']!,
            fieldNotes: extra?['fieldNotes'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/mukadam/issue/:ticketId',
        builder: (_, state) => MukadamIssueScreen(
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: '/mukadam/submitted',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final id = extra?['ticketId'] as String?;
          final at = extra?['submittedAt'] as DateTime?;
          if (id == null || at == null) {
            return const Scaffold(
              body: Center(child: Text('Missing submission details.')),
            );
          }
          return MukadamSubmissionCompleteScreen(
            ticketId: id,
            submittedAt: at,
          );
        },
      ),
      GoRoute(
        path: '/mukadam/profile',
        builder: (_, __) => const MukadamProfileScreen(),
      ),
      GoRoute(
        path: '/mukadam',
        redirect: (_, __) => '/mukadam/home',
      ),
      GoRoute(path: '/contractor/home', builder: (_, __) => const ContractorHomeScreen()),
      GoRoute(
        path: '/contractor/detail/:ticketId',
        builder: (_, state) => ContractorJobDetailScreen(ticketId: state.pathParameters['ticketId']!),
      ),
      GoRoute(
        path: '/contractor/inprogress/:ticketId',
        builder: (_, state) => ContractorInProgressScreen(ticketId: state.pathParameters['ticketId']!),
      ),
      GoRoute(
        path: '/contractor/camera/:ticketId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ContractorGhostCameraScreen(
            ticketId: state.pathParameters['ticketId']!,
            fieldNotes: extra?['fieldNotes'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/contractor/issue/:ticketId',
        builder: (_, state) => ContractorIssueScreen(ticketId: state.pathParameters['ticketId']!),
      ),
      GoRoute(
        path: '/contractor/submitted',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final id = extra?['ticketId'] as String?;
          final hash = extra?['hash'] as String?;
          final at = extra?['submittedAt'] as DateTime?;
          if (id == null || hash == null || at == null) {
            return const Scaffold(body: Center(child: Text('Missing submission details.')));
          }
          return ContractorSubmissionCompleteScreen(ticketId: id, hash: hash, submittedAt: at);
        },
      ),
      GoRoute(path: '/contractor/profile', builder: (_, __) => const ContractorProfileScreen()),
      GoRoute(path: '/contractor', redirect: (_, __) => '/contractor/home'),
    ],
  );
});
