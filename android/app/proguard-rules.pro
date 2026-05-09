# flutter_local_notifications — R8 minification ile sınıf bilgisi kaybını önler
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Health Connect — sınıf bilgisi kaybını önler
-keep class androidx.health.** { *; }
-keep class com.google.android.apps.healthdata.** { *; }
