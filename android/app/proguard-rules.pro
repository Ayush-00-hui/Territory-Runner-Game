# Flutter ProGuard/R8 Keep Rules for Territory Runner

# Flutter Engine / Wrapper Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Play Core Deferred Components (when dynamic delivery is not packaged)
-dontwarn com.google.android.play.core.**

# Application Entry Point
-keep class com.territoryrunner.app.** { *; }

# Geolocator Background Location Service
-keep class com.baseflow.geolocator.** { *; }
-keepclassmembers class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geolocator.GeolocatorPlugin { *; }
-dontwarn com.baseflow.geolocator.**

# Firebase Services (Auth, Firestore, Crashlytics, FCM Messaging)
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn javax.annotation.**
-dontwarn java.lang.invoke.**
-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Clipper2 Polygon Engine (JNI / Reflection / Native)
-keep class clipper2.** { *; }
-keep class org.clipper2.** { *; }
-keep class * implements clipper2.** { *; }
-dontwarn clipper2.**

# Hive & Persistence Serialization
-keep class * implements io.hive.** { *; }
-keep class io.hive.** { *; }
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
