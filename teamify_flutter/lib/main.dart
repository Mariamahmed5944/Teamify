import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'core/cache/cache_manager.dart';
import 'core/network/websocket_manager.dart';
import 'core/session/session_controller.dart';
import 'data/repositories/app_repositories.dart';
import 'services/app_services.dart';

import 'screens/auth/auth_screens.dart';
import 'screens/home/home_screens.dart';
import 'screens/home/new_user_home_screen.dart';
import 'screens/features/feature_screens.dart';
import 'screens/project/project_screens.dart';
import 'screens/chat/chat_screens.dart';
import 'screens/ai/ai_screens.dart';
import 'screens/profile/profile_screens.dart';
import 'screens/resume/resume_screens.dart';
import 'screens/admin/admin_screens.dart';
import 'screens/mentor/mentor_screens.dart';
import 'screens/team/team_screens.dart';
import 'screens/meeting/meeting_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Infrastructure ──────────────────────────────────────────────────────
  final cache = CacheManager();
  await cache.init();

  final repositories = AppRepositories();

  final session = SessionController(repositories.auth);

  // ── Service layer ──────────────────────────────────────────────────────
  final services = AppServices(
    repos: repositories,
    session: session,
    cache: cache,
  );

  // ── WebSocket ─────────────────────────────────────────────────────────
  final ws = WebSocketManager(repositories.tokenStorage);

  // Restore session, then connect WebSocket if authenticated
  await session.restoreSession();
  if (session.isAuthenticated) {
    await ws.connect();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AppRepositories>.value(value: repositories),
        Provider<AppServices>.value(value: services),
        Provider<CacheManager>.value(value: cache),
        Provider<WebSocketManager>.value(value: ws),
        ChangeNotifierProvider<SessionController>.value(value: session),
      ],
      child: const TeamifyApp(),
    ),
  );
}

class TeamifyApp extends StatelessWidget {
  const TeamifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Widget protected(Widget child) => ProtectedRoute(child: child);

