import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;

import '../Home/Screen/profilecard.dart';
import 'full_screen_image.dart';
import 'modelprofile.dart';

class GallerySection extends StatelessWidget {
  final List<GalleryImage> galleryImages;
  final bool showBlurredImage;
  final bool hasRequestedPhoto;
  final Function onRequestAccess;

  const GallerySection({
    Key? key,
    required this.galleryImages,
    required this.showBlurredImage,
    required this.hasRequestedPhoto,
    required this.onRequestAccess,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (galleryImages.isEmpty) {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gallery',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              if (showBlurredImage && !hasRequestedPhoto)
                ElevatedButton(
                  onPressed: () => onRequestAccess(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library, size: 16),
                      SizedBox(width: 6),
                      Text('Request Access'),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: galleryImages.length,
              itemBuilder: (context, index) {
                return _buildGalleryImage(context, galleryImages[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryImage(BuildContext context, GalleryImage image) {
    return GestureDetector(
      onTap: showBlurredImage
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FullScreenImageViewer(imageUrl: image.imageUrl),
                ),
              );
            },
      child: Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: showBlurredImage
            ? Stack(
          children: [
            CachedNetworkImage(
              imageUrl: image.imageUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.3),
                width: 100,
                height: 100,
              ),
            ),
            if (!hasRequestedPhoto)
              const Center(
                child: Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: 30,
                ),
              ),
          ],
        )
            : CachedNetworkImage(
          imageUrl: image.imageUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              strokeWidth: 2,
            ),
          ),
          errorWidget: (context, url, error) => const Icon(
            Icons.photo,
            size: 40,
            color: Colors.grey,
          ),
        ),
      ),
    ),
    );
  }
}