import 'package:flutter/material.dart';
import '../main.dart';
import '../core/services/api_service.dart';
import 'widgets_tv.dart';

class ProfileTvScreen extends StatefulWidget {
  const ProfileTvScreen({super.key});

  @override
  State<ProfileTvScreen> createState() => _ProfileTvScreenState();
}

class _ProfileTvScreenState extends State<ProfileTvScreen> {
  final api = SwingApiService();
  bool _loading = true;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    _profile = await api.getMyProfile();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const TvPage(
        child: Scaffold(
            body: Center(child: CircularProgressIndicator(color: Sp.focus))),
      );
    }
    final avatarUrl = _profile['id'] != null
        ? '${api.baseUrl}/users/me/avatar/${_profile['id']}'
        : '';
    final username = _profile['username'] ?? 'Utilisateur';

    return TvPage(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Profil'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Sp.surface,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl, headers: api.authHeaders)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(username.substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 40))
                      : null,
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    username,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
                TvListTile(
                  title: 'Email',
                  subtitle: _profile['email'] ?? 'Non défini',
                  leading: const Icon(Icons.email, color: Sp.textDim),
                  onTap: () {},
                ),
                TvListTile(
                  title: 'Bio',
                  subtitle: _profile['bio'] ?? 'Non défini',
                  leading: const Icon(Icons.description, color: Sp.textDim),
                  onTap: () {},
                ),
                TvListTile(
                  title: 'Date de naissance',
                  subtitle: _profile['birth_date'] ?? 'Non défini',
                  leading: const Icon(Icons.cake, color: Sp.textDim),
                  onTap: () {},
                ),
                const SizedBox(height: 24),
                TvButton(
                  label: 'Déconnexion',
                  icon: Icons.logout,
                  danger: true,
                  onTap: () async {
                    await api.logout();
                    // Navigate to login (requires context navigation setup)
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
