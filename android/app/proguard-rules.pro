# flutter_local_notifications: conserva clases serializadas con Gson para
# que las notificaciones programadas sobrevivan a R8 en builds de release.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
