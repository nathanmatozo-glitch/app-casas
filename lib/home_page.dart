import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'listing_form_page.dart';
import 'login_page.dart';
import 'models/property_listing.dart';
import 'owner_dashboard_page.dart';
import 'property_card.dart';
import 'property_detail_page.dart';
import 'services/auth_service.dart';
import 'services/listing_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.firebaseReady,
    required this.googleAuthReady,
    required this.user,
  });

  final bool firebaseReady;
  final bool googleAuthReady;
  final User? user;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ListingRepository repository;
  late final Stream<List<PropertyListing>> listingsStream;
  late final Stream<Set<String>> emptyFavoritesStream;
  String? favoriteStreamUid;
  Stream<Set<String>>? favoriteStream;
  final searchController = TextEditingController();
  final minPriceController = TextEditingController();
  final maxPriceController = TextEditingController();
  DealType? dealFilter;
  PropertyCategory? categoryFilter;
  int? bedroomFilter;
  Position? currentPosition;
  bool locationBusy = false;
  bool savedOnly = false;

  @override
  void initState() {
    super.initState();
    repository = ListingRepository(firebaseReady: widget.firebaseReady);
    listingsStream = repository.watchActiveListings();
    emptyFavoritesStream = Stream.value(const <String>{});
  }

  @override
  void dispose() {
    searchController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => LoginPage(
            firebaseReady: widget.firebaseReady,
            googleAuthReady: widget.googleAuthReady,
          ),
        ));
  }

  User? get _currentUser => widget.firebaseReady
      ? widget.user ?? FirebaseAuth.instance.currentUser
      : null;

  Future<User?> _requireSignedIn() async {
    if (_currentUser != null) return _currentUser;
    await _openLogin();
    return _currentUser;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _startListing() async {
    final user = await _requireSignedIn();
    if (user == null || !mounted) return;
    if (!widget.firebaseReady) {
      _message('Configure o Firebase para publicar e salvar anúncios.');
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ListingFormPage(
        uid: user.uid,
        firebaseReady: widget.firebaseReady,
        repository: repository,
      ),
    ));
  }

  Future<void> _toggleSaved(PropertyListing property, bool wasSaved) async {
    if (property.isDemo) {
      _message('Este é um exemplo. Faça uma busca com anúncios reais para salvar.');
      return;
    }
    final user = await _requireSignedIn();
    if (user == null || !mounted) return;
    try {
      await repository.setFavorite(
        uid: user.uid,
        propertyId: property.id,
        saved: !wasSaved,
      );
    } catch (_) {
      if (mounted) {
        _message('Não foi possível atualizar seus imóveis salvos. Tente novamente.');
      }
    }
  }

  Future<void> _requestLocation() async {
    setState(() => locationBusy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          _message('Ative a localização do aparelho ou pesquise por bairro, cidade ou CEP.');
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          _message('Sem problema. Você ainda pode pesquisar digitando uma localização.');
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted) setState(() => currentPosition = position);
    } catch (_) {
      if (mounted) {
        _message('Não conseguimos localizar você. Tente buscar por bairro ou cidade.');
      }
    } finally {
      if (mounted) setState(() => locationBusy = false);
    }
  }

  Future<void> _openOwnerDashboard() async {
    final user = await _requireSignedIn();
    if (user == null || !mounted) return;
    if (!widget.firebaseReady) {
      _message('Configure o Firebase para gerenciar seus anúncios.');
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => OwnerDashboardPage(
        uid: user.uid,
        repository: repository,
        onEdit: (listing) async {
          await Navigator.of(context).push<void>(MaterialPageRoute(
            builder: (_) => ListingFormPage(
              uid: user.uid,
              firebaseReady: widget.firebaseReady,
              repository: repository,
              listing: listing,
            ),
          ));
        },
      ),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _toggleSavedFilter() async {
    if (!savedOnly) {
      final user = await _requireSignedIn();
      if (user == null || !mounted) return;
    }
    setState(() => savedOnly = !savedOnly);
  }

  Stream<Set<String>> get _favoriteIdsStream {
    final uid = _currentUser?.uid;
    if (uid == null) return emptyFavoritesStream;
    if (favoriteStreamUid != uid) {
      favoriteStreamUid = uid;
      favoriteStream = repository.watchFavoriteIds(uid);
    }
    return favoriteStream!;
  }

  Future<void> _signOut() async {
    try {
      await const AuthService().signOut();
    } catch (_) {
      if (mounted) _message('Não foi possível sair agora. Tente novamente.');
    }
  }

  double? _moneyValue(TextEditingController controller) {
    final clean = controller.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean);
  }

  List<PropertyListing> _filtered(List<PropertyListing> all, Set<String> favorites) {
    final query = searchController.text.trim().toLowerCase();
    final min = _moneyValue(minPriceController);
    final max = _moneyValue(maxPriceController);
    final filtered = all.where((property) {
      final searchable = [
        property.title,
        property.neighborhood,
        property.city,
        property.state,
        property.category.label,
        property.postalCodePrefix,
      ].join(' ').toLowerCase();
      final queryDigits = query.replaceAll(RegExp(r'\D'), '');
      final matchesLocation = searchable.contains(query) ||
          (queryDigits.length >= 5 &&
              property.postalCodePrefix.startsWith(queryDigits.substring(0, 5)));
      if (query.isNotEmpty && !matchesLocation) return false;
      if (dealFilter != null && property.dealType != dealFilter) return false;
      if (categoryFilter != null && property.category != categoryFilter) {
        return false;
      }
      if (bedroomFilter != null &&
          (property.bedrooms == null || property.bedrooms! < bedroomFilter!)) {
        return false;
      }
      if (min != null && property.price < min) return false;
      if (max != null && property.price > max) return false;
      if (savedOnly && !favorites.contains(property.id)) return false;
      if (currentPosition != null &&
          property.latitude != null &&
          property.longitude != null) {
        final distance = Geolocator.distanceBetween(
          currentPosition!.latitude,
          currentPosition!.longitude,
          property.latitude!,
          property.longitude!,
        );
        if (distance > 30000) return false;
      }
      return true;
    }).toList();
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final profileName = _currentUser?.displayName?.trim() ?? '';
    final profileLetter = profileName.isNotEmpty ? profileName.substring(0, 1) : 'U';
    return Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: const Row(
            children: [
              Icon(Icons.home_work_rounded, color: Color(0xFF176B55)),
              SizedBox(width: 9),
              Text('App Casas', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            if (narrow)
              IconButton(
                tooltip: savedOnly ? 'Ver todos os imóveis' : 'Imóveis salvos',
                onPressed: _toggleSavedFilter,
                icon: Icon(savedOnly ? Icons.favorite : Icons.favorite_border),
              )
            else
              TextButton.icon(
                onPressed: _toggleSavedFilter,
                icon: Icon(savedOnly ? Icons.favorite : Icons.favorite_border),
                label: Text(savedOnly ? 'Todos' : 'Salvos'),
              ),
            if (narrow)
              IconButton(
                tooltip: 'Meus anúncios',
                onPressed: _openOwnerDashboard,
                icon: const Icon(Icons.real_estate_agent_outlined),
              )
            else
              TextButton.icon(
                onPressed: _openOwnerDashboard,
                icon: const Icon(Icons.real_estate_agent_outlined),
                label: const Text('Meus anúncios'),
              ),
            if (_currentUser == null)
              if (narrow)
                IconButton(
                  tooltip: 'Entrar',
                  onPressed: _openLogin,
                  icon: const Icon(Icons.login),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: FilledButton.tonal(
                    onPressed: _openLogin,
                    child: const Text('Entrar'),
                  ),
                )
            else
              PopupMenuButton<String>(
                tooltip: 'Minha conta',
                onSelected: (value) {
                  if (value == 'logout') _signOut();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text(profileName.isNotEmpty
                        ? profileName
                        : _currentUser?.email ?? 'Minha conta'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(children: [
                      Icon(Icons.logout, size: 19),
                      SizedBox(width: 8),
                      Text('Sair da conta'),
                    ]),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundImage: _currentUser?.photoURL == null
                        ? null
                        : NetworkImage(_currentUser!.photoURL!),
                    child: _currentUser?.photoURL == null
                        ? Text(profileLetter.toUpperCase())
                        : null,
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: StreamBuilder<Set<String>>(
            stream: _favoriteIdsStream,
            builder: (context, favoritesSnapshot) {
              final favorites = favoritesSnapshot.data ?? <String>{};
              return StreamBuilder<List<PropertyListing>>(
                stream: listingsStream,
                builder: (context, listingsSnapshot) {
                  final all = listingsSnapshot.data ?? const <PropertyListing>[];
                  final results = _filtered(all, favorites);
                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1220),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: constraints.maxWidth < 600 ? 16 : 28,
                              vertical: 18,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!widget.firebaseReady) ...[
                                  const _DemoBanner(),
                                  const SizedBox(height: 18),
                                ],
                                _HeroSection(
                                  onChooseDeal: (deal) => setState(() {
                                    dealFilter = deal;
                                    savedOnly = false;
                                  }),
                                  onAnnounce: _startListing,
                                ),
                                const SizedBox(height: 26),
                                _SearchPanel(
                                  searchController: searchController,
                                  minPriceController: minPriceController,
                                  maxPriceController: maxPriceController,
                                  dealFilter: dealFilter,
                                  categoryFilter: categoryFilter,
                                  bedroomFilter: bedroomFilter,
                                  locationBusy: locationBusy,
                                  locationOn: currentPosition != null,
                                  savedOnly: savedOnly,
                                  onSearchChanged: () => setState(() {}),
                                  onDealChanged: (value) => setState(() {
                                    dealFilter = value;
                                    savedOnly = false;
                                  }),
                                  onCategoryChanged: (value) =>
                                      setState(() => categoryFilter = value),
                                  onBedroomsChanged: (value) =>
                                      setState(() => bedroomFilter = value),
                                  onLocation: _requestLocation,
                                  onSaved: _toggleSavedFilter,
                                  onClear: () => setState(() {
                                    searchController.clear();
                                    minPriceController.clear();
                                    maxPriceController.clear();
                                    dealFilter = null;
                                    categoryFilter = null;
                                    bedroomFilter = null;
                                    currentPosition = null;
                                    savedOnly = false;
                                  }),
                                ),
                                const SizedBox(height: 28),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            savedOnly
                                                ? 'Seus imóveis salvos'
                                                : 'Imóveis para você',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            listingsSnapshot.hasData
                                                ? '${results.length} ${results.length == 1 ? 'imóvel encontrado' : 'imóveis encontrados'}'
                                                : 'Carregando anúncios…',
                                            style: TextStyle(
                                                color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (widget.firebaseReady)
                                      OutlinedButton.icon(
                                        onPressed: _startListing,
                                        icon: const Icon(Icons.add_home_work),
                                        label: const Text('Anunciar imóvel'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (currentPosition != null)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'Mostrando imóveis em até 30 km quando o anúncio informa uma localização. A busca digitada continua disponível.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                if (listingsSnapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !listingsSnapshot.hasData)
                                  const _LoadingState()
                                else if (listingsSnapshot.hasError)
                                  _ErrorState(
                                    onRetry: () => setState(() {}),
                                  )
                                else if (results.isEmpty)
                                  _EmptyState(
                                    savedOnly: savedOnly,
                                    demo: !widget.firebaseReady,
                                    onClear: () => setState(() {
                                      searchController.clear();
                                      minPriceController.clear();
                                      maxPriceController.clear();
                                      dealFilter = null;
                                      categoryFilter = null;
                                      bedroomFilter = null;
                                      currentPosition = null;
                                      savedOnly = false;
                                    }),
                                  )
                                else
                                  _PropertyGrid(
                                    properties: results,
                                    favorites: favorites,
                                    onFavorite: _toggleSaved,
                                    onOpen: (property) => Navigator.of(context)
                                        .push<void>(MaterialPageRoute(
                                          builder: (_) => PropertyDetailPage(
                                            listing: property,
                                            firebaseReady:
                                                widget.firebaseReady,
                                            repository: repository,
                                            onLoginRequired: _openLogin,
                                          ),
                                        )),
                                  ),
                                const SizedBox(height: 38),
                                const _Footer(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        floatingActionButton: MediaQuery.sizeOf(context).width < 700
            ? FloatingActionButton.extended(
                onPressed: _startListing,
                icon: const Icon(Icons.add),
                label: const Text('Anunciar'),
              )
            : null,
      );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5DF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAD8A5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF72500C)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Modo demonstração: os imóveis abaixo são exemplos. Configure o Firebase para ver anúncios reais, publicar, salvar e entrar em contato.',
              ),
            ),
          ],
        ),
      );
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.onChooseDeal,
    required this.onAnnounce,
  });

  final ValueChanged<DealType> onChooseDeal;
  final VoidCallback onAnnounce;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF145D4B), Color(0xFF248A6C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 720;
          final cards = [
            _PathCard(
              icon: Icons.key_rounded,
              title: 'Alugar um imóvel',
              subtitle: 'Encontre um lugar para morar',
              onTap: () => onChooseDeal(DealType.rent),
            ),
            _PathCard(
              icon: Icons.home_rounded,
              title: 'Comprar um imóvel',
              subtitle: 'Veja casas e apartamentos à venda',
              onTap: () => onChooseDeal(DealType.buy),
            ),
            _PathCard(
              icon: Icons.add_home_work_rounded,
              title: 'Anunciar um imóvel',
              subtitle: 'Conte para mais pessoas',
              onTap: onAnnounce,
            ),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('O próximo passo começa em casa',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 8),
              const Text(
                'Encontre um lugar para chamar de seu ou anuncie o seu imóvel.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 22),
              if (wide)
                Row(children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    if (index > 0) const SizedBox(width: 12),
                    Expanded(child: cards[index]),
                  ],
                ])
              else
                Column(children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    if (index > 0) const SizedBox(height: 10),
                    cards[index],
                  ],
                ]),
            ],
          );
        }),
      );
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE6F2EC),
                  foregroundColor: const Color(0xFF176B55),
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ),
      );
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.searchController,
    required this.minPriceController,
    required this.maxPriceController,
    required this.dealFilter,
    required this.categoryFilter,
    required this.bedroomFilter,
    required this.locationBusy,
    required this.locationOn,
    required this.savedOnly,
    required this.onSearchChanged,
    required this.onDealChanged,
    required this.onCategoryChanged,
    required this.onBedroomsChanged,
    required this.onLocation,
    required this.onSaved,
    required this.onClear,
  });

  final TextEditingController searchController;
  final TextEditingController minPriceController;
  final TextEditingController maxPriceController;
  final DealType? dealFilter;
  final PropertyCategory? categoryFilter;
  final int? bedroomFilter;
  final bool locationBusy;
  final bool locationOn;
  final bool savedOnly;
  final VoidCallback onSearchChanged;
  final ValueChanged<DealType?> onDealChanged;
  final ValueChanged<PropertyCategory?> onCategoryChanged;
  final ValueChanged<int?> onBedroomsChanged;
  final VoidCallback onLocation;
  final VoidCallback onSaved;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Buscar imóveis',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Alugar'),
                    selected: dealFilter == DealType.rent,
                    onSelected: (_) => onDealChanged(
                      dealFilter == DealType.rent ? null : DealType.rent,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Comprar'),
                    selected: dealFilter == DealType.buy,
                    onSelected: (_) => onDealChanged(
                      dealFilter == DealType.buy ? null : DealType.buy,
                    ),
                  ),
                  if (savedOnly)
                    const Chip(label: Text('Somente salvos')),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 700;
                final searchField = TextField(
                  controller: searchController,
                  onChanged: (_) => onSearchChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Onde você quer morar?',
                    hintText: 'Bairro, cidade ou CEP',
                    prefixIcon: Icon(Icons.search),
                  ),
                );
                final locationButton = OutlinedButton.icon(
                  onPressed: locationBusy ? null : onLocation,
                  icon: locationBusy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(locationOn ? Icons.my_location : Icons.near_me),
                  label: Text(locationOn ? 'Localização ativada' : 'Usar localização'),
                );
                if (wide) {
                  return Row(children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 10),
                    locationButton,
                  ]);
                }
                return Column(children: [
                  searchField,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: locationButton),
                ]);
              }),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final count = constraints.maxWidth > 700 ? 4 : 2;
                final width = (constraints.maxWidth - (count - 1) * 10) / count;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<PropertyCategory?>(
                        isExpanded: true,
                        value: categoryFilter,
                        decoration: const InputDecoration(labelText: 'Tipo de imóvel'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todas as categorias',
                                overflow: TextOverflow.ellipsis),
                          ),
                          ...PropertyCategory.values.map((category) =>
                              DropdownMenuItem(
                                  value: category,
                                  child: Text(category.label))),
                        ],
                        onChanged: onCategoryChanged,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<int?>(
                        isExpanded: true,
                        value: bedroomFilter,
                        decoration: const InputDecoration(labelText: 'Quartos'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Qualquer quantidade')),
                          DropdownMenuItem(value: 1, child: Text('1 ou mais')),
                          DropdownMenuItem(value: 2, child: Text('2 ou mais')),
                          DropdownMenuItem(value: 3, child: Text('3 ou mais')),
                          DropdownMenuItem(value: 4, child: Text('4 ou mais')),
                        ],
                        onChanged: onBedroomsChanged,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: minPriceController,
                        onChanged: (_) => onSearchChanged(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Preço mínimo', prefixText: 'R\$ '),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: maxPriceController,
                        onChanged: (_) => onSearchChanged(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Preço máximo', prefixText: 'R\$ '),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                TextButton.icon(
                  onPressed: onSaved,
                  icon: const Icon(Icons.favorite_border),
                  label: Text(savedOnly ? 'Ver todos' : 'Ver salvos'),
                ),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Limpar filtros'),
                ),
              ]),
            ],
          ),
        ),
      );
}

