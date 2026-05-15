const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp({
  credential: applicationDefault(),
});

const db = getFirestore();

async function inspect() {
  console.log("--- Inspecting Users Collection ---");
  try {
    // 1. List 5 users to see structure
    const snapshot = await db.collection("users").limit(5).get();
    if (snapshot.empty) {
      console.log("No users found in collection.");
    } else {
      console.log(`Found ${snapshot.size} users. Sample data:`);
      snapshot.forEach(doc => {
        console.log(`ID: ${doc.id}, Data:`, JSON.stringify(doc.data(), null, 2));
      });
    }

    // 2. Search for specific referral code
    const targetCode = "9Q8WH6";
    console.log(`\n--- Searching for referralCode: ${targetCode} ---`);
    const searchSnapshot = await db.collection("users").where("referralCode", "==", targetCode).get();
    if (searchSnapshot.empty) {
      console.log(`No user found with referralCode: ${targetCode}`);
    } else {
      console.log(`Found ${searchSnapshot.size} user(s) with referralCode: ${targetCode}`);
      searchSnapshot.forEach(doc => {
        console.log(`ID: ${doc.id}, Data:`, JSON.stringify(doc.data(), null, 2));
      });
    }
  } catch (error) {
    console.error("Error inspecting database:", error);
  }
}

inspect();
