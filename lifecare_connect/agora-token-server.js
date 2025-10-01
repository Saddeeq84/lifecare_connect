const express = require('express');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const app = express();
const APP_ID = 'a105462abb1746fc9075e6c2f81f5ac5';
const APP_CERTIFICATE = '740decce67ba417abc4a25458802d1e7'; // Use primary certificate

app.get('/agora-token', (req, res) => {
  const channelName = req.query.channelName; // appointment ID from your app
  const uid = req.query.uid || 0;
  const role = RtcRole.PUBLISHER;
  const expireTime = 3600; // 1 hour

  if (!channelName) {
    return res.status(400).json({ error: 'Missing channelName' });
  }

  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID, APP_CERTIFICATE, channelName, uid, role, expireTime
  );
  res.json({ token });
});

app.listen(3000, () => console.log('Agora token server running on port 3000'));
