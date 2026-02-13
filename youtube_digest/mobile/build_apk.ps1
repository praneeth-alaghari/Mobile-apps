# Build the APK
# Set JAVA_HOME to the Android Studio bundled JDK to fix the "invalid javaHome" error
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
flutter build apk --release

# Get the path to the APK
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
$desktopPath = [Environment]::GetFolderPath("Desktop")
$destPath = [System.IO.Path]::Combine($desktopPath, "yt_digest.apk")

# Copy to Desktop
if (Test-Path $apkPath) {
    Copy-Item $apkPath $destPath
    Write-Host "Success! APK has been copied to your Desktop as yt_digest.apk" -ForegroundColor Green
} else {
    Write-Host "Error: APK not found at $apkPath" -ForegroundColor Red
}
