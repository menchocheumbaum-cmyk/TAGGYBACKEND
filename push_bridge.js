function taggyBase64ToUint8Array(base64String) {
  const padding =
    "=".repeat((4 - base64String.length % 4) % 4);

  const base64 =
    (base64String + padding)
      .replace(/-/g, "+")
      .replace(/_/g, "/");

  const rawData = atob(base64);

  return Uint8Array.from(
    [...rawData].map(
      (char) => char.charCodeAt(0)
    )
  );
}

async function taggyEsperarServiceWorker(registration) {
  if (registration.active) {
    return;
  }

  const worker =
    registration.installing ||
    registration.waiting;

  if (!worker) {
    return;
  }

  if (worker.state === "activated") {
    return;
  }

  await new Promise((resolve) => {
    worker.addEventListener(
      "statechange",
      () => {
        if (worker.state === "activated") {
          resolve();
        }
      }
    );
  });
}

window.taggyCreatePushSubscription = async function () {
  if (!("serviceWorker" in navigator)) {
    throw new Error(
      "Este dispositivo no soporta Service Worker."
    );
  }

  if (!("PushManager" in window)) {
    throw new Error(
      "Este dispositivo no soporta notificaciones Push."
    );
  }

  const permission =
    await Notification.requestPermission();

  if (permission !== "granted") {
    throw new Error(
      "No se concedió permiso para notificaciones."
    );
  }

  const registration =
    await navigator.serviceWorker.register(
      "push-sw.js",
      {
        scope: "push/"
      }
    );

  await taggyEsperarServiceWorker(registration);

  const response = await fetch(
    "https://taggy-api.onrender.com/api/push/public-key",
    {
      cache: "no-store"
    }
  );

  if (!response.ok) {
    throw new Error(
      "No se pudo obtener la clave Push."
    );
  }

  const data = await response.json();

  let subscription =
    await registration.pushManager.getSubscription();

  if (!subscription) {
    subscription =
      await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey:
          taggyBase64ToUint8Array(data.publicKey)
      });
  }

  const json = subscription.toJSON();

  return JSON.stringify({
    endpoint: json.endpoint,
    keys: {
      p256dh: json.keys.p256dh,
      auth: json.keys.auth
    },
    plataforma:
      /iPhone|iPad|iPod/i.test(navigator.userAgent)
        ? "ios-pwa"
        : "web",
    user_agent: navigator.userAgent
  });
};
