/* ============================================================
   Configuracao do Firebase

   Projeto: tormentalia-db8d9
   O site e estatico e usa a API REST do Firestore (sem SDK),
   portanto apenas apiKey/projectId sao necessarios para o envio
   das sugestoes. Os demais campos ficam registrados para uso
   futuro (Auth, Storage, Analytics etc.).
   ============================================================ */
window.OCDM_FIREBASE = {
  apiKey: 'AIzaSyBw0XPICiPtbVxJ33D1ePwP5eY0h88PtjY',
  authDomain: 'tormentalia-db8d9.firebaseapp.com',
  projectId: 'tormentalia-db8d9',
  storageBucket: 'tormentalia-db8d9.firebasestorage.app',
  messagingSenderId: '1091414213163',
  appId: '1:1091414213163:web:d35a77d68dfb7572e1606e',
  // Colecao do Firestore onde as sugestoes serao salvas.
  collection: 'sugestoes',
};
