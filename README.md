# JackpotIQ

**Play Smarter - Your intelligent assistant for Mega Millions and Powerball.**

JackpotIQ is an iOS application designed to provide lottery enthusiasts with tools and insights for Mega Millions and Powerball games. It leverages historical data to help users make more informed decisions.

## Features

- **Latest Winning Numbers:** Quickly access the most recent drawing results for both Mega Millions and Powerball.
- **Optimized Number Generation:** Generate suggested lottery combinations based on statistical analysis of past winning numbers. Choose between optimization strategies:
  - **By Ball Position:** Considers the frequency of numbers appearing in specific draw positions.
  - **By Overall Frequency:** Focuses on the overall historical frequency of each number.
- **In-Depth Frequency Analysis:** Explore detailed charts and statistics:
  - Frequency of main numbers.
  - Frequency of the special ball (Mega Ball / Powerball).
  - Positional frequency analysis (how often numbers appear in each drawing slot).
- **Check Your Numbers:** Enter your combination and see if it has matched winning numbers in past drawings.
- **Dual Lottery Support:** Full features available for both Mega Millions and Powerball.
- **Modern Interface:** Built natively with SwiftUI for a clean and responsive user experience.
- **App Attestation:** Secure authentication using Apple's App Attest framework.

## Technology Stack

- **Frontend:** SwiftUI
- **Architecture:** MVVM (Model-View-ViewModel)
- **Language:** Swift
- **Authentication:** App Attest, JWT
- **Data Storage:** Keychain for secure token storage

## Backend

JackpotIQ connects to a secure API hosted on Google Cloud Run:

- **Base URL:** `https://jackpot-iq-api-669259029283.us-central1.run.app/api/`
- **Authentication:** JWT token-based authentication
- **Key Endpoints:**
  - `/auth/verify-app-attest`: Verifies device attestation
  - `/auth/token`: Generates authentication tokens
  - `/lottery/search`: Searches for matching lottery combinations
  - `/lottery`: Fetches latest lottery results
  - `/stats`: Retrieves statistical data

### API Response Format

The API returns lottery data in the following format:

```json
[
  {
    "specialBall": 10,
    "date": "2023-01-10",
    "numbers": [1, 2, 3, 4, 5],
    "type": "mega-millions"
  }
]
```

## Getting Started

1. Clone the repository.
2. Open `JackpotIQ.xcodeproj` in Xcode.
3. Build and run the application on a simulator or physical device.

## Security Notes

- The app uses App Attest for secure device verification
- Authentication tokens are stored securely in the Keychain
- All API requests are made over HTTPS
- Sensitive data is never logged or stored in plain text
