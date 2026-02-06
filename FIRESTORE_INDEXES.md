# Firestore and Behaviour Analysis

Behaviour analysis fetches all journal entries, reminders, and game scores for the patient from Firestore (using simple single-field queries), then filters by the selected date range in the app. No composite indexes or Firebase CLI are required.
