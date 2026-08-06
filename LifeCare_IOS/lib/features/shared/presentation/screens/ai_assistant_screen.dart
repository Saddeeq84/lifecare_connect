import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/services/gemini_service.dart';

enum AIAssistantType {
  chw,
  doctor,
  patient,
  nursing,
  opd,
  specialist,
  laboratory,
  publicHealth,
  pharmacy,
  scan,
}

class AIAssistantScreen extends StatefulWidget {
  final AIAssistantType assistantType;

  const AIAssistantScreen({super.key, required this.assistantType});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  GeminiService? _geminiService;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  final List<Map<String, String>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    try {
      await GeminiService.initialize();
      _geminiService = GeminiService.instance;
      setState(() {
        _isInitialized = true;
      });
      _addWelcomeMessage();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize AI: $e';
        _isInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    String welcomeText;
    List<String> quickActions;

    switch (widget.assistantType) {
      case AIAssistantType.chw:
        welcomeText =
            "👋 Hello! I'm your CHW AI Assistant powered by Google Gemini. I'm here to help you with:\n\n"
            "• Clinical decision-making support\n"
            "• Patient care best practices\n"
            "• Patient counseling techniques\n"
            "• Health education topics\n"
            "• Community health guidelines\n\n"
            "Ask me anything about patient care!";
        quickActions = [
          'How to counsel a diabetic patient?',
          'What are danger signs in pregnancy?',
          'How to educate about malaria prevention?',
          'When to refer a patient to a doctor?',
        ];
        break;
      case AIAssistantType.doctor:
        welcomeText =
            "👨‍⚕️ Welcome Doctor! I'm your Clinical AI Assistant powered by Google Gemini, providing:\n\n"
            "• Evidence-based treatment guidelines\n"
            "• Clinical decision-making support\n"
            "• Advanced clinical care protocols\n"
            "• Diagnostic support\n"
            "• Latest medical research insights\n\n"
            "How can I assist you today?";
        quickActions = [
          'Treatment protocol for severe malaria',
          'Management of hypertensive emergency',
          'Differential diagnosis for chest pain',
          'When to order CT scan vs MRI?',
        ];
        break;
      case AIAssistantType.patient:
        welcomeText =
            "🏥 Hello! I'm here to provide basic health education.\n\n"
            "⚠️ IMPORTANT DISCLAIMER:\n"
            "• This information is for educational purposes only\n"
            "• AI information is NOT 100% accurate\n"
            "• Always consult a qualified doctor for medical advice\n"
            "• In case of emergency, visit a hospital immediately\n\n"
            "Ask me about basic health topics!";
        quickActions = [
          'How to prevent malaria?',
          'What is diabetes?',
          'When should I see a doctor?',
          'How to maintain good hygiene?',
        ];
        break;
      case AIAssistantType.nursing:
        welcomeText =
            "👩‍⚕️ Welcome Nurse! I'm your Nursing AI Assistant powered by Google Gemini for:\n\n"
            "• Vital signs monitoring\n"
            "• Wound care and dressing\n"
            "• Patient positioning and care\n"
            "• Medication administration\n"
            "• Ward management support\n\n"
            "How can I support your nursing care today?";
        quickActions = [
          'Normal vital signs ranges?',
          'How to assess wound healing?',
          'Infection control best practices',
          'When to alert the doctor?',
        ];
        break;
      case AIAssistantType.opd:
        welcomeText =
            "🏥 Welcome to OPD Clinical Support powered by Google Gemini!\n\n"
            "• Triage and prioritization\n"
            "• Common OPD presentations\n"
            "• Examination techniques\n"
            "• Initial management\n"
            "• Admission criteria\n\n"
            "What clinical question can I help with?";
        quickActions = [
          'Triage guidelines?',
          'Abdominal pain assessment',
          'Fever workup approach',
          'When to admit vs discharge?',
        ];
        break;
      case AIAssistantType.specialist:
        welcomeText =
            "👨‍⚕️ Specialist Clinical Support powered by Google Gemini\n\n"
            "• Advanced diagnostic interpretation\n"
            "• ECG and imaging guidance\n"
            "• Complex case management\n"
            "• Subspecialty protocols\n"
            "• Research-based recommendations\n\n"
            "What specialized support do you need?";
        quickActions = [
          'ECG interpretation basics',
          'CT vs MRI selection',
          'Complex differential diagnosis',
          'Advanced management protocols',
        ];
        break;
      case AIAssistantType.laboratory:
        welcomeText =
            "🔬 Laboratory Support Assistant powered by Google Gemini\n\n"
            "• Lab test interpretation\n"
            "• Critical values recognition\n"
            "• Test selection guidance\n"
            "• Quality control\n"
            "• Result validation\n\n"
            "How can I help with laboratory matters?";
        quickActions = [
          'CBC interpretation?',
          'Liver function tests',
          'Critical lab values',
          'When to repeat tests?',
        ];
        break;
      case AIAssistantType.publicHealth:
        welcomeText =
            "📊 Public Health Support powered by Google Gemini\n\n"
            "• Disease surveillance\n"
            "• Outbreak investigation\n"
            "• Immunization programs\n"
            "• Health education campaigns\n"
            "• Data analysis and reporting\n\n"
            "What public health topic can I help with?";
        quickActions = [
          'Outbreak investigation steps',
          'Immunization schedule',
          'Disease surveillance methods',
          'Community health assessment',
        ];
        break;
      case AIAssistantType.pharmacy:
        welcomeText =
            "💊 Pharmacy Practice Assistant powered by Google Gemini\n\n"
            "• Medication safety and interactions\n"
            "• Drug information and counseling\n"
            "• Dosing and administration\n"
            "• Adverse effects monitoring\n"
            "• Pharmaceutical care\n\n"
            "How can I assist with pharmacy practice?";
        quickActions = [
          'Drug interaction check',
          'Proper medication storage',
          'Patient counseling points',
          'Antimicrobial stewardship',
        ];
        break;
      case AIAssistantType.scan:
        welcomeText =
            "🔬 Radiology/Imaging Assistant powered by Google Gemini\n\n"
            "• Imaging modality selection\n"
            "• Radiation safety protocols\n"
            "• Patient preparation guidance\n"
            "• Contrast agent safety\n"
            "• Image quality optimization\n\n"
            "What imaging topic can I help with?";
        quickActions = [
          'CT vs MRI indications',
          'Radiation safety (ALARA)',
          'Contrast contraindications',
          'Patient positioning tips',
        ];
        break;
    }

    setState(() {
      _messages.add(
        ChatMessage(
          text: welcomeText,
          isUser: false,
          timestamp: DateTime.now(),
          quickActions: quickActions,
          isError: false,
        ),
      );
    });
  }

