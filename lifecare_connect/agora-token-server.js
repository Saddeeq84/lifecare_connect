const express = require('express');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const app = express();
const APP_ID = process.env.AGORA_APP_ID;
const APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE;


app.get('/agora-token', (req, res) => {
  const channelName = req.query.channelName;
  const uid = req.query.uid || 0;
  const role = RtcRole.PUBLISHER;
  const expireTime = 3600; // 1 hour

  if (!APP_ID || !APP_CERTIFICATE) {
    return res.status(500).json({ error: 'Agora credentials not set' });
  }
  if (!channelName) {
    return res.status(400).json({ error: 'Missing channelName' });
  }

  const expireTimestamp = Math.floor(Date.now() / 1000) + expireTime;
  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID, APP_CERTIFICATE, channelName, uid, role, expireTimestamp
  );
  res.json({ rtcToken: token });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Agora token server running on port ${PORT}`));
