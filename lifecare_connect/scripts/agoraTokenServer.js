const express = require('express');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const app = express();
const port = 3000;

// Agora credentials
const APP_ID = 'a105462abb1746fc9075e6c2f81f5ac5';
const APP_CERTIFICATE = '740decce67ba417abc4a25458802d1e7';

app.get('/agora-token', (req, res) => {
  const channelName = req.query.channelName;
  const uid = req.query.uid || 0;
  const role = RtcRole.PUBLISHER;
  const expireTime = 3600; // 1 hour

  if (!channelName) {
    return res.status(400).json({ error: 'channelName is required' });
  }

  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpireTs = currentTimestamp + expireTime;

  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID, APP_CERTIFICATE, channelName, uid, role, privilegeExpireTs
  );

  res.json({ token });
});

app.listen(port, () => {
  console.log(`Agora token server running on port ${port}`);
});
