import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../screens/product_image_screen.dart';

class StockWiseHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final double height;

  const StockWiseHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.height = 96,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: AppColors.primary,
      child: Row(
        children: [
          SizedBox(width: 44, child: leading),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 44, child: trailing),
        ],
      ),
    );
  }
}

class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.maybePop(context),
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
    );
  }
}

class AppSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final Widget? suffixIcon;

  const AppSearchField({
    super.key,
    this.hint = 'Search',
    this.onChanged,
    this.controller,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
        suffixIcon: suffixIcon,
        isDense: true,
      ),
    );
  }
}

class ProductArtwork extends StatelessWidget {
  final double size;
  final String? imagePath;
  final bool enlargeOnTap;
  final String? imageLabel;

  const ProductArtwork({
    super.key,
    this.size = 58,
    this.imagePath,
    this.enlargeOnTap = false,
    this.imageLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<String?>(
          future: imagePath == null || imagePath!.isEmpty
              ? Future.value(null)
              : imagePath!.startsWith('http')
              ? Future.value(imagePath)
              : FirestoreService.instance.imageUrl(imagePath),
          builder: (context, snapshot) {
            if (snapshot.data != null) {
              final image = Image.network(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              );
              if (!enlargeOnTap) return image;
              return Tooltip(
                message: 'Enlarge image',
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => ProductImageScreen(
                        image: NetworkImage(snapshot.data!),
                        title: imageLabel ?? 'Product image',
                      ),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      const Positioned(
                        right: 6,
                        bottom: 6,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black54,
                          child: Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return _placeholder();
          },
        ),
      ),
    );
  }

  Widget _placeholder() => ColoredBox(
    color: const Color(0xFFF0F2EF),
    child: Icon(
      Icons.image_outlined,
      color: const Color(0xFFAFB5AD),
      size: size * .43,
    ),
  );
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill(this.label, {super.key, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
