const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// ─────────────────────────────────────────────────────────────────────────────
// 1. Notify receiver when a new chat message is sent
// ─────────────────────────────────────────────────────────────────────────────
exports.onNewMessage = onDocumentCreated(
  "chat_rooms/{chatRoomId}/messages/{msgId}",
  async (event) => {
    const data = event.data.data();
    const receiverId = data.receiverId;
    const senderId = data.senderId;
    const msgType = data.type ?? "text";

    if (!receiverId || !senderId || receiverId === senderId) return;

    // Get receiver FCM token
    const receiverSnap = await db.collection("users").doc(receiverId).get();
    const fcmToken = receiverSnap.data()?.fcmToken;
    if (!fcmToken) return;

    // Get sender display name
    const senderSnap = await db.collection("users").doc(senderId).get();
    const senderName = senderSnap.data()?.fio ?? "Кто-то";

    // Build notification body
    let body;
    if (msgType === "image") body = "📷 Фото";
    else if (msgType === "sticker") body = "🎉 Стикер";
    else body = data.message ?? "";

    if (body.length > 120) body = body.substring(0, 120) + "…";

    try {
      await messaging.send({
        token: fcmToken,
        notification: { title: senderName, body },
        data: {
          type: "message",
          chatRoomId: event.params.chatRoomId,
          senderId,
        },
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
      });
    } catch (err) {
      // Token might be stale — clear it
      if (err.code === "messaging/registration-token-not-registered") {
        await db
          .collection("users")
          .doc(receiverId)
          .update({ fcmToken: null });
      }
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. Notify friends when a user creates a new post
// ─────────────────────────────────────────────────────────────────────────────
exports.onNewPost = onDocumentCreated(
  "posts/{userId}/post/{postId}",
  async (event) => {
    const authorId = event.params.userId;
    const data = event.data.data();

    // Get author info + friends list
    const authorSnap = await db.collection("users").doc(authorId).get();
    const authorData = authorSnap.data();
    if (!authorData) return;

    const authorName = authorData.fio ?? "Пользователь";
    const friends = authorData.friends ?? [];
    if (friends.length === 0) return;

    // Build notification body from post
    const postTitle = data.namePost ?? "";
    const postDesc = data.descPost ?? "";
    let body = postTitle || postDesc;
    if (body.length > 120) body = body.substring(0, 120) + "…";
    if (!body) body = "Новый пост";

    // Collect FCM tokens of all friends in batches
    const batchSize = 10;
    for (let i = 0; i < friends.length; i += batchSize) {
      const batch = friends.slice(i, i + batchSize);
      const snaps = await Promise.all(
        batch.map((uid) => db.collection("users").doc(uid).get())
      );

      const tokens = snaps
        .map((s) => s.data()?.fcmToken)
        .filter((t) => typeof t === "string" && t.length > 0);

      if (tokens.length === 0) continue;

      try {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: `${authorName} опубликовал(а)`,
            body,
          },
          data: {
            type: "post",
            postId: event.params.postId,
            authorId,
          },
          android: { priority: "normal" },
          apns: { payload: { aps: { sound: "default" } } },
        });
      } catch (_) {
        // Ignore individual send errors
      }
    }
  }
);
