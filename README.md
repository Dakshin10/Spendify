# 🪙 Spendify — Privacy-First Smart Expense Tracker

Spendify is a state-of-the-art, privacy-first personal finance assistant that seamlessly combines **Smart Android SMS Ingestion**, **E-Statement Parsing (PDF/CSV)**, and **Llama-3 Powered AI Categorization** into a gorgeous, responsive Flutter interface.

Unlike generic expense trackers, Spendify implements a **Privacy-First Hybrid Architecture**: it cleanses sensitive Personal Identifiable Information (PII) like account numbers and phone numbers *locally* before using AI to categorize transactions, ensuring your private financial data never leaks.

---

## 🌟 Key Features

*   **📱 Smart Real-Time SMS Ingestor**: Runs in the background, listening for transactional SMS notifications. Automatically parses merchants, amounts, and transaction types (Debit/Credit) with advanced regex.
*   **🤖 AI Categorization Engine**: Leverages `Llama-3` (via Groq API) to accurately tag merchants into smart spending categories (e.g., Food & Beverages, Bills & Utilities, Shopping, Entertainment, etc.) with custom confidence thresholds.
*   **🔒 Local PII Scrubber**: Employs Python-based PII scrubbing on the backend to redact bank account numbers, UPI IDs, names, and phone numbers before submitting transactions to external AI models.
*   **📊 Multi-Source E-Statement Parser**: Import CSV or PDF statements (with password-decryption support) from major banks (HDFC, SBI, ICICI, etc.) for historic analysis.
*   **✨ Deduplication & Near-Duplicate Detector**: Intelligent hashing-based deduplication ensures that an SMS-tracked transaction is not double-counted when you upload your monthly e-statement.
*   **🎨 Premium Glassmorphic UI**: A dark-mode dashboard featuring modern charts, beautiful page transitions, budget goal management, an AI financial chat assistant, and interactive budget wizards.

---

## 🏗️ System Architecture

Spendify utilizes a modern Flutter client-server architecture paired with a fast FastAPI backend. Here is the operational flow of how a transaction is processed:

```mermaid
graph TD
    A[User Transactions] --> B[SMS Messages / E-Statement PDF/CSV]
    
    subgraph Frontend (Flutter)
        B --> C[another_telephony / File Picker]
        C --> D[Local SQLite Database]
        C --> E[Sync Request]
    end

    subgraph Backend (FastAPI + Python)
        E --> F[SMS / Statement Parsers]
        F --> G[PII Scrubber - Local Regex/ML]
        G --> H[Deduplication & Near-Duplicate Engine]
        H --> I[AI Categorization - Groq Llama-3]
        I --> J[SQLite Database & Sync Response]
    end

    J -->|Parsed & Categorized Data| D
```

---

## 🛠️ Technology Stack

### **Frontend App**
*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **Local Storage**: [sqflite](https://pub.dev/packages/sqflite) (SQLite) for zero-latency offline storage
*   **SMS Services**: [another_telephony](https://pub.dev/packages/another_telephony) for secure Android SMS polling
*   **State Management**: `ChangeNotifier` & custom `AnimatedBuilder` architecture
*   **Auth & Config**: [Firebase Core & Auth](https://firebase.google.com/)

### **Backend Server**
*   **Framework**: [FastAPI](https://fastapi.tiangolo.com/) (Python 3.10+)
*   **Statement Extractor**: `pdfplumber` (for secure PDFs) & `pandas` (for CSV processing)
*   **LLM Orchestrator**: Groq SDK (`Llama-3-8b-8192`)
*   **Database**: SQLite with `sqlite3` for light-weight caching and indexing

---

## 🚀 Installation & Setup Guide

### **1. Prerequisites**
Ensure you have the following installed on your machine:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.10+ recommended)
*   [Python 3.10+](https://www.python.org/downloads/)
*   [Android Studio / VS Code](https://developer.android.com/studio) (with Android Emulator or physical device connected)
*   A **Groq Cloud API Key** (Get one free at [console.groq.com](https://console.groq.com/))
*   Firebase Project configuration file (`google-services.json` for Android / `GoogleService-Info.plist` for iOS)

---

### **2. Running the Backend Server**

1.  **Navigate to the backend directory:**
    ```bash
    cd backend
    ```
2.  **Create and activate a Python virtual environment:**
    ```bash
    python -m venv venv
    
    # On Windows:
    .\venv\Scripts\activate
    # On macOS/Linux:
    source venv/bin/activate
    ```
3.  **Install the required dependencies:**
    ```bash
    pip install -r requirements.txt
    ```
    *(Note: If `requirements.txt` is not present, install the core libraries: `pip install fastapi uvicorn pydantic pandas pdfplumber groq python-dotenv`)*
    
4.  **Configure environment variables:**
    *   Create a `.env` file in the `backend` directory (referencing `.env.example`):
        ```env
        GROQ_API_KEY="your_actual_groq_api_key_here"
        ```
5.  **Launch the FastAPI server:**
    ```bash
    # Run from the project root directory
    cd ..
    python -m uvicorn backend.main:app --host 0.0.0.0 --port 8001 --reload
    ```
    The server will start running on **`http://localhost:8001`**.

---

### **3. Running the Flutter Frontend**

1.  **Retrieve dependencies:**
    ```bash
    flutter pub get
    ```
2.  **Connect to Backend:**
    *   By default, `lib/services/api_service.dart` is set to auto-detect if it is running on an Android Emulator, translating the local API URL to `http://10.0.2.2:8001`.
    *   If using a **physical Android device**, ensure your computer and phone are on the same Wi-Fi network, and update `getBackendUrl()` in `lib/services/api_service.dart` with your machine's local IP address (e.g. `http://192.168.1.50:8001`).
3.  **Launch the application:**
    ```bash
    flutter run
    ```

---

## 🔒 Security & Privacy First

1.  **Local Scrubbing**: When SMS/Statements are synced, they are passed through a PII scrubber locally before hitting the LLM. Personal credit card digits, account numbers, and phone numbers are hashed or replaced with `XXXXXXXX`.
2.  **Deduplication Hash**: We use SHA-256 to hash the `(Amount, Date, Raw Description, Type)` of a transaction. If a hash already exists in your local database or backend database, it will be skipped automatically.
3.  **On-device DB**: All charts, transaction feeds, and budgets are rendered from your local SQLite instance, ensuring full offline functionality and private data residency.

---

## 🎨 Walkthrough of the Application

### 🏠 Dashboard
Displays real-time spending insights, recent transactions, category-wise breakdowns, and remaining budgets in a glassmorphic dark-theme design.

### 📁 Statement Upload
Upload bank statements as PDF or CSV. Password-protected PDFs are supported and decrypted locally before parsing.

### 💬 AI Advisor
Interact with an intelligent, context-aware chatbot that analyzes your spending patterns and gives personalized budgeting recommendations.