// Simple Agora token server (Node.js/Express)
// Place your App ID and App Certificate in environment variables for security
const express = require('express');
const cors = require('cors');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');
require('dotenv').config();

const app = express();
app.use(cors());

const APP_ID = process.env.AGORA_APP_ID;
const APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE;

app.get('/rtcToken', (req, res) => {
  const channelName = req.query.channelName;
  if (!channelName) {
    return res.status(400).json({ 'error': 'channelName is required' });
  }
  const uid = req.query.uid || 0;
  const role = req.query.role === 'publisher' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;
  const expireTime = parseInt(req.query.expireTime, 10) || 3600;
  const currentTime = Math.floor(Date.now() / 1000);
  const privilegeExpireTime = currentTime + expireTime;

  if (!APP_ID || !APP_CERTIFICATE) {
    return res.status(500).json({ 'error': 'Agora credentials not set' });
  }

  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID, APP_CERTIFICATE, channelName, uid, role, privilegeExpireTime
  );
  return res.json({ 'rtcToken': token });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Agora Token Server running on port ${PORT}`);
});
