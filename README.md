# Contractor QR Scanner

iOS app for site security to scan and validate contractor QR codes for site entry. Works with the [Contractor QR Access](https://github.com/pktikkani/ContractorQRApp) system.

## How It Works

1. Contractor presents their QR code from the Contractor QR Access app
2. Security guard scans the code using this app (installed on iPad/iPhone at site entrance)
3. The app validates the code against the backend API
4. Displays ACCESS GRANTED or ACCESS DENIED with contractor details

## Features

- Native AVFoundation camera for fast QR code scanning
- Real-time validation against backend API
- Animated viewfinder with scan line
- Haptic feedback on successful scan
- Auto-reset after 8 seconds for continuous scanning
- Dark cybersecurity theme
- Works on iPhone and iPad

## Requirements

- iOS 16.0+
- Camera access
- Network connection to backend API

## Backend API

This app communicates with the Contractor QR Access API at `https://contractor-api.nubewired.com`. The validation endpoint (`POST /api/v1/qr/validate`) is public and requires no authentication.

## Related Projects

- [Contractor QR Access](https://github.com/pktikkani/ContractorQRApp) - iOS app for contractors + Go backend + Scanner webapp
