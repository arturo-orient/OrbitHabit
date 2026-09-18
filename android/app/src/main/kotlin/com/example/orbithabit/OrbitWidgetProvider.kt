package com.example.orbithabit

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class OrbitWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Open App on Widget Click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val title = widgetData.getString("widget_title", "Órbita Zen")
                val content = widgetData.getString("widget_content", "Cargando hábitos...")
                val progress = widgetData.getInt("widget_progress", 0)

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_content, content)
                
                // Actualizar barra de progreso y texto
                setProgressBar(R.id.widget_progress, 100, progress, false)
                setTextViewText(R.id.widget_progress_text, "${progress}%")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
