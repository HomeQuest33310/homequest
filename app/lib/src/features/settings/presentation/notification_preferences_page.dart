import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/dashboard_home_button.dart';
import '../../family/providers/family_members_provider.dart';

class NotificationPreferencesPage extends ConsumerStatefulWidget {
  const NotificationPreferencesPage({super.key});
  @override
  ConsumerState<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends ConsumerState<NotificationPreferencesPage> {
  Map<String, dynamic> values = {
    'quest_notifications': true,
    'validation_notifications': true,
    'reward_notifications': true,
    'boss_notifications': true,
    'quiet_hours_enabled': false,
  };
  bool loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final member = await ref.read(currentFamilyMemberProvider.future);
    if (member != null) {
      final row = await Supabase.instance.client.from('notification_preferences')
          .select().eq('member_id', member.id).maybeSingle();
      if (row != null && mounted) setState(() => values = {...values, ...row});
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save(String key, bool value) async {
    setState(() => values[key] = value);
    final member = await ref.read(currentFamilyMemberProvider.future);
    if (member == null) return;
    await Supabase.instance.client.from('notification_preferences').upsert({
      ...values, key: value, 'member_id': member.id, 'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: const DashboardHomeButton(), title: const Text('Préférences des notifications')),
        body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(child: ListTile(leading: Icon(Icons.tune), title: Text('Choisissez votre accompagnement'), subtitle: Text('Désactivez les catégories qui ne vous concernent pas. Les notifications du royaume restent consultables dans l’application.'))),
            for (final item in const [
              ('quest_notifications', 'Missions', 'Attributions et reprises de missions'),
              ('validation_notifications', 'Validations', 'Résultats des missions réalisées'),
              ('reward_notifications', 'Récompenses', 'Récompenses débloquées'),
              ('boss_notifications', 'Boss', 'Nouvelles et victoires des boss'),
              ('quiet_hours_enabled', 'Heures silencieuses', 'Prépare les rappels sans déranger'),
            ]) SwitchListTile(title: Text(item.$2), subtitle: Text(item.$3), value: values[item.$1] == true, onChanged: (v) => _save(item.$1, v)),
          ],
        ),
      );
}
