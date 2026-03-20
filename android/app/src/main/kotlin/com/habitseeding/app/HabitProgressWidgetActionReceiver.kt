package com.habitseeding.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class HabitProgressWidgetActionReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    if (intent?.action != ACTION_TOGGLE_HABIT) return
    val habitId = intent.getStringExtra(EXTRA_HABIT_ID)?.trim().orEmpty()
    if (habitId.isEmpty()) return

    HabitProgressWidgetStore.enqueueToggleAction(context, habitId)
    HabitProgressWidgetStore.applyOptimisticToggleToSnapshot(context, habitId)
    HabitProgressAppWidget.updateAll(context)
  }

  companion object {
    const val ACTION_TOGGLE_HABIT = "com.habitseeding.app.action.TOGGLE_HABIT_FROM_WIDGET"
    const val EXTRA_HABIT_ID = "extra_habit_id"
  }
}
