// Firebase Cloud Messaging service worker (web push).
//
// This file is served at the site root and handles BACKGROUND notifications
// (tab closed / not focused). Service workers can't read Dart --dart-define
// values, so the *public* web config below must be pasted in by hand from
// Firebase console → Project settings → General → "Your apps" (Web app).
// These are public, client-safe values (the same ones in env.json) — the FCM
// server credential is a secret and never appears here.
//
// Until you paste real values, `firebase.initializeApp` throws and the worker
// simply does nothing — foreground pushes and the in-app inbox still work.

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'FIREBASE_API_KEY',
  appId: 'FIREBASE_APP_ID',
  messagingSenderId: 'FIREBASE_MESSAGING_SENDER_ID',
  projectId: 'FIREBASE_PROJECT_ID',
});

const messaging = firebase.messaging();

// Show a notification when a data/notification message arrives in the background.
messaging.onBackgroundMessage((payload) => {
  const title = (payload.notification && payload.notification.title) || 'Sporve';
  const body = (payload.notification && payload.notification.body) || '';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  });
});
