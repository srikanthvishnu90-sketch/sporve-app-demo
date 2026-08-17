import 'package:flutter/material.dart';
import '../../../core/matching/provider_matcher.dart';
import '../../../core/models/query_intent.dart';
import '../../../core/models/query_intent_parser.dart';

class AiPlatformDemoScreen extends StatefulWidget {
  const AiPlatformDemoScreen({super.key});

  @override
  State<AiPlatformDemoScreen> createState() => _AiPlatformDemoScreenState();
}

class _AiPlatformDemoScreenState extends State<AiPlatformDemoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // AI Search demo state
  final TextEditingController _searchQueryController = TextEditingController(text: 'Boxing lessons for 8 year old under \$70 in Chicago');
  QueryIntent? _parsedIntent;

  // AI Chatbox demo state
  final List<Map<String, String>> _chatMessages = [
    {'sender': 'parent', 'text': 'Hi! My 10yo daughter wants to start soccer training. What clinic do you recommend?'},
    {'sender': 'ai', 'text': 'I recommend the "Junior Soccer Fundamentals" with Coach Sarah! It focuses on footwork and finishing in a low-intensity, supportive environment.'},
  ];
  final TextEditingController _chatInputController = TextEditingController();
  bool _isGeneratingDraft = false;
  String? _draftReply;

  // Sample catalog for AI Matching & Recommended For You
  final List<Map<String, dynamic>> _sampleCatalog = [
    {
      '_id': 'p1',
      'providerName': 'Apex Martial Arts',
      'title': 'Junior Taekwondo & Agility',
      'sportType': 'taekwondo',
      'minimumAge': 6,
      'maximumAge': 14,
      'price': 65,
      'intensity': 'low',
      'background_check_status': 'verified',
      'account_status': 'active',
      'rating': 4.9,
    },
    {
      '_id': 'p2',
      'providerName': 'Iron Boxing Gym',
      'title': 'Advanced Contact Sparring',
      'sportType': 'boxing',
      'minimumAge': 8,
      'maximumAge': 18,
      'price': 80,
      'intensity': 'high', // Will be age-gated for young kids
      'background_check_status': 'verified',
      'account_status': 'active',
      'rating': 4.7,
    },
    {
      '_id': 'p3',
      'providerName': 'Little Champions Boxing',
      'title': 'Youth Boxing Fundamentals',
      'sportType': 'boxing',
      'minimumAge': 6,
      'maximumAge': 12,
      'price': 50,
      'intensity': 'low',
      'background_check_status': 'verified',
      'account_status': 'active',
      'rating': 4.85,
    },
  ];

  List<ProviderMatch> _aiRecommendations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _parseAiSearchQuery();
    _computeAiRecommendations();
  }

  void _parseAiSearchQuery() {
    final query = _searchQueryController.text;
    setState(() {
      _parsedIntent = QueryIntentParser.parse(query);
    });
  }

  void _computeAiRecommendations() {
    final intent = QueryIntent(sport: 'boxing', age: 8);
    final matches = ProviderMatcher.retrieve(_sampleCatalog, intent);
    setState(() {
      _aiRecommendations = matches;
    });
  }

  void _sendChatMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _chatMessages.add({'sender': 'parent', 'text': text});
      _chatInputController.clear();
      _isGeneratingDraft = true;
    });

    // Simulate AI responses
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        _isGeneratingDraft = false;
        _chatMessages.add({
          'sender': 'ai',
          'text': 'Thanks for asking! I found 2 verified coaches matching "$text" with 4.8+ ratings.',
        });
      });
    });
  }

  void _generateDraftRecap() {
    setState(() {
      _isGeneratingDraft = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _isGeneratingDraft = false;
        _draftReply = 'Awesome work at today’s clinic! Athletes practiced speed footwork and passing drills. Great energy!';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Sporve AI Platform Suite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'AI Search'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'AI Chatbox'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Recommended'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAiSearchTab(),
          _buildAiChatboxTab(),
          _buildAiRecommendedTab(),
        ],
      ),
    );
  }

  // Tab 1: AI Search Demo
  Widget _buildAiSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Natural Language Query Parser',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Parses unstructured parent inputs into sport types, target ages, max budgets, and geo anchors.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchQueryController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type query (e.g., Soccer for 10yo under \$50)...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _parseAiSearchQuery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Parse AI', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_parsedIntent != null) ...[
            const Text('AI Extracted Intent Metadata:', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildIntentTile('Detected Sport', _parsedIntent!.sport ?? 'All Sports', Icons.sports),
            _buildIntentTile('Target Age', _parsedIntent!.age != null ? '${_parsedIntent!.age} years old' : 'Unspecified', Icons.child_care),
            _buildIntentTile('Max Budget', _parsedIntent!.priceMaxCents != null ? '\$${(_parsedIntent!.priceMaxCents! / 100).round()}' : 'Flexible', Icons.attach_money),
            _buildIntentTile('Intent Confidence Score', '98.4%', Icons.check_circle_outline),
          ],
        ],
      ),
    );
  }

  // Tab 2: AI Chatbox & Draft Replies Demo
  Widget _buildAiChatboxTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _chatMessages.length,
            itemBuilder: (context, i) {
              final msg = _chatMessages[i];
              final isUser = msg['sender'] == 'parent';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    msg['text']!,
                    style: TextStyle(color: isUser ? Colors.black : Colors.white, fontSize: 14),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isGeneratingDraft)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(color: Color(0xFF38BDF8), backgroundColor: Colors.white12),
          ),
        if (_draftReply != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
              border: Border.all(color: const Color(0xFF38BDF8)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 6),
                    Text('AI Drafted Clinic Recap:', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_draftReply!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8)),
                onPressed: _generateDraftRecap,
                tooltip: 'Generate AI Recap',
              ),
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Ask AI assistant...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF38BDF8)),
                onPressed: _sendChatMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Tab 3: Recommended For You & Safety Ceiling Gating Demo
  Widget _buildAiRecommendedTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('AI "Recommended For You" Engine', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Ranked match algorithm enforcing per-sport age ceilings & rating weights (Age 8, Boxing intent).',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: const [
              Icon(Icons.shield, color: Color(0xFF34D399)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Safety Gating Active: High-intensity boxing sparring blocked for 8yo child.',
                  style: TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final item in _aiRecommendations) ...[
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF0F172A),
                child: Icon(Icons.fitness_center, color: Color(0xFF38BDF8)),
              ),
              title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Rating: ⭐ ${item.ratingAvg} • Tier: Low Intensity\nMatch Score: 96.5%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              trailing: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black),
                child: const Text('Book', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIntentTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
