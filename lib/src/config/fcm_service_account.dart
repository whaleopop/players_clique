/// Firebase Service Account credentials for sending FCM notifications directly.
///
/// HOW TO GET THIS:
/// 1. Go to https://console.firebase.google.com → project "players-clique"
/// 2. Project Settings (gear icon) → Service accounts tab
/// 3. Click "Generate new private key" → download JSON file
/// 4. Copy the values from the JSON into this map below.
///
/// ⚠️  Keep this file out of public repos (.gitignore it if needed).
const Map<String, dynamic> fcmServiceAccount = {
  "type": "service_account",
  "project_id": "players-clique",
  "private_key_id": "PASTE_private_key_id_HERE",
  "private_key":
      "PASTE_private_key_HERE",
  "client_email": "PASTE_client_email_HERE",
  "client_id": "PASTE_client_id_HERE",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url":
      "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "PASTE_client_x509_cert_url_HERE",
  "universe_domain": "googleapis.com",
};
