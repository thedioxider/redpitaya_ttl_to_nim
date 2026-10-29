// A classic script in <head>, so the saved theme applies before the first paint.
(() => {
  const KEY = "ttl2nim-theme";
  const root = document.documentElement;

  try {
    const saved = localStorage.getItem(KEY);
    if (saved === "light" || saved === "dark") root.dataset.theme = saved;
  } catch {
    // Storage blocked: follow the system theme.
  }

  const isDark = () =>
    root.dataset.theme
      ? root.dataset.theme === "dark"
      : matchMedia("(prefers-color-scheme: dark)").matches;

  document.addEventListener("DOMContentLoaded", () => {
    document.getElementById("theme").addEventListener("click", () => {
      const theme = isDark() ? "light" : "dark";
      root.dataset.theme = theme;
      try {
        localStorage.setItem(KEY, theme);
      } catch {
        // Storage blocked: the choice lasts until reload.
      }
    });
  });
})();
