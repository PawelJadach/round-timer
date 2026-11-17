-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

-keep class app.roundtimer.** { *; }

-keep class androidx.compose.** { *; }
-keep class kotlin.Metadata { *; }
-keepclassmembers class * {
    @androidx.compose.runtime.Composable *;
}

-dontwarn org.jetbrains.annotations.**
-dontwarn kotlin.coroutines.jvm.internal.**
-dontwarn androidx.compose.**