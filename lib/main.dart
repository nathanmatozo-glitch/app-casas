import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const AppCasasApp());

class AppCasasApp extends StatelessWidget {
  const AppCasasApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'App Casas',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B55)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF6F8F7),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const HomePage(),
      );
}

class Property {
  Property({required this.title, required this.city, required this.price,
    required this.kind, required this.rooms, required this.area,
    required this.description, this.phone = ''});
  final String title, city, kind, description, phone;
  final int rooms;
  final double price, area;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final search = TextEditingController();
  String filter = 'Todos';
  final List<Property> properties = [
    Property(title: 'Casa moderna com quintal', city: 'Cuiabá, MT', price: 420000,
      kind: 'Venda', rooms: 3, area: 140, description: 'Casa espaçosa, com quintal e garagem. Anúncio demonstrativo.'),
    Property(title: 'Apartamento próximo ao centro', city: 'Várzea Grande, MT', price: 1850,
      kind: 'Aluguel', rooms: 2, area: 68, description: 'Apartamento iluminado, com dois quartos. Anúncio demonstrativo.'),
    Property(title: 'Casa familiar em bairro tranquilo', city: 'Rondonópolis, MT', price: 320000,
      kind: 'Venda', rooms: 2, area: 96, description: 'Casa confortável perto de serviços essenciais. Anúncio demonstrativo.'),
  ];

  List<Property> get visible => properties.where((p) {
    final q = search.text.toLowerCase();
    final matchesText = '${p.title} ${p.city}'.toLowerCase().contains(q);
    return matchesText && (filter == 'Todos' || p.kind == filter);
  }).toList();

  String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> addProperty() async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController();
    final city = TextEditingController();
    final price = TextEditingController();
    final rooms = TextEditingController(text: '2');
    final area = TextEditingController(text: '80');
    final description = TextEditingController();
    String kind = 'Venda';
    final result = await showDialog<Property>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialog) =>
        AlertDialog(
          title: const Text('Novo anúncio'),
          content: SizedBox(width: 420, child: SingleChildScrollView(
            child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Título'), validator: (v) => v == null || v.trim().isEmpty ? 'Informe o título' : null),
              const SizedBox(height: 10),
              TextFormField(controller: city, decoration: const InputDecoration(labelText: 'Cidade / bairro'), validator: (v) => v == null || v.trim().isEmpty ? 'Informe a localização' : null),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(initialValue: kind, decoration: const InputDecoration(labelText: 'Tipo'), items: const [
                DropdownMenuItem(value: 'Venda', child: Text('Venda')),
                DropdownMenuItem(value: 'Aluguel', child: Text('Aluguel')),
              ], onChanged: (v) => setDialog(() => kind = v ?? 'Venda')),
              const SizedBox(height: 10),
              TextFormField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço (R\$)'), validator: (v) => double.tryParse((v ?? '').replaceAll(',', '.')) == null ? 'Informe um preço válido' : null),
              const SizedBox(height: 10),
              TextFormField(controller: rooms, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quartos')),
              const SizedBox(height: 10),
              TextFormField(controller: area, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Área (m²)')),
              const SizedBox(height: 10),
              TextFormField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição')),
            ])),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, Property(
                  title: title.text.trim(), city: city.text.trim(),
                  price: double.parse(price.text.replaceAll(',', '.')),
                  kind: kind, rooms: int.tryParse(rooms.text) ?? 0,
                  area: double.tryParse(area.text.replaceAll(',', '.')) ?? 0,
                  description: description.text.trim().isEmpty ? 'Sem descrição.' : description.text.trim(),
                ));
              }
            }, child: const Text('Salvar')),
          ],
        )),
    );
    if (result != null && mounted) setState(() => properties.insert(0, result));
  }

  Future<void> contact(Property p) async {
    final phone = p.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione o telefone do anunciante para habilitar o WhatsApp.')));
      return;
    }
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent('Olá! Tenho interesse no imóvel: ${p.title}.')}');
    if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
  }

  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(children: [Icon(Icons.home_work_rounded), SizedBox(width: 8), Text('App Casas')]),
      actions: [IconButton(tooltip: 'Novo anúncio', onPressed: addProperty, icon: const Icon(Icons.add_home_work_rounded))],
    ),
    body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF176B55), Color(0xFF259477)]),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Encontre seu próximo lar', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Casas e apartamentos para venda e aluguel', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          TextField(controller: search, onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar cidade ou imóvel',
              prefixIcon: const Icon(Icons.search),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            )),
        ]),
      ),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(spacing: 8, children: [
        for (final f in ['Todos', 'Venda', 'Aluguel'])
          ChoiceChip(label: Text(f), selected: filter == f, onSelected: (_) => setState(() => filter = f)),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Text('${visible.length} imóveis encontrados', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
      Expanded(child: visible.isEmpty
        ? const Center(child: Text('Nenhum imóvel encontrado.'))
        : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final p = visible[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              clipBehavior: Clip.antiAlias,
              elevation: 1,
              child: InkWell(
                onTap: () => showModalBottomSheet(context: context, isScrollControlled: true,
                  builder: (context) => SafeArea(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Wrap(runSpacing: 12, children: [
                      Row(children: [Expanded(child: Text(p.title, style: Theme.of(context).textTheme.headlineSmall)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
                      Chip(label: Text(p.kind)),
                      Text(p.city, style: Theme.of(context).textTheme.titleMedium),
                      Text(money(p.price) + (p.kind == 'Aluguel' ? ' / mês' : ''), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: const Color(0xFF176B55), fontWeight: FontWeight.bold)),
                      Text('${p.rooms} quartos   •   ${p.area.toStringAsFixed(0)} m²'),
                      Text(p.description),
                      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => contact(p), icon: const Icon(Icons.chat), label: const Text('Falar com anunciante no WhatsApp'))),
                    ]),
                  ))),
                child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                  Container(width: 92, height: 100, decoration: BoxDecoration(color: const Color(0xFFDDEBE5), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.home_rounded, size: 48, color: Color(0xFF176B55))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(p.kind.toUpperCase(), style: const TextStyle(color: Color(0xFF176B55), fontWeight: FontWeight.bold, fontSize: 11))), const Icon(Icons.chevron_right)]),
                    const SizedBox(height: 5),
                    Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(p.city, style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Text(money(p.price) + (p.kind == 'Aluguel' ? ' / mês' : ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${p.rooms} quartos • ${p.area.toStringAsFixed(0)} m²', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                  ])),
                ])),
              ),
            );
          },
        )),
    ])),
    floatingActionButton: FloatingActionButton.extended(onPressed: addProperty, icon: const Icon(Icons.add), label: const Text('Anunciar imóvel')),
  );
}
