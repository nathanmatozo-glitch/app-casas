import 'package:flutter/material.dart';

import 'models/property_listing.dart';
import 'property_card.dart';
import 'services/listing_repository.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({
    super.key,
    required this.uid,
    required this.repository,
    required this.onEdit,
  });

  final String uid;
  final ListingRepository repository;
  final Future<void> Function(PropertyListing listing) onEdit;

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  late final Stream<List<PropertyListing>> listings;

  @override
  void initState() {
    super.initState();
    listings = widget.repository.watchOwnerListings(widget.uid);
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _setStatus(PropertyListing listing, ListingStatus status) async {
    try {
      await widget.repository.updateStatus(listing.id, status);
      if (!mounted) return;
      _message(switch (status) {
        ListingStatus.active => 'Anúncio reativado.',
        ListingStatus.paused => 'Anúncio pausado.',
        ListingStatus.rented => 'Imóvel marcado como alugado.',
        ListingStatus.sold => 'Imóvel marcado como vendido.',
        ListingStatus.deleted => 'Anúncio removido.',
      });
    } catch (_) {
      if (mounted) {
        _message('Não foi possível atualizar o anúncio. Tente novamente.');
      }
    }
  }

  Future<void> _delete(PropertyListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover anúncio?'),
        content: const Text(
            'O anúncio será apagado e deixará de aparecer na busca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteListing(listing);
      if (!mounted) return;
      _message('Anúncio removido.');
    } catch (_) {
      if (mounted) _message('Não foi possível remover o anúncio. Tente novamente.');
    }
  }

  String _statusLabel(ListingStatus status) => switch (status) {
        ListingStatus.active => 'Publicado',
        ListingStatus.paused => 'Pausado',
        ListingStatus.rented => 'Alugado',
        ListingStatus.sold => 'Vendido',
        ListingStatus.deleted => 'Removido',
      };

  Color _statusColor(ListingStatus status) => switch (status) {
        ListingStatus.active => const Color(0xFF176B55),
        ListingStatus.paused => const Color(0xFF815B0D),
        ListingStatus.rented || ListingStatus.sold => Colors.blueGrey,
        ListingStatus.deleted => Colors.redAccent,
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Meus anúncios')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: StreamBuilder<List<PropertyListing>>(
                stream: listings,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const _DashboardMessage(
                      icon: Icons.cloud_off_outlined,
                      title: 'Não foi possível carregar seus anúncios.',
                      body: 'Confira sua conexão e tente novamente.',
                    );
                  }
                  final properties = snapshot.data ?? const <PropertyListing>[];
                  if (properties.isEmpty) {
                    return const _DashboardMessage(
                      icon: Icons.home_work_outlined,
                      title: 'Você ainda não anunciou um imóvel.',
                      body: 'Quando publicar seu primeiro anúncio, ele aparecerá aqui.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Text(
                        'Cuide dos seus imóveis em um só lugar.',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, size) {
                        final count = size.maxWidth > 900
                            ? 3
                            : size.maxWidth > 560
                                ? 2
                                : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: properties.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: count,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            mainAxisExtent: count == 1 ? 430 : 470,
                          ),
                          itemBuilder: (context, index) =>
                              _OwnerListingCard(
                            listing: properties[index],
                            statusLabel: _statusLabel(properties[index].status),
                            statusColor: _statusColor(properties[index].status),
                            onEdit: () => widget.onEdit(properties[index]),
                            onStatus: (status) =>
                                _setStatus(properties[index], status),
                            onDelete: () => _delete(properties[index]),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
}

class _OwnerListingCard extends StatelessWidget {
  const _OwnerListingCard({
    required this.listing,
    required this.statusLabel,
    required this.statusColor,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
  });

  final PropertyListing listing;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onEdit;
  final ValueChanged<ListingStatus> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: PropertyCard(
                listing: listing,
                saved: false,
                showFavorite: false,
                onTap: onEdit,
                onFavorite: () {},
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 10),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text(statusLabel),
                      labelStyle: TextStyle(
                          color: statusColor, fontWeight: FontWeight.bold),
                      side: BorderSide(color: statusColor.withValues(alpha: .4)),
                      backgroundColor: statusColor.withValues(alpha: .08),
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                      ),
                      if (listing.status == ListingStatus.active)
                        TextButton.icon(
                          onPressed: () => onStatus(ListingStatus.paused),
                          icon: const Icon(Icons.pause_circle_outline, size: 18),
                          label: const Text('Pausar'),
                        )
                      else if (listing.status == ListingStatus.paused)
                        TextButton.icon(
                          onPressed: () => onStatus(ListingStatus.active),
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: const Text('Reativar'),
                        ),
                      PopupMenuButton<String>(
                        tooltip: 'Mais opções',
                        onSelected: (value) {
                          if (value == 'rented') onStatus(ListingStatus.rented);
                          if (value == 'sold') onStatus(ListingStatus.sold);
                          if (value == 'delete') onDelete();
                        },
                        itemBuilder: (context) => [
                          if (listing.dealType == DealType.rent)
                            const PopupMenuItem(
                                value: 'rented', child: Text('Marcar como alugado')),
                          if (listing.dealType == DealType.buy)
                            const PopupMenuItem(
                                value: 'sold', child: Text('Marcar como vendido')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Remover anúncio')),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          child: Icon(Icons.more_horiz),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: const Color(0xFF176B55)),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
