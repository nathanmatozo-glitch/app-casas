import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/property_listing.dart';
import 'property_card.dart';
import 'services/listing_repository.dart';

class PropertyDetailPage extends StatefulWidget {
  const PropertyDetailPage({
    super.key,
    required this.listing,
    required this.firebaseReady,
    required this.repository,
    required this.onLoginRequired,
  });

  final PropertyListing listing;
  final bool firebaseReady;
  final ListingRepository repository;
  final Future<void> Function() onLoginRequired;

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  int photoIndex = 0;

  User? get _currentUser => widget.firebaseReady
      ? FirebaseAuth.instance.currentUser
      : null;

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _contact({required bool whatsapp}) async {
    final listing = widget.listing;
    if (listing.isDemo) {
      _message('Este é um exemplo. O contato fica disponível em anúncios reais.');
      return;
    }
    if (!listing.phonePublished) {
      _message('O anunciante escolheu não divulgar o telefone neste anúncio.');
      return;
    }
    if (_currentUser == null) await widget.onLoginRequired();
    if (_currentUser == null || !mounted) return;

    try {
      final phone = await widget.repository.phoneForContact(listing);
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final brazilianNumber = digits.length <= 11 ? '55$digits' : digits;
      final uri = whatsapp
          ? Uri.https('wa.me', '/$brazilianNumber', {
              'text': 'Olá! Tenho interesse no imóvel: ${listing.title}.',
            })
          : Uri(scheme: 'tel', path: phone.trim());
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _message('Não foi possível abrir o aplicativo de contato.');
    } catch (error) {
      _message(error is StateError
          ? error.message
          : 'Não conseguimos carregar o contato. Tente novamente.');
    }
  }

  Future<void> _openMap() async {
    final listing = widget.listing;
    final query = listing.latitude != null && listing.longitude != null
        ? '${listing.latitude},${listing.longitude}'
        : listing.publicAddress.isNotEmpty
            ? listing.publicAddress
            : listing.shortLocation;
    final uri = Uri.https('www.openstreetmap.org', '/search', {'query': query});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      _message('Não foi possível abrir o mapa.');
    }
  }

  Future<void> _report() async {
    if (widget.listing.isDemo) {
      _message('Denúncias ficam disponíveis em anúncios reais.');
      return;
    }
    if (_currentUser == null) await widget.onLoginRequired();
    final user = _currentUser;
    if (user == null || !mounted) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _ReportDialog(),
    );
    if (reason == null || !mounted) return;
    try {
      await widget.repository.reportListing(
        propertyId: widget.listing.id,
        reporterUid: user.uid,
        reason: reason,
      );
      _message('Obrigado. Sua denúncia foi enviada para análise.');
    } catch (_) {
      _message('Não foi possível enviar a denúncia. Tente novamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do imóvel'),
        actions: [
          IconButton(
            tooltip: 'Denunciar anúncio',
            onPressed: _report,
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Gallery(
                    listing: listing,
                    index: photoIndex,
                    onChanged: (value) => setState(() => photoIndex = value),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth > 760;
                    final details = _ListingTextDetails(listing: listing);
                    final contact = _ContactCard(
                      listing: listing,
                      onCall: () => _contact(whatsapp: false),
                      onWhatsApp: () => _contact(whatsapp: true),
                      onMap: _openMap,
                    );
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: details),
                              const SizedBox(width: 22),
                              SizedBox(width: 340, child: contact),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [details, const SizedBox(height: 18), contact],
                          );
                  }),
                  if (listing.isDemo) ...[
                    const SizedBox(height: 16),
                    const _Notice(
                      text: 'Anúncio demonstrativo: as informações e fotos são exemplos para testar a navegação.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.listing,
    required this.index,
    required this.onChanged,
  });

  final PropertyListing listing;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).width < 600 ? 245 : 410,
              width: double.infinity,
              child: listing.photos.isEmpty
                  ? const _EmptyPhoto()
                  : PageView.builder(
                      itemCount: listing.photos.length,
                      onPageChanged: onChanged,
                      itemBuilder: (context, photoIndex) => Image.network(
                        listing.photos[photoIndex].url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _EmptyPhoto(),
                      ),
                    ),
            ),
            if (listing.photos.isNotEmpty)
              Positioned(
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text('${index + 1} / ${listing.photos.length}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            if (listing.photos.isEmpty)
              const Positioned(right: 12, bottom: 12, child: _DemoLabel()),
          ],
        ),
      );
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFE5F0EA),
        child: const Center(
          child: Icon(Icons.home_work_rounded,
              size: 76, color: Color(0xFF176B55)),
        ),
      );
}

