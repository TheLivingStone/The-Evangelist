import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'add_person_screen.dart';
import 'person_profile_screen.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});
  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  String? _filter; // null = All

  static const _chips = [
    (null, 'All'),
    ('new_contact', 'New'),
    ('followup_started', 'Follow-Up'),
    ('connected_to_church', 'Church'),
    ('active', 'Active'),
  ];

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsListProvider(_filter));
    return Scaffold(
      appBar: AppBar(title: const Text('My People')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPersonScreen()),
          );
          ref.invalidate(contactsListProvider(_filter));
        },
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _chips
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.$2),
                        selected: _filter == c.$1,
                        selectedColor: AppColors.accent.withValues(alpha: 0.25),
                        onSelected: (_) => setState(() => _filter = c.$1),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: contacts.when(
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text('Add the first person you meet. 🙂'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _ContactTile(
                        contact: list[i],
                        onChanged: () =>
                            ref.invalidate(contactsListProvider(_filter)),
                      ),
                    ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onChanged;
  const _ContactTile({required this.contact, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final due =
        contact.nextFollowupAt != null &&
        !contact.nextFollowupAt!.isAfter(DateTime.now());
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
          child: Text(contact.firstName.characters.first),
        ),
        title: Text(contact.displayName),
        subtitle: Text(
          [
            contact.metLocation,
            prettyStatus(contact.status),
          ].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
        ),
        trailing: due
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Due',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              )
            : const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonProfileScreen(contact: contact),
            ),
          );
          onChanged();
        },
      ),
    );
  }
}
