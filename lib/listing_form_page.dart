import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'models/property_listing.dart';
import 'services/listing_repository.dart';

class ListingFormPage extends StatefulWidget {
  const ListingFormPage({
    super.key,
    required this.uid,
    required this.firebaseReady,
    required this.repository,
    this.listing,
  });

  final String uid;
  final bool firebaseReady;
  final ListingRepository repository;
  final PropertyListing? listing;

  @override
  State<ListingFormPage> createState() => _ListingFormPageState();
}

class _ListingFormPageState extends State<ListingFormPage> {
  final pageController = PageController();
  final titleController = TextEditingController();
  final streetController = TextEditingController();
  final numberController = TextEditingController();
  final complementController = TextEditingController();
  final neighborhoodController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final postalCodeController = TextEditingController();
  final priceController = TextEditingController();
  final condoController = TextEditingController();
  final taxController = TextEditingController();
  final areaController = TextEditingController();
  final bedroomsController = TextEditingController();
  final bathroomsController = TextEditingController();
  final parkingController = TextEditingController();
  final descriptionController = TextEditingController();
  final advertiserController = TextEditingController();
  final phoneController = TextEditingController();
  final _titleForm = GlobalKey<FormState>();
  final _addressForm = GlobalKey<FormState>();
  final _detailsForm = GlobalKey<FormState>();
  final _contactForm = GlobalKey<FormState>();

  DealType dealType = DealType.rent;
  PropertyCategory category = PropertyCategory.apartment;
  bool showFullAddress = false;
  bool publishPhone = false;
  bool whatsappAvailable = false;
  bool loadingPrivateDetails = false;
  bool locationBusy = false;
  bool saving = false;
  int step = 0;
  double? latitude;
  double? longitude;
  List<ListingPhotoSelection> photos = [];
  String? errorMessage;

