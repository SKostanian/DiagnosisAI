# DiagnosisAI:

It is an AI-powered health triage assistant built with Flutter, Firebase, Cloud Functions, and Vertex AI.

Author: Spartak
Contact: SKostanian@uclan.ac.uk
Repository: https://github.com/SKostanian/DiagnosisAI

## Table of Contents
- [About the Project](#about-the-project)
  - [Key Features](#key-features)
  - [Technology Stack](#technology-stack)

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Configuration](#configuration)

- [Development](#development)
  - [Running Tests](#running-tests)
  - [Project Structure](#project-structure)

- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Contact](#contact)
- [Acknowledgments](#acknowledgments)

## About the Project:

This application helps users describe their symptoms and receive the AI-assisted triage guidance through an interactive chat interface.

Currently it does not have a medical license and all the diagnoses provided in code and in implementation are experimental. 
Personally, this project was an opportunity to experiment with how medical triage systems works, how Cloud solutions are configured, how the gemini flash model API responds and works. References are commented in code and the parts of project will be discussed in final report.

### Key features
1) AI Questions that are driven from Gemini Flash.
2) Diagnoses output with probabilities (Please make sure to know that they are experimental and do not cover many conditions)
3) Multi-Language Ui
4) Firebase authentification for google. Full registration screen with email send verification.
5) Google Cloud functions
6) Dark and Light theme UI
7) Session handling with firestore.

### Technology Stack
**Frontend**
- Dart Flutter
- Easy Localization
- Material UI

**Backend**
- Firebase Functions (TypeScript)
- Firestore Database

**AI Logic**
- Google Vertex AI, gemini-flash-lite model
- Custom triage logic, normalizations

## Getting started:

### Prerequisites
To setup DiagnosisAI you need:
1)   Android Studio with Android Phone emulator   (https://developer.android.com/studio).
2)   service-account.json   (It is a sensitive file, it holds private API Key and it is submitted on Uclan blackboard).
3)   Flutter SDK   (https://docs.flutter.dev/install).
4)   Firebase CLI   (http://firebaseopensource.com/projects/firebase/firebase-tools).
5)   Npm   (https://docs.npmjs.com/downloading-and-installing-node-js-and-npm).
6)   Node.js   (https://nodejs.org/en/download, project uses Node 22 version for stable work with dependencies).

### Installation
- git clone https://github.com/SKostanian/DiagnosisAI
- cd DiagnosisAI

### Configuration
DiagnosisAI uses service-account.json which holds private information about google authentification private key and app's private key. 

**It MUST NOT be shared with third parties.**

To launch configuration, the following commands are used:

### 1) Configure google credentials
Set the environment variable GOOGLE_APPLICATION_CREDENTIALS to the path of the service-account.json file:
```
$env:GOOGLE_APPLICATION_CREDENTIALS="your path to the service-account.json file"

Example:
$env:GOOGLE_APPLICATION_CREDENTIALS="service-account.json"
```

### 2) Authenticate the service account
Authenticate the local environment to access Google Cloud services with the credentials defined:
```
gcloud auth activate-service-account --key-file=$env:GOOGLE_APPLICATION_CREDENTIALS
```

### 3) Select the google cloud project
Set the project which is used by Google Cloud and Firebase:
```
gcloud config set project health-app-9b2f5
```

### 3) Build firebase cloud functions
Navigate to the functions directory,
```
cd "your path to the DiagnosisAI project"/functions"

Example: cd functions
```
### 4) Install npm and run build
npm install and run the typescript build:
```
npm install
npm run build
```

### 5) Start firebase emulator
Start the local firebase emulators:
```
firebase emulators:start --only "functions,firestore,auth"
```
This allows the app to run locally on emulator. Project is using Cloud functions, firestore database and firebase authentification. 
(It requires some time to run).

### 6) In case of Firebase emulator error (VERY IMPORTANT).
Please run in new Powershell window
```
taskkill /F /IM java.exe
```
try again to launch: `'firebase emulators:start --only "functions,firestore,auth"` and type the flutter command on section 7 in new terminal.

### 7) Open a new terminal
And type:
```
flutter pub get
flutter run
```
To run the flutter locally and see the DiagnosisAI application on emulator.

You can skip registration (tap on red text and select yes) to reach out to the body selection screen and triage quickly.

In case of any errors or unexpected behaviour, please contact here: `SKostanian@uclan.ac.uk`.

## Development.

### Running Tests
- For testing the backend index.ts function go to functions/ folder `cd functions` and use `npm test`.
- For testing the frontend UI and widgets go to root of the project `cd DiagnosisAI` and type `flutter test` in console.

## Project Structure.
<img width="411" height="318" alt="DiagnosisAI drawio" src="https://github.com/user-attachments/assets/ec8ab1c1-1b20-4866-b9aa-09d2d5aebe00" />

## Roadmap

### Planned Features
- Add more questions, symptoms and diagnoses for more body areas (abdomen, hand, leg, skin and many more).
- Add localization of greek for triage.
- Connect registration profiles for each of the triage chat, to save them on each account.

### Known limitations
- Unfortunately could not reach out to medical professionals yet.
- The diagnoses results are not medically certified.
- AI responses for questions and answers may sometimes be inconsistent, general.

### Future improvements
- Integrate more closely and accurately with clinical datasets.
- Add red-flag detection for emergency conditions.
- Add more correlations between user profiles and functionality.
- Have more testing for the app.
- Optimize backend and reduce the time of responses.

## Contributing
- I would like to express my gratitude to Nearchos Paspallis for giving me a guideline and suggestions on how to improve DiagnosisAI project. 
DiagnosisAI project is not a final or fully ready-made product, but an evolving system with clear opportunities for further improvement.

- I am grateful to Infermedica team for giving me access to their API.  
For this project however, I chose to design and implement my own system in order to better understand how such triage systems work in practice.

## Contact
- Spartak
- **SKostanian@uclan.ac.uk**
- https://github.com/SKostanian/DiagnosisAI

## Acknowledgements
This project gave me an understanding on how serverless, AI powered, and medical triage systems work. How they might be configured, how complex ideas can be interpreted into parts of code and connected together.  

