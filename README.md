# Wake Up Buddy
A Flutter-based mobile alarm application that turns off only after facial recognition confirms the user is awake.

##  About the Project
Wake Up Buddy is an intelligent mobile alarm system designed to prevent oversleeping by verifying that the user is genuinely awake. Unlike traditional alarm applications that can be dismissed easily, this app introduces a two-step alarm mechanism that combines timed alerts with facial recognition–based confirmation.

The system first triggers a standard wake-up alarm at the scheduled time. After a short delay, a second confirmation alarm activates the device camera and requires successful facial recognition to permanently stop the alarm. If the user fails at any stage, the alarm is automatically rescheduled, ensuring reliable wake-up behavior.

For testing and demonstration purposes, the delay between the wake-up alarm and the facial recognition confirmation alarm is currently set to 1 minute. In real-world use, this interval can be adjusted based on user preference or system configuration.

Facial recognition is performed entirely on-device using Google ML Kit, prioritizing speed, accuracy, and user privacy without relying on cloud processing.

## Key Features

- Two-step alarm system for reliable wake-up
- Primary alarm to wake the user
- Secondary confirmation alarm using facial recognition
- Eye-open detection to verify alertness
- Automatic retry mechanism on failure
- Alarm rescheduling after 90 seconds if any step fails
- On-device face detection (no internet required)
- Privacy-focused design with no face data storage
- Built with Flutter for cross-platform support


## System Workflow
1. User schedules a wake-up alarm.
2. The primary alarm rings at the scheduled time.
3. After 1 minute, a confirmation alarm is triggered.
4. The front camera activates and facial recognition begins.
5. The system verifies:
   - Face presence
   - Eye openness 
   - Stable detection across multiple frames
6. If verification succeeds, the alarm stops permanently.
7. If verification fails or the user misses any step:
8. The alarm is rescheduled to ring again after 90 seconds.
9. The cycle repeats until wakefulness is confirmed.

## Privacy & Security
### Wake Up Buddy is designed with privacy as a core principle:
- No facial images are stored
- No biometric data is uploaded to the cloud
- Facial recognition runs entirely on-device
- Camera access is limited to the confirmation phase only
- No user data is shared with third parties

## Configuration Details:
### Current testing configuration
- Confirmation alarm delay: 1 minute
- Retry interval on failure: 90 seconds
- Required successful face detections: Multiple stable confirmations

## Use Cases
- Heavy sleepers
- Students and professionals with strict schedules
- Users who snooze alarms unconsciously
- Research and experimental alarm systems

## Contributing

Contributions, suggestions, and improvements are welcome.

If you’d like to discuss ideas, report issues, or collaborate, please open an issue
or submit a pull request. You can also reach out directly through our Discord
community for faster discussion and coordination:

🔗 Discord: https://discord.gg/4TdXRpxanJLicense

## License
This project is licensed under the Apache License 2.0.

## Author
Aseem Ahamed

Flutter Developer | AI Enthusiast