    return MaterialApp(
      title: 'Teamify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: R.splash,
      routes: {
        // ── Auth ──────────────────────────────────────────────────────────────
        R.splash: (_) => const SplashScreen(),
        R.onboarding: (_) => const OnboardingScreen(),
        R.roleSelection: (_) => const RoleSelectionScreen(),
        R.login: (_) => const LoginScreen(),
        R.signupAdmin: (_) => const AdminSignupScreen(),
        R.signupFreelancer: (_) => const FreelancerSignupScreen(),
        R.signupStudent: (_) => const StudentSignupScreen(),
        R.verifyEmail: (_) => const VerifyEmailScreen(),
        R.forgotPassword: (_) => const ForgotPasswordScreen(),
        R.otpVerification: (_) => const OTPVerificationScreen(),
        R.createNewPassword: (_) => const CreateNewPasswordScreen(),
        R.confirmationAdmin: (_) => const ConfirmationAdminScreen(),
        R.confirmationFreelancer: (_) => const ConfirmationFreelancerScreen(),
        R.confirmationStudent: (_) => const ConfirmationStudentScreen(),

        // ── Home ─────────────────────────────────────────────────────────────
        R.freelancerHome: (_) => protected(const FreelancerHomeScreen()),
        R.studentHome: (_) => protected(const StudentHomeScreen()),
        R.adminHome: (_) => protected(const AdminHomeScreen()),
        R.newUserHome: (_) => const NewUserHomeScreen(),
        R.search: (_) => protected(const SearchScreen()),
        R.completeProfile: (_) => protected(const CompleteProfileScreen()),
        R.teammateMatching: (_) => protected(const AITeammateMatchingScreen()),
        R.riskPredictor: (_) => protected(const ProjectRiskPredictorScreen()),
        R.chatEmotion: (_) => protected(const ChatEmotionScreen()),
        R.meetingTranscription: (_) =>
            protected(const MeetingTranscriptionScreen()),
        R.fileHistory: (_) => protected(const FileVersionHistoryScreen()),
        R.notifications: (_) => protected(const NotificationsScreen()),
        R.settings: (_) => protected(const SettingsScreen()),
        R.addUser: (_) => protected(const AddUserScreen()),
        R.mentorMain: (_) => protected(const MentorMainScreen()),
        R.addTask: (_) => protected(const AddTaskScreen()),

        // ── Project ───────────────────────────────────────────────────────────
        R.projectsList: (_) => protected(const ProjectsListScreen()),
        R.projectDetails: (_) => protected(const ProjectDetailsScreen()),
        R.addProject: (_) => protected(const AddProjectScreen()),

        // ── Chat ─────────────────────────────────────────────────────────────
        R.chatList: (_) => protected(const ChatListScreen()),
        R.groupChat: (_) => protected(const GroupChatScreen()),
        R.directChat: (_) => protected(const DirectChatScreen()),
        R.chatSummary: (_) => protected(const ChatSummaryScreen()),
        R.pinnedMessages: (_) => protected(const PinnedMessagesScreen()),
        R.smartQA: (_) => protected(const SmartQAScreen()),
        R.fileSharing: (_) => protected(const FileSharingScreen()),
        R.fileIntegrity: (_) => protected(const FileIntegrityScreen()),
        R.meeting: (_) => protected(const MeetingScreen()),

        // ── AI ────────────────────────────────────────────────────────────────
        R.aiHub: (_) => protected(const MentorMainScreen()),
        R.smartTodo: (_) => protected(const SmartTodoScreen()),
        R.aiTaskAllocation: (_) => protected(const AITaskAllocationScreen()),
        R.aiSuggestedResult: (_) => protected(const AISuggestedResultScreen()),
        R.aiExplanation: (_) => protected(const AIExplanationScreen()),
        R.aiPriority: (_) => protected(const AIPriorityScreen()),
        R.aiDeadline: (_) => protected(const AIDeadlineScreen()),
        R.pomodoro: (_) => protected(const PomodoroScreen()),
        R.aiInsights: (_) => protected(const AIInsightsScreen()),
        R.aiMentor: (_) => protected(const AIMentorScreen()),
        R.aiMentorChat: (_) => protected(const CareerMentorChatScreen()),
        R.teamRecommendation: (_) =>
            protected(const TeamRecommendationScreen()),
        R.recommendedCourses: (_) =>
            protected(const RecommendedCoursesScreen()),
        R.skills: (_) => protected(const SkillsScreen()),

        // ── Profile ───────────────────────────────────────────────────────────
        R.freelancerProfile: (_) => protected(const FreelancerProfileScreen()),
        R.studentProfile: (_) => protected(const StudentProfileScreen()),
        R.adminProfile: (_) => protected(const AdminProfileScreen()),
        R.editProfile: (_) => protected(const EditProfileScreen()),
        R.completedProjects: (_) => protected(const CompletedProjectsScreen()),
        R.ratings: (_) => protected(const RatingsScreen()),
        R.performance: (_) => protected(const PerformanceScreen()),
        R.languageSwitch: (_) => protected(const LanguageSwitchScreen()),

        // ── Resume ────────────────────────────────────────────────────────────
        R.resumeCVStart: (_) => protected(const ResumeCVStartScreen()),
        R.resumeBuilder: (_) => protected(const ResumeBuilderScreen()),
        R.resumePreview: (_) => protected(const ResumePreviewScreen()),
        R.resumeEditContent: (_) => protected(const ResumeEditContentScreen()),
        R.resumeCustomize: (_) => protected(const ResumeCustomizeScreen()),
        R.resumeExportSuccess: (_) =>
            protected(const ResumeExportSuccessScreen()),

        // ── Admin / Security ──────────────────────────────────────────────────
        R.adminUsers: (_) => protected(const AdminUsersScreen()),
        R.adminUserDetails: (_) => protected(const UserDetailsAdminScreen()),
        R.adminRoles: (_) => protected(const AdminRolesScreen()),
        R.editRolePermissions: (_) =>
            protected(const EditRolePermissionsScreen()),
        R.securityChecklist: (_) => protected(const SecurityChecklistScreen()),
        R.loginLogs: (_) => protected(const LoginLogsScreen()),
        R.securityAlerts: (_) => protected(const SecurityAlertsScreen()),
        R.alertDetails: (_) => protected(const AlertDetailsScreen()),
        R.securityMonitor: (_) => protected(const SecurityMonitorScreen()),
        R.rateLimiting: (_) => protected(const RateLimitingScreen()),
        R.encryptionStatus: (_) => protected(const EncryptionStatusScreen()),
        R.twoFAStatus: (_) => protected(const TwoFAEnableScreen()),
        R.twoFAVerify: (_) => protected(const TwoFAVerifyScreen()),
        R.twoFASuccess: (_) => protected(const TwoFASuccessScreen()),
        R.analyst: (_) => protected(const AnalystScreen()),
        R.securityFiles: (_) => protected(const SecurityFilesScreen()),
        R.securityCenter: (_) => protected(const SecurityCenterScreen()),
        R.securityOverview: (_) => protected(const SecurityOverviewScreen()),
        R.forceLogout: (_) => protected(const ForceLogoutScreen()),
        R.logoutAllDevices: (_) => protected(const LogoutAllDevicesScreen()),
        R.reviewActivity: (_) => protected(const ReviewActivityScreen()),
        R.askAI: (_) => protected(const AskAIScreen()),
        R.teamsList: (_) => protected(const TeamsListScreen()),
        R.membersList: (_) => protected(const MembersListScreen()),
      },
    );
  }
}

class ProtectedRoute extends StatelessWidget {
  final Widget child;

  const ProtectedRoute({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.status == SessionStatus.unknown) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!session.isAuthenticated) {
      Future.microtask(() {
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(context, R.login, (_) => false);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return child;
  }
}
