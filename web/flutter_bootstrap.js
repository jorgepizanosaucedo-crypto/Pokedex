{{flutter_js}}
{{flutter_build_config}}

// Arranque de la app en web. Igual que el de Flutter, pero quita el aviso de
// "Cargando…" de index.html en cuanto la app dibuja su primer cuadro.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const loading = document.getElementById('loading');
    if (loading) {
      loading.classList.add('done');
      setTimeout(function () { loading.remove(); }, 400);
    }
  },
});
