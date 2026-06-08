import { initializeApp, getApps } from 'firebase/app'
import { getAuth } from 'firebase/auth'
import { getFirestore } from 'firebase/firestore'
import { getStorage } from 'firebase/storage'

const firebaseConfig = {
  apiKey: "AIzaSyChv9Tfgfd8wMiwZIRf9BpXn336bf0gVvY",
  authDomain: "backline-7e769.firebaseapp.com",
  projectId: "backline-7e769",
  storageBucket: "backline-7e769.firebasestorage.app",
  messagingSenderId: "1039412382496",
  appId: "1:1039412382496:web:a7e3d883012e32e6672545",
  measurementId: "G-9F6R8MSFW1"
}

// Initialize Firebase only once
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0]

export const auth = getAuth(app)
export const db = getFirestore(app)
export const storage = getStorage(app)
export { app }
