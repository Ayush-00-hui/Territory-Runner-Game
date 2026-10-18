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

# Firebase Services (Auth, Firestore, Messaging)
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn javax.annotation.**
-dontwarn java.lang.invoke.**
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Hive & Persistence Serialization
-keepattributes EnclosingMethod
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
