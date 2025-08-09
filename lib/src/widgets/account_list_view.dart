import 'package:flutter/material.dart';
import '../models/cloud_account.dart';
import '../providers/base/oauth_cloud_provider.dart';
import 'account_card.dart';

class AccountListView extends StatefulWidget {
  final OAuthCloudProvider provider;

  const AccountListView({Key? key, required this.provider}) : super(key: key);

  @override
  _AccountListViewState createState() => _AccountListViewState();
}

class _AccountListViewState extends State<AccountListView> {
  late Future<List<CloudAccount>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = widget.provider.getAllUsers();
  }

  void _refreshAccounts() {
    setState(() {
      _accountsFuture = widget.provider.getAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<List<CloudAccount>>(
            future: _accountsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Center(child: Text('Error loading accounts: ${snapshot.error}'));
              }

              final accounts = snapshot.data!;

              if (accounts.isEmpty) {
                return const Center(child: Text('No accounts found.'));
              }

              return ListView.builder(
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: AccountCard(
                      account: account,
                      theme: Theme.of(context),
                      onTap: () async {
                        if (!account.isActive) {
                          await widget.provider.switchToUser(account.id);
                          _refreshAccounts();
                        }
                      },
                      onReauthenticate: () async {
                        await widget.provider.authenticate();
                        _refreshAccounts();
                      },
                      onRemove: () async {
                        await widget.provider.deleteUser(account.id);
                        _refreshAccounts();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              await widget.provider.authenticate();
              _refreshAccounts();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Account'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50), // full width
            ),
          ),
        ),
      ],
    );
  }
}
