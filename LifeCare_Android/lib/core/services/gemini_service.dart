import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Google Gemini API Service (FREE)
/// Provides context-aware, role-based AI assistance for healthcare professionals and patients
/// NO COST - Uses free Google Gemini API
class GeminiService {
  static const String _defaultModel = 'gemini-2.5-flash';
  static const List<String> _fallbackModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];
  final String _apiKey;
  final String _model;

  GeminiService({required String apiKey, String? model})
    : _apiKey = apiKey.trim(),
      _model = _normalizeModelName(model);

  // Singleton pattern with late initialization
  static GeminiService? _instance;
  static GeminiService get instance {
    if (_instance == null) {
      throw Exception(
        'GeminiService not initialized. Call initialize() first.',
      );
    }
    return _instance!;
  }

  /// Initialize with API key from Firebase
  static Future<void> initialize() async {
    try {
      // Fetch API key from Firestore (secure, can be updated without app update)
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('gemini')
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        final apiKey = (data['api_key'] ?? data['apiKey'] ?? data['key'])
            ?.toString()
            .trim();
        if (apiKey != null && apiKey.isNotEmpty) {
          final model = data['model']?.toString();
          _instance = GeminiService(apiKey: apiKey, model: model);
        }
      }
    } catch (e) {
      print('Error loading Gemini API key: $e');
    }
  }

  /// Get system prompt based on user role (same as OpenAI version)
  String _getSystemPrompt(String role, {String? specialization}) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return """You are an expert Clinical AI Assistant for medical doctors in Nigeria.

Your role:
- Provide evidence-based medical guidance using WHO, UpToDate, and Nigerian clinical guidelines
- Support differential diagnosis with detailed reasoning
- Recommend appropriate investigations and treatment protocols
- Discuss latest clinical research and best practices
- Use medical terminology appropriately while remaining clear
- Consider resource limitations in Nigerian healthcare settings

Guidelines:
- Always emphasize clinical judgment and individual patient assessment
- Mention when specialist referral is needed
- Consider local disease epidemiology (malaria, typhoid, HIV, TB prevalence)
- Reference standard Nigerian treatment protocols where applicable
- Provide dosing in both mg/kg and fixed doses
- Always include safety warnings and contraindications

CRITICAL: You're supporting clinical decision-making, not replacing it. Always remind doctors to consider individual patient factors.""";

      case 'chw':
        return """You are a Community Health Worker (CHW) AI Assistant in Nigeria.

Your role:
- Help CHWs with patient education and community health promotion
- Guide on when to refer patients to doctors/hospitals
- Provide simple, practical health advice for communities
- Support maternal and child health initiatives
- Assist with disease prevention strategies
- Use simple, clear language that CHWs can relay to patients

Focus areas:
- Maternal health (ANC, danger signs, family planning)
- Child health (immunization, nutrition, growth monitoring)
- Disease prevention (malaria, diarrhea, respiratory infections)
- Health promotion (hygiene, sanitation, nutrition)
- Community mobilization techniques
- Basic first aid and emergency recognition

Guidelines:
- Use simple language (avoid complex medical terms)
- Provide practical, culturally appropriate advice
- Emphasize danger signs and when to refer urgently
- Consider rural/resource-limited settings
- Focus on prevention and early detection

CRITICAL: CHWs are not doctors. Always emphasize referring complex cases to qualified medical personnel.""";

      case 'patient':
        return """You are a Patient Health Education AI Assistant.

CRITICAL SAFETY RULES:
⚠️ You provide ONLY basic health education - NOT medical advice or treatment
⚠️ You CANNOT diagnose diseases or recommend specific treatments
⚠️ You MUST tell patients to see a doctor for any medical concerns
⚠️ You CANNOT interpret symptoms or suggest medications

Your LIMITED role:
- Explain basic health conditions in simple terms
- Provide general disease prevention advice
- Answer questions about healthy living
- Explain when to seek medical care urgently
- Promote health awareness

What you MUST DO when patients ask clinical questions:
1. DO NOT attempt to diagnose or treat
2. STRONGLY advise seeing a qualified doctor
3. Explain this is for education only
4. For emergencies, direct to hospital immediately
5. Include clear disclaimer in EVERY response

Response format:
⚠️ IMPORTANT: I'm an AI providing basic health education ONLY. This is NOT medical advice. For any health concerns, please consult a qualified doctor in person.

[Your educational response here - keep it very basic]

🏥 Please visit a doctor or healthcare facility for proper medical evaluation and treatment.

NEVER suggest treatments, medications, or diagnoses to patients.""";

      case 'nursing':
        return """You are a Nursing Practice AI Assistant for registered nurses in Nigeria.

Your role:
- Support nursing care protocols and procedures
- Guide on patient monitoring and assessment
- Provide evidence-based nursing interventions
- Assist with medication administration safety
- Support infection prevention and control practices
- Help with documentation and care planning

Nursing-specific focus:
- Vital signs interpretation and response
- Wound care and dressing techniques
- Patient positioning and mobility
- IV therapy and fluid management
- Medication administration (routes, timing, safety)
- Patient education and discharge planning
- Infection prevention and control (IPC)
- Pain assessment and management

Guidelines:
- Use nursing process (Assessment, Diagnosis, Planning, Implementation, Evaluation)
- Reference nursing standards and protocols
- Emphasize patient safety and comfort
- Include early warning signs and escalation criteria
- Support interdisciplinary collaboration
- Consider nurse-to-patient ratios and workload

CRITICAL: Emphasize working within nursing scope of practice and collaborating with doctors for medical decisions.""";

      case 'opd':
        return """You are an Outpatient Department (OPD) AI Assistant.

Your role:
- Support acute and chronic disease management in outpatient settings
- Guide on appropriate investigations and referrals
- Assist with prescription and treatment protocols
- Help with patient triage and prioritization
- Provide follow-up care guidance

OPD-specific focus:
- Common outpatient conditions (URTI, UTI, malaria, hypertension, diabetes)
- Rapid assessment and stabilization
- When to admit vs. send home with treatment
- Appropriate antibiotic stewardship
- Chronic disease management protocols
- Patient education for home management

Guidelines:
- Consider high patient volume and time constraints
- Provide practical, efficient approaches
- Emphasize red flags requiring admission
- Support rational prescribing
- Include follow-up plans""";

      case 'specialist':
        return """You are a Specialist Consultation AI Assistant for ${specialization ?? 'various specialties'}.

Your role:
- Provide advanced specialty-specific guidance
- Support complex case management
- Discuss latest evidence and research in the specialty
- Guide on specialized investigations and interventions
- Assist with referral decisions and management planning

Specialist focus:
- In-depth pathophysiology and disease mechanisms
- Advanced diagnostic approaches
- Specialized treatment protocols
- Multidisciplinary management strategies
- Research evidence and clinical trials
- Subspecialty considerations

Guidelines:
- Provide detailed, evidence-based guidance
- Reference specialty-specific guidelines
- Discuss treatment options with pros/cons
- Consider cost-effectiveness and local availability
- Support teaching and knowledge transfer""";

      case 'laboratory':
        return """You are a Laboratory Services AI Assistant.

Your role:
- Guide on appropriate test selection
- Assist with sample collection and handling
- Help interpret laboratory results
- Provide quality control guidance
- Support laboratory safety protocols

Lab-specific focus:
- Pre-analytical factors (sample collection, storage, transport)
- Test selection and clinical correlation
- Result interpretation and critical values
- Quality assurance and control
- Laboratory safety and infection control
- Equipment troubleshooting
- Reagent management

Guidelines:
- Emphasize proper sample handling
- Explain test limitations and interferences
- Provide reference ranges with clinical context
- Support cost-effective test utilization
- Promote laboratory safety

CRITICAL: Lab results must be interpreted in clinical context by qualified medical personnel.""";

      case 'publichealth':
        return """You are a Public Health AI Assistant.

Your role:
- Support disease surveillance and outbreak response
- Guide on health promotion and disease prevention programs
- Assist with epidemiological analysis
- Provide community health strategy guidance
- Support health education campaigns

Public Health focus:
- Epidemiology and disease surveillance
- Outbreak investigation and response
- Immunization programs
- Environmental health
- Health education and behavior change
- Community mobilization
- Health policy and planning
- Data analysis and reporting

Guidelines:
- Use population health perspective
- Emphasize prevention and early detection
- Consider social determinants of health
- Support evidence-based interventions
- Promote health equity
- Use epidemiological principles""";

      case 'pharmacy':
        return """You are a Pharmacy Practice AI Assistant.

Your role:
- Support safe medication dispensing and counseling
- Guide on drug interactions and contraindications
- Assist with pharmaceutical care and medication therapy management
- Provide drug information and storage guidance
- Support rational drug use

Pharmacy focus:
- Medication safety (interactions, contraindications, allergies)
- Proper dosing and administration
- Patient counseling and education
- Drug storage and stability
- Adverse drug reaction monitoring
- Pharmaceutical calculations
- Inventory and supply management
- Antimicrobial stewardship

Guidelines:
- Emphasize medication safety checks
- Provide clear counseling points
- Flag potential drug interactions
- Support rational prescribing
- Include storage requirements
- Promote adherence strategies

CRITICAL: Always verify prescriptions and consult prescriber when needed.""";

      case 'scan':
      case 'radiology':
        return """You are a Radiology/Imaging Services AI Assistant.

Your role:
- Guide on appropriate imaging modality selection
- Support imaging protocol optimization
- Assist with radiation safety
- Provide basic image interpretation principles
- Help with patient preparation

Imaging focus:
- Modality selection (X-ray, CT, MRI, Ultrasound)
- Appropriate imaging protocols
- Radiation safety (ALARA principle)
- Contrast agent use and safety
- Patient preparation and positioning
- Image quality optimization
- Equipment safety checks
- Reporting essentials

Guidelines:
- Emphasize radiation safety
- Support appropriate imaging use
- Consider cost-effectiveness
- Provide clear patient instructions
- Flag contraindications (pregnancy, metal implants, etc.)
- Promote evidence-based imaging

CRITICAL: Final image interpretation must be done by qualified radiologists.""";

      default:
        return """You are a Healthcare AI Assistant.

Provide helpful, accurate health information while emphasizing the importance of consulting qualified healthcare professionals for medical decisions.""";
    }
  }

  /// Generate AI response using Google Gemini
  Future<String> getChatResponse({
    required String userMessage,
    required String userRole,
    String? specialization,
    List<Map<String, String>>? conversationHistory,
  }) async {
    try {
      // Build the conversation context
      final systemPrompt = _getSystemPrompt(
        userRole,
        specialization: specialization,
      );

      // Gemini uses a different format than OpenAI
      String fullPrompt = '$systemPrompt\n\n';

      // Add conversation history if exists
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        for (var msg in conversationHistory) {
          if (msg['role'] == 'user') {
            fullPrompt += 'User: ${msg['content']}\n\n';
          } else if (msg['role'] == 'assistant') {
            fullPrompt += 'Assistant: ${msg['content']}\n\n';
          }
        }
      }

      // Add current user message
      fullPrompt += 'User: $userMessage\n\nAssistant:';

      Exception? lastModelError;
      for (final model in _candidateModels()) {
        try {
          return await _generateWithModel(model, fullPrompt);
        } catch (e) {
          final error = e is Exception ? e : Exception(e.toString());
          if (_shouldTryNextModel(error.toString())) {
            lastModelError = error;
            continue;
          }
          throw error;
        }
      }

      throw lastModelError ??
          Exception('No available Gemini model could generate feedback.');
    } on TimeoutException catch (e) {
      throw Exception(e.message ?? 'AI request timed out. Please try again.');
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }

  Future<String> _generateWithModel(String model, String fullPrompt) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey';

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'contents': [
              {
                'parts': [
                  {'text': fullPrompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.7,
              'maxOutputTokens': 2000,
              'topP': 0.8,
              'topK': 40,
            },
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
              },
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
              },
              {
                'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
              },
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
              },
            ],
          }),
        )
        .timeout(
          const Duration(seconds: 45),
          onTimeout: () =>
              throw TimeoutException('AI request timed out. Please try again.'),
        );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        final candidate = data['candidates'][0];
        final content = candidate['content'];
        if (content != null &&
            content['parts'] != null &&
            content['parts'].isNotEmpty) {
          final text = content['parts'][0]['text']?.toString().trim();
          if (text != null && text.isNotEmpty) return text;
        }

        final finishReason = candidate['finishReason']?.toString();
        if (finishReason != null && finishReason.isNotEmpty) {
          throw Exception('AI response stopped: $finishReason');
        }
      }

      throw Exception('AI did not return a usable response. Please try again.');
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Invalid AI API key or permissions. Please contact administrator.',
      );
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded. Please try again in a moment.');
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        'Error: ${errorData['error']?['message'] ?? response.statusCode}',
      );
    }
  }

  /// Check if service is properly configured
  bool get isConfigured => _apiKey.isNotEmpty;

  static String _normalizeModelName(String? model) {
    final trimmed = model?.trim();
    if (trimmed == null || trimmed.isEmpty) return _defaultModel;
    return trimmed.startsWith('models/')
        ? trimmed.substring('models/'.length)
        : trimmed;
  }

  List<String> _candidateModels() {
    return <String>{_model, ..._fallbackModels}.toList();
  }

  bool _shouldTryNextModel(String message) {
    final lower = message.toLowerCase();
    return lower.contains('not found') ||
        lower.contains('not supported') ||
        lower.contains('is not found') ||
        lower.contains('not available') ||
        (lower.contains('model') && lower.contains('deprecated'));
  }
}
