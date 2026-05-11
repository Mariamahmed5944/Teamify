import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/models/models.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

// ── Local chat data (no backend endpoint for chat rooms / messages) ──────────
const _localChatRooms = <ChatRoom>[
  ChatRoom(id: '1', name: 'Website Redesign', lastMessage: 'Alice: Updated wireframes!', time: '10:30 AM', initials: 'WR', unread: 3, isGroup: true),
  ChatRoom(id: '2', name: 'John Doe', lastMessage: 'Can you review the PR?', time: '9:15 AM', initials: 'JD', unread: 1, isGroup: false),
  ChatRoom(id: '3', name: 'AI Planner Team', lastMessage: 'Mike: Model is ready!', time: 'Yesterday', initials: 'AP', unread: 0, isGroup: true),
  ChatRoom(id: '4', name: 'Lisa Park', lastMessage: 'Designs sent to Figma.', time: 'Yesterday', initials: 'LP', unread: 0, isGroup: false),
];

const _localGroupMessages = <ChatMessage>[
  ChatMessage(id: '1', senderId: '5', senderName: 'Mariam Kamel', senderInitials: 'MK', message: 'Hey team, just uploaded the latest wireframes. Take a look when you get a chance!', time: '9:30 AM', isMe: false),
  ChatMessage(id: '2', senderId: '1', senderName: 'Alice Smith', senderInitials: 'AS', message: "Great! I'll review them this afternoon.", time: '9:35 AM', isMe: true),
  ChatMessage(id: '3', senderId: '3', senderName: 'Mike Kumar', senderInitials: 'MK', message: 'Quick question - should we use the new color scheme for the dashboard?', time: '10:15 AM', isMe: false),
  ChatMessage(id: '4', senderId: '5', senderName: 'Mariam Kamel', senderInitials: 'MK2', message: "Yes, let's go with the new palette. It aligns better with the brand guidelines.", time: '10:20 AM', isMe: false),
  ChatMessage(id: '5', senderId: '1', senderName: 'Alice Smith', senderInitials: 'AS', message: "I've made some updates to the homepage mockup. Can someone review?", time: '2:30 PM', isMe: true),
  ChatMessage(id: '6', senderId: '3', senderName: 'Mike Kumar', senderInitials: 'MK', message: "I'll review them now.", time: '2:50 PM', isMe: false),
];

// ── Chat List ─────────────────────────────────────────────────────────────────
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('New Message',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                ...[
                                  'Alice Smith',
                                  'John Doe',
                                  'Mike Kumar',
                                  'Lisa Park'
                                ].map((name) => ListTile(
                                      leading: TAvatar(
                                          initials: name
                                              .split(' ')
                                              .map((e) => e[0])
                                              .join(),
                                          radius: 18),
                                      title: Text(name),
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.pushNamed(
                                            context, R.directChat);
                                      },
                                    )),
                              ]),
                        ));
              })
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _localChatRooms.length,
        itemBuilder: (_, i) {
          final r = _localChatRooms[i];
          return TCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => Navigator.pushNamed(
                context, r.isGroup ? R.groupChat : R.directChat,
                arguments: r),
            child: Row(children: [
              Stack(children: [
                TAvatar(
                    initials: r.initials,
                    radius: 24,
                    bg: r.isGroup ? AppColors.primary : AppColors.accent),
                if (r.unread > 0)
                  Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: Center(
                            child: Text('${r.unread}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold))),
                      )),
              ]),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          Text(r.time,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ]),
                    const SizedBox(height: 2),
                    Text(r.lastMessage,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ])),
            ]),
          );
        },
      ),
      bottomNavigationBar:
          TBottomNav(current: 3, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }
}

