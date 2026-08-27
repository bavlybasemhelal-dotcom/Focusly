# -----------------------------------------------------------------------------
# ProGuard / R8 Rules for Focusly
# -----------------------------------------------------------------------------
# CRITICAL FIX FOR:
# java.lang.IllegalStateException: TypeToken must be created with a type argument:
# new TypeToken<...>() {}; When using code shrinkers (ProGuard, R8, ...) make sure
# that generic signatures are preserved.
#
# Root Cause:
# When building release APKs with code shrinking / minification (R8), generic
# signatures are stripped by default unless `-keepattributes Signature` is declared.
# flutter_local_notifications uses Gson's TypeToken inside ScheduledNotificationReceiver
# and ScheduledNotificationBootReceiver to deserialize scheduled notification metadata
# from SharedPreferences. When the alarm triggers or the device boots, missing signatures
# cause an uncaught IllegalStateException that crashes the app ("Focusly keeps stopping").
# -----------------------------------------------------------------------------

# 1. Preserve generic type signatures and runtime annotations for reflection
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# 2. Preserve flutter_local_notifications plugin classes and receivers
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }

# 3. Preserve Google Gson models, serialization, and TypeToken implementations
-keep class com.google.gson.** { *; }
-keepclassmembers class com.google.gson.** { *; }
-keepclassmembers enum * { *; }

# 4. Preserve Firebase and Firestore serialization helpers
-keepattributes SourceFile,LineNumberTable
-keep public class com.google.firebase.** { *; }
