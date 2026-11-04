import '../shared/customer_image.dart';
import 'package:flutter/material.dart';

/// All booking cards use the same saved-photo fields and failure fallback.
String? professionalPhoto(Map worker) {
  for (final key in const [
    'photoUrl',
    'profileImageUrl',
    'avatarUrl',
    'profilePhotoPath',
  ]) {
    final value = worker[key];
    if (value is! String || value.trim().isEmpty) continue;
    final photo = value.trim();
    final uri = Uri.tryParse(photo);
    if (photo.startsWith('assets/') ||
        (uri != null &&
            uri.hasAuthority &&
            (uri.scheme == 'https' || uri.scheme == 'http'))) {
      return photo;
    }
  }
  return null;
}

class ProfessionalPortrait extends StatelessWidget {
  const ProfessionalPortrait({super.key, required this.worker, this.size = 48});
  final Map worker;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = professionalPhoto(worker);
    Widget placeholder() => const ColoredBox(
      color: Color(0xFFFFF0F5),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          color: Color(0xFFA5003D),
          size: 28,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: photo == null
            ? placeholder()
            : Image(
                image: photo.startsWith('assets/')
                    ? AssetImage(photo) as ImageProvider
                    : customerImageProvider(photo),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder(),
              ),
      ),
    );
  }
}
