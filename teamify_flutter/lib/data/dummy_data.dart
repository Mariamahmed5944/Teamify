import '../models/models.dart';

class DummyData {
  // ── Users ──────────────────────────────────────────────────────────────────
  static const List<UserModel> users = [
    UserModel(
        id: '1',
        name: 'Alice Smith',
        email: 'alice@teamify.com',
        role: 'Freelancer',
        rating: 4.8,
        projectsCount: 12,
        skills: ['Flutter', 'Dart', 'Firebase', 'UI/UX']),
    UserModel(
        id: '2',
        name: 'John Doe',
        email: 'john@teamify.com',
        role: 'Freelancer',
        rating: 4.6,
        projectsCount: 8,
        skills: ['React', 'Node.js', 'TypeScript']),
    UserModel(
        id: '3',
        name: 'Mike Kumar',
        email: 'mike@teamify.com',
        role: 'Student',
        rating: 4.3,
        projectsCount: 5,
        skills: ['Python', 'ML', 'Scikit-learn']),
    UserModel(
        id: '4',
        name: 'Lisa Park',
        email: 'lisa@teamify.com',
        role: 'Student',
        rating: 4.5,
        projectsCount: 6,
        skills: ['Design', 'Figma', 'CSS']),
    UserModel(
        id: '5',
        name: 'Mariam Kamel',
        email: 'mariam@teamify.com',
        role: 'Admin',
        rating: 4.9,
        projectsCount: 15,
        skills: ['Management', 'Security', 'Analytics']),
  ];

  // ── Projects ───────────────────────────────────────────────────────────────
  static List<ProjectModel> projects = [
    const ProjectModel(
      id: '1',
      name: 'Website Redesign',
      company: 'Tech Crop',
      description:
          'Complete redesign of the company website with modern UI/UX.',
      status: 'In Progress',
      delayRisk: 'Low Risk',
      progress: 75,
      members: ['Alice Smith', 'John Doe', 'Mike Kumar'],
      tasks: [
        TaskModel(
            id: '1',
            title: 'Create wireframes',
            assignee: 'Alice Smith',
            assigneeInitials: 'AS',
            status: 'Complete',
            priority: 'High',
            dueDate: '20 Dec'),
        TaskModel(
            id: '2',
            title: 'Design homepage mockup',
            assignee: 'Alice Smith',
            assigneeInitials: 'AS',
            status: 'In Progress',
            priority: 'High',
            dueDate: '10 Dec'),
        TaskModel(
            id: '3',
            title: 'Develop frontend components',
            assignee: 'Mike Kumar',
            assigneeInitials: 'MK',
            status: 'In Progress',
            priority: 'Medium',
            dueDate: '5 Dec'),
        TaskModel(
            id: '4',
            title: 'Set up backend API',
            assignee: 'Alice Smith',
            assigneeInitials: 'AS',
            status: 'Complete',
            priority: 'High',
            dueDate: '20 Dec'),
        TaskModel(
            id: '5',
            title: 'Write documentation',
            assignee: 'John Doe',
            assigneeInitials: 'JD',
            status: 'To Do',
            priority: 'Low',
            dueDate: '14 Dec'),
      ],
    ),
    const ProjectModel(
      id: '2',
      name: 'Tech Crop',
      company: 'InnovateCo',
      description: 'Building a scalable tech platform for crop management.',
      status: 'In Progress',
      delayRisk: 'Medium Risk',
      progress: 45,
      members: ['Alice Smith', 'Lisa Park'],
      tasks: [
        TaskModel(
            id: '6',
            title: 'Market research',
            assignee: 'Lisa Park',
            assigneeInitials: 'LP',
            status: 'Complete',
            priority: 'High',
            dueDate: '15 Nov'),
        TaskModel(
            id: '7',
            title: 'UI Design',
            assignee: 'Lisa Park',
            assigneeInitials: 'LP',
            status: 'In Progress',
            priority: 'High',
            dueDate: '25 Nov'),
      ],
    ),
    const ProjectModel(
      id: '3',
      name: 'AI Planner',
      company: 'StartupXYZ',
      description: 'AI-powered project planning and task management tool.',
      status: 'Complete',
      delayRisk: 'Low Risk',
      progress: 100,
      members: ['Alice Smith', 'John Doe', 'Mariam Kamel'],
      tasks: [
        TaskModel(
            id: '8',
            title: 'ML Model Training',
            assignee: 'Mariam Kamel',
            assigneeInitials: 'MK',
            status: 'Complete',
            priority: 'High',
            dueDate: '1 Dec'),
        TaskModel(
            id: '9',
            title: 'API Integration',
            assignee: 'Mike Kumar',
            assigneeInitials: 'MK',
            status: 'In Progress',
            priority: 'Medium',
            dueDate: '10 Dec'),
      ],
    ),
  ];

