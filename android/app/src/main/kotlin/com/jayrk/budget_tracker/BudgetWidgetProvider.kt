package com.jayrk.budget_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen widget: month-to-date spend, budget progress, income, net,
/// and top spending category, styled after the in-app hero card. Data is
/// written from Flutter via home_widget.
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
                    widgetData.getString("title_text", "THIS MONTH · SPENT"),
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

                // Insight row
                setTextViewText(R.id.widget_income, widgetData.getString("income_text", "₹0"))
                val net = widgetData.getString("net_text", "₹0")
                setTextViewText(R.id.widget_net, net)
                val netPositive = widgetData.getBoolean("net_positive", true)
                setTextColor(
                    R.id.widget_net,
                    if (netPositive) Color.parseColor("#4CC795") else Color.parseColor("#E8888C"),
                )

                val topCategory = widgetData.getString("top_category_text", "")
                setTextViewText(R.id.widget_top_category, topCategory)
                setViewVisibility(
                    R.id.widget_top_category,
                    if (topCategory.isNullOrEmpty()) android.view.View.GONE else android.view.View.VISIBLE,
                )

                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