class _PropertyGrid extends StatelessWidget {
  const _PropertyGrid({
    required this.properties,
    required this.favorites,
    required this.onFavorite,
    required this.onOpen,
  });

  final List<PropertyListing> properties;
  final Set<String> favorites;
  final Future<void> Function(PropertyListing, bool) onFavorite;
  final ValueChanged<PropertyListing> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final count = size.maxWidth > 1000 ? 3 : size.maxWidth > 650 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: properties.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: count == 1 ? 315 : 350,
          ),
          itemBuilder: (context, index) {
            final property = properties[index];
            return PropertyCard(
              listing: property,
              saved: favorites.contains(property.id),
              onTap: () => onOpen(property),
              onFavorite: () => onFavorite(
                property,
                favorites.contains(property.id),
              ),
            );
          },
        );
      });
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.wifi_off, size: 36, color: Color(0xFF176B55)),
              const SizedBox(height: 10),
              const Text(
                'Não foi possível carregar os imóveis. Confira sua conexão e se o Firestore está ativado.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.savedOnly,
    required this.demo,
    required this.onClear,
  });

  final bool savedOnly;
  final bool demo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          const Icon(Icons.search_off, size: 38, color: Color(0xFF176B55)),
          const SizedBox(height: 10),
          Text(
            savedOnly
                ? 'Você ainda não salvou imóveis.'
                : demo
                    ? 'Nenhum exemplo combina com esses filtros.'
                    : 'Ainda não encontramos imóveis com esses filtros.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text('Tente outra localização ou ajuste o preço e a quantidade de quartos.'),
          const SizedBox(height: 12),
          TextButton(onPressed: onClear, child: const Text('Limpar filtros')),
        ]),
      );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFDDE5E0))),
        ),
        child: Text(
          'App Casas • Encontre seu próximo lar com tranquilidade.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      );
}