  // ── Chat Rooms ─────────────────────────────────────────────────────────────
  static const List<ChatRoom> chatRooms = [
    ChatRoom(
        id: '1',
        name: 'Website Redesign',
        lastMessage: 'Alice: Updated wireframes!',
        time: '10:30 AM',
        initials: 'WR',
        unread: 3,
        isGroup: true),
    ChatRoom(
        id: '2',
        name: 'John Doe',
        lastMessage: 'Can you review the PR?',
        time: '9:15 AM',
        initials: 'JD',
        unread: 1,
        isGroup: false),
    ChatRoom(
        id: '3',
        name: 'AI Planner Team',
        lastMessage: 'Mike: Model is ready!',
        time: 'Yesterday',
        initials: 'AP',
        unread: 0,
        isGroup: true),
    ChatRoom(
        id: '4',
        name: 'Lisa Park',
        lastMessage: 'Designs sent to Figma.',
        time: 'Yesterday',
        initials: 'LP',
        unread: 0,
        isGroup: false),
  ];

  static const List<ChatMessage> groupMessages = [
    ChatMessage(
        id: '1',
        senderId: '5',
        senderName: 'Mariam Kamel',
        senderInitials: 'MK',
        message:
            'Hey team, just uploaded the latest wireframes. Take a look when you get a chance!',
        time: '9:30 AM',
        isMe: false),
    ChatMessage(
        id: '2',
        senderId: '1',
        senderName: 'Alice Smith',
        senderInitials: 'AS',
        message: "Great! I'll review them this afternoon.",
        time: '9:35 AM',
        isMe: true),
    ChatMessage(
        id: '3',
        senderId: '3',
        senderName: 'Mike Kumar',
        senderInitials: 'MK',
        message:
            'Quick question - should we use the new color scheme for the dashboard?',
        time: '10:15 AM',
        isMe: false),
    ChatMessage(
        id: '4',
        senderId: '5',
        senderName: 'Mariam Kamel',
        senderInitials: 'MK2',
        message:
            "Yes, let's go with the new palette. It aligns better with the brand guidelines.",
        time: '10:20 AM',
        isMe: false),
    ChatMessage(
        id: '5',
        senderId: '1',
        senderName: 'Alice Smith',
        senderInitials: 'AS',
        message:
            "I've made some updates to the homepage mockup. Can someone review?",
        time: '2:30 PM',
        isMe: true),
    ChatMessage(
        id: '6',
        senderId: '3',
        senderName: 'Mike Kumar',
        senderInitials: 'MK',
        message: "I'll review them now.",
        time: '2:50 PM',
        isMe: false),
  ];

  // ── Security Alerts ────────────────────────────────────────────────────────
  static const List<SecurityAlert> securityAlerts = [
    SecurityAlert(
        id: '1',
        title: 'Multiple failed logins',
        user: 'Mike Chen',
        description:
            '5 consecutive failed login attempts detected from an unknown location',
        risk: 'HIGH RISK',
        status: 'New',
        time: '5 minutes ago'),
    SecurityAlert(
        id: '2',
        title: 'Suspicious location',
        user: 'Unknown User',
        description: 'Login attempt from unusual geographic location',
        risk: 'MEDIUM RISK',
        status: 'New',
        time: '1 hour ago'),
    SecurityAlert(
        id: '3',
        title: 'Account access attempt',
        user: 'Jessica Martinez',
        description: 'Password reset requested from new device',
        risk: 'LOW RISK',
        status: 'Resolved',
        time: '3 hours ago'),
    SecurityAlert(
        id: '4',
        title: 'Unusual activity',
        user: 'David Park',
        description: 'Large file download at unusual time',
        risk: 'MEDIUM RISK',
        status: 'Resolved',
        time: 'Yesterday'),
  ];

