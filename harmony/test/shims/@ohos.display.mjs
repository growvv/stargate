// Stub for @ohos.display. The pure-logic tests never need real display metrics;
// a stable 3.25 density mirrors the Mate 60 device the app was verified on.
export default {
  getDefaultDisplaySync: () => ({ densityPixels: 3.25, densityDPI: 480, width: 1216, height: 2688 }),
};
