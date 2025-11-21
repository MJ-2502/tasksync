import 'package:flutter/material.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_theme.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  List<_TutorialSection> get _sections => const [
        _TutorialSection(
          icon: Icons.rocket_launch_outlined,
          title: 'Getting Started',
          description: 'Create your first workspace, invite teammates, and sync tasks in minutes.',
          steps: [
            'Tap the + button on Home to create a project. Give it a descriptive name.',
            'Invite teammates from the project header by entering their email addresses.',
            'Add your first task with due dates, assignees, and priority so reminders stay accurate.',
          ],
          tips: [
            'Use short, action-oriented project names like "Q4 Launch".',
            'Need inspiration? Pick a template from the suggestion chip when it appears.',
          ],
        ),
        _TutorialSection(
          icon: Icons.dashboard_customize_outlined,
          title: 'Home Overview',
          description: 'Track open projects, pending invites, and connectivity at a glance.',
          steps: [
            'The header shows sync status and pending invitations. Tap the mail icon to respond.',
            'Scroll the project list, then tap a card to open details or long-press for quick actions.',
            'Use the floating + button to create projects or tasks from anywhere.',
          ],
          tips: [
            'Swipe down to refresh if another teammate just updated the project.',
            'Offline? You can still read cached data. We’ll sync changes once you reconnect.',
          ],
        ),
        _TutorialSection(
          icon: Icons.fact_check_outlined,
          title: 'Managing Tasks',
          description: 'Assign owners, set priorities, and attach due dates so nothing slips.',
          steps: [
            'Inside a project tap “Add Task”, fill in title, assignee, dates, and optional flags.',
            'Toggle the priority pill to highlight critical items in the timeline.',
            'Use the status picker (In progress / Blocked / Completed) to keep everyone aligned.',
          ],
          tips: [
            'Need a reminder? Task notifications trigger 24h and 1h before the due date.',
            'Completed tasks stay visible for audit history – archive them from the overflow menu.',
          ],
        ),
        _TutorialSection(
          icon: Icons.calendar_month_outlined,
          title: 'Calendar View',
          description: 'See all project deadlines in one timeline and drill down on busy days.',
          steps: [
            'Use the arrows to move between months or tap Today to jump back instantly.',
            'Dots under a date show how many tasks are due. Tap a date to expand the list.',
            'Tap a task row to open it in the originating project and update the status.',
          ],
          tips: [
            'Color badges help you see who owns the work—hover (desktop) or tap to view details.',
            'Filter to “My Tasks” from the project screen to focus on your workload only.',
          ],
        ),
        _TutorialSection(
          icon: Icons.notifications_active_outlined,
          title: 'Staying Notified',
          description: 'Receive invitations, task reminders, and project updates across devices.',
          steps: [
            'Enable push notifications when prompted on first launch or from Settings > Notifications.',
            'Check the bell in the project header to review unread updates and mentions.',
            'Use Profile > Theme & Preferences to choose quiet hours for notifications.',
          ],
          tips: [
            'Invites arrive via email too, but accepting inside TaskSync adds you instantly.',
            'If a reminder feels noisy, open the task and adjust its reminder lead time.',
          ],
        ),
      ];

  List<_FaqItem> get _faq => const [
        _FaqItem(
          question: 'How do I reset my password?',
          answer:
              'Tap “Forgot Password?” on the login screen. Enter your account email and we’ll send a secure reset link. Make sure to complete the flow within 15 minutes.',
        ),
        _FaqItem(
          question: 'How can I resend a project invite?',
          answer:
              'Open the project, tap Members > Invites, then resend. If the invite already exists we update it and notify the recipient again.',
        ),
        _FaqItem(
          question: 'Can I work offline?',
          answer:
              'Yes. You can review cached projects and tasks offline. Changes queue locally and sync automatically when you regain connectivity.',
        ),
        _FaqItem(
          question: 'Where can I contact support?',
          answer:
              'Send feedback from Profile > Help & Feedback or email support@tasksync.app. Include screenshots or logs if possible.',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorial & Help'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.spaceLarge),
        children: [
          _buildHeroCard(context),
          const SizedBox(height: AppConstants.spaceLarge),
          ..._sections.map((section) => _TutorialCard(section: section)),
          const SizedBox(height: AppConstants.spaceLarge),
          Text(
            'FAQs',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppConstants.spaceSmall),
          ..._faq.map((item) => _FaqTile(item: item)),
          const SizedBox(height: AppConstants.spaceLarge),
          _buildSupportCard(context),
          const SizedBox(height: AppConstants.spaceXLarge),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: 
              [const Color(0xFF1E88E5), const Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: AppTheme.getShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Welcome to TaskSync',
            style: TextStyle(
              fontSize: AppConstants.fontSizeXXLarge,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: AppConstants.spaceSmall),
          Text(
            'This quick guide shows you the core workflows so you can onboard your team in minutes.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceLarge),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: AppTheme.getShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.support_agent_outlined, size: 28),
              SizedBox(width: AppConstants.spaceSmall),
              Text(
                'Need more help?',
                style: TextStyle(
                  fontSize: AppConstants.fontSizeLarge,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSmall),
          Text(
            'We respond within one business day. Include screenshots and timestamps so we can help faster.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppConstants.spaceMedium),
          Wrap(
            spacing: AppConstants.spaceSmall,
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.email_outlined),
                label: const Text('Email support@tasksync.app'),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Open feedback form'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TutorialSection {
  final IconData icon;
  final String title;
  final String description;
  final List<String> steps;
  final List<String> tips;

  const _TutorialSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.steps,
    required this.tips,
  });
}

class _TutorialCard extends StatelessWidget {
  final _TutorialSection section;

  const _TutorialCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceLarge),
      padding: const EdgeInsets.all(AppConstants.spaceLarge),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: AppTheme.getShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spaceSmall),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Icon(section.icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppConstants.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(section.description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMedium),
          const Text(
            'Steps',
            style: TextStyle(
              fontSize: AppConstants.fontSizeMedium,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.spaceSmall),
          ...section.steps.map((step) => _StepRow(text: step)),
          const SizedBox(height: AppConstants.spaceMedium),
          const Text(
            'Pro tips',
            style: TextStyle(
              fontSize: AppConstants.fontSizeMedium,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.spaceSmall),
          ...section.tips.map((tip) => _TipRow(text: tip)),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String text;

  const _StepRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF116DE6)),
          const SizedBox(width: AppConstants.spaceSmall),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String text;

  const _TipRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceSmall),
      padding: const EdgeInsets.all(AppConstants.spaceSmall),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 18),
          const SizedBox(width: AppConstants.spaceSmall),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}

class _FaqTile extends StatelessWidget {
  final _FaqItem item;

  const _FaqTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceSmall),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        boxShadow: AppTheme.getShadow(context),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceMedium,
          vertical: AppConstants.spaceSmall,
        ),
        title: Text(
          item.question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppConstants.spaceMedium,
          0,
          AppConstants.spaceMedium,
          AppConstants.spaceMedium,
        ),
        children: [
          Text(
            item.answer,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