  String _getAssistantTitle() {
    switch (widget.assistantType) {
      case AIAssistantType.chw:
        return 'CHW AI Assistant';
      case AIAssistantType.doctor:
        return 'Clinical AI Assistant';
      case AIAssistantType.patient:
        return 'Health Education AI';
      case AIAssistantType.nursing:
        return 'Nursing AI Assistant';
      case AIAssistantType.opd:
        return 'OPD Clinical Support';
      case AIAssistantType.specialist:
        return 'Specialist AI Assistant';
      case AIAssistantType.laboratory:
        return 'Laboratory AI Assistant';
      case AIAssistantType.publicHealth:
        return 'Public Health AI Assistant';
      case AIAssistantType.pharmacy:
        return 'Pharmacy AI Assistant';
      case AIAssistantType.scan:
        return 'Radiology AI Assistant';
    }
  }

  Color _getAssistantColor() {
    switch (widget.assistantType) {
      case AIAssistantType.chw:
        return Colors.teal;
      case AIAssistantType.doctor:
        return Colors.indigo;
      case AIAssistantType.patient:
        return Colors.blue;
      case AIAssistantType.nursing:
        return Colors.pink;
      case AIAssistantType.opd:
        return Colors.orange;
      case AIAssistantType.specialist:
        return Colors.purple;
      case AIAssistantType.laboratory:
        return Colors.cyan;
      case AIAssistantType.publicHealth:
        return Colors.green;
      case AIAssistantType.pharmacy:
        return Colors.deepPurple;
      case AIAssistantType.scan:
        return Colors.blueGrey;
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: message,
          isUser: true,
          timestamp: DateTime.now(),
          isError: false,
        ),
      );
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Add to conversation history
    _conversationHistory.add({'role': 'user', 'content': message});