  // ── Login Logs ─────────────────────────────────────────────────────────────
  static const List<LoginLog> loginLogs = [
    LoginLog(
        id: '1',
        userName: 'Sarah Johnson',
        status: 'Success',
        time: '10:24 AM',
        date: 'Apr 20, 2026',
        device: 'Desktop',
        ip: '192.168.1.45'),
    LoginLog(
        id: '2',
        userName: 'Mike Chen',
        status: 'Failed',
        time: '09:15 AM',
        date: 'Apr 20, 2026',
        device: 'Mobile',
        ip: '203.0.113.42'),
    LoginLog(
        id: '3',
        userName: 'Emily Davis',
        status: 'Success',
        time: '08:45 AM',
        date: 'Apr 20, 2026',
        device: 'Desktop',
        ip: '192.168.1.78'),
    LoginLog(
        id: '4',
        userName: 'Unknown User',
        status: 'Failed',
        time: '07:30 AM',
        date: 'Apr 20, 2026',
        device: 'Mobile',
        ip: '198.51.100.23'),
    LoginLog(
        id: '5',
        userName: 'Alex Kim',
        status: 'Success',
        time: 'Yesterday 11:30 PM',
        date: 'Apr 19, 2026',
        device: 'Desktop',
        ip: '192.168.1.90'),
    LoginLog(
        id: '6',
        userName: 'Jessica Martinez',
        status: 'Failed',
        time: 'Yesterday 10:15 PM',
        date: 'Apr 19, 2026',
        device: 'Mobile',
        ip: '203.0.113.67'),
  ];

  // ── Files ──────────────────────────────────────────────────────────────────
  static const List<FileItem> secureFiles = [
    FileItem(
        id: '1',
        name: 'document-3.pdf',
        size: '1.2 MB',
        type: 'pdf',
        uploadedBy: 'Alice Smith',
        date: 'Just now',
        status: 'Verified'),
    FileItem(
        id: '2',
        name: 'project-brief.pdf',
        size: '2.4 MB',
        type: 'pdf',
        uploadedBy: 'John Doe',
        date: '2 hours ago',
        status: 'Verified'),
    FileItem(
        id: '3',
        name: 'security-report.docx',
        size: '1.8 MB',
        type: 'docx',
        uploadedBy: 'Mariam Kamel',
        date: '1 day ago',
        status: 'Verified'),
  ];

  static const List<FileItem> projectFiles = [
    FileItem(
        id: '1',
        name: 'project-proposal.pdf',
        size: '2.4 MB',
        type: 'pdf',
        uploadedBy: 'John Doe',
        date: 'Dec 15'),
    FileItem(
        id: '2',
        name: 'wireframe-v2.fig',
        size: '1.8 MB',
        type: 'figma',
        uploadedBy: 'Alice Smith',
        date: 'Dec 18'),
    FileItem(
        id: '3',
        name: 'hero-image.png',
        size: '3.2 MB',
        type: 'image',
        uploadedBy: 'Alice Smith',
        date: 'Dec 20'),
    FileItem(
        id: '4',
        name: 'meeting-notes.docx',
        size: '0.8 MB',
        type: 'doc',
        uploadedBy: 'John Doe',
        date: 'Jan 2'),
    FileItem(
        id: '5',
        name: 'design-system.sketch',
        size: '4.1 MB',
        type: 'sketch',
        uploadedBy: 'Alice Smith',
        date: 'Dec 25'),
  ];

  // ── Courses ────────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> recommendedCourses = [
    {
      'title': 'Advanced Flutter Development',
      'platform': 'Udemy',
      'progress': 65,
      'match': 95
    },
    {
      'title': 'Machine Learning with Python',
      'platform': 'Coursera',
      'progress': 30,
      'match': 88
    },
    {
      'title': 'UI/UX Design Fundamentals',
      'platform': 'Skillshare',
      'progress': 80,
      'match': 82
    },
    {
      'title': 'Firebase & Cloud Functions',
      'platform': 'YouTube',
      'progress': 10,
      'match': 75
    },
  ];

  // ── Recent Activity ────────────────────────────────────────────────────────
  static const List<Map<String, String>> recentActivity = [
    {
      'title': 'Completed "Design System Update"',
      'project': 'Project Alpha',
      'time': '2h ago'
    },
    {
      'title': 'New feedback received',
      'project': 'Performance',
      'time': '5h ago'
    },
    {
      'title': 'Started "API Integration"',
      'project': 'Project Beta',
      'time': '1d ago'
    },
  ];
  // ── Teams ──────────────────────────────────────────────────────────────────
  static List<TeamModel> teams = [
    const TeamModel(
        id: '1',
        name: 'Design Team',
        description: 'UI/UX designers and creative professionals',
        memberIds: ['1', '4'],
        projectsCount: 3),
    const TeamModel(
        id: '2',
        name: 'Development Team',
        description: 'Frontend and backend developers',
        memberIds: ['2', '3', '5'],
        projectsCount: 5),
    const TeamModel(
        id: '3',
        name: 'Marketing Team',
        description: 'Content, social media, and brand strategists',
        memberIds: ['4'],
        projectsCount: 2),
    const TeamModel(
        id: '4',
        name: 'Data Analytics',
        description: 'Data scientists and analysts',
        memberIds: ['3', '5'],
        projectsCount: 4),
  ];
}
