import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Legal & Safety'),
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: 'Terms'),
              Tab(text: 'Privacy'),
              Tab(text: 'Guidelines'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _LegalDocument(
              title: 'Terms of Use',
              sections: <_LegalSection>[
                _LegalSection(
                  heading: 'Anonymous Access',
                  body:
                      'ShadeFast is designed for anonymous participation. You are responsible for content you post through your anonymous session.',
                ),
                _LegalSection(
                  heading: 'Prohibited Conduct',
                  body:
                      'Content that is illegal, violent, exploitative, non-consensual, or targeted harassment is prohibited and may trigger enforcement actions.',
                ),
                _LegalSection(
                  heading: 'Ephemeral Content',
                  body:
                      'Content is designed to expire, but temporary operational logs and abuse signals may be retained for safety and legal compliance.',
                ),
              ],
            ),
            _LegalDocument(
              title: 'Privacy Notice',
              sections: <_LegalSection>[
                _LegalSection(
                  heading: 'What We Store',
                  body:
                      'The app uses anonymous Supabase auth identifiers and temporary content records needed to operate communities, feeds, and moderation tools.',
                ),
                _LegalSection(
                  heading: 'No Profile Identity',
                  body:
                      'ShadeFast does not require email, phone, or personal profile fields for normal usage.',
                ),
                _LegalSection(
                  heading: 'Safety Retention',
                  body:
                      'Reports, moderation actions, and abuse-prevention signals can be retained longer than public posts for enforcement and compliance needs.',
                ),
              ],
            ),
            _LegalDocument(
              title: 'Community Guidelines',
              sections: <_LegalSection>[
                _LegalSection(
                  heading: 'Respect Boundaries',
                  body:
                      'No doxxing, targeted threats, non-consensual sexual content, or content that encourages self-harm.',
                ),
                _LegalSection(
                  heading: 'No Illegal Content',
                  body:
                      'Do not post content involving minors, violent criminal acts, or any unlawful material.',
                ),
                _LegalSection(
                  heading: 'Enforcement',
                  body:
                      'Serious or repeated violations can result in warnings, temporary bans, or permanent bans for anonymous sessions.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalDocument extends StatelessWidget {
  const _LegalDocument({
    required this.title,
    required this.sections,
  });

  final String title;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        for (final section in sections) ...<Widget>[
          Text(
            section.heading,
            style: const TextStyle(
              color: Color(0xFFFF2D55),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            section.body,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _LegalSection {
  const _LegalSection({
    required this.heading,
    required this.body,
  });

  final String heading;
  final String body;
}
