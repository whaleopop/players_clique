// Firebase Messaging Service Worker — required for background web notifications.
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAatJoiW4pCg3fxHJvAzuWvrXfiMPda5AQ",
  authDomain: "players-clique.firebaseapp.com",
  projectId: "players-clique",
  storageBucket: "players-clique.appspot.com",
  messagingSenderId: "924845558356",
  appId: "1:924845558356:web:0eaca2749a75247fc4fbc1",
});

const messaging = firebase.messaging();

// Handle background messages (tab is closed or in background).
messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification ?? {};
  const title = notification.title ?? "РКН Российская Коммуна Никиты";
  const body = notification.body ?? "";

  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: payload.data,
  });
});
