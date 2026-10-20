import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';

/// Data structure representing an individual slide in [GuestHeroBanner].
class HeroSlideData {
  const HeroSlideData({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.route,
  });

  /// Distinctive badge / pill text (e.g. '✦ ĐÀ NẴNG').
  final String tag;

  /// High-impact headline for the slide.
  final String title;

  /// Secondary descriptive text.
  final String subtitle;

  /// High-resolution photographic asset URL.
  final String imageUrl;

  /// Optional route to navigate to when this slide is tapped.
  final String? route;
}

/// A magazine-quality, auto-rotating hero banner for the TripMate Guest Homepage.
///
/// Features:
/// - Smooth automatic slideshow transition (4.5s cycle) with manual swipe support.
/// - Dynamic multi-stop gradient overlay ensuring 100% text contrast.
/// - Frosted glass destination badge and clear typography.
/// - Pre-caching of all photographic assets to eliminate loading pop-in.
/// - Isolated widget state preventing unnecessary rebuilds of the parent homepage.
/// - Automatic pause when accessibility reduced motion (`disableAnimations`) is active.
class GuestHeroBanner extends StatefulWidget {
  const GuestHeroBanner({
    super.key,
    this.height = 215,
    this.autoRotate = true,
    this.rotationInterval = const Duration(milliseconds: 4500),
    this.customSlides,
  });

  /// Banner height in logical pixels.
  final double height;

  /// Whether auto-rotation is enabled.
  final bool autoRotate;

  /// Duration each slide is displayed before auto-advancing.
  final Duration rotationInterval;

  /// Optional custom slide list (primarily for tests).
  final List<HeroSlideData>? customSlides;

  /// Authoritative Central Vietnam destination slides showcasing iconic landmarks.
  static const List<HeroSlideData> defaultSlides = [
    HeroSlideData(
      tag: '✦ ĐÀ NẴNG',
      title: 'Cầu Rồng & Biển Mỹ Khê',
      subtitle: 'Thành phố ánh sáng và cung đường biển quyến rũ',
      imageUrl:
          'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=1200',
    ),
    HeroSlideData(
      tag: '✦ DI SẢN UNESCO',
      title: 'Phố Cổ Hội An Lung Linh',
      subtitle: 'Dạo bước qua ngàn năm hoài niệm và đèn lồng rực rỡ',
      imageUrl:
          'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200',
    ),
    HeroSlideData(
      tag: '✦ CỐ ĐÔ HUẾ',
      title: 'Đại Nội & Lăng Tẩm Cung Đình',
      subtitle: 'Dấu ấn vương triều bên dòng sông Hương thơ mộng',
      imageUrl:
          'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=1200',
    ),
    HeroSlideData(
      tag: '✦ KỲ QUAN THIÊN NHIÊN',
      title: 'Bà Nà Hills & Ngũ Hành Sơn',
      subtitle: 'Khám phá mây trời non nước và danh thắng kỳ vĩ',
      imageUrl:
          'https://images.unsplash.com/photo-1528127269322-539801943592?w=1200',
    ),
  ];

  @override
  State<GuestHeroBanner> createState() => _GuestHeroBannerState();
}

class _GuestHeroBannerState extends State<GuestHeroBanner> {
  late final PageController _pageController;
  Timer? _rotationTimer;
  int _currentIndex = 0;
  bool _preloaded = false;

  List<HeroSlideData> get _slides =>
      widget.customSlides ?? GuestHeroBanner.defaultSlides;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!_preloaded && !isTest) {
      _preloaded = true;
      for (final slide in _slides) {
        if (slide.imageUrl.startsWith('http')) {
          precacheImage(
            NetworkImage(slide.imageUrl),
            context,
            onError: (_, _) {},
          );
        }
      }
    }
    _startTimer();
  }

  void _startTimer() {
    _rotationTimer?.cancel();
    if (!widget.autoRotate || _slides.length <= 1) return;

    _rotationTimer = Timer.periodic(widget.rotationInterval, (_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) return;

      final nextIndex = (_currentIndex + 1) % _slides.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _resetTimer() {
    _rotationTimer?.cancel();
    _startTimer();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleSlideTap(HeroSlideData slide) {
    if (slide.route != null) {
      context.push(slide.route!);
    } else {
      context.push(AppRoutes.explore);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1800152A),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // PageView Carousel
            PageView.builder(
              controller: _pageController,
              itemCount: slides.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _resetTimer();
              },
              itemBuilder: (context, index) {
                final slide = slides[index];
                return _buildSlide(slide);
              },
            ),

            // Persistent slide indicators at bottom-right
            Positioned(
              bottom: 14,
              right: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < slides.length; i++)
                    _buildIndicator(isSelected: i == _currentIndex),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(HeroSlideData slide) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSlideTap(slide),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Slide photographic background
            Image.network(
              slide.imageUrl,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: 'Ảnh ${slide.title}',
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return const _HeroPlaceholder(isShimmer: true);
              },
              errorBuilder: (_, _, _) => const _HeroPlaceholder(),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const _HeroPlaceholder(isShimmer: true);
              },
            ),

            // Multi-stop gradient overlay for superior text contrast
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x38000000),
                    Color(0x12000000),
                    Color(0x7300152A),
                    Color(0xD900152A),
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),

            // Foreground caption & badge
            Positioned(
              left: 14,
              right: 80, // Leave room for indicators on the right
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Destination Tag Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      slide.tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Title
                  Text(
                    slide.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: -0.3,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Subtitle
                  Text(
                    slide.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator({required bool isSelected}) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return AnimatedContainer(
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      width: isSelected ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(3),
        boxShadow: isSelected
            ? const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder({this.isShimmer = false});

  final bool isShimmer;

  @override
  Widget build(BuildContext context) {
    const staticContent = ColoredBox(
      color: Color(0xFF0F2B48),
      child: SizedBox.expand(
        child: Center(
          child: Icon(
            Icons.landscape_outlined,
            color: Colors.white24,
            size: 40,
          ),
        ),
      ),
    );

    if (isShimmer) {
      return const AppShimmer(child: staticContent);
    }
    return staticContent;
  }
}
