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
    this.height = 168,
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
      tag: 'ĐÀ NẴNG',
      title: 'Cầu Rồng & Biển Mỹ Khê',
      subtitle: 'Thành phố ánh sáng và cung đường biển quyến rũ',
      imageUrl: 'assets/images/destinations/danang_dragon_bridge.jpg',
    ),
    HeroSlideData(
      tag: 'DI SẢN UNESCO',
      title: 'Phố Cổ Hội An Lung Linh',
      subtitle: 'Dạo bước qua ngàn năm hoài niệm và đèn lồng rực rỡ',
      imageUrl: 'assets/images/destinations/hoian_lantern_night.jpg',
    ),
    HeroSlideData(
      tag: 'CỐ ĐÔ HUẾ',
      title: 'Đại Nội & Lăng Tẩm Cung Đình',
      subtitle: 'Dấu ấn vương triều bên dòng sông Hương thơ mộng',
      imageUrl: 'assets/images/destinations/hue_ngo_mon.jpg',
    ),
    HeroSlideData(
      tag: 'KỲ QUAN THIÊN NHIÊN',
      title: 'Bà Nà Hills & Ngũ Hành Sơn',
      subtitle: 'Khám phá mây trời non nước và danh thắng kỳ vĩ',
      imageUrl: 'assets/images/destinations/marble_mountains.jpg',
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
        if (slide.imageUrl.startsWith('assets/')) {
          precacheImage(
            AssetImage(slide.imageUrl),
            context,
            onError: (_, _) {},
          );
        } else if (slide.imageUrl.startsWith('http')) {
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12103B39),
              blurRadius: 12,
              offset: Offset(0, 4),
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
            _buildSlideImage(slide),

            // Multi-stop gradient overlay for gentle Coastal contrast
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x180E1E1D),
                    Color(0x0A0E1E1D),
                    Color(0x6B102827),
                    Color(0xCC0E2221),
                  ],
                  stops: [0.0, 0.35, 0.68, 1.0],
                ),
              ),
            ),

            // Foreground caption & badge
            Positioned(
              left: 14,
              right: 76, // Leave room for indicators on the right
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
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!slide.tag.startsWith('✦')) ...[
                          const Icon(
                            Icons.auto_awesome,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          slide.tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
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
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.22,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 4,
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
                      color: Colors.white.withValues(alpha: 0.90),
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

  Widget _buildSlideImage(HeroSlideData slide) {
    if (slide.imageUrl.startsWith('assets/')) {
      return Image.asset(
        slide.imageUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        semanticLabel: 'Ảnh ${slide.title}',
        errorBuilder: (_, _, _) => const _HeroPlaceholder(),
      );
    }

    return Image.network(
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
      color: Color(0xFF174B4A),
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
