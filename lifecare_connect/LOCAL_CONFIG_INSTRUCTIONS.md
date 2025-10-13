# 🔐 Local Development Configuration

## NEVER COMMIT SENSITIVE KEYS TO VERSION CONTROL!

### For Local Development:

1. **Create a local config file** (NOT tracked by git):
   ```bash
   cp web/env-config.js web/env-config.local.js
   ```

2. **Edit `web/env-config.local.js`** with your actual keys:
   ```javascript
   window.ENV_FIREBASE_API_KEY = 'your_actual_browser_key_here';
   window.ENV_FIREBASE_SENDER_ID = 'your_actual_sender_id_here';
   window.ENV_FIREBASE_APP_ID = 'your_actual_app_id_here';
   ```

3. **Include in your HTML** (for local testing):
   ```html
   <script src="env-config.local.js"></script>
   ```

### For Production Deployment:

Use Firebase Hosting environment configuration or build-time environment variables.

### Security Rules:
- ✅ `env-config.local.js` is in .gitignore (never committed)
- ✅ Template files only contain placeholders
- ✅ Real keys are only in local/production environment

### Getting Your API Keys:
1. Go to: https://console.cloud.google.com/apis/credentials
2. Generate NEW keys (old ones should be revoked)
3. Add domain restrictions for security
4. Use in local configuration only