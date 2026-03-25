# DiagnosisAI:

It is an AI-powered health triage assistant built with Flutter, Firebase, Cloud Functions, and Vertex AI.

This application helps users describe their symptoms and receive the AI-assisted triage guidance through an interactive chat interface.
Currently it does not have a medical license and all the diagnoses provided in code and in implementation are experimental. 

# Setup:

To setup DiagnosisAI you need:
1)   Android Studio   (https://developer.android.com/studio).
2)   service-account.json   (It is a sensitive file, it holds private API Key and it is submitted on Uclan blackboard).
3)   Flutter SDK   (https://docs.flutter.dev/install).
4)   Firebase CLI   (http://firebaseopensource.com/projects/firebase/firebase-tools).
5)   Npm   (https://docs.npmjs.com/downloading-and-installing-node-js-and-npm).
6)   Node.js   (https://nodejs.org/en/download, project uses Node 22 version for stable work with dependencies).

# How to Launch?

DiagnosisAI uses service-account.json which holds private information about google authentification private key and app's private key. 

### It MUST NOT be shared with third parties.

To launch, the following commands are used:

## 1) Configure google credentials
Set the environment variable GOOGLE_APPLICATION_CREDENTIALS to the path of the service-account.json file:
```
$env:GOOGLE_APPLICATION_CREDENTIALS="your path to the service-account.json file"

Example:
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\Users\Sasha\StudioProjects\DiagnosisAI\service-account.json"
```

## 2) Authenticate the service account
Authenticate the local environment to access Google Cloud services with the credentials defined:
```
gcloud auth activate-service-account --key-file=$env:GOOGLE_APPLICATION_CREDENTIALS
```

## 3) Select the google cloud project
Set the project which is used by Google Cloud and Firebase:
```
gcloud config set project health-app-9b2f5
```

## 3) Build firebase cloud functions
Navigate to the functions directory,
```
cd "your path to the DiagnosisAI project"/functions"

Example: cd C:\Users\Sasha\StudioProjects\DiagnosisAI\functions
```
and run the typescript build:
```
npm run build
```

## 4) Start firebase emulator
Start the local firebase emulators:
```
firebase emulators:start --only "functions,firestore,auth"
```
This allows the app to run locally on emulator. Project is using Cloud functions, firestore database and firebase authentification.

## 5) Open a new terminal
And type:
```
flutter pub get
flutter run
```
To run the flutter locally and see the DiagnosisAI application on emulator.

## 6) In case of Firebase emulator error (VERY IMPORTANT).
Please run in Powershell window
```
taskkill /F /IM java.exe
```
try again to launch: `'firebase emulators:start --only "functions,firestore,auth"` and type the flutter commands on 5 in new terminal.

In case of any errors or unexpected behaviour, please contact here: `SKostanian@uclan.ac.uk`.

## Testing.
For testing the index.ts function go to functions/ folder `cd functions` and use `npm test`.
