const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

/**
 * Sends a push notification when a new message is created in a conversation.
 *
 * Trigger: conversations/{conversationId}/messages/{messageId}
 *
 * Looks up the recipient's FCM token from their user document and sends
 * a notification with the sender's username and message text.
 */
exports.sendMessageNotification = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) return;

    const { senderUID, text } = messageData;
    const conversationId = event.params.conversationId;

    if (!senderUID || !text) return;

    const db = getFirestore();

    // Get the conversation to find participants
    const conversationDoc = await db
      .collection("conversations")
      .doc(conversationId)
      .get();

    if (!conversationDoc.exists) return;

    const conversationData = conversationDoc.data();
    const participants = conversationData.participants || [];
    const participantUsernames = conversationData.participantUsernames || {};

    // Find the recipient (the participant who is NOT the sender)
    const recipientUID = participants.find((uid) => uid !== senderUID);
    if (!recipientUID) return;

    // Get the recipient's FCM token
    const recipientDoc = await db.collection("users").doc(recipientUID).get();
    if (!recipientDoc.exists) return;

    const recipientData = recipientDoc.data();
    const fcmToken = recipientData.fcmToken;
    if (!fcmToken) return;

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
      await getMessaging().send(message);
    } catch (error) {
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
