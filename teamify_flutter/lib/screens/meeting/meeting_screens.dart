import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/meeting_browser_speech.dart';
import '../../core/audio/meeting_speech_recorder.dart';
import '../../core/network/api_result.dart';
import '../../core/network/websocket_manager.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';

class _MeetingParticipant {
  final String userId;
  final String name;
  final String email;
  final String initials;
  bool isActive;

  _MeetingParticipant({
    required this.userId,
    required this.name,
    this.email = '',
    required this.initials,
    this.isActive = false,
  });
}

// ── Meeting Screen (Live/Start) ──────────────────────────────────────────────
class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  String? _roomId;
  String? _projectId;
  String _roomName = 'Meeting';
  List<_MeetingParticipant> _participants = [];
  Set<String> _presenceActiveIds = {};
  List<String> _liveNoteLines = [];
  List<Map<String, dynamic>> _chatRooms = [];

  bool _loading = true;
  String? _loadError;
  bool _isLive = false;
  bool _muted = false;
  String? _sessionId;
  bool _sessionSaved = false;
  bool _startingMeeting = false;
  bool _stoppingSession = false;
  List<Map<String, dynamic>> _sessionTranscript = [];
  final MeetingSpeechRecorder _speechRecorder = MeetingSpeechRecorder();
  MeetingBrowserSpeech? _browserSpeech;
  bool _useBrowserSpeech = false;
  bool _speechActive = false;
  bool _speechUnavailable = false;
  String? _livePartialSpeech;

  DateTime? _startedAt;
  Timer? _elapsedTimer;
  Timer? _pollTimer;
  StreamSubscription<SocketPayload>? _wsSub;
  WebSocketManager? _wsManager;
  String _elapsedLabel = '00:00';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _browserSpeech?.stop(null);
    _stopSpeechCapture();
    _speechRecorder.dispose();
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    _wsSub?.cancel();
    if (_isLive && _roomId != null) {
      _wsManager?.leaveMeeting(_roomId!);
    }
    super.dispose();
  }

  void _emitLeaveMeeting(String roomId) {
    _wsManager?.leaveMeeting(roomId);
  }

  WebSocketManager? _ws() {
    try {
      return context.read<WebSocketManager>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _bootstrap() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final argRoomId = args?['roomId']?.toString();
    final argRoomName = args?['roomName']?.toString();
    final argProjectId = args?['projectId']?.toString();

    try {
      final chat = context.read<AppServices>().chat;
      final rooms = await chat.listRooms().unwrap();
      if (!mounted) return;

      _chatRooms = rooms;
      String? selectedId = argRoomId;
      if (selectedId == null ||
          selectedId.isEmpty ||
          selectedId == 'general' ||
          int.tryParse(selectedId) == null) {
        final projectRooms = rooms
            .where((r) => r['project_id'] != null)
            .toList();
        if (projectRooms.isNotEmpty) {
          selectedId = projectRooms.first['id']?.toString();
        } else if (rooms.isNotEmpty) {
          selectedId = rooms.first['id']?.toString();
        }
      }

      if (selectedId == null) {
        setState(() {
          _loading = false;
          _loadError =
              'No chat rooms yet. Start a conversation first, then join a meeting from that chat.';
        });
        return;
      }

      await _loadRoom(
        selectedId,
        fallbackName: argRoomName,
        projectId: argProjectId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<List<_MeetingParticipant>> _loadParticipants(
    List<Map<String, dynamic>> chatMembers,
    String? projectId,
  ) async {
    final byId = <String, _MeetingParticipant>{};

    void addUser(String id, String name, String email) {
      if (id.isEmpty) return;
      byId[id] = _MeetingParticipant(
        userId: id,
        name: name,
        email: email,
        initials: _initials(name),
      );
    }

    for (final m in chatMembers) {
      addUser(
        m['user_id']?.toString() ?? '',
        m['display_name']?.toString() ?? 'User',
        m['email']?.toString() ?? '',
      );
    }

    if (projectId != null && projectId.isNotEmpty) {
      final result =
          await context.read<AppServices>().projects.listMembers(projectId);
      result.when(
        success: (users) {
          for (final u in users) {
            addUser(u.id, u.primaryName, u.email);
          }
        },
        failure: (_) {},
      );
    }

    final list = byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  void _applyMeetingPresence(Map<String, dynamic> data) {
    if (data['room_id']?.toString() != _roomId) return;
    final ids = (data['active_user_ids'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        {};

    if (!mounted) return;
    setState(() {
      _presenceActiveIds = ids;
      final known = {for (final p in _participants) p.userId: p};
      final users = (data['users'] as List?)?.whereType<Map>();
      if (users != null) {
        for (final raw in users) {
          final u = Map<String, dynamic>.from(raw);
          final id = u['user_id']?.toString() ?? '';
          if (id.isEmpty || known.containsKey(id)) continue;
          final name = u['display_name']?.toString() ?? 'User';
          _participants.add(_MeetingParticipant(
            userId: id,
            name: name,
            email: u['email']?.toString() ?? '',
            initials: _initials(name),
            isActive: ids.contains(id),
          ));
        }
      }
      for (final p in _participants) {
        p.isActive = _isLive && ids.contains(p.userId);
      }
    });
  }

  Future<void> _loadRoom(
    String roomId, {
    String? fallbackName,
    String? projectId,
  }) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final data =
          await context.read<AppServices>().chat.getRoom(roomId).unwrap();
      if (!mounted) return;

      final room = data['room'] as Map<String, dynamic>? ?? {};
      final members = (data['members'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      final name = room['name']?.toString().trim();
      _roomId = roomId;
      _projectId = room['project_id']?.toString() ?? projectId;
      _roomName = (name != null && name.isNotEmpty)
          ? name
          : (fallbackName ?? 'Chat $roomId');

      final session = context.read<SessionController>();
      final myId = session.currentUser?.id ?? '';

      _participants = await _loadParticipants(members, _projectId);

      if (_participants.isEmpty && myId.isNotEmpty) {
        final me = session.currentUser;
        final meName = me?.displayName ?? me?.fullName ?? 'You';
        _participants = [
          _MeetingParticipant(
            userId: myId,
            name: meName,
            email: me?.email ?? '',
            initials: _initials(meName),
          ),
        ];
      }

      await _refreshLiveNotes();

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  /// Keeps speech lines and merges in chat messages (by id), sorted by time.
  List<Map<String, dynamic>> _mergeChatIntoTranscript(
    List<Map<String, dynamic>> chatEntries,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final e in _sessionTranscript) {
      if (e['source']?.toString() == 'speech') {
        final id = e['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          byId[id] = Map<String, dynamic>.from(e);
        }
      }
    }
    for (final e in chatEntries) {
      final id = e['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      byId[id] = Map<String, dynamic>.from(e);
    }
    final merged = byId.values.toList();
    merged.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return da.compareTo(db);
    });
    return merged;
  }

  List<Map<String, dynamic>> _transcriptSnapshot() {
    return _sessionTranscript
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _refreshLiveNotes() async {
    final rid = _roomId;
    if (rid == null) return;

    List<Map<String, dynamic>> msgs;
    try {
      msgs = await context
          .read<AppServices>()
          .chat
          .getMessages(rid, perPage: 50)
          .unwrap();
    } catch (_) {
      return;
    }

    if (!mounted) return;

    final lines = msgs
        .map((m) => '${m['sender_name'] ?? 'User'}: ${m['content'] ?? ''}')
        .where((line) => line.trim().length > 2)
        .toList();

    List<String> noteLines;
    if (_isLive && _startedAt != null) {
      noteLines = [];
      final chatEntries = <Map<String, dynamic>>[];
      for (final m in msgs) {
        final created = m['created_at']?.toString() ?? '';
        final dt = DateTime.tryParse(created);
        if (dt != null && !dt.isBefore(_startedAt!)) {
          noteLines.add(
            '${m['sender_name'] ?? 'User'}: ${m['content'] ?? ''}',
          );
          chatEntries.add({
            'id': m['id'],
            'sender_id': m['sender_id'],
            'sender_name': m['sender_name'] ?? 'User',
            'content': m['content'] ?? '',
            'created_at': created,
          });
        }
      }
      // Merge chat with speech — do not replace (speech would be lost on save).
      _sessionTranscript = _mergeChatIntoTranscript(chatEntries);
      noteLines = _sessionTranscript
          .map((e) {
            final name = e['sender_name'] ?? 'User';
            final text = e['content'] ?? '';
            if (e['source']?.toString() == 'speech') {
              return '[Speech] $name: $text';
            }
            return '$name: $text';
          })
          .where((line) => line.trim().length > 2)
          .toList();
    } else {
      noteLines = lines.length > 5 ? lines.sublist(lines.length - 5) : lines;
    }

    if (!mounted) return;
    setState(() {
      for (final p in _participants) {
        p.isActive = _isLive && _presenceActiveIds.contains(p.userId);
      }
      _liveNoteLines = noteLines.length > 8
          ? noteLines.sublist(noteLines.length - 8)
          : noteLines;
    });
  }

  Future<void> _startMeeting() async {
    final rid = _roomId;
    if (rid == null || _startingMeeting) return;

    setState(() => _startingMeeting = true);

    final chat = context.read<AppServices>().chat;
    try {
      final session = await chat.startMeetingSession(rid).unwrap();
      if (!mounted) return;

      final startedRaw = session['started_at']?.toString();
      final startedAt = DateTime.tryParse(startedRaw ?? '') ?? DateTime.now();
      final myId = context.read<SessionController>().currentUser?.id ?? '';

      setState(() {
        _startingMeeting = false;
        _isLive = true;
        _sessionId = session['id']?.toString();
        _sessionSaved = false;
        _sessionTranscript = [];
        _startedAt = startedAt;
        _presenceActiveIds = {if (myId.isNotEmpty) myId};
        for (final p in _participants) {
          p.isActive = p.userId == myId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _startingMeeting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start meeting: $e')),
      );
      return;
    }

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = _startedAt;
      if (start == null || !mounted || !_isLive) return;
      final elapsed = DateTime.now().difference(start);
      if (!mounted) return;
      setState(() {
        _elapsedLabel = _formatDuration(elapsed);
      });
    });

    _wsSub?.cancel();
    _pollTimer?.cancel();

    await _startSpeechCapture();

    _wsManager = _ws();
    final wsManager = _wsManager;
    if (wsManager != null && wsManager.isConnected) {
      wsManager.joinRoom(rid);
      wsManager.joinMeeting(rid);
      _wsSub = wsManager.stream.listen((payload) {
        if (payload.event == SocketEvent.meetingPresence) {
          _applyMeetingPresence(payload.data);
        } else if (payload.event == SocketEvent.chatMessage) {
          if (payload.data['room_id']?.toString() == _roomId) {
            _refreshLiveNotes();
          }
        }
      });
    } else {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _refreshLiveNotes();
      });
    }
    _refreshLiveNotes();
  }

  List<String> _participantIdsForSession() {
    final ids = <String>{..._presenceActiveIds};
    final myId = context.read<SessionController>().currentUser?.id;
    if (myId != null && myId.isNotEmpty) ids.add(myId);
    return ids.toList();
  }

  Future<bool> _persistSession({bool silent = false}) async {
    final rid = _roomId;
    final sid = _sessionId;
    if (rid == null || sid == null || _sessionSaved || _stoppingSession) {
      return _sessionSaved;
    }

    if (!silent && mounted) {
      setState(() => _stoppingSession = true);
    }

    final participantIds = _participantIdsForSession();
    final transcript = _transcriptSnapshot();
    final chat = context.read<AppServices>().chat;
    try {
      await chat.stopMeetingSession(
            rid,
            sid,
            transcript: transcript,
            participantIds: participantIds,
          ).unwrap();
      _sessionSaved = true;
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting transcript saved'),
          ),
        );
      }
      return true;
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save transcript: $e')),
        );
      }
      return false;
    } finally {
      if (!silent && mounted) {
        setState(() => _stoppingSession = false);
      }
    }
  }

  Future<void> _startSpeechCapture() async {
    if (kIsWeb) {
      final browser = MeetingBrowserSpeech();
      final ok = await browser.initialize();
      if (ok) {
        _browserSpeech = browser;
        _useBrowserSpeech = true;
        await browser.startListening(_onBrowserSpeechResult);
        if (mounted) {
          setState(() {
            _speechActive = true;
            _speechUnavailable = false;
          });
        }
        return;
      }
    }

    final allowed = await _speechRecorder.ensurePermission();
    if (!allowed) {
      if (mounted) {
        setState(() => _speechUnavailable = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow microphone access to transcribe speech.',
            ),
          ),
        );
      }
      return;
    }
    _useBrowserSpeech = false;
    _speechRecorder.start(
      shouldCapture: () => _isLive && !_muted,
      onChunk: _onSpeechChunk,
    );
    if (mounted) setState(() => _speechActive = true);
  }

  void _stopSpeechCapture() {
    _browserSpeech?.stop(null);
    _browserSpeech = null;
    _useBrowserSpeech = false;
    _speechRecorder.stop();
    if (mounted) {
      setState(() {
        _speechActive = false;
        _livePartialSpeech = null;
      });
    }
  }

  Future<void> _flushSpeechCapture() async {
    if (!_isLive || _muted) return;
    if (_useBrowserSpeech && _browserSpeech != null) {
      await _browserSpeech!.stop(_onBrowserSpeechResult);
      return;
    }
    await _speechRecorder.flush(
      _onSpeechChunk,
      shouldCapture: () => _isLive && !_muted,
    );
  }

  void _onBrowserSpeechResult(String text, bool isFinal) {
    if (!_isLive || _muted || !mounted || text.trim().isEmpty) return;
    if (!isFinal) {
      setState(() => _livePartialSpeech = text.trim());
      return;
    }
    _appendSpeechLine(text.trim());
    setState(() => _livePartialSpeech = null);
  }

  void _appendSpeechLine(String text) {
    if (!mounted) return;
    final user = context.read<SessionController>().currentUser;
    final name = (user?.fullName.isNotEmpty == true)
        ? user!.fullName
        : (user?.displayName ?? 'You');
    final myId = user?.id ?? '';

    final dup = _sessionTranscript.any(
      (e) =>
          e['source']?.toString() == 'speech' &&
          e['content']?.toString() == text,
    );
    if (dup) return;

    final line = '$name: $text';
    final entry = {
      'id': 'speech-${DateTime.now().millisecondsSinceEpoch}',
      'source': 'speech',
      'sender_id': myId,
      'sender_name': name,
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    setState(() {
      _sessionTranscript = [..._sessionTranscript, entry];
      final notes = [..._liveNoteLines, '[Speech] $line'];
      _liveNoteLines =
          notes.length > 12 ? notes.sublist(notes.length - 12) : notes;
    });
  }

  Future<void> _onSpeechChunk(Uint8List bytes, String filename) async {
    if (!_isLive || _muted || !mounted) return;

    final result = await context.read<AppServices>().ai.transcribe(
          bytes,
          filename: filename,
        );
    if (!mounted) return;

    if (!result.isSuccess) {
      if (!_speechUnavailable && mounted) {
        setState(() => _speechUnavailable = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.error?.contains('502') == true ||
                      result.error?.toLowerCase().contains('stt') == true
                  ? 'Whisper STT offline — on Chrome, speech uses browser captions when the mic is allowed.'
                  : 'Speech transcription failed: ${result.error}',
            ),
          ),
        );
      }
      return;
    }

    final text = result.data!.text.trim();
    if (text.isEmpty) return;
    _appendSpeechLine(text);
  }

  Future<void> _stopRecording() async {
    if (_stoppingSession) return;
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    _wsSub?.cancel();
    await _flushSpeechCapture();
    _stopSpeechCapture();
    if (_roomId != null) {
      _emitLeaveMeeting(_roomId!);
    }
    await _refreshLiveNotes();
    await _persistSession();
    if (!mounted) return;
    setState(() {
      _isLive = false;
      _speechActive = false;
      _presenceActiveIds = {};
      for (final p in _participants) {
        p.isActive = false;
      }
    });
  }

  Future<void> _endMeeting() async {
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    _wsSub?.cancel();
    await _flushSpeechCapture();
    _stopSpeechCapture();
    if (_isLive && _roomId != null) {
      _emitLeaveMeeting(_roomId!);
    }
    if (_sessionId != null && !_sessionSaved) {
      await _refreshLiveNotes();
      await _persistSession(silent: true);
    } else if (_sessionId != null && _sessionSaved) {
      // Still refresh so inline transcript for summary includes speech.
      await _refreshLiveNotes();
    }
    final rid = _roomId;
    final sessionId = _sessionId;
    final transcript = _transcriptSnapshot();
    if (rid == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingSummaryScreen(
          roomName: _roomName,
          roomId: rid,
          sessionId: sessionId,
          inlineTranscript: transcript,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h.toString().padLeft(2, '0')}:$m:$s';
    return '$m:$s';
  }

  String _initials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  int get _activeCount => _participants.where((p) => p.isActive).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: _isLive ? null : () => Navigator.pop(context)),
        title: const Text('Meeting',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _errorBody()
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_chatRooms.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _roomId,
                          decoration: InputDecoration(
                            labelText: 'Chat room',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _chatRooms
                              .map((r) => DropdownMenuItem(
                                    value: r['id']?.toString(),
                                    child: Text(
                                      r['name']?.toString() ??
                                          'Room ${r['id']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: _isLive
                              ? null
                              : (id) {
                                  if (id != null) _loadRoom(id);
                                },
                        ),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.videocam_outlined,
                                    color: AppColors.primary)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_roomName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  Text(
                                    _isLive
                                        ? 'Live · $_activeCount in meeting now'
                                        : _projectId != null
                                            ? 'Project team · chat history'
                                            : 'Linked to chat room',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.people_outline,
                              size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          const Text('Participants',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const Spacer(),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                  _isLive
                                      ? '$_activeCount active'
                                      : '${_participants.length} members',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isLive) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFDC2626),
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Text('Speech + chat transcript',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppColors.textPrimary)),
                                    Text(
                                        _sessionId != null
                                            ? _speechActive
                                                ? _useBrowserSpeech
                                                    ? 'Session #$_sessionId · live speech (browser) + chat'
                                                    : 'Session #$_sessionId · Whisper STT + chat'
                                                : _speechUnavailable
                                                    ? 'Session #$_sessionId · chat only (mic/STT off)'
                                                    : 'Session #$_sessionId · saving to database'
                                            : 'Starting session…',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                  ])),
                              const Icon(Icons.access_time,
                                  size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(_elapsedLabel,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Expanded(
                        child: _participants.isEmpty
                            ? const Center(
                                child: Text(
                                  'No members in this room yet.',
                                  style:
                                      TextStyle(color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _participants.length,
                                itemBuilder: (_, i) {
                                  final p = _participants[i];
                                  return _participantRow(
                                    p.name,
                                    p.email,
                                    p.isActive ? 'In meeting' : 'Not joined',
                                    p.isActive,
                                    p.initials,
                                  );
                                },
                              ),
                      ),
                      if (!_isLive && _liveNoteLines.isNotEmpty) ...[
                        const Text('Recent chat',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _liveNoteLines
                                .map(
                                  (line) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      line,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_isLive) ...[
                        const Text('Live Notes',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(minHeight: 72),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12)),
                          child: _liveNoteLines.isEmpty &&
                                  (_livePartialSpeech == null ||
                                      _livePartialSpeech!.isEmpty)
                              ? Text(
                                  _speechActive
                                      ? 'Listening… speak clearly or send chat messages.'
                                      : 'Waiting for chat or microphone speech…',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ..._liveNoteLines.map(
                                      (line) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Text(
                                          line,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_livePartialSpeech != null &&
                                        _livePartialSpeech!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '[Listening] $_livePartialSpeech…',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final next = !_muted;
                                      setState(() => _muted = next);
                                      if (next) {
                                        await _browserSpeech?.stop(null);
                                      } else if (_isLive && _useBrowserSpeech) {
                                        await _browserSpeech?.startListening(
                                          _onBrowserSpeechResult,
                                        );
                                      }
                                    },
                                    icon: Icon(_muted
                                        ? Icons.mic_off
                                        : Icons.mic_none),
                                    label: Text(_muted ? 'Unmute' : 'Mute'),
                                    style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 50),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12))))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: _isLive && !_stoppingSession
                                        ? _stopRecording
                                        : null,
                                    icon: const Icon(Icons.stop_circle_outlined,
                                        color: Color(0xFFDC2626)),
                                    label: Text(
                                        _stoppingSession
                                            ? 'Saving…'
                                            : 'Stop & Save',
                                        style: const TextStyle(
                                            color: Color(0xFFDC2626))),
                                    style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 50),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12))))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _endMeeting,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                minimumSize: const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: const Text('End Meeting',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))),
                      ] else ...[
                        ElevatedButton(
                            onPressed: _roomId == null || _startingMeeting
                                ? null
                                : _startMeeting,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            child: _startingMeeting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Start Meeting',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14))),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _loadError = null;
                });
                _bootstrap();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _participantRow(String name, String email, String status,
      bool isActive, String initials) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(
          children: [
            TAvatar(initials: initials, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  if (email.isNotEmpty)
                    Text(email,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  Text(status,
                      style: TextStyle(
                          fontSize: 11,
                          color: isActive
                              ? const Color(0xFF16A34A)
                              : AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Meeting Summary Screen ───────────────────────────────────────────────────
class MeetingSummaryScreen extends StatefulWidget {
  final String roomName;
  final String roomId;
  final String? sessionId;
  final List<Map<String, dynamic>> inlineTranscript;

  const MeetingSummaryScreen({
    super.key,
    required this.roomName,
    required this.roomId,
    this.sessionId,
    this.inlineTranscript = const [],
  });

  @override
  State<MeetingSummaryScreen> createState() => _MeetingSummaryScreenState();
}

class _MeetingSummaryScreenState extends State<MeetingSummaryScreen> {
  bool _loading = true;
  String? _error;
  String _summaryText = '';
  List<String> _speechTranscript = [];
  List<String> _keyPoints = [];
  List<Map<String, String>> _actions = [];
  int _participantsCount = 0;
  String? _durationLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSummary());
  }

  Future<void> _loadSummary() async {
    try {
      final svc = context.read<AppServices>();

      // ── 1. Try to get stored session ──────────────────────────────────────
      List<Map<String, dynamic>> msgs = [...widget.inlineTranscript];
      Map<String, dynamic>? storedSummary;

      try {
        final roomData = await svc.chat.getRoom(widget.roomId).unwrap();
        final members =
            (roomData['members'] as List?)?.whereType<Map<String, dynamic>>();
        _participantsCount = members?.length ?? 0;
      } catch (_) {}

      final sid = widget.sessionId;
      if (sid != null && sid.isNotEmpty) {
        try {
          final session = await svc.chat
              .getMeetingSession(widget.roomId, sid)
              .unwrap();

          final participants = session['participant_ids'];
          if (participants is List && participants.isNotEmpty) {
            _participantsCount = participants.length;
          }
          final secs = session['duration_seconds'];
          if (secs is int && secs > 0) {
            final d = Duration(seconds: secs);
            final h = d.inHours;
            final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
            final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
            _durationLabel =
                h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
          }

          // Prefer inline transcript; fall back to DB when inline is empty.
          final transcriptRaw = session['transcript'];
          final dbMsgs = transcriptRaw is List
              ? transcriptRaw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];
          if (msgs.isEmpty) {
            msgs = dbMsgs;
          } else if (dbMsgs.length > msgs.length) {
            msgs = dbMsgs;
          }

          // Use stored AI summary only when transcript has content.
          final summaryText = session['summary']?.toString().trim();
          if (summaryText != null &&
              summaryText.isNotEmpty &&
              msgs.isNotEmpty) {
            storedSummary = Map<String, dynamic>.from(session);
          } else {
            final aiSummary = session['ai_summary'];
            if (aiSummary is Map &&
                aiSummary['summary'] != null &&
                msgs.isNotEmpty) {
              storedSummary = Map<String, dynamic>.from(
                  aiSummary as Map<String, dynamic>);
            }
          }
        } catch (_) {}
      }

      // ── 2. If still no messages, load from chat history ──────────────────
      if (msgs.isEmpty) {
        try {
          msgs = await svc.chat
              .getMessages(widget.roomId, perPage: 100)
              .unwrap();
        } catch (_) {}
      }

      if (_durationLabel == null && msgs.length >= 2) {
        final first =
            DateTime.tryParse(msgs.first['created_at']?.toString() ?? '');
        final last =
            DateTime.tryParse(msgs.last['created_at']?.toString() ?? '');
        if (first != null && last != null) {
          final diff = last.difference(first);
          final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
          final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
          _durationLabel =
              '${diff.inHours > 0 ? '${diff.inHours}h ' : ''}$m:$s';
        }
      }

      // ── 3. Use stored summary if available ────────────────────────────────
      if (storedSummary != null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _applySummaryPayload(storedSummary!, msgs);
        });
        return;
      }

      // ── 4. Build summary from transcript ─────────────────────────────────
      if (msgs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _summaryText = 'No messages were captured in this meeting.';
        });
        return;
      }

      final transcript = msgs
          .map((m) => '${m['sender_name'] ?? 'User'}: ${m['content'] ?? ''}')
          .where((l) => l.trim().length > 3)
          .join('\n');

      Map<String, dynamic> summary;
      try {
        summary = await svc.ai.summarizeChat(transcript, topN: 6).unwrap();
      } catch (_) {
        summary = _buildLocalSummaryPayload(msgs);
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _applySummaryPayload(summary, msgs);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _applySummaryPayload(
    Map<String, dynamic> summary,
    List<Map<String, dynamic>> msgs,
  ) {
    _summaryText = summary['summary']?.toString().trim() ?? '';
    if (_summaryText.isEmpty) {
      _summaryText = _buildLocalSummaryText(msgs);
    }

    final speechRaw = summary['speech_transcript'];
    if (speechRaw is List && speechRaw.isNotEmpty) {
      _speechTranscript =
          speechRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    } else {
      _speechTranscript = msgs
          .where((m) => m['source']?.toString() == 'speech')
          .map((m) => '${m['sender_name'] ?? 'User'}: ${m['content'] ?? ''}')
          .where((line) => line.trim().length > 2)
          .toList();
    }

    final kp = summary['key_points'];
    final ai = summary['action_items'];
    _keyPoints = kp is List
        ? kp.map((e) => e.toString()).where((s) => s.length >= 4).toList()
        : _extractLocalKeyPoints(msgs);
    _actions = [];
    if (ai is List) {
      for (final item in ai) {
        if (item is Map) {
          _actions.add({
            'text': item['text']?.toString() ??
                item['action']?.toString() ??
                item.toString(),
            'owner': item['owner']?.toString() ??
                item['person']?.toString() ??
                item['assignee']?.toString() ??
                'Unassigned',
            'due': item['due']?.toString() ??
                item['due_date']?.toString() ??
                'TBD',
          });
        } else {
          _actions.add({
            'text': item.toString(),
            'owner': 'Unassigned',
            'due': 'TBD',
          });
        }
      }
    }
  }

  Map<String, dynamic> _buildLocalSummaryPayload(
    List<Map<String, dynamic>> msgs,
  ) {
    return {
      'summary': _buildLocalSummaryText(msgs),
      'speech_transcript': msgs
          .where((m) => m['source']?.toString() == 'speech')
          .map((m) => '${m['sender_name'] ?? 'User'}: ${m['content'] ?? ''}')
          .toList(),
      'key_points': _extractLocalKeyPoints(msgs),
      'action_items': const [],
    };
  }

  String _buildLocalSummaryText(List<Map<String, dynamic>> msgs) {
    if (msgs.isEmpty) {
      return 'No speech or chat content was captured in this meeting.';
    }
    final speech = msgs
        .where((m) => m['source']?.toString() == 'speech')
        .map((m) => (m['content'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final chat = msgs
        .where((m) => m['source']?.toString() != 'speech')
        .map((m) => (m['content'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final who = msgs.first['sender_name']?.toString() ?? 'Participants';

    if (speech.isNotEmpty) {
      return '$who spoke during this session. '
          'Transcribed speech: "${speech.join('; ')}".';
    }
    if (chat.isNotEmpty) {
      return '$who discussed: ${chat.take(6).join('. ')}.';
    }
    return 'Meeting content was captured but could not be summarized.';
  }

  List<String> _extractLocalKeyPoints(List<Map<String, dynamic>> msgs) {
    return msgs
        .map((m) => (m['content'] ?? '').toString().trim())
        .where((s) => s.length >= 4)
        .take(6)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Meeting Summary',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _loadSummary();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Row(children: [
                        Icon(Icons.bolt, size: 16, color: Color(0xFF7C3AED)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'AI summary from speech (Whisper) + chat transcript',
                              style: TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    _sectionHeader(Icons.summarize_outlined, 'Meeting Summary'),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Text(
                        _summaryText.isNotEmpty
                            ? _summaryText
                            : 'No summary could be generated from this meeting.',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.roomName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_participantsCount participants'
                      '${_durationLabel != null ? ' · $_durationLabel' : ''}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    if (_speechTranscript.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionHeader(Icons.mic_none, 'Speech Transcript'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          _speechTranscript.join('\n'),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.7,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _sectionHeader(
                        Icons.chat_bubble_outline, 'Key Discussion Points'),
                    if (_keyPoints.isEmpty)
                      const Text('No key points returned.',
                          style: TextStyle(color: AppColors.textSecondary))
                    else
                      ..._keyPoints.map(_pointBox),
                    const SizedBox(height: 24),
                    _sectionHeader(Icons.assignment_outlined, 'Action Items'),
                    if (_actions.isEmpty)
                      const Text('No action items returned.',
                          style: TextStyle(color: AppColors.textSecondary))
                    else
                      ..._actions.map((a) => _actionCard(
                            a['text']!,
                            a['owner']!,
                            a['due']!,
                            const Color(0xFFF59E0B),
                          )),
                    const SizedBox(height: 30),
                  ],
                ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.textPrimary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
      ]));

  Widget _pointBox(String t) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8)),
      child: Text(t,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textPrimary, height: 1.4)));

  Widget _actionCard(String t, String owner, String date, Color c) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF1E40AF))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(owner,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          Text(date,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: c))
        ])
      ]));
}