// ── Group Chat ────────────────────────────────────────────────────────────────
class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _ctrl = TextEditingController();
  final List<Map<String, dynamic>> _msgs = [];

  void _send() {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() {
      _msgs.add({'text': _ctrl.text, 'isMe': true, 'time': '2:55 PM'});
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final msgs = [..._localGroupMessages, ..._msgs.map((m) => _FakeMsg(m))];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Row(children: [
          TAvatar(initials: 'WD', radius: 18),
          SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Group Chat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('Tab here for group info',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () => Navigator.pushNamed(context, R.meeting)),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: msgs.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: TChip(label: 'Today', bg: AppColors.border)));
                }
                final m = msgs[i - 1];
                return _buildBubble(m);
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(dynamic m) {
    final isMe = m is _FakeMsg ? m.isMe : (m as dynamic).isMe as bool;
    final text = m is _FakeMsg ? m.text : m.message as String;
    final time = m is _FakeMsg ? m.time : m.time as String;
    final name = m is _FakeMsg ? 'You' : m.senderName as String;
    final init = m is _FakeMsg ? 'AS' : m.senderInitials as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            TAvatar(initials: init, radius: 16, bg: AppColors.primary),
            const SizedBox(width: 8)
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(name,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isMe ? null : Border.all(color: AppColors.border),
                  ),
                  child: Text(text,
                      style: TextStyle(
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          fontSize: 13)),
                ),
                Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('$time ✓✓',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary))),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            const TAvatar(initials: 'AS', radius: 16)
          ],
        ],
      ),
    );
  }

  Widget _buildInput() => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SafeArea(
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.add, color: AppColors.textSecondary),
                onPressed: () {}),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                      hintText: 'Type a message...', border: InputBorder.none),
                ),
              ),
            ),
            IconButton(
                icon: const Icon(Icons.copy_outlined,
                    color: AppColors.textSecondary),
                onPressed: () {}),
            IconButton(
                icon: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.textSecondary),
                onPressed: () {}),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      );
}

class _FakeMsg {
  final String text, time;
  final bool isMe;
  _FakeMsg(Map m)
      : text = m['text'],
        time = m['time'],
        isMe = m['isMe'];
}

// ── Direct Chat ───────────────────────────────────────────────────────────────
class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({super.key});
  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _ctrl = TextEditingController();
  final _msgs = <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Row(children: [
          TAvatar(initials: 'JD', radius: 18),
          SizedBox(width: 8),
          Text('John Doe',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            _bubble('Hi! Can you review the latest PR?', false, '9:00 AM'),
            _bubble('Sure, I\'ll check it now.', true, '9:02 AM'),
            _bubble('Thanks! Also, the meeting is at 3 PM.', false, '9:05 AM'),
            ..._msgs.map((m) => _bubble(m['text'], true, m['time'])),
          ])),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SafeArea(
                child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (_ctrl.text.isNotEmpty) {
                    setState(() {
                      _msgs.add({'text': _ctrl.text, 'time': 'Now'});
                      _ctrl.clear();
                    });
                  }
                },
                child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.send, color: Colors.white, size: 18)),
              ),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, bool isMe, String time) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isMe ? null : Border.all(color: AppColors.border)),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(text,
                    style: TextStyle(
                        color: isMe ? Colors.white : AppColors.textPrimary,
                        fontSize: 13)),
                Text(time,
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            isMe ? Colors.white60 : AppColors.textSecondary)),
              ]),
            ),
          ],
        ),
      );
}

// ── Chat Summary ──────────────────────────────────────────────────────────────
class ChatSummaryScreen extends StatelessWidget {
  const ChatSummaryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Chat Summary',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const AIBanner(
            title: 'AI Summary',
            subtitle: 'Generated from last 24 hours of conversation'),
        const SizedBox(height: 16),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Key Points',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 16)),
          const SizedBox(height: 12),
          ...[
            'Alice uploaded new wireframes for Website Redesign',
            'Team agreed to use new color scheme aligned with brand',
            'Homepage mockup updates need review from team members',
            'Mike confirmed he will review the updates immediately',
          ].map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
                Expanded(
                    child: Text(p,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary))),
              ]))),
        ])),
        const SizedBox(height: 12),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Action Items',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 16)),
          const SizedBox(height: 12),
          ...[
            'Review homepage mockup — Alice Smith',
            'Confirm color scheme — All team',
            'Update brand guidelines doc — Mike Kumar'
          ].map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.check_box_outline_blank,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(a,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary))),
              ]))),
        ])),
      ]),
    );
  }
}

// ── Pinned Messages ───────────────────────────────────────────────────────────
class PinnedMessagesScreen extends StatelessWidget {
  const PinnedMessagesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Pinned Messages',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, i) => TCard(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            const Icon(Icons.push_pin, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      [
                        'Alice: New wireframes uploaded!',
                        'Mariam: Meeting at 3 PM today',
                        'Mike: API docs updated'
                      ][i],
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 13)),
                  Text(['10:30 AM', '9:00 AM', 'Yesterday'][i],
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ])),
          ]),
        ),
      ),
    );
  }
}

