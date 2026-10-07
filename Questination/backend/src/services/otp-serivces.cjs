function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString(); // 6-digit OTP
}

// Replace this stub with real Twilio/MSG91 call once decided with Person 1
async function sendOtp(phoneNumber, otp) {
  console.log(`[DEV MODE] Sending OTP ${otp} to ${phoneNumber}`);
  // Example Twilio usage (uncomment once you have credentials):
  //
  // const twilio = require('twilio')(process.env.TWILIO_SID, process.env.TWILIO_AUTH_TOKEN);
  // await twilio.messages.create({
  //   body: `Your Questination coupon OTP is ${otp}`,
  //   from: process.env.TWILIO_PHONE_NUMBER,
  //   to: phoneNumber,
  // });
}

module.exports = { generateOtp, sendOtp };