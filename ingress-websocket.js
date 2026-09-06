/* OwnTone's notify socket must share Home Assistant's authenticated ingress. */
(() => {
  const match = window.location.pathname.match(/^\/api\/hassio_ingress\/[^/]+\//);
  if (!match) return;
  const NativeWebSocket = window.WebSocket;
  window.WebSocket = class extends NativeWebSocket {
    constructor(url, protocols) {
      const notify = protocols === "notify"
        || (Array.isArray(protocols) && protocols.includes("notify"));
      if (notify) {
        const endpoint = new URL(`${match[0]}ws`, window.location.href);
        endpoint.protocol = endpoint.protocol === "https:" ? "wss:" : "ws:";
        url = endpoint.href;
      }
      if (protocols === undefined) super(url);
      else super(url, protocols);
    }
  };
})();
