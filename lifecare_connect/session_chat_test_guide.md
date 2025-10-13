# Session-Specific Private Chat Test Guide

## 🔒 **New Private Chat Features**

### **Session-Based Privacy**
- ✅ **Private to session participants only** - No outsiders can see messages
- ✅ **Real-time session verification** - Only active participants can send messages  
- ✅ **Secure data structure** - Messages stored in session-specific collections
- ✅ **Enhanced Firestore rules** - Database-level security for chat privacy

## 🧪 **Testing URLs**

### **Session A - Doctor & Patient Consultation**
```
Doctor: https://lifecare-connect.web.app/agora_call/?channelName=session_A_test&type=video&userName=Dr.Smith&userRole=doctor&uid=11111

Patient: https://lifecare-connect.web.app/agora_call/?channelName=session_A_test&type=video&userName=Mary&userRole=patient&uid=22222
```

### **Session B - Different Consultation (Should be completely separate)**
```
Doctor: https://lifecare-connect.web.app/agora_call/?channelName=session_B_test&type=video&userName=Dr.Johnson&userRole=doctor&uid=33333

Patient: https://lifecare-connect.web.app/agora_call/?channelName=session_B_test&type=video&userName=John&userRole=patient&uid=44444
```

## 📋 **Privacy Test Scenarios**

### **Test 1: Session Isolation**
1. **Join Session A**: Doctor and Patient join `session_A_test`
2. **Join Session B**: Different Doctor and Patient join `session_B_test` 
3. **Send messages in both**: Each session sends different messages
4. **Verify isolation**: Session A participants should NEVER see Session B messages
5. **Expected result**: Each session has completely separate chat history

### **Test 2: Participant-Only Access**
1. **Join Session A**: Doctor joins and sends message
2. **Open outsider tab**: Open `session_A_test` URL with different UID (55555)
3. **Try to join as outsider**: Third person tries to access the session
4. **Verify access control**: Outsider should not see previous messages
5. **Expected result**: Only legitimate session participants see chat history

### **Test 3: Real-time Session Validation**
1. **Join session**: Both participants join and start chatting
2. **One leaves call**: Doctor clicks "Leave Only" 
3. **Try to send message**: Doctor tries to send message after leaving
4. **Verify blocking**: Should get "Join the call to send messages" error
5. **Expected result**: Chat disabled when not actively in session

### **Test 4: Session End & Restart**
1. **Active chat session**: Participants chatting normally
2. **End call completely**: One participant clicks "End for All"
3. **Check chat access**: Both should have chat disabled after session ends
4. **Restart session**: Use restart button to create new session
5. **Verify fresh chat**: New session should start with clean chat (previous messages not visible)

## 🔍 **Visual Indicators to Check**

### **Chat Header**
- Should show: **"🔒 Private Chat"**
- Subtitle: **"Session participants only"**

### **Chat Input States**
- **When in session**: Input enabled, placeholder "Type your message..."
- **When not in session**: Input disabled, placeholder "Join the call to send messages"
- **Send button**: Grayed out when disabled, normal when enabled

### **Welcome Message**
- **Session-specific**: "Welcome [UserName]! This is your private consultation chat."
- **Privacy notice**: "🔐 This chat is private to this session only..."

## 🔐 **Security Features Implemented**

### **Database Level**
- **Session-specific collections**: `/sessionChats/{sessionId}/messages/`
- **Participant validation**: Messages tied to specific session IDs
- **Access control rules**: Firestore rules prevent cross-session access
- **Query limits**: Max 100 messages per query to prevent abuse

### **Client-side Security**
- **Session validation**: Real-time checks if user is active participant
- **Participant tracking**: Session record tracks who's currently active
- **Input state management**: Chat disabled when not properly joined
- **Message verification**: Session ID validation before sending

### **Privacy Protection**
- **No global chat visibility**: Messages never visible outside session
- **Automatic cleanup**: Participant status updates when leaving
- **Session isolation**: Each channel completely separate from others
- **Real-time validation**: Continuous checks for legitimate session access

## 🚀 **Expected Behavior**

### ✅ **What Should Work**
1. **Private messaging** between session participants only
2. **Real-time updates** within the same session
3. **Session isolation** - no cross-contamination between different calls
4. **Access control** - chat disabled when not in active session
5. **Clean session restart** - fresh chat after restart

### ❌ **What Should Be Blocked**
1. **Cross-session visibility** - Session A can't see Session B messages
2. **Outsider access** - Non-participants can't see session messages
3. **Post-session messaging** - Can't send messages after leaving call
4. **Unauthorized access** - Database rules prevent improper queries

## 🐛 **Debugging Tools**

### **Browser Console Logs**
Look for these emoji indicators:
- `💬 Received session chat snapshot` - Chat messages loading
- `📨 Added session message from:` - New message received  
- `✅ Session record created/updated` - Session properly initialized
- `🔐 This chat is private to this session only` - Privacy notice shown

### **Firebase Console**
Check these collections:
- `/sessionChats/{sessionId}/` - Session-specific chat data
- `/callSessions/{sessionId}` - Session participant tracking
- `/chatMessages/` - Legacy backup (should have sessionReference)

## 🎯 **Success Criteria**

- ✅ **Complete session isolation**: Different sessions can't see each other's messages
- ✅ **Participant-only access**: Only active session members can send/receive
- ✅ **Real-time validation**: Chat access tied to actual session participation  
- ✅ **Clean UI states**: Clear visual indicators for chat availability
- ✅ **Secure data storage**: Messages properly organized by session with security rules

The chat system now provides **medical-grade privacy** suitable for confidential healthcare consultations! 🏥