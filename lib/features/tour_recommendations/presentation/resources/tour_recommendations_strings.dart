abstract final class TourRecommendationsStrings {
  static const String appBarTitle = 'Recommended Tours';
  static const String preferencesTooltip = 'Travel Preferences';
  static const String bannerTitle =
      'Personalized Recommendations (> 80% Match)';
  static const String bannerDescription =
      'Tours are automatically curated based on your travel interests and preferred itinerary themes.';
  static const String bannerEditPreferences = 'Edit Travel Preferences →';
  static const String pendingIntegrationTitle =
      'Tour Recommendations Coming Soon';
  static const String pendingIntegrationDescription =
      'Our AI recommendation engine is pending backend service integration. You can explore all tours or update your travel preferences in the meantime.';
  static const String exploreAllTours = 'Explore All Tours';
  static const String updateTravelPreferences = 'Update Travel Preferences';
  static const String noPreferencesTitle = 'No Preferences Configured';
  static const String setupTravelPreferences = 'Configure Travel Preferences';
  static const String noMatchesTitle = 'No Tours Match (> 80%)';
  static const String adjustPreferences = 'Adjust Preferences';
  static const String errorTitle = 'Unable to Load Recommendations';
  static const String retry = 'Retry';
  static const String previousPage = 'Previous';
  static const String nextPage = 'Next';

  static String matchingToursCount(int count) => 'Found $count matching tours';
  static String pageIndicator(int current, int total) =>
      'Page $current / $total';
  static String pageRatio(int current, int total) => '$current / $total';
  static String matchPercent(int percent) => '$percent% match';

  // Demo Simulation Controls (Debug only)
  static const String demoControlsTitle =
      'DEMO SIMULATION CONTROLS (Debug Mode Only)';
  static const String demoChipSuccess = 'Success (>80%)';
  static const String demoChipNoPreferences = 'No Preferences (MSG28)';
  static const String demoChipNoMatches = 'No Matches >80% (MSG64)';
  static const String demoChipError = 'Network Error (MSG127)';
}
