package com.jayrk.budget_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen widget: month-to-date spend with budget progress, styled
/// after the in-app hero card. Data is written from Flutter via home_widget.
class BudgetWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.budget_widget).apply {
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("title_text", "THIS MONTH"),
                )
                setTextViewText(
                    R.id.widget_spent,
                    widgetData.getString("spent_text", "₹0"),
                )
                setTextViewText(
                    R.id.widget_subtitle,
                    widgetData.getString("subtitle_text", "Set a budget in Budgetify"),
                )
                val progress = widgetData.getInt("progress_percent", -1)
                setViewVisibility(
                    R.id.widget_progress,
                    if (progress >= 0) android.view.View.VISIBLE else android.view.View.GONE,
                )
                if (progress >= 0) {
                    setProgressBar(R.id.widget_progress, 100, progress.coerceAtMost(100), false)
                }
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
