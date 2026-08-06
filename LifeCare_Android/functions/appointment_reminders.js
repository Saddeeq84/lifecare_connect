const functions = require('firebase-functions');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const axios = require('axios');

// Define secrets for Termii SMS service
const TERMII_API_KEY = defineSecret('TERMII_API_KEY');
const TERMII_SENDER_ID = defineSecret('TERMII_SENDER_ID');

/**
 * Cloud Function to send appointment reminders
 * Triggered when appointments are created
 */
exports.sendAppointmentReminders = functions
  .runWith({secrets: [TERMII_API_KEY, TERMII_SENDER_ID]})
  .firestore
  .document('chw_patients/{patientId}/appointments/{appointmentId}')
  .onCreate(async (snap, context) => {
    const appointment = snap.data();
    const now = admin.firestore.Timestamp.now();
    const firestore = admin.firestore();

    console.log('Appointment created, checking if reminder should be sent:', appointment);

    try {
      // Only send reminder if enabled and appointment is scheduled
      if (!appointment.reminderEnabled || appointment.status !== 'scheduled') {
        console.log('Reminder not enabled or appointment not scheduled, skipping');
        return;
      }

      // Get patient data
      const patientDoc = await firestore.collection('chw_patients').doc(context.params.patientId).get();
      if (!patientDoc.exists) {
        console.log('Patient not found');
        return;
      }

      const patientData = patientDoc.data();
      const patientName = patientData.fullName || 'Patient';
      const patientPhone = patientData.phone;

      if (!patientPhone) {
        console.log('Patient has no phone number, skipping reminder');
        return;
      }

      // Check if appointment is within reminder window (e.g., within 24 hours)
      const appointmentDate = appointment.appointmentDate;
      if (!appointmentDate) {
        console.log('No appointment date specified');
        return;
      }

      const appointmentTime = appointmentDate.toDate();
      const timeDiff = appointmentTime.getTime() - now.toDate().getTime();
      const hoursUntilAppointment = timeDiff / (1000 * 60 * 60);

      // Only send reminder if appointment is within 24 hours
      if (hoursUntilAppointment < 0 || hoursUntilAppointment > 24) {
        console.log(`Appointment is ${hoursUntilAppointment.toFixed(1)} hours away, not sending reminder`);
        return;
      }

      // Send SMS reminder
      const message = `Hi ${patientName}, this is a reminder for your appointment on ${appointmentTime.toLocaleDateString()} at ${appointmentTime.toLocaleTimeString()}. Please arrive on time. - LifeCare Connect`;

      await sendSMS(patientPhone, message);
      console.log('Appointment reminder sent to:', patientPhone);

    } catch (error) {
      console.error('Error sending appointment reminder:', error);
    }
  });

/**
 * Trigger when a new appointment is created
 * Validates reminder settings and schedules notification
 */
exports.onAppointmentCreated = functions
  .runWith({secrets: [TERMII_API_KEY, TERMII_SENDER_ID]})
  .firestore
  .document('chw_patient_records/{patientId}/appointments/{appointmentId}')
  .onCreate(async (snap, context) => {
    const appointment = snap.data();
    const patientId = context.params.patientId;
    const appointmentId = context.params.appointmentId;
    
    console.log('New appointment created:', appointmentId, 'for patient:', patientId);
    
    // Validate appointment data
    if (!appointment.appointmentDateTime) {
      console.warn('Appointment missing appointmentDateTime:', appointmentId);
      return null;
    }
    
    const appointmentDateTime = appointment.appointmentDateTime.toDate();
    const now = new Date();
    
    // Check if appointment is in the past
    if (appointmentDateTime < now) {
      console.warn('Appointment is in the past:', appointmentId);
      return null;
    }
    
    // If reminders are enabled, log the scheduled reminder time
    if (appointment.reminderEnabled) {
      const reminderMinutes = appointment.reminderTime || 60;
      const reminderTime = new Date(appointmentDateTime.getTime() - (reminderMinutes * 60 * 1000));
      
      console.log('Appointment reminder scheduled for:', reminderTime.toISOString());
      
      // Initialize reminder status
      await snap.ref.update({
        reminderSent: false,
        reminderScheduled: true,
      });
    }
    
    return null;
  });

/**
 * Trigger when an appointment is updated
 * Re-schedule reminder if appointment time changes
 */
exports.onAppointmentUpdated = functions
  .runWith({secrets: [TERMII_API_KEY, TERMII_SENDER_ID]})
  .firestore
  .document('chw_patient_records/{patientId}/appointments/{appointmentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const appointmentId = context.params.appointmentId;
    
    // Check if appointment date/time changed
    const beforeDateTime = before.appointmentDateTime?.toDate();
    const afterDateTime = after.appointmentDateTime?.toDate();
    
    if (beforeDateTime && afterDateTime && beforeDateTime.getTime() !== afterDateTime.getTime()) {
      console.log('Appointment time changed for:', appointmentId);
      
      // Reset reminder status if time changed
      if (after.reminderEnabled) {
        await change.after.ref.update({
          reminderSent: false,
        });
        
        console.log('Reminder status reset for appointment:', appointmentId);
      }
    }
    
    // Check if reminder settings changed
    if (before.reminderEnabled !== after.reminderEnabled || before.reminderTime !== after.reminderTime) {
      console.log('Reminder settings changed for appointment:', appointmentId);
      
      if (after.reminderEnabled) {
        await change.after.ref.update({
          reminderSent: false,
          reminderScheduled: true,
        });
      }
    }
    
    return null;
  });

/**
 * Trigger when appointment status changes to completed or cancelled
 * Disable reminder if appointment is no longer active
 */
exports.onAppointmentStatusChange = functions
  .runWith({secrets: [TERMII_API_KEY, TERMII_SENDER_ID]})
  .firestore
  .document('chw_patient_records/{patientId}/appointments/{appointmentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Check if status changed to completed or cancelled
    if (before.status !== after.status && 
        (after.status === 'completed' || after.status === 'cancelled')) {
      
      console.log('Appointment status changed to:', after.status);
      
      // Disable reminders for completed/cancelled appointments
      if (after.reminderEnabled) {
        await change.after.ref.update({
          reminderEnabled: false,
        });
        
        console.log('Reminders disabled for appointment:', context.params.appointmentId);
      }
    }
    
    return null;
  });

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
    
    // Send SMS via Termii using generic channel (for notifications, not OTP)
    const response = await axios.post('https://api.ng.termii.com/api/sms/send', {
      to: formattedPhone,
      from: senderId,
      sms: message,
      type: 'plain',
      channel: 'generic', // Use 'generic' for appointment notifications, not 'dnd'
      api_key: termiiApiKey,
    });
    
    console.log('SMS sent successfully to:', formattedPhone, 'Response:', response.data);
    return response.data;
    
  } catch (error) {
    console.error('Error sending SMS via Termii:', error.response?.data || error.message);
    throw error;
  }
}
