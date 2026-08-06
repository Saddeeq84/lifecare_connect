const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { defineSecret } = require('firebase-functions/params');

// Define secrets for Termii SMS
const TERMII_API_KEY = defineSecret('TERMII_API_KEY');
const TERMII_SENDER_ID = defineSecret('TERMII_SENDER_ID');

/**
 * Helper function to send SMS via Termii
 * For appointment notifications (non-OTP, uses generic channel)
 */
async function sendSMS(phoneNumber, message) {
  try {
    // Get Termii credentials from secrets
    const termiiApiKey = TERMII_API_KEY.value();
    const senderId = TERMII_SENDER_ID.value();
    
    if (!termiiApiKey) {
      console.error('Termii API key not configured');
      return Promise.reject(new Error('SMS service not configured'));
    }
    
    // Validate phone number format (should be in +234XXXXXXXXXX format)
    let formattedPhone = phoneNumber;
    if (!phoneNumber.startsWith('+')) {
      // Assume Nigerian number if no country code
      formattedPhone = phoneNumber.startsWith('0') 
        ? '+234' + phoneNumber.substring(1) 
        : '+234' + phoneNumber;
    }
    
    // Send SMS via Termii using DND channel (same as OTP)
    const requestData = {
      to: formattedPhone,
      from: senderId,
      sms: message,
      type: 'plain',
      channel: 'dnd', // Use 'dnd' channel like OTP function
      api_key: termiiApiKey,
    };
    
    console.log('📤 Sending SMS with channel:', requestData.channel, 'to:', formattedPhone);
    const response = await axios.post('https://api.ng.termii.com/api/sms/send', requestData);
    
    console.log('SMS sent successfully to:', formattedPhone);
    return response.data;
    
  } catch (error) {
    console.error('Error sending SMS via Termii:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * Helper function to get user phone number from Firestore
 */
async function getUserPhone(userId, userType) {
  try {
    const db = admin.firestore();
    let phone = null;
    
    // Try users collection first
    console.log(`🔍 Checking users collection for ${userId}...`);
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      console.log(`📱 User data for ${userId}:`, {
        phoneNumber: userData.phoneNumber,
        phone: userData.phone,
        mobile: userData.mobile,
        contactNumber: userData.contactNumber,
      });
      phone = userData.phoneNumber || userData.phone || userData.mobile || userData.contactNumber;
    }
    
    // Try chw_providers collection
    if (!phone) {
      console.log(`🔍 Checking chw_providers collection for ${userId}...`);
      const chwProviderDoc = await db.collection('chw_providers').doc(userId).get();
      if (chwProviderDoc.exists) {
        const chwProviderData = chwProviderDoc.data();
        console.log(`📱 CHW Provider data for ${userId}:`, {
          phoneNumber: chwProviderData.phoneNumber,
          phone: chwProviderData.phone,
          mobile: chwProviderData.mobile,
          contactNumber: chwProviderData.contactNumber,
        });
        phone = chwProviderData.phoneNumber || chwProviderData.phone || chwProviderData.mobile || chwProviderData.contactNumber;
      }
    }
    
    // Try chw_patients collection
    if (!phone) {
      console.log(`🔍 Checking chw_patients collection for ${userId}...`);
      const chwPatientDoc = await db.collection('chw_patients').doc(userId).get();
      if (chwPatientDoc.exists) {
        const chwPatientData = chwPatientDoc.data();
        console.log(`📱 CHW Patient data for ${userId}:`, {
          phoneNumber: chwPatientData.phoneNumber,
          phone: chwPatientData.phone,
          mobile: chwPatientData.mobile,
          contactNumber: chwPatientData.contactNumber,
        });
        phone = chwPatientData.phoneNumber || chwPatientData.phone || chwPatientData.mobile || chwPatientData.contactNumber;
      }
    }
    
    if (!phone) {
      console.log(`❌ No phone number found for user: ${userId} (${userType})`);
      return null;
    }
    
    console.log(`✅ Found phone for ${userId}: ${phone}`);
    return phone;
  } catch (error) {
    console.error('Error getting user phone:', error);
    return null;
  }
}

/**
 * Helper function to send in-app message via Firestore
 */
async function sendInAppMessage({
  senderId,
  senderName,
  senderRole,
  receiverId,
  receiverName,
  receiverRole,
  content,
  type = 'appointment_notification',
  priority = 'normal',
}) {
  try {
    const db = admin.firestore();
    
    // Create or get conversation between sender and receiver
    const participantIds = [senderId, receiverId].sort();
    const conversationId = `${participantIds[0]}_${participantIds[1]}`;
    
    // Check if conversation exists
    const conversationRef = db.collection('messages').doc(conversationId);
    const conversationDoc = await conversationRef.get();
    
    if (!conversationDoc.exists) {
      // Create new conversation
      await conversationRef.set({
        participantIds: [senderId, receiverId],
        participants: [senderId, receiverId],
        participantNames: {
          [senderId]: senderName,
          [receiverId]: receiverName,
        },
        participantRoles: {
          [senderId]: senderRole,
          [receiverId]: receiverRole,
        },
        type: 'direct',
        unreadCounts: { [senderId]: 0, [receiverId]: 1 },
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // Update conversation
      await conversationRef.update({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
        [`unreadCounts.${receiverId}`]: admin.firestore.FieldValue.increment(1),
      });
    }
    
    // Send the message
    await db.collection('messages').add({
      conversationId,
      senderId,
      senderName,
      senderRole,
      receiverId,
      receiverName,
      receiverRole,
      content,
      type,
      isRead: false,
      isDelivered: false,
      status: 'sent',
      priority,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      participants: [senderId, receiverId],
    });
    
    console.log(`✅ In-app message sent from ${senderName} to ${receiverName}`);
  } catch (error) {
    console.error('Error sending in-app message:', error);
    throw error;
  }
}

/**
 * Cloud Function: Triggered when a new appointment is created
 * Sends SMS and in-app notification to the doctor/CHW, and confirmation to patient
 */
exports.onAppointmentBooked = functions
  .runWith({ secrets: [TERMII_API_KEY, TERMII_SENDER_ID] })
  .firestore
  .document('appointments/{appointmentId}')
  .onCreate(async (snap, context) => {
    const appointmentData = snap.data();
    const appointmentId = context.params.appointmentId;
    
    try {
      console.log('New appointment created:', appointmentId);
      
      // Extract appointment details
      const patientId = appointmentData.patientId || appointmentData.patientUid;
      const patientName = appointmentData.patientName || 'Unknown Patient';
      const providerId = appointmentData.providerId;
      const providerName = appointmentData.providerName || 'Doctor';
      const providerType = appointmentData.providerType || 'doctor';
      const department = appointmentData.department || 'General';
      
      // Handle appointmentDate - can be Timestamp, string, or undefined
      let appointmentDate = 'Not specified';
      let formattedDate = '';
      let formattedTime = '';
      try {
        if (appointmentData.appointmentDate?.toDate) {
          // Firestore Timestamp
          const date = appointmentData.appointmentDate.toDate();
          appointmentDate = date.toLocaleDateString('en-NG');
          formattedDate = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
          formattedTime = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
        } else if (typeof appointmentData.appointmentDate === 'string') {
          // ISO string
          const date = new Date(appointmentData.appointmentDate);
          appointmentDate = date.toLocaleDateString('en-NG');
          formattedDate = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
          formattedTime = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
        }
      } catch (e) {
        console.error('Could not format appointment date:', e);
      }
      
      const appointmentTime = appointmentData.appointmentTime || formattedTime || 'Not specified';
      const status = appointmentData.status || 'pending';
      
      // Send notification for ALL pending appointments (facility AND remote patient bookings)
      // - 'pending': Remote patient bookings (direct doctor/CHW appointments)
      // - 'pending_opd_approval': Facility OPD appointments
      // - 'pending_specialist_approval': Facility specialist appointments
      const validStatuses = ['pending', 'pending_opd_approval', 'pending_specialist_approval'];
      
      if (!validStatuses.includes(status)) {
        console.log('Skipping notification for status:', status);
        return null;
      }
      
      if (!providerId) {
        console.error('No providerId found in appointment');
        return null;
      }
      
      // Get provider details for in-app message
      const providerDoc = await admin.firestore().collection('users').doc(providerId).get();
      const providerData = providerDoc.exists ? providerDoc.data() : {};
      const providerFullName = providerData.firstName && providerData.lastName
        ? `${providerData.firstName} ${providerData.lastName}`.trim()
        : providerName;
      const providerRole = providerData.role || 'doctor';
      
      // Determine provider type for phone lookup (doctor or chw)
      const lookupType = providerType.toLowerCase().includes('chw') ? 'chw' : 'doctor';
      
      // Get provider phone number
      const providerPhone = await getUserPhone(providerId, lookupType);
      
      // Compose messages
      const reason = appointmentData.reason || 'General Consultation';
      const facilityName = appointmentData.facilityName;
      
      let smsMessage;
      let inAppMessageProvider;
      if (facilityName) {
        // Facility appointment - include department and facility
        smsMessage = `New Appointment Request\n` +
          `Patient: ${patientName}\n` +
          `Department: ${department}\n` +
          `Facility: ${facilityName}\n` +
          `Date: ${appointmentDate}\n` +
          `Time: ${appointmentTime}\n` +
          `Please review and approve in LifeCare Connect app.`;
        
        inAppMessageProvider = `📅 New Appointment Request\n\n` +
          `Patient: ${patientName}\n` +
          `Department: ${department}\n` +
          `Facility: ${facilityName}\n` +
          `Date: ${formattedDate || appointmentDate}\n` +
          `Time: ${appointmentTime}\n` +
          `Reason: ${reason}\n\n` +
          `Please review and respond to this appointment request in the app.`;
      } else {
        // Remote patient appointment - simpler message
        smsMessage = `New Appointment Request\n` +
          `Patient: ${patientName}\n` +
          `Reason: ${reason}\n` +
          `Date: ${appointmentDate}\n` +
          `Time: ${appointmentTime}\n` +
          `Please review and approve in LifeCare Connect app.`;
        
        inAppMessageProvider = `📅 New Appointment Request\n\n` +
          `Patient: ${patientName}\n` +
          `Reason: ${reason}\n` +
          `Date: ${formattedDate || appointmentDate}\n` +
          `Time: ${appointmentTime}\n\n` +
          `This is a remote consultation request. Please review and respond in the app.`;
      }
      
      // Send SMS to provider (if phone available)
      if (providerPhone) {
        await sendSMS(providerPhone, smsMessage);
        console.log(`✅ SMS notification sent to ${lookupType}:`, providerId);
      } else {
        console.warn(`⚠️ Provider phone number not found for ${lookupType}:`, providerId);
      }
      
      // Send in-app message to provider
      await sendInAppMessage({
        senderId: 'system',
        senderName: 'LifeCare Connect',
        senderRole: 'system',
        receiverId: providerId,
        receiverName: providerFullName,
        receiverRole: providerRole,
        content: inAppMessageProvider,
        type: 'appointment_notification',
        priority: 'high',
      });
      
      // Check if this is a facility-booked appointment (facility patients don't have user accounts)
      const isFacilityBooked = appointmentData.bookedBy === 'medical_records' && 
                               appointmentData.bookedById && 
                               appointmentData.facilityId;
      
      if (isFacilityBooked) {
        // Notify facility staff instead of patient
        const facilityId = appointmentData.facilityId;
        
        // Get facility admins/staff who should be notified
        const facilityUsersSnapshot = await admin.firestore()
          .collection('users')
          .where('facilityId', '==', facilityId)
          .where('role', 'in', ['facility_admin', 'medical_records'])
          .get();
        
        const facilityMessage = `✅ Remote Appointment Booked Successfully!\n\n` +
          `Patient: ${patientName}\n` +
          `Remote Doctor: ${providerName}\n` +
          `Department: ${department}\n` +
          `Date: ${formattedDate || appointmentDate}\n` +
          `Time: ${appointmentTime}\n` +
          `Status: Pending Doctor Approval\n\n` +
          `📋 NEXT STEPS:\n` +
          `• The remote doctor has been notified\n` +
          `• You'll be notified when the doctor responds\n` +
          `• Check "Remote Consultations" tab for status\n\n` +
          `The doctor will review and respond to this appointment request.`;
        
        for (const facilityUserDoc of facilityUsersSnapshot.docs) {
          const facilityUserData = facilityUserDoc.data();
          const facilityUserName = facilityUserData.firstName && facilityUserData.lastName
            ? `${facilityUserData.firstName} ${facilityUserData.lastName}`.trim()
            : 'Facility Staff';
          const facilityUserRole = facilityUserData.role || 'staff';
          
          await sendInAppMessage({
            senderId: 'system',
            senderName: 'LifeCare Connect',
            senderRole: 'system',
            receiverId: facilityUserDoc.id,
            receiverName: facilityUserName,
            receiverRole: facilityUserRole,
            content: facilityMessage,
            type: 'appointment_notification',
            priority: 'normal',
          });
          
          console.log(`✅ Confirmation sent to facility staff:`, facilityUserDoc.id);
        }
      } else if (patientId) {
        // Send confirmation to regular patient (who has a user account)
        const patientDoc = await admin.firestore().collection('users').doc(patientId).get();
        const patientData = patientDoc.exists ? patientDoc.data() : {};
        const patientFullName = patientData.firstName && patientData.lastName
          ? `${patientData.firstName} ${patientData.lastName}`.trim()
          : patientName;
        const patientRole = patientData.role || 'patient';
        
        const patientMessage = `✅ Appointment Request Submitted Successfully!\n\n` +
          `Provider: ${providerName}\n` +
          `Date: ${formattedDate || appointmentDate}\n` +
          `Time: ${appointmentTime}\n` +
          `Status: Pending Approval\n\n` +
          `📋 NEXT STEPS:\n` +
          `• Your healthcare provider has been notified\n` +
          `• Please wait for approval (you'll receive a notification)\n` +
          `• Check the "Appointments" tab for status updates\n\n` +
          `We'll notify you as soon as your appointment is reviewed. Thank you for choosing LifeCare Connect!`;
        
        await sendInAppMessage({
          senderId: 'system',
          senderName: 'LifeCare Connect',
          senderRole: 'system',
          receiverId: patientId,
          receiverName: patientFullName,
          receiverRole: patientRole,
          content: patientMessage,
          type: 'appointment_notification',
          priority: 'normal',
        });
        
        console.log(`✅ Confirmation message sent to patient:`, patientId);
      }
      
      // If CHW booked for a registered patient, also notify the actual patient
      if (appointmentData.relatedPatientId && appointmentData.relatedPatientName) {
        const relatedPatientId = appointmentData.relatedPatientId;
        const relatedPatientDoc = await admin.firestore().collection('users').doc(relatedPatientId).get();
        const relatedPatientData = relatedPatientDoc.exists ? relatedPatientDoc.data() : {};
        const relatedPatientFullName = relatedPatientData.firstName && relatedPatientData.lastName
          ? `${relatedPatientData.firstName} ${relatedPatientData.lastName}`.trim()
          : appointmentData.relatedPatientName;
        const relatedPatientRole = relatedPatientData.role || 'patient';
        
        const relatedPatientMessage = `✅ Appointment Booked for You by Your CHW!\n\n` +
          `Provider: ${providerName}\n` +
          `Date: ${formattedDate || appointmentDate}\n` +
          `Time: ${appointmentTime}\n` +
          `Status: Pending Doctor Approval\n\n` +
          `📋 NEXT STEPS:\n` +
          `• Your CHW has submitted the appointment request\n` +
          `• The doctor will review and respond soon\n` +
          `• You'll be notified when the appointment is approved\n` +
          `• Check the "Appointments" tab for status updates\n\n` +
          `Thank you for choosing LifeCare Connect!`;
        
        await sendInAppMessage({
          senderId: 'system',
          senderName: 'LifeCare Connect',
          senderRole: 'system',
          receiverId: relatedPatientId,
          receiverName: relatedPatientFullName,
          receiverRole: relatedPatientRole,
          content: relatedPatientMessage,
          type: 'appointment_notification',
          priority: 'normal',
        });
        
        console.log(`✅ Confirmation message sent to related patient:`, relatedPatientId);
      }
      
      console.log(`✅ Appointment booking notifications sent for appointment:`, appointmentId);
      return null;
      
    } catch (error) {
      console.error('Error sending appointment booking notification:', error);
      // Don't throw - appointment was already created successfully
      return null;
    }
  });

/**
 * Cloud Function: Triggered when appointment status changes
 * Sends SMS notification to the patient when appointment is approved
 */
exports.onAppointmentApproved = functions
  .runWith({ secrets: [TERMII_API_KEY, TERMII_SENDER_ID] })
  .firestore
  .document('appointments/{appointmentId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const appointmentId = context.params.appointmentId;
    
    try {
      // Check if status changed to 'approved'
      const statusChanged = beforeData.status !== afterData.status;
      const newStatus = afterData.status;
      
      if (!statusChanged || newStatus !== 'approved') {
        return null; // Only notify when status changes to approved
      }
      
      console.log('Appointment approved:', appointmentId);
      
      // Extract patient and appointment details
      const patientId = afterData.patientId || afterData.patientUid;
      const patientName = afterData.patientName || 'Patient';
      const providerName = afterData.providerName || afterData.doctorName || 'Doctor';
      const department = afterData.department || 'General';
      
      // Handle appointmentDate - can be Timestamp, string, or undefined
      let appointmentDate = 'Not specified';
      try {
        if (afterData.appointmentDate?.toDate) {
          // Firestore Timestamp
          appointmentDate = afterData.appointmentDate.toDate().toLocaleDateString('en-NG');
        } else if (typeof afterData.appointmentDate === 'string') {
          // ISO string
          appointmentDate = new Date(afterData.appointmentDate).toLocaleDateString('en-NG');
        }
      } catch (e) {
        console.error('Could not format appointment date:', e);
      }
      
      const appointmentTime = afterData.appointmentTime || 'Not specified';
      const facilityName = afterData.facilityName;
      const reason = afterData.reason || 'General Consultation';
      
      // Check if this is a facility-booked appointment
      const isFacilityBooked = afterData.bookedBy === 'medical_records' && 
                               afterData.bookedById && 
                               afterData.facilityId;
      
      if (!patientId) {
        console.error('No patientId found in appointment');
        return null;
      }
      
      if (isFacilityBooked) {
        // Notify facility staff instead of patient
        const facilityId = afterData.facilityId;
        
        // Get facility admins/staff who should be notified
        const facilityUsersSnapshot = await admin.firestore()
          .collection('users')
          .where('facilityId', '==', facilityId)
          .where('role', 'in', ['facility_admin', 'medical_records'])
          .get();
        
        const facilityMessage = `✅ Remote Appointment APPROVED!\n\n` +
          `Patient: ${patientName}\n` +
          `Remote Doctor: ${providerName}\n` +
          `Date: ${appointmentDate}\n` +
          `Time: ${appointmentTime}\n\n` +
          `📋 NEXT STEPS:\n` +
          `• Ensure the patient is ready for the consultation\n` +
          `• Check "Remote Consultations" tab for approved appointments\n` +
          `• The doctor will initiate the consultation at the scheduled time\n\n` +
          `Please prepare the patient and facility for the remote consultation.`;
        
        for (const facilityUserDoc of facilityUsersSnapshot.docs) {
          const facilityUserData = facilityUserDoc.data();
          const facilityUserName = facilityUserData.firstName && facilityUserData.lastName
            ? `${facilityUserData.firstName} ${facilityUserData.lastName}`.trim()
            : 'Facility Staff';
          const facilityUserRole = facilityUserData.role || 'staff';
          
          await sendInAppMessage({
            senderId: 'system',
            senderName: 'LifeCare Connect',
            senderRole: 'system',
            receiverId: facilityUserDoc.id,
            receiverName: facilityUserName,
            receiverRole: facilityUserRole,
            content: facilityMessage,
            type: 'appointment_notification',
            priority: 'high',
          });
          
          console.log(`✅ Approval notification sent to facility staff:`, facilityUserDoc.id);
        }
      } else {
        // Regular patient appointment - send to patient
        // Get patient phone number
        const patientPhone = await getUserPhone(patientId, 'patient');
        if (!patientPhone) {
          console.error('Patient phone number not found:', patientId);
          return null;
        }
      
        // Compose SMS message
        let message;
        if (facilityName) {
          // Facility appointment
          message = `Your appointment has been APPROVED!\n` +
            `Department: ${department}\n` +
            `Date: ${appointmentDate}\n` +
            `Time: ${appointmentTime}\n` +
            `Location: ${facilityName}\n` +
            `Please arrive 15 minutes early. Thank you!`;
        } else {
          // Remote appointment
          message = `Your appointment has been APPROVED!\n` +
            `Doctor: ${providerName}\n` +
            `Date: ${appointmentDate}\n` +
            `Time: ${appointmentTime}\n` +
            `This is a remote consultation. Please be available at the scheduled time.`;
        }
      
        // Send SMS to patient
        await sendSMS(patientPhone, message);
      
        console.log('✅ Appointment approval notification sent to patient:', patientId);
      }
      return null;
      
    } catch (error) {
      console.error('Error sending appointment approval notification:', error);
      // Don't throw - appointment update was already successful
      return null;
    }
  });

/**
 * Cloud Function: Triggered when appointment status changes to denied
 * Sends SMS notification to the patient when appointment is denied/rejected
 */
exports.onAppointmentDenied = functions
  .runWith({ secrets: [TERMII_API_KEY, TERMII_SENDER_ID] })
  .firestore
  .document('appointments/{appointmentId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const appointmentId = context.params.appointmentId;
    
    try {
      // Check if status changed to 'denied'
      const statusChanged = beforeData.status !== afterData.status;
      const newStatus = afterData.status;
      
      if (!statusChanged || newStatus !== 'denied') {
        return null; // Only notify when status changes to denied
      }
      
      console.log('Appointment denied:', appointmentId);
      
      // Extract patient and appointment details
      const patientId = afterData.patientId || afterData.patientUid;
      const patientName = afterData.patientName || 'Patient';
      const providerName = afterData.providerName || afterData.doctorName || 'Doctor';
      const denialReason = afterData.denialReason || 'Not specified';
      
      // Handle appointmentDate - can be Timestamp, string, or undefined
      let appointmentDate = 'Not specified';
      try {
        if (afterData.appointmentDate?.toDate) {
          // Firestore Timestamp
          appointmentDate = afterData.appointmentDate.toDate().toLocaleDateString('en-NG');
        } else if (typeof afterData.appointmentDate === 'string') {
          // ISO string
          appointmentDate = new Date(afterData.appointmentDate).toLocaleDateString('en-NG');
        }
      } catch (e) {
        console.error('Could not format appointment date:', e);
      }
      
      const appointmentTime = afterData.appointmentTime || 'Not specified';
      
      // Check if this is a facility-booked appointment
      const isFacilityBooked = afterData.bookedBy === 'medical_records' && 
                               afterData.bookedById && 
                               afterData.facilityId;
      
      if (!patientId) {
        console.error('No patientId found in appointment');
        return null;
      }
      
      if (isFacilityBooked) {
        // Notify facility staff instead of patient
        const facilityId = afterData.facilityId;
        
        // Get facility admins/staff who should be notified
        const facilityUsersSnapshot = await admin.firestore()
          .collection('users')
          .where('facilityId', '==', facilityId)
          .where('role', 'in', ['facility_admin', 'medical_records'])
          .get();
        
        const facilityMessage = `❌ Remote Appointment DECLINED\n\n` +
          `Patient: ${patientName}\n` +
          `Remote Doctor: ${providerName}\n` +
          `Date: ${appointmentDate}\n` +
          `Time: ${appointmentTime}\n\n` +
          `📋 Reason: ${denialReason}\n\n` +
          `🔄 WHAT TO DO NEXT:\n` +
          `• Inform the patient about the declined appointment\n` +
          `• You can book a new appointment with a different doctor or time\n` +
          `• Check "Remote Consultations" tab to book another consultation\n\n` +
          `Please coordinate with the patient for alternative arrangements.`;
        
        for (const facilityUserDoc of facilityUsersSnapshot.docs) {
          const facilityUserData = facilityUserDoc.data();
          const facilityUserName = facilityUserData.firstName && facilityUserData.lastName
            ? `${facilityUserData.firstName} ${facilityUserData.lastName}`.trim()
            : 'Facility Staff';
          const facilityUserRole = facilityUserData.role || 'staff';
          
          await sendInAppMessage({
            senderId: 'system',
            senderName: 'LifeCare Connect',
            senderRole: 'system',
            receiverId: facilityUserDoc.id,
            receiverName: facilityUserName,
            receiverRole: facilityUserRole,
            content: facilityMessage,
            type: 'appointment_notification',
            priority: 'high',
          });
          
          console.log(`✅ Denial notification sent to facility staff:`, facilityUserDoc.id);
        }
      } else {
        // Regular patient appointment - send to patient
        // Get patient phone number
        const patientPhone = await getUserPhone(patientId, 'patient');
      
        if (!patientPhone) {
          console.error('Patient phone number not found:', patientId);
          return null;
        }
      
        // Compose SMS message
        const message = `Your appointment request has been DECLINED.\n` +
          `Date: ${appointmentDate}\n` +
          `Time: ${appointmentTime}\n` +
          `Reason: ${denialReason}\n` +
          `You can book a new appointment through LifeCare Connect app.`;
      
        // Send SMS to patient
        await sendSMS(patientPhone, message);
      
        console.log('✅ Appointment denial notification sent to patient:', patientId);
      
        // Also notify related patient if this was booked by CHW
        if (afterData.relatedPatientId) {
          const relatedPatientPhone = await getUserPhone(afterData.relatedPatientId, 'patient');
        
          if (relatedPatientPhone) {
            const relatedMessage = `Your appointment (booked by CHW) has been DECLINED.\n` +
              `Date: ${appointmentDate}\n` +
              `Time: ${appointmentTime}\n` +
              `Reason: ${denialReason}\n` +
              `Your CHW can help you book another appointment.`;
          
            await sendSMS(relatedPatientPhone, relatedMessage);
            console.log('✅ Appointment denial notification sent to related patient:', afterData.relatedPatientId);
          }
        }
      }
      
      // Notify CHW if they booked this appointment
      if (afterData.bookedBy === 'chw' && afterData.bookedById) {
        const chwId = afterData.bookedById;
        const chwPhone = await getUserPhone(chwId, 'chw');
        const chwPatientName = afterData.patientName || 'Unknown Patient';
        
        if (chwPhone) {
          const chwMessage = `Appointment Request DECLINED\n` +
            `Patient: ${chwPatientName}\n` +
            `Date: ${appointmentDate}\n` +
            `Time: ${appointmentTime}\n` +
            `Reason: ${denialReason}\n` +
            `You can book a new appointment for this patient in LifeCare Connect app.`;
          
          await sendSMS(chwPhone, chwMessage);
          console.log('✅ Appointment denial notification sent to CHW:', chwId);
        } else {
          console.warn('⚠️ CHW phone number not found:', chwId);
        }
        
        // Send in-app message to CHW
        const chwDoc = await admin.firestore().collection('users').doc(chwId).get();
        if (chwDoc.exists) {
          const chwData = chwDoc.data();
          const chwName = chwData.firstName && chwData.lastName
            ? `${chwData.firstName} ${chwData.lastName}`.trim()
            : 'CHW';
          const chwRole = chwData.role || 'chw';
          
          const chwInAppMessage = `❌ Appointment Request DECLINED\n\n` +
            `Patient: ${chwPatientName}\n` +
            `Date: ${appointmentDate}\n` +
            `Time: ${appointmentTime}\n\n` +
            `📋 Reason: ${denialReason}\n\n` +
            `🔄 NEXT STEPS:\n` +
            `• You can book a new appointment for this patient\n` +
            `• Try a different time slot or doctor\n` +
            `• Check "Appointments" tab to book again\n\n` +
            `We apologize for any inconvenience.`;
          
          await sendInAppMessage({
            senderId: 'system',
            senderName: 'LifeCare Connect',
            senderRole: 'system',
            receiverId: chwId,
            receiverName: chwName,
            receiverRole: chwRole,
            content: chwInAppMessage,
            type: 'appointment_notification',
            priority: 'high',
          });
          
          console.log(`✅ In-app denial notification sent to CHW:`, chwId);
        }
      }
      
      return null;
      
    } catch (error) {
      console.error('Error sending appointment denial notification:', error);
      // Don't throw - appointment update was already successful
      return null;
    }
  });

/**
 * Cloud Function: Triggered when appointment is rescheduled
 * Sends SMS and in-app notification to the patient
 */
exports.onAppointmentRescheduled = functions
  .runWith({ secrets: [TERMII_API_KEY, TERMII_SENDER_ID] })
  .firestore
  .document('appointments/{appointmentId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const appointmentId = context.params.appointmentId;
    
    try {
      // Check if appointment date changed (indicating reschedule)
      const dateChanged = beforeData.appointmentDate !== afterData.appointmentDate;
      const wasRescheduled = afterData.rescheduledBy && afterData.rescheduledAt;
      
      if (!dateChanged || !wasRescheduled) {
        return null; // Not a reschedule operation
      }
      
      console.log('Appointment rescheduled:', appointmentId);
      
      // Extract patient and appointment details
      const patientId = afterData.patientId || afterData.patientUid;
      const patientName = afterData.patientName || 'Patient';
      const providerName = afterData.providerName || afterData.doctorName || 'Doctor';
      
      // Handle appointmentDate - can be Timestamp, string, or undefined
      let appointmentDate = 'Not specified';
      let formattedDate = '';
      let formattedTime = '';
      try {
        if (afterData.appointmentDate?.toDate) {
          // Firestore Timestamp
          const date = afterData.appointmentDate.toDate();
          appointmentDate = date.toLocaleDateString('en-NG');
          formattedDate = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
          formattedTime = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
        } else if (typeof afterData.appointmentDate === 'string') {
          // ISO string
          const date = new Date(afterData.appointmentDate);
          appointmentDate = date.toLocaleDateString('en-NG');
          formattedDate = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
          formattedTime = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
        }
      } catch (e) {
        console.error('Could not format appointment date:', e);
      }
      
      const appointmentTime = afterData.appointmentTime || formattedTime || 'Not specified';
      
      // Check if this is a facility-booked appointment
      const isFacilityBooked = afterData.bookedBy === 'medical_records' && 
                               afterData.bookedById && 
                               afterData.facilityId;
      
      if (!patientId) {
        console.error('No patientId found in appointment');
        return null;
      }
      
      if (isFacilityBooked) {
        // Notify facility staff instead of patient
        const facilityId = afterData.facilityId;
        
        // Get facility admins/staff who should be notified
        const facilityUsersSnapshot = await admin.firestore()
          .collection('users')
          .where('facilityId', '==', facilityId)
          .where('role', 'in', ['facility_admin', 'medical_records'])
          .get();
        
        const facilityMessage = `🔄 Remote Appointment RESCHEDULED\n\n` +
          `Patient: ${patientName}\n` +
          `Remote Doctor: ${providerName}\n` +
          `New Date: ${appointmentDate}\n` +
          `New Time: ${appointmentTime}\n` +
          `Status: Approved for new time\n\n` +
          `📋 ACTION REQUIRED:\n` +
          `• Inform the patient about the new appointment time\n` +
          `• Ensure the patient will be available at the new time\n` +
          `• Prepare the facility for the remote consultation\n\n` +
          `Please coordinate with the patient for the rescheduled consultation.`;
        
        for (const facilityUserDoc of facilityUsersSnapshot.docs) {
          const facilityUserData = facilityUserDoc.data();
          const facilityUserName = facilityUserData.firstName && facilityUserData.lastName
            ? `${facilityUserData.firstName} ${facilityUserData.lastName}`.trim()
            : 'Facility Staff';
          const facilityUserRole = facilityUserData.role || 'staff';
          
          await sendInAppMessage({
            senderId: 'system',
            senderName: 'LifeCare Connect',
            senderRole: 'system',
            receiverId: facilityUserDoc.id,
            receiverName: facilityUserName,
            receiverRole: facilityUserRole,
            content: facilityMessage,
            type: 'appointment_notification',
            priority: 'high',
          });
          
          console.log(`✅ Reschedule notification sent to facility staff:`, facilityUserDoc.id);
        }
      } else {
        // Regular patient appointment - send to patient
        // Get patient phone number
        const patientPhone = await getUserPhone(patientId, 'patient');
      
        // Compose SMS message
        const smsMessage = `Your appointment has been RESCHEDULED by ${providerName}.\n` +
          `New Date: ${appointmentDate}\n` +
          `New Time: ${appointmentTime}\n` +
          `Status: Approved for new time\n` +
          `Please be punctual. Check LifeCare Connect app for details.`;
      
        // Send SMS to patient (if phone available)
        if (patientPhone) {
          await sendSMS(patientPhone, smsMessage);
          console.log('✅ Reschedule SMS notification sent to patient:', patientId);
        } else {
          console.warn('⚠️ Patient phone number not found:', patientId);
        }
      }
      
      // Notify CHW if they booked this appointment
      if (afterData.bookedBy === 'chw' && afterData.bookedById) {
        const chwId = afterData.bookedById;
        const chwPhone = await getUserPhone(chwId, 'chw');
        const chwPatientName = afterData.patientName || 'Unknown Patient';
        
        if (chwPhone) {
          const chwMessage = `Appointment RESCHEDULED by Doctor\n` +
            `Patient: ${chwPatientName}\n` +
            `New Date: ${appointmentDate}\n` +
            `New Time: ${appointmentTime}\n` +
            `Status: Approved for new time\n` +
            `Please inform the patient. Check LifeCare Connect app for details.`;
          
          await sendSMS(chwPhone, chwMessage);
          console.log('✅ Reschedule SMS notification sent to CHW:', chwId);
        } else {
          console.warn('⚠️ CHW phone number not found:', chwId);
        }
        
        // Send in-app message to CHW
        const chwDoc = await admin.firestore().collection('users').doc(chwId).get();
        if (chwDoc.exists) {
          const chwData = chwDoc.data();
          const chwName = chwData.firstName && chwData.lastName
            ? `${chwData.firstName} ${chwData.lastName}`.trim()
            : 'CHW';
          const chwRole = chwData.role || 'chw';
          
          const chwInAppMessage = `🔄 Appointment RESCHEDULED by Doctor\n\n` +
            `Patient: ${chwPatientName}\n` +
            `📅 New Date & Time: ${formattedDate || appointmentDate} at ${appointmentTime}\n\n` +
            `✅ Automatically APPROVED for new time\n\n` +
            `📋 ACTION REQUIRED:\n` +
            `• Inform the patient about the new time\n` +
            `• Ensure patient is available at the new time\n` +
            `• Check "Appointments" tab for updated details\n\n` +
            `Thank you for coordinating!`;
          
          await sendInAppMessage({
            senderId: 'system',
            senderName: 'LifeCare Connect',
            senderRole: 'system',
            receiverId: chwId,
            receiverName: chwName,
            receiverRole: chwRole,
            content: chwInAppMessage,
            type: 'appointment_notification',
            priority: 'high',
          });
          
          console.log(`✅ In-app reschedule notification sent to CHW:`, chwId);
        }
      }
      
      console.log('✅ Appointment reschedule notifications sent');
      return null;
      
    } catch (error) {
      console.error('Error sending appointment reschedule notification:', error);
      // Don't throw - appointment update was already successful
      return null;
    }
  });

/**
 * Cloud Function: Send SMS notification for referrals
 * Called from app when referral is created or approved
 * Can notify both the recipient doctor/CHW AND the patient
 */
exports.sendReferralNotification = functions
  .runWith({ secrets: [TERMII_API_KEY, TERMII_SENDER_ID] })
  .https.onCall(async (data, context) => {
  try {
    const {
      recipientId,
      recipientType, // 'doctor' or 'chw'
      patientId, // Optional: patient ID to also notify
      patientName,
      referrerName,
      toProviderName, // Optional: name of doctor/CHW being referred to (for patient notification)
      reason,
      urgency,
      notifyPatient, // Optional: boolean to control patient notification
      isApproved, // Optional: true if referral was approved (changes patient message)
    } = data;
    
    // Validate inputs
    if (!recipientId || !recipientType || !patientName || !referrerName || !reason) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: recipientId, recipientType, patientName, referrerName, reason'
      );
    }
    
    const notifications = [];
    
    // 1. Send SMS to recipient doctor/CHW
    const recipientPhone = await getUserPhone(recipientId, recipientType);
    
    if (recipientPhone) {
      const urgencyText = urgency ? ` (${urgency.toUpperCase()})` : '';
      const recipientMessage = `New Patient Referral${urgencyText}\n` +
        `Patient: ${patientName}\n` +
        `From: ${referrerName}\n` +
        `Reason: ${reason}\n` +
        `Please review in LifeCare Connect app.`;
      
      await sendSMS(recipientPhone, recipientMessage);
      notifications.push(`recipient ${recipientType}`);
      console.log('✅ Referral notification sent to recipient:', recipientId);
    } else {
      console.warn(`⚠️ Phone number not found for ${recipientType}: ${recipientId}`);
    }
    
    // 2. Send SMS to patient if requested
    if (notifyPatient && patientId) {
      // Try to get patient phone from users collection (registered patients)
      let patientPhone = await getUserPhone(patientId, 'patient');
      
      // If not found in users, try chw_patients collection
      if (!patientPhone) {
        const chwPatientDoc = await admin.firestore().collection('chw_patients').doc(patientId).get();
        if (chwPatientDoc.exists) {
          const chwPatientData = chwPatientDoc.data();
          patientPhone = chwPatientData.phoneNumber || chwPatientData.phone;
        }
      }
      
      if (patientPhone) {
        let patientMessage;
        
        if (isApproved) {
          // Message for approved referral
          const providerName = toProviderName || 'a specialist';
          patientMessage = `Your referral to ${providerName} has been APPROVED.\n` +
            `Reason: ${reason}\n` +
            `Please check LifeCare Connect app to book your appointment or view details.`;
        } else {
          // Message for new referral
          const providerName = toProviderName || 'a specialist';
          patientMessage = `You have been referred to ${providerName} by ${referrerName}.\n` +
            `Reason: ${reason}\n` +
            `Please check LifeCare Connect app for details.`;
        }
        
        await sendSMS(patientPhone, patientMessage);
        notifications.push('patient');
        console.log('✅ Referral notification sent to patient:', patientId);
      } else {
        console.warn('⚠️ Phone number not found for patient:', patientId);
      }
    }
    
    const notificationSummary = notifications.length > 0 
      ? notifications.join(' and ') 
      : 'recipient only';
    
    return {
      success: true,
      message: `Referral notification sent to ${notificationSummary}`,
      notificationsSent: notifications,
    };
    
  } catch (error) {
    console.error('Error in sendReferralNotification:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to send referral notification');
  }
});

module.exports = {
  onAppointmentBooked: exports.onAppointmentBooked,
  onAppointmentApproved: exports.onAppointmentApproved,
  onAppointmentDenied: exports.onAppointmentDenied,
  onAppointmentRescheduled: exports.onAppointmentRescheduled,
  sendReferralNotification: exports.sendReferralNotification,
};
