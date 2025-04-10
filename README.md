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

## Technology Stack

- **Frontend:** SwiftUI
- **Architecture:** MVVM (Model-View-ViewModel)
- **Language:** Swift

## Backend

JackpotIQ relies on a backend service (via `NetworkService`) to fetch up-to-date lottery results, historical data, and perform statistical calculations. _(Note: Details of the backend API are not included in this repository)_.

## Getting Started

1.  Clone the repository.
2.  Open `JackpotIQ.xcodeproj` in Xcode.
3.  Ensure you have a compatible backend service running and configured in `NetworkService`.
4.  Build and run the application on a simulator or physical device.
