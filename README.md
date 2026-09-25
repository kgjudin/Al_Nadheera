# Al Nadheera Construction & Site Operations Management Platform

Executive construction management mobile application and backend services built for real-time site operational, financial, and inventory tracking.

## Architecture & Tech Stack

- **Frontend**: Flutter / Dart (Cross-platform iOS & Android application)
- **Backend**: Node.js / Express REST API
- **Database & Realtime Services**: Supabase (PostgreSQL, Realtime Subscriptions, Auth, RLS Policies)
- **Cloud Deployment**: Render (`render.yaml` configuration included)

## Key Features

1. **Dashboard Operations Hub**: Live total site metrics, assigned budget tracking, total spent aggregation, and active projects overview.
2. **Site Details & Financial Modules**:
   - **Summary Tab**: Inflow tracking, cash expense logging, and balance management.
   - **Labour Cost Tab**: Headcount tracking, trade rates, total shift calculations, and pending payments.
   - **Material Cost Tab**: Supplier tracking, invoice numbers, VAT calculations, and remarks.
   - **Sub Contractors Tab**: Subcontractor invoice management, tax numbers, and expense logging.
   - **Additional Expenses & Tasks**: Custom expense tracking and site task progress board.
   - **Site Chat**: Real-time group chat communication per project site.
3. **Products & Inventory**: Manage construction products, prices, unit rates, and database syncing.
4. **Income Budget Files**: Track external budget files, spent items, category breakdowns, and pie chart visual analytics.

## Getting Started

### Backend Setup
```bash
cd backend
npm install
npm start
```

### Mobile App Setup
```bash
cd mobile
flutter pub get
flutter run
```

## Render Deployment
Deploy the backend by connecting this repository to Render. Render will automatically pick up `render.yaml`.