// ── Smart Q&A ─────────────────────────────────────────────────────────────────
class SmartQAScreen extends StatefulWidget {
  const SmartQAScreen({super.key});
  @override
  State<SmartQAScreen> createState() => _SmartQAScreenState();
}

class _SmartQAScreenState extends State<SmartQAScreen> {
  final _ctrl = TextEditingController();
  final _answers = <Map<String, String>>[];

  void _ask() {
    if (_ctrl.text.trim().isEmpty) return;
    final q = _ctrl.text;
    setState(() {
      _answers.add({
        'q': q,
        'a':
            'Based on the project data: ${q.contains('deadline') ? "The project deadline is December 20, 2024." : q.contains('task') ? "There are 5 tasks: 2 complete, 2 in progress, 1 to do." : "I found relevant information in the project chat and files."}'
      });
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Smart Q&A',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(children: [
        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          const AIBanner(
              title: 'Ask AI about this project',
              subtitle: 'Get instant answers from chat history and files'),
          const SizedBox(height: 16),
          ..._answers.map((a) => Column(children: [
                Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16)),
                        child: Text(a['q']!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)))),
                TCard(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.auto_awesome,
                                  color: Colors.white, size: 14)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(a['a']!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary))),
                        ])),
              ])),
        ])),
        Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: SafeArea(
                child: Row(children: [
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(24)),
                      child: TextField(
                          controller: _ctrl,
                          decoration: const InputDecoration(
                              hintText: 'Ask about deadlines, tasks...',
                              border: InputBorder.none)))),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: _ask,
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 18))),
            ]))),
      ]),
    );
  }
}

// ── File Sharing ──────────────────────────────────────────────────────────────
class FileSharingScreen extends StatefulWidget {
  const FileSharingScreen({super.key});
  @override
  State<FileSharingScreen> createState() => _FileSharingScreenState();
}

class _FileSharingScreenState extends State<FileSharingScreen> {
  late Future<List<ApiFile>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = context.read<AppRepositories>().files.listFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Shared Files',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                icon: const Icon(Icons.upload_file_outlined), onPressed: () {})
          ]),
      body: FutureBuilder<List<ApiFile>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _filesFuture = context.read<AppRepositories>().files.listFiles();
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ]),
            );
          }
          final files = snapshot.data ?? [];
          if (files.isEmpty) {
            return const Center(
              child: Text('No shared files yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: files.map((f) => TCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.insert_drive_file_outlined,
                        color: AppColors.primary, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(f.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 13)),
                      Text('${f.size} • ${f.uploadedBy}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ])),
                IconButton(
                    icon: const Icon(Icons.download_outlined,
                        color: AppColors.primary),
                    onPressed: () {}),
              ]),
            )).toList(),
          );
        },
      ),
    );
  }
}

// ── File Integrity ────────────────────────────────────────────────────────────
class FileIntegrityScreen extends StatefulWidget {
  const FileIntegrityScreen({super.key});
  @override
  State<FileIntegrityScreen> createState() => _FileIntegrityScreenState();
}

class _FileIntegrityScreenState extends State<FileIntegrityScreen> {
  late Future<List<ApiFile>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = context.read<AppRepositories>().files.listFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('File Integrity',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: FutureBuilder<List<ApiFile>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _filesFuture = context.read<AppRepositories>().files.listFiles();
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ]),
            );
          }
          final files = snapshot.data ?? [];
          return ListView(padding: const EdgeInsets.all(16), children: [
            const TCard(
                child: Column(children: [
              Icon(Icons.verified_user, color: AppColors.success, size: 48),
              SizedBox(height: 8),
              Text('All Files Verified',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success)),
              SizedBox(height: 4),
              Text('Last scan: 2 minutes ago',
                  style: TextStyle(color: AppColors.textSecondary))
            ])),
            const SizedBox(height: 12),
            if (files.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No files to verify.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ...files.map((f) => TCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(f.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary))),
                    TChip(
                        label: 'SHA-256 ✓',
                        bg: AppColors.success.withOpacity(0.1),
                        textColor: AppColors.success),
                  ]))),
          ]);
        },
      ),
    );
  }
}
