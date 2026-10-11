# Android in-app updates and release signing

The app checks the latest GitHub Release, selects the APK for the device profile, downloads it to temporary app storage, verifies the published SHA-256 digest, and opens Android's package installer. Android still requires the user to approve installation.

## Required one-time setup

Android will only update an installed package when the new APK has the same application ID and is signed by the same signing certificate. The existing CI used an ephemeral runner/debug signing key, so a new APK built on another runner is not guaranteed to update the installed copy. Do not claim automatic updates are ready until a persistent release key is configured.

1. Create a release keystore on a trusted computer and keep a secure offline backup. Never commit the .jks file or send its passwords in chat.

   Example from PowerShell (choose and securely store the passwords when prompted):

       keytool -genkeypair -v -keystore .\reproductor-release.jks -alias reproductor-release -keyalg RSA -keysize 4096 -validity 10000
       [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\reproductor-release.jks")) | Set-Clipboard

2. In the GitHub repository, open **Settings → Secrets and variables → Actions → New repository secret** and create:

   - ANDROID_KEYSTORE_BASE64: Base64 content of the keystore.
   - ANDROID_KEY_ALIAS: alias chosen when creating the keystore.
   - ANDROID_KEY_PASSWORD: password for the key.
   - ANDROID_STORE_PASSWORD: keystore password.

3. Keep this keystore permanently for all future Android mobile, Android TV and Fire TV releases. Losing it means future APKs cannot update existing installations signed with that key.

4. The release workflow now fails closed if these secrets are absent, instead of publishing an APK that cannot reliably update an earlier installation.

## Transition from existing installations

An APK installed before a persistent release key was used may be signed with a different certificate. Android deliberately rejects an in-place update when certificates differ. In that case, the first transition to the stable-signed release may require a one-time reinstall from the new release, which can remove app-private data if Android treats it as a different package or requires uninstalling first. Back up playlists before doing that. After the stable-signed version is installed, subsequent matching releases can be offered from Settings → Updates.

## Security behavior

- Only HTTPS GitHub Release assets for this repository are accepted.
- The app requires a valid SHA-256 digest published by GitHub and checks it before opening the installer.
- Android handles package/signature validation and asks the user to confirm installation.
- A missing APK, missing digest, incomplete download, or failed integrity check blocks installation.
