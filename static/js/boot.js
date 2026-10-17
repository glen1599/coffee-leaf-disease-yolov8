/* Runs synchronously from <head>, before the body is parsed and before the
   first paint. Two jobs:
     1. apply the saved appearance, so the page never flashes the wrong theme
     2. mark that scripting is available, which is what arms the entrance
        animations — without it the content is simply visible. */
(() => {
  document.documentElement.dataset.js = "";
  try {
    const saved = localStorage.getItem("coffee_leaf_theme");
    if (saved === "light" || saved === "dark") {
      document.documentElement.dataset.theme = saved;
    }
  } catch {
    /* private mode: fall back to the system preference */
  }
})();