  bool get editing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    if (listing != null) {
      titleController.text = listing.title;
      dealType = listing.dealType;
      category = listing.category;
      neighborhoodController.text = listing.neighborhood;
      cityController.text = listing.city;
      stateController.text = listing.state;
      priceController.text = listing.price.toStringAsFixed(0);
      condoController.text = listing.condoFee?.toStringAsFixed(0) ?? '';
      taxController.text = listing.propertyTax?.toStringAsFixed(0) ?? '';
      areaController.text = listing.area?.toStringAsFixed(0) ?? '';
      bedroomsController.text = listing.bedrooms?.toString() ?? '';
      bathroomsController.text = listing.bathrooms?.toString() ?? '';
      parkingController.text = listing.parkingSpaces?.toString() ?? '';
      descriptionController.text = listing.description;
      showFullAddress = listing.fullAddressPublished;
      publishPhone = listing.phonePublished;
      whatsappAvailable =
          listing.phonePublished && listing.whatsappAvailable;
      latitude = listing.latitude;
      longitude = listing.longitude;
      photos = listing.photos
          .map(ListingPhotoSelection.existing)
          .toList();
      loadingPrivateDetails = true;
      _loadPrivateDetails(listing.id);
    } else {
      loadingPrivateDetails = true;
      _loadContactDefaults();
    }
  }

  Future<void> _loadContactDefaults() async {
    try {
      final defaults = await widget.repository.getContactDefaults(widget.uid);
      if (!mounted) return;
      if (advertiserController.text.isEmpty) {
        advertiserController.text = defaults['advertiserName'] ?? '';
      }
      if (phoneController.text.isEmpty) {
        phoneController.text = defaults['phone'] ?? '';
      }
    } catch (error) {
      // The form can still be completed manually if the profile is unavailable.
      debugPrint('Não foi possível carregar os dados de contato salvos: $error');
    } finally {
      if (mounted) setState(() => loadingPrivateDetails = false);
    }
  }

  Future<void> _loadPrivateDetails(String propertyId) async {
    try {
      final draft = await widget.repository.getOwnerDraft(propertyId);
      if (!mounted) return;
      setState(() {
        streetController.text = draft.privateDetails.street;
        numberController.text = draft.privateDetails.number;
        complementController.text = draft.privateDetails.complement;
        postalCodeController.text = draft.privateDetails.postalCode;
        advertiserController.text = draft.privateDetails.advertiserName;
        phoneController.text = draft.contactDetails.phone;
        loadingPrivateDetails = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingPrivateDetails = false;
        errorMessage = 'Não foi possível abrir os dados deste anúncio.';
      });
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    for (final controller in [
      titleController,
      streetController,
      numberController,
      complementController,
      neighborhoodController,
      cityController,
      stateController,
      postalCodeController,
      priceController,
      condoController,
      taxController,
      areaController,
      bedroomsController,
      bathroomsController,
      parkingController,
      descriptionController,
      advertiserController,
      phoneController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) {
    final clean = value.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  String? _requiredText(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  String? _validatePrice(String? value) =>
      (_number(value ?? '') ?? 0) <= 0 ? 'Informe um preço válido.' : null;

  bool _validateStep() {
    if (step == 0) return _titleForm.currentState?.validate() ?? false;
    if (step == 1) return _addressForm.currentState?.validate() ?? false;
    if (step == 2) return _detailsForm.currentState?.validate() ?? false;
    final contactValid = _contactForm.currentState?.validate() ?? false;
    if (!contactValid) return false;
    if (photos.isEmpty) {
      setState(() => errorMessage = 'Adicione pelo menos uma foto do imóvel.');
      return false;
    }
    return true;
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (!_validateStep()) return;
    setState(() => errorMessage = null);
    if (step < 3) {
      setState(() => step++);
      pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      _saveListing();
    }
  }

  void _back() {
    if (step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      step--;
      errorMessage = null;
    });
    pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickPhotos() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 82);
      if (!mounted || picked.isEmpty) return;
      setState(() {
        for (final image in picked) {
          if (photos.length >= 10) break;
          photos.add(ListingPhotoSelection.newFile(image));
        }
        errorMessage = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => errorMessage =
            'Não conseguimos abrir suas fotos. Confira a permissão do aparelho.');
      }
    }
  }

  Future<void> _markApproximateLocation() async {
    setState(() {
      locationBusy = true;
      errorMessage = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Ative a localização do aparelho e tente novamente.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Sem problema. Você pode publicar sem marcar a região.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (!mounted) return;
      setState(() {
        latitude = double.parse(position.latitude.toStringAsFixed(2));
        longitude = double.parse(position.longitude.toStringAsFixed(2));
      });
    } on StateError catch (error) {
      if (mounted) setState(() => errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => errorMessage = 'Não conseguimos marcar essa região.');
      }
    } finally {
      if (mounted) setState(() => locationBusy = false);
    }
  }

  String _fullAddress() => [
        '${streetController.text.trim()} ${numberController.text.trim()}'.trim(),
        if (complementController.text.trim().isNotEmpty)
          complementController.text.trim(),
        neighborhoodController.text.trim(),
        '${cityController.text.trim()} - ${stateController.text.trim().toUpperCase()}',
        if (postalCodeController.text.trim().isNotEmpty)
          'CEP ${postalCodeController.text.trim()}',
      ].where((part) => part.isNotEmpty).join(', ');

  ListingDraft _buildDraft() {
    final old = widget.listing;
    final postalDigits = postalCodeController.text.replaceAll(RegExp(r'\D'), '');
    final listing = PropertyListing(
      id: old?.id ?? '',
      ownerUid: widget.uid,
      title: titleController.text.trim(),
      dealType: dealType,
      category: category,
      neighborhood: neighborhoodController.text.trim(),
      city: cityController.text.trim(),
      state: stateController.text.trim().toUpperCase(),
      postalCodePrefix: postalDigits.length > 5
          ? postalDigits.substring(0, 5)
          : postalDigits,
      price: _number(priceController.text) ?? 0,
      condoFee: _number(condoController.text),
      propertyTax: _number(taxController.text),
      area: _number(areaController.text),
      bedrooms: int.tryParse(bedroomsController.text.trim()),
      bathrooms: int.tryParse(bathroomsController.text.trim()),
      parkingSpaces: int.tryParse(parkingController.text.trim()),
      description: descriptionController.text.trim(),
      status: old?.status ?? ListingStatus.active,
      photos: old?.photos ?? const [],
      phonePublished: publishPhone,
      whatsappAvailable: publishPhone && whatsappAvailable,
      fullAddressPublished: showFullAddress,
      publicAddress: showFullAddress ? _fullAddress() : '',
      latitude: latitude,
      longitude: longitude,
      createdAt: old?.createdAt,
    );
    final privateDetails = ListingPrivateDetails(
      street: streetController.text,
      number: numberController.text,
      complement: complementController.text,
        postalCode: postalCodeController.text,
        advertiserName: advertiserController.text,
      );
    return ListingDraft(
      listing: listing,
      privateDetails: privateDetails,
      contactDetails: ListingContactDetails(phone: phoneController.text),
    );
  }

  Future<void> _saveListing() async {
    if (!widget.firebaseReady) {
      setState(() => errorMessage =
          'Conecte o Firebase para publicar anúncios e enviar fotos.');
      return;
    }
    setState(() {
      saving = true;
      errorMessage = null;
    });
    try {
      await widget.repository.saveListing(
        uid: widget.uid,
        draft: _buildDraft(),
        photoSelections: List.unmodifiable(photos),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(editing ? 'Anúncio atualizado.' : 'Seu anúncio foi publicado.'),
      ));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error is StateError
            ? error.message
            : 'Não foi possível salvar o anúncio ou enviar as fotos. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _stepTitle() => switch (step) {
        0 => 'Sobre o imóvel',
        1 => 'Onde ele fica?',
        2 => 'Preço e características',
        _ => 'Fotos e contato',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(editing ? 'Editar anúncio' : 'Novo anúncio'),
          leading: IconButton(
            tooltip: 'Voltar',
            onPressed: saving ? null : _back,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: loadingPrivateDetails
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Etapa ${step + 1} de 4',
                              style: const TextStyle(
                                  color: Color(0xFF176B55),
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(value: (step + 1) / 4),
                          const SizedBox(height: 14),
                          Text(_stepTitle(),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          if (errorMessage != null) ...[
                            _ErrorBox(text: errorMessage!),
                            const SizedBox(height: 10),
                          ],
                          Expanded(
                            child: PageView(
                              controller: pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildAboutStep(),
                                _buildAddressStep(),
                                _buildDetailsStep(),
                                _buildPhotosAndContactStep(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            if (step > 0)
                              OutlinedButton(
                                onPressed: saving ? null : _back,
                                child: const Text('Voltar'),
                              ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: saving ? null : _next,
                              icon: saving
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Icon(step == 3
                                      ? Icons.publish_outlined
                                      : Icons.arrow_forward),
                              label: Text(saving
                                  ? 'Salvando…'
                                  : step == 3
                                      ? editing
                                          ? 'Salvar alterações'
                                          : 'Publicar anúncio'
                                      : 'Continuar'),
                            ),
                          ]),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      );

  Widget _buildAboutStep() => SingleChildScrollView(
        child: Form(
          key: _titleForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Conte primeiro se o imóvel é para aluguel ou venda.'),
              const SizedBox(height: 14),
              Wrap(spacing: 10, children: [
                ChoiceChip(
                  label: const Text('Alugar'),
                  selected: dealType == DealType.rent,
                  onSelected: (_) => setState(() => dealType = DealType.rent),
                ),
                ChoiceChip(
                  label: const Text('Vender'),
                  selected: dealType == DealType.buy,
                  onSelected: (_) => setState(() => dealType = DealType.buy),
                ),
              ]),
              const SizedBox(height: 14),
              const Text('Que tipo de imóvel é?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final item in PropertyCategory.values)
                  ChoiceChip(
                    label: Text(item.label),
                    selected: category == item,
                    onSelected: (_) => setState(() => category = item),
                  ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: titleController,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Dê um título ao anúncio',
                  hintText: 'Ex.: Apartamento claro perto do parque',
                  helperText: 'Use uma frase curta para chamar atenção.',
                ),
                validator: (value) => _requiredText(value, 'Escreva um título.'),
              ),
            ],
          ),
        ),
      );

  Widget _buildAddressStep() => SingleChildScrollView(
        child: Form(
          key: _addressForm,
          child: Column(
            children: [
              TextFormField(
                controller: streetController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Rua ou avenida'),
                validator: (value) => _requiredText(value, 'Informe a rua.'),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, size) {
                final wide = size.maxWidth > 500;
                final number = TextFormField(
                  controller: numberController,
                  decoration: const InputDecoration(labelText: 'Número'),
                  validator: (value) => _requiredText(value, 'Informe o número.'),
                );
                final complement = TextFormField(
                  controller: complementController,
                  decoration: const InputDecoration(
                    labelText: 'Complemento (opcional)',
                    hintText: 'Apto, bloco, casa dos fundos',
                  ),
                );
                return wide
                    ? Row(children: [
                        Expanded(flex: 1, child: number),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: complement),
                      ])
                    : Column(children: [
                        number,
                        const SizedBox(height: 10),
                        complement,
                      ]);
              }),
              const SizedBox(height: 10),
              TextFormField(
                controller: neighborhoodController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Bairro'),
                validator: (value) => _requiredText(value, 'Informe o bairro.'),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, size) {
                final wide = size.maxWidth > 500;
                final city = TextFormField(
                  controller: cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Cidade'),
                  validator: (value) => _requiredText(value, 'Informe a cidade.'),
                );
                final state = TextFormField(
                  controller: stateController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    hintText: 'MT',
                    counterText: '',
                  ),
                  validator: (value) => value == null || value.trim().length != 2
                      ? 'Use a sigla de 2 letras.'
                      : null,
                );
                return wide
                    ? Row(children: [
                        Expanded(flex: 3, child: city),
                        const SizedBox(width: 10),
                        Expanded(flex: 1, child: state),
                      ])
                    : Column(children: [
                        city,
                        const SizedBox(height: 10),
                        state,
                      ]);
              }),
              const SizedBox(height: 10),
              TextFormField(
                controller: postalCodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CEP',
                  hintText: '00000-000',
                  helperText: 'O CEP fica privado quando o endereço for aproximado.',
                ),
                validator: (value) => _requiredText(value, 'Informe o CEP.'),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Como mostrar a localização?',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              RadioGroup<bool>(
                groupValue: showFullAddress,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => showFullAddress = value);
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      title: Text('Mostrar apenas bairro e cidade'),
                      subtitle: Text('Seu endereço completo fica privado.'),
                    ),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      title: Text('Mostrar o endereço completo'),
                      subtitle: Text(
                        'Rua, número e CEP aparecerão no anúncio.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: locationBusy ? null : _markApproximateLocation,
                icon: locationBusy
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_searching),
                label: Text(latitude == null
                    ? 'Marcar região aproximada no mapa'
                    : 'Região marcada'),
              ),
              const SizedBox(height: 4),
              const Text(
                'Opcional: só usamos sua localização se você autorizar. A posição exibida será aproximada.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );

  Widget _buildDetailsStep() => SingleChildScrollView(
        child: Form(
          key: _detailsForm,
          child: Column(
            children: [
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: dealType == DealType.rent
                      ? 'Valor do aluguel'
                      : 'Preço de venda',
                  prefixText: 'R\$ ',
                  helperText: dealType == DealType.rent
                      ? 'Informe o valor por mês.'
                      : 'Informe o valor total do imóvel.',
                ),
                validator: _validatePrice,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, size) {
                final wide = size.maxWidth > 500;
                final condo = TextFormField(
                  controller: condoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Condomínio (opcional)', prefixText: 'R\$ '),
                );
                final tax = TextFormField(
                  controller: taxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'IPTU (opcional)', prefixText: 'R\$ '),
                );
                return wide
                    ? Row(children: [
                        Expanded(child: condo),
                        const SizedBox(width: 10),
                        Expanded(child: tax),
                      ])
                    : Column(children: [
                        condo,
                        const SizedBox(height: 10),
                        tax,
                      ]);
              }),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, size) {
                final wide = size.maxWidth > 500;
                final area = TextFormField(
                  controller: areaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Área em m² (opcional)'),
                );
                final bedrooms = TextFormField(
                  controller: bedroomsController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Quartos (opcional)'),
                );
                final bathrooms = TextFormField(
                  controller: bathroomsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Banheiros (opcional)'),
                );
                final parking = TextFormField(
                  controller: parkingController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Vagas (opcional)'),
                );
                final fields = [area, bedrooms, bathrooms, parking];
                return wide
                    ? Row(children: [
                        for (var index = 0; index < fields.length; index++) ...[
                          if (index > 0) const SizedBox(width: 8),
                          Expanded(child: fields[index]),
                        ],
                      ])
                    : Column(children: [
                        for (var index = 0; index < fields.length; index++) ...[
                          if (index > 0) const SizedBox(height: 10),
                          fields[index],
                        ],
                      ]);
              }),
              const SizedBox(height: 10),
              TextFormField(
                controller: descriptionController,
                minLines: 4,
                maxLines: 6,
                maxLength: 800,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Conte um pouco sobre o imóvel',
                  hintText: 'Fale sobre os espaços e o que há por perto.',
                ),
                validator: (value) =>
                    (value?.trim().length ?? 0) < 20
                        ? 'Escreva ao menos 20 caracteres.'
                        : null,
              ),
            ],
          ),
        ),
      );

  Widget _buildPhotosAndContactStep() => SingleChildScrollView(
        child: Form(
          key: _contactForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fotos do imóvel',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Use fotos do imóvel e evite mostrar documentos, pessoas ou dados pessoais.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: photos.length >= 10 ? null : _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(photos.isEmpty ? 'Adicionar fotos' : 'Adicionar mais fotos'),
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 10),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: photos.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = photos.removeAt(oldIndex);
                      photos.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final selection = photos[index];
                    final file = selection.file;
                    return ListTile(
                      key: ObjectKey(selection),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 54,
                          height: 54,
                          child: file != null
                              ? FutureBuilder(
                                  future: file.readAsBytes(),
                                  builder: (context, snapshot) =>
                                      snapshot.hasData
                                          ? Image.memory(snapshot.data!,
                                              fit: BoxFit.cover)
                                          : const ColoredBox(
                                              color: Color(0xFFE5F0EA),
                                              child: Icon(Icons.image_outlined),
                                            ),
                                )
                              : Image.network(
                                  selection.photo!.url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image_not_supported),
                                ),
                        ),
                      ),
                      title: Text('Foto ${index + 1}'),
                      subtitle: const Text('Arraste para mudar a ordem'),
                      trailing: IconButton(
                        tooltip: 'Remover foto',
                        onPressed: () => setState(() => photos.removeAt(index)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                ),
              ],
              const Divider(height: 28),
              Text('Contato',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                controller: advertiserController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Seu nome'),
                validator: (value) => _requiredText(value, 'Informe seu nome.'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone com DDD',
                  hintText: '(65) 99999-9999',
                  helperText: 'O telefone fica guardado com segurança.',
                ),
                validator: (value) => (value?.replaceAll(RegExp(r'\D'), '').length ?? 0) < 10
                    ? 'Informe um telefone com DDD.'
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: publishPhone,
                onChanged: (value) => setState(() {
                  publishPhone = value ?? false;
                  if (!publishPhone) whatsappAvailable = false;
                }),
                title: const Text(
                  'Autorizo mostrar meu telefone para pessoas interessadas neste anúncio.',
                ),
                subtitle: const Text(
                  'Sem autorização, o telefone não será exibido e os botões de contato ficarão desativados.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (publishPhone)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: whatsappAvailable,
                  onChanged: (value) => setState(
                    () => whatsappAvailable = value ?? false,
                  ),
                  title: const Text('Este telefone também tem WhatsApp.'),
                  subtitle: const Text(
                    'Marque para permitir que interessados iniciem uma conversa pelo WhatsApp.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0ED),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFF9D321F))),
      );
}