    try {
      // Check if Gemini is configured
      if (_geminiService == null || !_geminiService!.isConfigured) {
        throw Exception(
          'Gemini AI is not configured. Please contact your administrator.',
        );
      }

      // Get role name from assistant type
      final roleName = widget.assistantType.toString().split('.').last;

      // Get response from Gemini
      final response = await _geminiService!.getChatResponse(
        userMessage: message,
        userRole: roleName,
        conversationHistory: _conversationHistory,
      );

      // Add AI response to conversation history
      _conversationHistory.add({'role': 'assistant', 'content': response});

      setState(() {
        _messages.add(
          ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            isError: false,
          ),
        );
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      String errorMessage = 'Sorry, I encountered an error: ${e.toString()}';

      if (e.toString().contains('401')) {
        errorMessage =
            '🔐 AI service is not configured. Please contact your administrator to set up the Gemini API key.';
      } else if (e.toString().contains('429')) {
        errorMessage =
            '⏰ Too many requests. Please wait a moment and try again.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('SocketException')) {
        errorMessage =
            '🌐 Network error. Please check your internet connection and try again.';
      }

      setState(() {
        _messages.add(
          ChatMessage(
            text: errorMessage,
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAssistantTitle()),
        backgroundColor: _getAssistantColor(),
        elevation: 2,
        actions: [
          if (_isInitialized)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('About AI Assistant'),
                    content: const SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Powered by Google Gemini',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '✓ FREE to use\n'
                            '✓ Real AI intelligence\n'
                            '✓ Role-specific medical knowledge\n'
                            '✓ Conversation context maintained\n'
                            '✓ Latest medical information',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '⚠️ Important',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'AI responses are for guidance only. Always verify critical medical decisions with updated clinical guidelines and senior staff.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Chat'),
                  content: const Text(
                    'Are you sure you want to clear this conversation?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _conversationHistory.clear();
                        });
                        _addWelcomeMessage();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Error banner if AI failed to initialize
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red[100],
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Service Error',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                      _initializeAI();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),

          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getAssistantColor(),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getAssistantColor(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(color: _getAssistantColor(), fontSize: 12),
                  ),
                ],
              ),
            ),

          // Message input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: _getAssistantColor()),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: _getAssistantColor(),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(_messageController.text),
                    enabled: _isInitialized && !_isLoading,
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _isInitialized && !_isLoading
                      ? () => _sendMessage(_messageController.text)
                      : null,
                  backgroundColor: _isInitialized && !_isLoading
                      ? _getAssistantColor()
                      : Colors.grey,
                  mini: true,
                  child: const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: message.isError
                      ? Colors.red
                      : _getAssistantColor(),
                  child: Icon(
                    message.isError ? Icons.error_outline : Icons.smart_toy,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? _getAssistantColor()
                        : (message.isError ? Colors.red[50] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.isUser)
                        Text(
                          message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        )
                      else
                        MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 14,
                              color: message.isError
                                  ? Colors.red[900]
                                  : Colors.black87,
                            ),
                            strong: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: message.isError
                                  ? Colors.red[900]
                                  : Colors.black,
                            ),
                            listBullet: TextStyle(
                              color: message.isError
                                  ? Colors.red[900]
                                  : _getAssistantColor(),
                            ),
                          ),
                        ),
                      if (message.quickActions != null &&
                          message.quickActions!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Quick actions:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: message.quickActions!
                              .map(
                                (action) => InkWell(
                                  onTap: () => _sendMessage(action),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _getAssistantColor(),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      action,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getAssistantColor(),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (message.isUser) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 16, color: Colors.white),
                ),
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: message.isUser ? 0 : 40,
              right: message.isUser ? 40 : 0,
              top: 4,
            ),
            child: Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? quickActions;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickActions,
    required this.isError,
  });
}
