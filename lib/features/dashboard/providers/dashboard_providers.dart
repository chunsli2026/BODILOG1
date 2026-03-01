export '../../results/providers/results_providers.dart'
    show
        colorAnalysisServiceProvider,
        currentTestResultProvider,
        latestTestResultProvider,
        testResultsProvider,
        parameterTrendProvider;

/// The 4 key parameters shown as trend charts on the dashboard.
const List<String> kDashboardTrendParameters = [
  'pH',
  'Glucose',
  'Protein',
  'Specific Gravity',
];
