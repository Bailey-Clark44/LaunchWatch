// Receives LaunchWatch alerts while the site is closed or in the background.
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDVHNC-tRjHKxNum4qUUDd0212M84M8J9k',
  appId: '1:599559992619:web:51f96344501b8cb227c16e',
  messagingSenderId: '599559992619',
  projectId: 'launchwatch-c77fa',
  authDomain: 'launchwatch-c77fa.firebaseapp.com',
  storageBucket: 'launchwatch-c77fa.firebasestorage.app',
});

// Notification payloads are shown by the browser automatically. Taps open
// the launch, using the link set by the server in webpush.fcmOptions.link.
firebase.messaging();
