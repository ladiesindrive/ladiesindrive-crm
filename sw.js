// Service worker antigo não faz mais nada útil (só ficava travando
// sessão/cache em alguns navegadores, exigindo limpar dados do site pra
// conseguir logar). Esta versão se autodestrói assim que o navegador
// checar por uma atualização: limpa todo o cache guardado, se
// desregistra, e recarrega as abas abertas do CRM pra ficarem livres
// dele de vez.
self.addEventListener("install", () => self.skipWaiting());

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const chaves = await caches.keys();
      await Promise.all(chaves.map(k => caches.delete(k)));
      await self.registration.unregister();
      const clientes = await self.clients.matchAll({ type: "window" });
      clientes.forEach(c => c.navigate(c.url));
    })()
  );
});
