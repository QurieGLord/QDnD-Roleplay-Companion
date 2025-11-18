<p align="center">
  <a href="https://github.com/your_username/your_repository">
    <img src="assets/images/icon.svg" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">QD&D - Your Digital D&D Companion</h3>

  <p align="center">
    A comprehensive, offline-first D&D 5th Edition companion app for Android & iOS, built with Flutter.
    <br />
    <a href="https://github.com/your_username/your_repository/issues">Report Bug</a>
    ·
    <a href="https://github.com/your_username/your_repository/issues">Request Feature</a>
  </p>
</p>

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Status](https://img.shields.io/badge/status-in%20development-green.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## About The Project

QD&D is your ultimate digital companion for Dungeons & Dragons 5th Edition. Designed with a "build once, populate infinitely" philosophy, our data-driven architecture allows for near-infinite expandability. New classes, spells, or items can be added by simply dropping in a JSON file, no code changes required.

This is more than just a character sheet—it's a complete roleplaying toolkit.

### Key Features:

*   **Universal System:** Supports all 13 official D&D 5e classes and is easily extendable.
*   **Offline First:** No internet connection? No problem. Your data is always available.
*   **Bilingual:** Full support for both English and Russian.
*   **FC5 Compatibility:** Import and export characters from Fight Club 5.
*   **Material You:** A beautiful, modern interface with 5 color themes.

## Tech Stack

*   **Framework:** Flutter 3.35.7
*   **Language:** Dart 3.9.4
*   **State Management:** Provider
*   **Storage:** Hive
*   **Design:** Material 3 Expressive

## Getting Started

To get a local copy up and running follow these simple steps.

### Prerequisites

*   Flutter `3.35.7` or newer
*   Dart `3.9.4` or newer
*   Java OpenJDK `17`
*   Android SDK (Build-Tools `35`, Platform `36`)

### Installation

1.  **Clone the repo**
    ```sh
    git clone https://github.com/your_username/your_repository.git
    ```
2.  **Set up your environment**
    ```sh
    # Example for setting JAVA_HOME
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
    export PATH=$JAVA_HOME/bin:$PATH
    ```
3.  **Install dependencies**
    ```sh
    flutter pub get
    ```

## Usage

*   **Run on a device**
    ```sh
    flutter run
    ```
*   **Build an APK**
    ```sh
    # For debugging
    flutter build apk --debug

    # For release
    flutter build apk --release
    ```

## Roadmap

**Session 2 Focus: Data Models & Character Creation**

- [ ] Set up Hive for local storage.
- [ ] Create data models (Character, AbilityScores, Skills).
- [ ] Implement the character creation flow.
- [ ] Build the basic character sheet UI.

See the [open issues](https://github.com/your_username/your_repository/issues) for a full list of proposed features (and known issues).

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

QurieGLord - tipquri@gmail.com

Project Link: [https://github.com/your_username/your_repository](https://github.com/your_username/your_repository)

