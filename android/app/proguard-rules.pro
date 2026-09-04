# Aura Quest — release shrinking rules.
#
# Flutter's own engine classes are kept by the plugin's consumer rules;
# these entries cover the plugins this app ships with.

# Supabase / Ktor use reflection on their serializers.
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Passkeys plugin (androidx credentials) reflects on provider classes.
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**

# Keep annotations used for runtime reflection.
-keepattributes *Annotation*, InnerClasses, Signature, EnclosingMethod
