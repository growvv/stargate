import { register } from 'node:module';
register('./loader.mjs', import.meta.url);

// Aggregator: run every *test suite's default export.
const suites = [
  './Smoke.test.ets',
  './RankingEngine.test.ets',
  './PinyinUtil.test.ets',
  './CapabilityRepository.test.ets',
  './UsageStore.test.ets',
  './WidgetCardData.test.ets',
  './ThemeTokens.test.ets',
  './SearchFilter.test.ets',
  './PageRouter.test.ets',
  './LaunchDispatcher.test.ets',
  './ConfigAccess.test.ets',
  './SuggestionPolicy.test.ets',
  './CatalogEditor.test.ets',
  './CardBinding.test.ets',
  './D1FlatSections.test.ets',
  './D2CardFeedback.test.ets',
  './D3ThemeColors.test.ets',
  './CardPalette.test.ets',
  './BrandMark.test.ets',
  './GlassStyle.test.ets',
  './FrameGroups.test.ets',
  './CardChrome.test.ets',
  './InnerPageLayout.test.ets',
  './AppTemplateCatalog.test.ets',
  './InstalledProbe.test.ets',
  './EffectiveCatalog.test.ets',
  './CatalogDiff.test.ets',
  './InstallSnapshotStore.test.ets',
  './RefreshOrchestrator.test.ets',
  './DiscoveryStats.test.ets',
  './DiscoveryCandidateCatalog.test.ets',
  './AtomicFunction.test.ets',
  './VerticalStarter.test.ets',
  './SeedCatalog.test.ets',
  './LetterSections.test.ets',
  './RecentAdditions.test.ets',
  './CategoryOrderStore.test.ets',
];

for (const s of suites) {
  const url = new URL('../entry/src/test/' + s, import.meta.url);
  try {
    const mod = await import(url.href);
    if (typeof mod.default === 'function') mod.default();
  } catch (e) {
    // A suite that does not exist yet is a RED signal, not a silent skip.
    if (e && (e.code === 'ERR_MODULE_NOT_FOUND' || String(e.message).includes('Cannot find'))) {
      console.error('MISSING SUITE (RED): ' + s + ' -> ' + String(e.message).split('\n')[0]);
      process.exitCode = 1;
    } else {
      throw e;
    }
  }
}
