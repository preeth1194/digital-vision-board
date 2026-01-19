#!/bin/bash

# Script to update imports after reorganization
# This updates service and screen imports to match the new folder structure

cd /workspace/lib

# Update service imports
find . -name "*.dart" -type f -exec sed -i \
  -e "s|import '../services/boards_storage_service.dart'|import '../../services/board/boards_storage_service.dart'|g" \
  -e "s|import 'services/boards_storage_service.dart'|import 'services/board/boards_storage_service.dart'|g" \
  -e "s|import '../services/vision_board_components_storage_service.dart'|import '../../services/board/vision_board_components_storage_service.dart'|g" \
  -e "s|import 'services/vision_board_components_storage_service.dart'|import 'services/board/vision_board_components_storage_service.dart'|g" \
  -e "s|import '../services/grid_tiles_storage_service.dart'|import '../../services/board/grid_tiles_storage_service.dart'|g" \
  -e "s|import 'services/grid_tiles_storage_service.dart'|import 'services/board/grid_tiles_storage_service.dart'|g" \
  -e "s|import '../services/dv_auth_service.dart'|import '../../services/auth/dv_auth_service.dart'|g" \
  -e "s|import 'services/dv_auth_service.dart'|import 'services/auth/dv_auth_service.dart'|g" \
  -e "s|import '../services/app_settings_service.dart'|import '../../services/utils/app_settings_service.dart'|g" \
  -e "s|import 'services/app_settings_service.dart'|import 'services/utils/app_settings_service.dart'|g" \
  -e "s|import '../services/logical_date_service.dart'|import '../../services/utils/logical_date_service.dart'|g" \
  -e "s|import 'services/logical_date_service.dart'|import 'services/utils/logical_date_service.dart'|g" \
  -e "s|import '../services/reminder_summary_service.dart'|import '../../services/utils/reminder_summary_service.dart'|g" \
  -e "s|import 'services/reminder_summary_service.dart'|import 'services/utils/reminder_summary_service.dart'|g" \
  -e "s|import '../services/daily_overview_service.dart'|import '../../services/utils/daily_overview_service.dart'|g" \
  -e "s|import 'services/daily_overview_service.dart'|import 'services/utils/daily_overview_service.dart'|g" \
  -e "s|import '../services/notifications_service.dart'|import '../../services/utils/notifications_service.dart'|g" \
  -e "s|import 'services/notifications_service.dart'|import 'services/utils/notifications_service.dart'|g" \
  -e "s|import '../services/sync_service.dart'|import '../../services/sync/sync_service.dart'|g" \
  -e "s|import 'services/sync_service.dart'|import 'services/sync/sync_service.dart'|g" \
  -e "s|import '../services/habit_geofence_tracking_service.dart'|import '../../services/habits/habit_geofence_tracking_service.dart'|g" \
  -e "s|import 'services/habit_geofence_tracking_service.dart'|import 'services/habits/habit_geofence_tracking_service.dart'|g" \
  -e "s|import '../services/habit_timer_state_service.dart'|import '../../services/habits/habit_timer_state_service.dart'|g" \
  -e "s|import 'services/habit_timer_state_service.dart'|import 'services/habits/habit_timer_state_service.dart'|g" \
  -e "s|import '../services/image_persistence.dart'|import '../../services/image/image_persistence.dart'|g" \
  -e "s|import 'services/image_persistence.dart'|import 'services/image/image_persistence.dart'|g" \
  -e "s|import '../services/image_service.dart'|import '../../services/image/image_service.dart'|g" \
  -e "s|import 'services/image_service.dart'|import 'services/image/image_service.dart'|g" \
  -e "s|import '../services/image_region_cropper.dart'|import '../../services/image/image_region_cropper.dart'|g" \
  -e "s|import 'services/image_region_cropper.dart'|import 'services/image/image_region_cropper.dart'|g" \
  -e "s|import '../services/journal_storage_service.dart'|import '../../services/journal/journal_storage_service.dart'|g" \
  -e "s|import 'services/journal_storage_service.dart'|import 'services/journal/journal_storage_service.dart'|g" \
  {} \;

echo "Service imports updated"
