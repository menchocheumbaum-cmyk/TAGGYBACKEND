self.addEventListener("push", (event) => {
  let data = {};

  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {}

  const title = data.title || "TAGGY";

  const options = {
    body: data.body || "Tienes una nueva notificación de TAGGY.",
    icon: "icons/Icon-192.png",
    badge: "icons/Icon-192.png",
    data: {
      url: data.url || "/TAGGYBACKEND/"
    }
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const url =
    event.notification.data?.url ||
    "/TAGGYBACKEND/";

  event.waitUntil(
    clients.openWindow(url)
  );
});
