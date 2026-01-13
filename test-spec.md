# Test Spec: User Notification Feature

## Overview
Add a notification system to alert users when their tasks complete.

## Proposed Implementation

### Frontend
- New `NotificationToast` component for displaying alerts
- New `NotificationBell` icon component in header
- Extend `Button` with `notification` variant for dismiss action

### Backend
- New `POST /api/notifications` route to create notifications
- New `GET /api/notifications` route to fetch user notifications
- New `NotificationService` for handling notification logic

### Data
- New `notification_status` enum: `unread`, `read`, `dismissed`
- New `notifications` table with user_id, message, status, created_at

### Auth
- New `notifications:read` permission scope
- New `notifications:write` permission scope
