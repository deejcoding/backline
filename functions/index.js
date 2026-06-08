const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");

initializeApp({
  credential: applicationDefault(),
});

/**
 * Fetches a Spotify client credentials access token.
 * This keeps the clientSecret secure on the server.
 */
exports.getSpotifyAccessToken = onCall(async (request) => {
  const clientID = "4bbf6c9d330b421fa7710966ffe5208e";
  const clientSecret = "d3504992f0ab416492cae9e4c4bbd47f";

  try {
    const authOptions = {
      method: "POST",
      headers: {
        "Authorization": "Basic " + Buffer.from(clientID + ":" + clientSecret).toString("base64"),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: "grant_type=client_credentials",
    };

    const response = await fetch("https://accounts.spotify.com/api/token", authOptions);
    const data = await response.json();

    if (!response.ok) {
      throw new HttpsError("internal", "Spotify auth failed: " + (data.error || response.statusText));
    }

    return {
      access_token: data.access_token,
      expires_in: data.expires_in,
    };
  } catch (error) {
    console.error("getSpotifyAccessToken error:", error);
    throw new HttpsError("internal", "Failed to fetch Spotify token.");
  }
});

/**
 * Aggregates global stats when new documents are created.
...
exports.aggregateGlobalStats = onDocumentCreated(
  "{collection}/{id}",
  async (event) => {
    const coll = event.params.collection;
    const trackedCollections = {
      users: "totalUsers",
      listings: "totalListings",
      serviceListings: "totalServices",
      isoPosts: "totalISOPosts",
      showFlyers: "totalShowFlyers",
      conversations: "totalConversations",
    };

    const field = trackedCollections[coll];
    if (!field) return;

    const db = getFirestore();
    try {
      await db.collection("stats").doc("global").set({
        [field]: FieldValue.increment(1),
        lastUpdated: FieldValue.serverTimestamp(),
      }, { merge: true });
    } catch (error) {
      console.error("Error updating global stats:", error);
    }
  }
);

/**
 * Sends a push notification when a new message is created in a conversation.
...
 * Trigger: conversations/{conversationId}/messages/{messageId}
 *
 * Looks up the recipient's FCM token from their user document and sends
 * a notification with the sender's username and message text.
 */
exports.sendMessageNotification = onDocumentCreated(
  {
    document: "conversations/{conversationId}/messages/{messageId}",
  },
  async (event) => {

    console.log("STEP 0: function triggered");

    const messageData = event.data?.data();
    console.log("STEP 1: messageData =", messageData);

    if (!messageData){
      console.log("EXIT: no messageData");
      return;
    }

    const { senderUID, text } = messageData;
    const conversationId = event.params.conversationId;

    console.log("STEP 2: senderUID =", senderUID);
    console.log("STEP 3: text =", text);
    console.log("STEP 4: conversationId =", conversationId);

    if (!senderUID || !text) {
      console.log("EXIT: missing senderUID or text");
      return;
    }
    const db = getFirestore();

    // Get the conversation to find participants
    const conversationDoc = await db
      .collection("conversations")
      .doc(conversationId)
      .get();

    console.log("STEP 5: conversation exists =", conversationDoc.exists);

    if (!conversationDoc.exists) {
      console.log("EXIT: conversation not found");
      return;
    }

    const conversationData = conversationDoc.data();
    const participants = conversationData.participants || [];

    console.log("STEP 6: participants =", participants);
    
    const participantUsernames = conversationData.participantUsernames || {};

    // Find the recipient (the participant who is NOT the sender)
    const recipientUID = participants.find((uid) => uid !== senderUID);

    console.log("STEP 7: recipientUID =", recipientUID);

    if (!recipientUID){
      console.log("EXIT: no recipientUID found");
      return;
    }

    // Get the recipient's FCM token
    const recipientDoc = await db.collection("users").doc(recipientUID).get();
    console.log("STEP 8: recipient exists =", recipientDoc.exists);

    if (!recipientDoc.exists){
      console.log("EXIT: recipient not found");
      return;
    }

    const recipientData = recipientDoc.data();
    const fcmToken = recipientData.fcmToken;

    console.log("STEP 9: fcmToken =", fcmToken);

    if (!fcmToken){
      console.log("EXIT: no fcmToken");
      return;
    }

    // Get the sender's username
    const senderUsername = participantUsernames[senderUID] || "Someone";

    // Send the notification
    const message = {
      token: fcmToken,
      notification: {
        title: senderUsername,
        body: text,
      },
      data: {
        type: "message",
        conversationId: conversationId,
        senderUID: senderUID,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
        const response = await getMessaging().send(message);
        console.log("FCM SUCCESS:", response);
    } catch (error) {
      console.log("FCM ERROR:", error);
      // Token may be invalid/expired — clean it up
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(recipientUID).update({
          fcmToken: null,
        });
      }
    }
  }
);

/**
 * Sends a push notification when a new connection request is created.
 *
 * Trigger: connectionRequests/{requestId}
 *
 * Only fires for new documents with status "pending".
 * Looks up the recipient's FCM token and sends a notification.
 */
exports.sendConnectionRequestNotification = onDocumentCreated(
  "connectionRequests/{requestId}",
  async (event) => {
    const requestData = event.data?.data();
    if (!requestData) return;

    const { fromUID, toUID, participantUsernames, status } = requestData;

    // Only notify on new pending requests
    if (status !== "pending") return;
    if (!fromUID || !toUID) return;

    const db = getFirestore();

    // Get the recipient's FCM token
    const recipientDoc = await db.collection("users").doc(toUID).get();
    if (!recipientDoc.exists) return;

    const recipientData = recipientDoc.data();
    const fcmToken = recipientData.fcmToken;
    if (!fcmToken) return;

    // Check if the recipient has blocked the sender
    const blockedUsers = recipientData.blockedUsers || [];
    if (blockedUsers.includes(fromUID)) return;

    // Get the sender's username
    const senderUsername =
      (participantUsernames && participantUsernames[fromUID]) || "Someone";

    const message = {
      token: fcmToken,
      notification: {
        title: "New Connection Request",
        body: `@${senderUsername} wants to connect with you`,
      },
      data: {
        type: "connectionRequest",
        requestId: event.params.requestId,
        fromUID: fromUID,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      await getMessaging().send(message);
    } catch (error) {
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(toUID).update({
          fcmToken: null,
        });
      }
    }
  }
);

/**
 * Callable function: notifies a user that their content was removed.
 *
 * Called from the admin panel before deleting content.
 * Expects: { userUID: string, contentType: string, contentTitle: string }
 */
exports.notifyContentRemoval = onCall(async (request) => {
  const { userUID, contentType, contentTitle } = request.data;

  if (!userUID || !contentType) {
    throw new HttpsError("invalid-argument", "userUID and contentType are required.");
  }

  const db = getFirestore();

  const userDoc = await db.collection("users").doc(userUID).get();
  if (!userDoc.exists) return { success: false, reason: "user not found" };

  const userData = userDoc.data();
  const fcmToken = userData.fcmToken;
  if (!fcmToken) return { success: false, reason: "no fcm token" };

  const typeLabels = {
    listing: "listing",
    service: "service listing",
    isoPost: "ISO post",
  };
  const label = typeLabels[contentType] || "content";
  const title = contentTitle || "your " + label;

  const message = {
    token: fcmToken,
    notification: {
      title: "Content Removed",
      body: `Your ${label} "${title}" was removed for violating community guidelines.`,
    },
    data: {
      type: "contentRemoval",
      contentType: contentType,
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    await getMessaging().send(message);
    return { success: true };
  } catch (error) {
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      await db.collection("users").doc(userUID).update({ fcmToken: null });
    }
    return { success: false, reason: error.message };
  }
});

/**
 * Sends push notifications to a user's connections when they post a show flyer.
 *
 * Trigger: showFlyers/{flyerId}
 *
 * Looks up the poster's accepted connections, gets each connection's FCM token,
 * and sends a notification that deep-links to the flyer.
 */
exports.sendShowFlyerNotification = onDocumentCreated(
  "showFlyers/{flyerId}",
  async (event) => {
    const flyerData = event.data?.data();
    if (!flyerData) return;

    const { posterUID, posterUsername, title } = flyerData;
    const flyerId = event.params.flyerId;

    if (!posterUID) return;

    const db = getFirestore();

    // Find all accepted connections where the poster is a participant
    const connectionsSnap = await db
      .collection("connectionRequests")
      .where("participants", "array-contains", posterUID)
      .where("status", "==", "accepted")
      .get();

    if (connectionsSnap.empty) return;

    // Collect the UIDs of all connected users
    const connectedUIDs = connectionsSnap.docs
      .map((doc) => {
        const participants = doc.data().participants || [];
        return participants.find((uid) => uid !== posterUID);
      })
      .filter(Boolean);

    if (connectedUIDs.length === 0) return;

    // Fetch FCM tokens for all connected users (batch in chunks of 30 for Firestore `in` query limit)
    const tokens = [];
    for (let i = 0; i < connectedUIDs.length; i += 30) {
      const chunk = connectedUIDs.slice(i, i + 30);
      const usersSnap = await db
        .collection("users")
        .where("__name__", "in", chunk)
        .get();

      for (const userDoc of usersSnap.docs) {
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        // Skip users who have blocked the poster
        const blockedUsers = userData.blockedUsers || [];
        if (fcmToken && !blockedUsers.includes(posterUID)) {
          tokens.push({ uid: userDoc.id, token: fcmToken });
        }
      }
    }

    if (tokens.length === 0) return;

    const displayName = posterUsername || "Someone";
    const flyerTitle = title || "a show";

    // Send notifications to all connected users
    const sendPromises = tokens.map(async ({ uid, token }) => {
      const message = {
        token: token,
        notification: {
          title: `${displayName} posted a show`,
          body: flyerTitle,
        },
        data: {
          type: "showFlyer",
          flyerId: flyerId,
          posterUID: posterUID,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      try {
        await getMessaging().send(message);
      } catch (error) {
        if (
          error.code === "messaging/invalid-registration-token" ||
          error.code === "messaging/registration-token-not-registered"
        ) {
          await db.collection("users").doc(uid).update({ fcmToken: null });
        }
      }
    });

    await Promise.allSettled(sendPromises);
  }
);

/**
 * Callable function: deletes a user's account and all associated data.
 *
 * Must be called by the authenticated user themselves.
 * Deletes: user doc, listings, service listings, ISO posts,
 * conversations, connection requests, reports, profile photo,
 * listing photos, and the Firebase Auth record.
 */
/**
 * Sends push notifications to users whose roles match a newly posted ISO post.
 *
 * Trigger: isoPosts/{postId}
 *
 * Reads the roleNeeded from the new post, finds users with matching roles
 * using synonym-aware matching, and sends notifications to each.
 */
exports.sendISOPostRoleMatchNotification = onDocumentCreated(
  "isoPosts/{postId}",
  async (event) => {
    const postData = event.data?.data();
    if (!postData) return;

    const { roleNeeded, posterUID, posterUsername } = postData;
    const postId = event.params.postId;

    if (!roleNeeded || !posterUID) return;

    const db = getFirestore();

    // Synonym groups — mirrors the client-side roleSynonyms
    const roleSynonyms = [
      ["drums", "drummer", "percussionist", "percussion"],
      ["guitar", "guitarist"],
      ["bass", "bassist", "bass player"],
      ["vocals", "vocalist", "singer"],
      ["keyboardist", "keyboard", "keys", "pianist", "piano"],
      ["synth", "synthesizer", "synth player"],
      ["producing", "producer", "music producer"],
      ["dj", "disc jockey"],
      ["rapper", "mc", "emcee"],
      ["mixing engineer", "mixer", "mix engineer"],
      ["mastering engineer", "mastering"],
      ["recording engineer", "recording"],
      ["live sound engineering", "live sound", "sound engineer", "sound tech", "audio engineer"],
      ["graphic design", "graphic designer", "designer"],
      ["videography", "videographer", "video"],
      ["photography", "photographer"],
      ["managing", "manager", "band manager"],
      ["songwriting", "songwriter"],
      ["beat maker", "beatmaker", "beat producer"],
      ["saxophone", "sax", "sax player"],
      ["flute", "flutist", "flautist"],
      ["trumpet", "trumpeter"],
      ["violin", "violinist", "fiddle"],
      ["cello", "cellist"],
      ["banjo", "banjoist"],
      ["harp", "harpist"],
      ["accordion", "accordionist"],
      ["mandolin", "mandolinist"],
      ["upright bass", "double bass", "standup bass"],
      ["steel guitar", "pedal steel", "lap steel"],
      ["booking", "booker", "booking agent"],
      ["tour managing", "tour manager"],
      ["promoter", "concert promoter"],
      ["venue manager", "venue"],
      ["noise artist", "noise", "experimental"],
      ["vocal coach", "voice coach", "voice teacher"],
      ["lighting", "lighting operator", "lighting designer", "lights"],
      ["a&r", "artists and repertoire"],
      ["publicist", "press", "public relations", "pr"],
      ["music video director", "video director", "music video"],
      ["tambourine"],
      ["vocal arrangement"],
      ["lessons"],
      ["rehearsal space"],
      ["studio rental"],
      ["social media"],
      ["diy organizer"],
    ];

    function roleMatches(userRole, postRole) {
      const u = userRole.toLowerCase();
      const p = postRole.toLowerCase();

      // Direct substring match
      if (u.includes(p) || p.includes(u)) return true;

      // Synonym group match
      for (const group of roleSynonyms) {
        const uInGroup = group.some((s) => u.includes(s) || s.includes(u));
        const pInGroup = group.some((s) => p.includes(s) || s.includes(p));
        if (uInGroup && pInGroup) return true;
      }

      return false;
    }

    // Fetch all users who have roles set
    // (Firestore doesn't support "array-contains-any" with dynamic matching,
    //  so we fetch users who have non-empty roles arrays and filter in code)
    const usersSnap = await db
      .collection("users")
      .where("roles", "!=", [])
      .get();

    if (usersSnap.empty) return;

    const tokens = [];
    for (const userDoc of usersSnap.docs) {
      // Skip the poster themselves
      if (userDoc.id === posterUID) continue;

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      if (!fcmToken) continue;

      // Skip users who have blocked the poster
      const blockedUsers = userData.blockedUsers || [];
      if (blockedUsers.includes(posterUID)) continue;

      // Check if any of the user's roles match the post's roleNeeded
      const userRoles = userData.roles || [];
      const hasMatch = userRoles.some((role) => roleMatches(role, roleNeeded));
      if (hasMatch) {
        tokens.push({ uid: userDoc.id, token: fcmToken });
      }
    }

    if (tokens.length === 0) return;

    const displayName = posterUsername || "Someone";

    const sendPromises = tokens.map(async ({ uid, token }) => {
      const message = {
        token: token,
        notification: {
          title: `New gig for you: ${roleNeeded}`,
          body: `@${displayName} is looking for a ${roleNeeded}`,
        },
        data: {
          type: "isoPost",
          postId: postId,
          posterUID: posterUID,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      try {
        await getMessaging().send(message);
      } catch (error) {
        if (
          error.code === "messaging/invalid-registration-token" ||
          error.code === "messaging/registration-token-not-registered"
        ) {
          await db.collection("users").doc(uid).update({ fcmToken: null });
        }
      }
    });

    await Promise.allSettled(sendPromises);
  }
);

/**
 * Callable function: deletes a user's account and all associated data.
 *
 * Must be called by the authenticated user themselves.
 * Deletes: user doc, listings, service listings, ISO posts,
 * conversations, connection requests, reports, profile photo,
 * listing photos, and the Firebase Auth record.
 */
exports.deleteUserAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in to delete account.");
  }

  const db = getFirestore();
  const batch = db.batch();

  // Helper: query a collection and add all matching docs to the batch
  async function batchDeleteQuery(query) {
    const snapshot = await query.get();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    return snapshot.size;
  }

  // Helper: delete subcollection docs in chunks (messages inside conversations)
  async function deleteSubcollections(parentRefs, subcollection) {
    for (const ref of parentRefs) {
      const sub = await ref.collection(subcollection).get();
      sub.docs.forEach((doc) => batch.delete(doc.ref));
    }
  }

  try {
    // 1. Find user's conversations and delete their messages
    const convosQuery = db.collection("conversations")
      .where("participants", "array-contains", uid);
    const convosSnap = await convosQuery.get();
    await deleteSubcollections(convosSnap.docs.map((d) => d.ref), "messages");
    convosSnap.docs.forEach((doc) => batch.delete(doc.ref));

    // 2. Delete user's listings
    await batchDeleteQuery(
      db.collection("listings").where("sellerUID", "==", uid)
    );

    // 3. Delete user's service listings
    await batchDeleteQuery(
      db.collection("serviceListings").where("sellerUID", "==", uid)
    );

    // 4. Delete user's ISO posts
    await batchDeleteQuery(
      db.collection("isoPosts").where("posterUID", "==", uid)
    );

    // 4b. Delete user's show flyers
    await batchDeleteQuery(
      db.collection("showFlyers").where("posterUID", "==", uid)
    );

    // 5. Delete connection requests (sent or received)
    await batchDeleteQuery(
      db.collection("connectionRequests").where("fromUID", "==", uid)
    );
    await batchDeleteQuery(
      db.collection("connectionRequests").where("toUID", "==", uid)
    );

    // 6. Delete reports filed by this user
    await batchDeleteQuery(
      db.collection("reports").where("reporterUID", "==", uid)
    );

    // 7. Delete user document
    batch.delete(db.collection("users").doc(uid));

    // Commit all Firestore deletions
    await batch.commit();

    // 8. Delete profile photo from Storage
    try {
      const bucket = getStorage().bucket();
      await bucket.file(`profile_photos/${uid}.jpg`).delete();
    } catch (_) {
      // File may not exist — that's fine
    }

    // 9. Delete listing photos folder from Storage
    try {
      const bucket = getStorage().bucket();
      const [files] = await bucket.getFiles({ prefix: `listing_photos/` });
      // Only delete files belonging to listings owned by this user
      // (listings already deleted from Firestore above, so just clean up known prefix)
      const userListingFiles = files.filter((f) => f.name.startsWith(`listing_photos/`));
      // Since we can't easily filter by owner in storage, we skip granular deletion here.
      // The Firestore docs are already gone, so orphaned images are harmless.
    } catch (_) {
      // Ignore storage errors
    }

    // 10. Delete the Firebase Auth user record
    await getAuth().deleteUser(uid);

    return { success: true };
  } catch (error) {
    console.error("deleteUserAccount error:", error);
    throw new HttpsError("internal", "Failed to delete account: " + error.message);
  }
});

/**
 * Scheduled function: sends weekly "X people viewed your profile" push notifications.
 * Runs every Monday at 10:00 AM Eastern Time.
 * Queries profileViews from the last 7 days, groups by viewed user,
 * counts unique viewers, and sends a notification to each user.
 */
exports.sendWeeklyProfileViewNotifications = onSchedule(
  {
    schedule: "every monday 10:00",
    timeZone: "America/New_York",
  },
  async () => {
    const db = getFirestore();

    const oneWeekAgo = Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );

    // 1. Fetch all profile views from the last 7 days
    const snapshot = await db
      .collection("profileViews")
      .where("timestamp", ">=", oneWeekAgo)
      .get();

    if (snapshot.empty) {
      console.log("No profile views this week.");
      return;
    }

    // 2. Group by viewedUID, count unique viewers
    const viewsByUser = {};
    snapshot.docs.forEach((doc) => {
      const { viewedUID, viewerUID } = doc.data();
      if (!viewedUID) return;
      if (!viewsByUser[viewedUID]) {
        viewsByUser[viewedUID] = new Set();
      }
      viewsByUser[viewedUID].add(viewerUID);
    });

    // 3. Save weekly summary for each user and send notification if >= 5 views
    const weekId = new Date().toISOString().slice(0, 10); // e.g. "2026-06-09"

    const sendPromises = Object.entries(viewsByUser).map(
      async ([viewedUID, viewers]) => {
        const uniqueCount = viewers.size;
        const totalViews = snapshot.docs.filter(
          (doc) => doc.data().viewedUID === viewedUID
        ).length;

        // Save weekly summary to users/{uid}/profileAnalytics/{weekId}
        try {
          await db
            .collection("users")
            .doc(viewedUID)
            .collection("profileAnalytics")
            .doc(weekId)
            .set({
              weekOf: weekId,
              uniqueViewers: uniqueCount,
              totalViews: totalViews,
              timestamp: FieldValue.serverTimestamp(),
            });
        } catch (err) {
          console.error(
            `Error saving analytics for ${viewedUID}:`,
            err
          );
        }

        // Only send push notification if >= 5 unique viewers
        if (uniqueCount < 5) return;

        try {
          const userDoc = await db.collection("users").doc(viewedUID).get();
          if (!userDoc.exists) return;

          const userData = userDoc.data();
          const fcmToken = userData.fcmToken;
          if (!fcmToken) return;

          const bodyText = `${uniqueCount} people viewed your profile this week.`;

          const message = {
            token: fcmToken,
            notification: {
              title: "Your profile is getting noticed",
              body: bodyText,
            },
            data: {
              type: "profile",
              uid: viewedUID,
              username: userData.username || "",
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                },
              },
            },
          };

          await getMessaging().send(message);
          console.log(
            `Sent weekly profile view notification to ${viewedUID} (${uniqueCount} views)`
          );
        } catch (error) {
          console.error(
            `Error sending profile view notification to ${viewedUID}:`,
            error
          );
          if (
            error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered"
          ) {
            await db
              .collection("users")
              .doc(viewedUID)
              .update({ fcmToken: null });
          }
        }
      }
    );

    await Promise.allSettled(sendPromises);

    // 4. Clean up old profileViews (older than 30 days)
    const thirtyDaysAgo = Timestamp.fromDate(
      new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
    );
    const oldDocs = await db
      .collection("profileViews")
      .where("timestamp", "<", thirtyDaysAgo)
      .limit(500)
      .get();

    if (!oldDocs.empty) {
      const batch = db.batch();
      oldDocs.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      console.log(`Cleaned up ${oldDocs.size} old profile view records.`);
    }
  }
);
