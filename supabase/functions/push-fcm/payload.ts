/** Keep private quest/report text out of FCM and APNs. */
export function buildFcmMessage(payload: {
  token: string;
  platform?: string;
  category: string;
  refId?: string | null;
  id?: number;
}) {
  return {
    token: payload.token,
    data: {
      category: payload.category,
      refId: payload.refId ?? "",
      id: String(payload.id ?? ""),
    },
    android: { priority: "high" },
    apns: payload.platform === "ios"
      ? {
        // A silent background ping cannot reliably notify a suspended app.
        // iOS presents this fixed, non-personal text without running Dart.
        headers: { "apns-priority": "10", "apns-push-type": "alert" },
        payload: {
          aps: {
            alert: { title: "Aura Quest", body: "New quest activity. Open Aura Quest to see what's happening." },
            sound: "default",
          },
        },
      }
      : {
        headers: { "apns-priority": "5", "apns-push-type": "background" },
        payload: { aps: { "content-available": 1 } },
      },
  };
}