class _DemoLabel extends StatelessWidget {
  const _DemoLabel();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5DF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('Sem fotos de demonstração',
            style: TextStyle(fontSize: 12)),
      );
}

class _ListingTextDetails extends StatelessWidget {
  const _ListingTextDetails({required this.listing});

  final PropertyListing listing;

  @override
  Widget build(BuildContext context) {
    final facts = <Widget>[
      if (listing.bedrooms != null)
        _Fact(icon: Icons.bed_outlined, value: '${listing.bedrooms} quartos'),
      if (listing.bathrooms != null)
        _Fact(icon: Icons.shower_outlined, value: '${listing.bathrooms} banheiros'),
      if (listing.parkingSpaces != null)
        _Fact(icon: Icons.directions_car_outlined, value: '${listing.parkingSpaces} vagas'),
      if (listing.area != null)
        _Fact(icon: Icons.square_foot, value: '${listing.area!.round()} m²'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, children: [
          Chip(label: Text(listing.dealType.label)),
          Chip(label: Text(listing.category.label)),
        ]),
        const SizedBox(height: 5),
        Text(listing.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.place_outlined, size: 19, color: Color(0xFF176B55)),
          const SizedBox(width: 4),
          Expanded(child: Text(listing.shortLocation)),
        ]),
        if (listing.fullAddressPublished && listing.publicAddress.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(listing.publicAddress,
              style: TextStyle(color: Colors.grey.shade700)),
        ] else ...[
          const SizedBox(height: 5),
          Text('O endereço exato não é divulgado.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        Text(
          '${formatBrl(listing.price)}${listing.dealType == DealType.rent ? ' / mês' : ''}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF176B55),
                fontWeight: FontWeight.bold,
              ),
        ),
        if (listing.condoFee != null || listing.propertyTax != null) ...[
          const SizedBox(height: 5),
          Wrap(spacing: 14, children: [
            if (listing.condoFee != null)
              Text('Condomínio: ${formatBrl(listing.condoFee!)} / mês'),
            if (listing.propertyTax != null)
              Text('IPTU: ${formatBrl(listing.propertyTax!)}'),
          ]),
        ],
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('Características',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: facts),
        ],
        const SizedBox(height: 22),
        Text('Sobre o imóvel',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(listing.description, style: const TextStyle(height: 1.5)),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF176B55)),
          const SizedBox(width: 6),
          Text(value),
        ],
      );
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.listing,
    required this.onCall,
    required this.onWhatsApp,
    required this.onMap,
  });

  final PropertyListing listing;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Fale com o anunciante',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              if (!listing.phonePublished)
                const _Notice(
                  text: 'O anunciante preferiu não divulgar o telefone neste anúncio.',
                )
              else if (listing.isDemo)
                const _Notice(
                  text: 'O contato será liberado em anúncios reais.',
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onWhatsApp,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Conversar no WhatsApp'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Ligar para o anunciante'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Você precisará entrar com Google para ver os dados de contato.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver localização no mapa'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5DF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String reason = 'Informação incorreta';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Denunciar anúncio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Conte o que parece errado ou suspeito.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: reason,
              items: const [
                DropdownMenuItem(
                    value: 'Informação incorreta',
                    child: Text('Informação incorreta')),
                DropdownMenuItem(
                    value: 'Anúncio suspeito', child: Text('Anúncio suspeito')),
                DropdownMenuItem(
                    value: 'Imóvel indisponível',
                    child: Text('Imóvel indisponível')),
                DropdownMenuItem(
                    value: 'Outro motivo', child: Text('Outro motivo')),
              ],
              onChanged: (value) => setState(() => reason = value ?? reason),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, reason),
              child: const Text('Enviar denúncia')),
        ],
      );
}

