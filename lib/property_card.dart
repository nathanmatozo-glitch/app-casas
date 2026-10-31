import 'package:flutter/material.dart';

import 'models/property_listing.dart';

String formatBrl(double value) =>
    'R\$ ${value.round().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
        )}';

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.listing,
    required this.saved,
    required this.onTap,
    required this.onFavorite,
    this.showFavorite = true,
  });

  final PropertyListing listing;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 174,
                    child: listing.photos.isEmpty
                        ? const _PhotoPlaceholder()
                        : Image.network(
                            listing.photos.first.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _PhotoPlaceholder(),
                          ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Text(
                          listing.dealType.label,
                          style: const TextStyle(
                            color: Color(0xFF176B55),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showFavorite)
                    Positioned(
                    right: 10,
                    top: 10,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.96),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: saved ? 'Remover dos salvos' : 'Salvar imóvel',
                        onPressed: onFavorite,
                        icon: Icon(saved ? Icons.favorite : Icons.favorite_border,
                            color: saved ? Colors.redAccent : Colors.black87),
                      ),
                    ),
                    ),
                  if (listing.isDemo)
                    const Positioned(
                      right: 12,
                      bottom: 10,
                      child: _DemoLabel(),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.category.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listing.shortLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      Text(
                        '${formatBrl(listing.price)}${listing.dealType == DealType.rent ? ' / mês' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Color(0xFF176B55),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (listing.bedrooms != null)
                            _Feature(icon: Icons.bed_outlined, text: '${listing.bedrooms} quartos'),
                          if (listing.area != null)
                            _Feature(
                              icon: Icons.square_foot,
                              text: '${listing.area!.round()} m²',
                            ),
                          const _Feature(
                              icon: Icons.arrow_forward, text: 'Ver detalhes'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFE5F0EA),
        child: const Center(
          child: Icon(Icons.home_work_rounded,
              size: 58, color: Color(0xFF176B55)),
        ),
      );
}

class _DemoLabel extends StatelessWidget {
  const _DemoLabel();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5DF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text('Exemplo',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      );
}
