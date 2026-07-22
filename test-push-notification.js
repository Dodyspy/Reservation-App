#!/usr/bin/env node

// Test script to send a push notification to the iOS app
// Run this after the app is installed and running on your device

const https = require('https');

const testData = {
  customerName: "Test Client",
  customerEmail: "test@example.com",
  customerPhone: "01 23 45 67 89",
  partySize: 2,
  date: "2025-01-25",
  time: "19:30",
  specialRequests: "Test de notification push",
  customerHistory: {
    totalReservations: 1,
    noShowCount: 0,
    isRepeatCustomer: false
  }
};

const data = JSON.stringify(testData);

const options = {
  hostname: 'www.casanovadissy.fr',
  port: 443,
  path: '/api/send-push-notification',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

console.log('🔔 Testing push notification...');
console.log('📱 Make sure your iOS app is running and you accepted notification permissions');
console.log('📤 Sending test notification to:', options.hostname + options.path);

const req = https.request(options, (res) => {
  console.log(`📊 Status: ${res.statusCode}`);
  
  let responseData = '';
  res.on('data', (chunk) => {
    responseData += chunk;
  });
  
  res.on('end', () => {
    console.log('📥 Response:', responseData);
    
    if (res.statusCode === 200) {
      console.log('✅ Push notification sent successfully!');
      console.log('📱 Check your iPhone for the notification');
    } else {
      console.log('❌ Failed to send push notification');
    }
  });
});

req.on('error', (error) => {
  console.error('❌ Error:', error);
});

req.write(data);
req.end();
