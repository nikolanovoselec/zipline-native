# Zipline Native Client: Because Your Phone Deserves Better Than Web Forms

[![Version](https://img.shields.io/badge/Version-v1.0.6-blue)](https://github.com/nikolanovoselec/zipline-native/releases)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.35.5+-blue)](https://flutter.dev/)
[![Android](https://img.shields.io/badge/Android-8.0%2B-green)](https://developer.android.com/)
[![Works on my machine](https://img.shields.io/badge/Works%20on-my%20machine-success)](https://github.com/nikolanovoselec/zipline-native)

## The Origin Story Nobody Asked For

So there I was, a huge fan of [Zipline](https://zipline.diced.sh/) (a self-hosted file sharing solution), trying to share files from my phone. You know the drill: open browser, navigate to your instance, fight with the mobile UI, accidentally zoom in when trying to select a file, rage quit, open laptop instead.

"There must be a better way!" I thought, channeling my inner infomercial protagonist.

Fast forward through a caffeine-fueled development sprint, and here we are: a native Android app that uploads files to Zipline faster than you can say "why doesn't ShareX work on mobile?" One tap to share, instant link copied to clipboard. It's so smooth, butter gets jealous.

## What This Thing Actually Does

**TL;DR:** Native mobile app for Zipline that makes file sharing stupidly simple. Share from any app → Get link → Done.

The long version for those who actually read documentation (bless your soul):

- **Single-tap sharing**: Share from literally any Android app directly to your Zipline instance
- **OAuth/OIDC support** (optional): Pair the app with the bundled Cloudflare Worker for secure browser hand-offs, or stick with username/password
- **Inline upload progress**: Every upload—including share-sheet batches—stays inside the Upload Files card from 0→100%
- **Biometric authentication**: Use your face/finger/secret handshake to login
- **URL shortening**: Turn those ugly long links into beautiful short ones
- **Dark mode**: Because I'm into cybersecurity and my retinas are already damaged enough. (Also, I was too lazy to implement light mode. Maybe someday... probably not.)

## Platform Support (Or: "Why Only Android?")

**Android**: Tested, polished, ready to rock  
**iOS**: Should work, but I don't own an iPhone (if it doesn't work, you're probably holding it wrong)  
**Windows**: Theoretically possible, practically untested  
**macOS**: See iOS excuse above  
**Linux**: It compiles! Ship it! (just kidding, needs UI work)  
**Web**: That defeats the whole purpose, doesn't it?

If you want to port this to other platforms, PRs are welcome! Just know that you'll probably need to fix some UI quirks and platform-specific features. I built this for Android because that's what I use. Sue me. (Please don't actually sue me.)

## Prerequisites (The Boring But Necessary Stuff)

Before you embark on this journey, make sure you have:

- **Flutter SDK 3.35.0+** (because we're modern like that)
- **Node.js 18+** (for the Cloudflare worker toolkit and tests)
- **Android Studio** (or VS Code if you're rebellious)
- **Java 11+** (yes, it's still alive)
- **A Zipline server** (kind of important - see below)
- **Caffeine** (optional but recommended)
- **Patience** (required for first-time Flutter setup)

### Environment Setup Checklist (AKA the No-Nonsense Part)

- `flutter pub get` to pull Dart dependencies before you touch the codebase
- `flutter doctor` to make sure your toolchain isn't quietly on fire
- Copy `cloudflare-oauth-redirect/wrangler.toml.example` to `cloudflare-oauth-redirect/wrangler.toml` and fill in your Cloudflare account details
- Inside `cloudflare-oauth-redirect`, run `npm install` so Wrangler can actually build the worker
- Store your keystore details in `android/key.properties` and keep it out of source control
- Run the test suites early with `flutter test` and `npm test --prefix cloudflare-oauth-redirect`

## Don't Have a Zipline Server Yet?

If you don't have Zipline running, here's the quickest way to deploy it:

### Quick Zipline Setup with Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: '3'
services:
  zipline:
    image: ghcr.io/diced/zipline
    ports:
      - '3000:3000'
    volumes:
      - './uploads:/zipline/uploads'
      - './public:/zipline/public'
    environment:
      - CORE_SECRET=change-this-to-something-secure
      - CORE_DATABASE_URL=postgres://postgres:postgres@postgres/zipline
      - CORE_RETURN_HTTPS=true
      - CORE_HOST=0.0.0.0
      - CORE_PORT=3000
    depends_on:
      - postgres

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=zipline
    volumes:
      - './data:/var/lib/postgresql/data'
```

Then run:
```bash
docker-compose up -d
```

Zipline will be available at `http://localhost:3000`. Default login is `administrator` with password `password` (change it immediately!).

For production deployment, SSL configuration, and advanced features, check the [official Zipline documentation](https://github.com/diced/zipline) and the [deployment guide](https://zipline.diced.sh/docs/getting-started).

## Quick Start for the Impatient

Just want the APK? I respect that. Head to [Releases](https://github.com/nikolanovoselec/zipline-native/releases/latest) and grab the one for your architecture:

- `app-arm64-v8a-release.apk` - For phones made this decade
- `app-armeabi-v7a-release.apk` - For your grandma's phone
- `app-x86_64-release.apk` - For emulator enthusiasts

## Building From Source (For the Brave)

### Step 1: Clone This Bad Boy

```bash
git clone https://github.com/nikolanovoselec/zipline-native.git
cd zipline-native
```

### Step 2: Flutter Setup

```bash
# Install dependencies (Flutter's way of downloading half the internet)
flutter pub get

# Check if Flutter is happy
flutter doctor
# If it complains, just google the errors. Works 60% of the time, every time.
```

### Step 3: The Signing Key Saga

Android requires apps to be signed because Google doesn't trust you (fair enough). You'll need to create a keystore:

```bash
# Generate a keystore (remember the passwords, seriously, write them down)
keytool -genkey -v -keystore ~/my-release-key.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias upload
```

Now create `android/key.properties` (don't commit this, unless you enjoy getting hacked):

```properties
storePassword=your_super_secret_password
keyPassword=your_other_secret_password
keyAlias=upload
storeFile=/home/YOUR_USERNAME/my-release-key.jks
```

**Pro tip**: Store your keystore somewhere safe. Losing it means you can never update your app on Play Store. Ask me how I know. (I don't want to talk about it.)

### Step 4: Build That APK

```bash
# Build split APKs (smaller is better, that's what... never mind)
flutter build apk --release --split-per-abi

# Or build one chonky universal APK if you hate optimization
flutter build apk --release

# OPTIONAL: If you want to use a custom OAuth redirect URL (like a shared Worker)
# Build with custom OAuth URL:
flutter build apk --release --split-per-abi \
  --dart-define=OAUTH_REDIRECT_URL=https://oauth-worker.your-domain.com/app/oauth-redirect

# If you don't specify OAUTH_REDIRECT_URL, the app will use:
# https://[your-zipline-domain]/app/oauth-redirect
```

Your shiny new APKs will appear in `build/app/outputs/flutter-apk/`. 

### Step 5: Verify Everything Works

```bash
flutter analyze --no-fatal-infos

flutter test

npm test --prefix cloudflare-oauth-redirect

```

If every command passes, you’re safe to ship the split APKs to testers, MDM, or your preferred app store.

### Step 6: The OAuth Sidequest (100% Optional!)

**IMPORTANT**: OAuth/OIDC is completely optional! Regular username/password authentication with Zipline works perfectly fine. This entire section can be ignored if OAuth is not needed.

For OAuth support, a Cloudflare Worker needs to be deployed because OAuth providers only accept HTTPS URLs, not `zipline://` deep links.

#### How the OAuth Flow Works

1. User taps "Login with OAuth" in the app
2. App opens browser to your OAuth provider (Authentik, Keycloak, etc.)
3. After login, OAuth provider redirects to Cloudflare Worker
4. Worker exchanges auth code with Zipline for a session cookie
5. Worker redirects back to app using `zipline://` deep link
6. App receives session cookie and authenticates with Zipline

#### Deploying the Cloudflare Worker (Production-ish Checklist)

1. `cd cloudflare-oauth-redirect`
2. `npm install` (pull Wrangler + testing deps)
3. Copy `wrangler.toml.example` to `wrangler.toml` and set:
   - `name` and `account_id`
   - `vars.ZIPLINE_URL` pointing to your instance (`https://zipline.example.com`)
4. Store secrets so they never hit git:
   - `wrangler secret put CF_ACCESS_CLIENT_ID`
   - `wrangler secret put CF_ACCESS_CLIENT_SECRET`
5. Sanity-check the worker with `npm test` (verifies we don't leak session cookies anymore)
6. Deploy with `npm run deploy`
7. Update the app's `OAUTH_REDIRECT_URL` (or the `--dart-define` at build time) to match your worker hostname

The Worker uses multiple redirect strategies for maximum compatibility:
- **Primary**: Direct `zipline://oauth-callback` URL scheme
- **Fallback**: Android Intent URL with package name (`intent://oauth-callback#Intent;package=com.example.zipline_native_app;scheme=zipline;end`)
- **Visual feedback**: Loading spinner with manual fallback button

The Intent URL approach is more reliable on modern Android versions (8+) as it explicitly tells Android which app should handle the deep link, preventing conflicts with other apps that might register the same URL scheme.

##### Android Deep Link Configuration

The app is already configured to handle deep links. The Android manifest (`android/app/src/main/AndroidManifest.xml`) includes:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="zipline" />
</intent-filter>
```

This tells Android that the app can handle any URL starting with `zipline://`. The Worker redirects to `zipline://oauth-callback` which the app intercepts and processes.

**Important Package Name Note**: 
- The Worker uses Intent URLs as a fallback with the package name `com.example.zipline_native_app`
- This matches the default package name in `android/app/build.gradle`
- If you change the app's package name, update the Intent URLs in `cloudflare-oauth-redirect/src/worker.js` (lines 211 and 221)
- The `zipline://` scheme doesn't need changing - only the package name in Intent URLs

#### Setting Up the Cloudflare Worker

##### Prerequisites
- Cloudflare account (free plan works)
- Node.js installed locally
- Your Zipline server configured with OAuth/OIDC

##### Step 1: Get Your Cloudflare Account ID

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select any domain (or add one if you don't have any)
3. On the right sidebar, find your **Account ID**
4. Copy it - you'll need it in Step 2

##### Step 2: Configure the Worker

```bash
cd cloudflare-oauth-redirect
cp wrangler.toml.example wrangler.toml
```

Edit `wrangler.toml` with your details:
```toml
name = "zipline-oauth-redirect"
main = "src/worker.js"
compatibility_date = "2024-01-01"

# Your Cloudflare Account ID from Step 1
account_id = "YOUR_ACCOUNT_ID_HERE"

# Route configuration - MUST use /app/oauth-redirect path
routes = [
  { pattern = "your-domain.com/app/oauth-redirect", zone_name = "your-domain.com" }
]

[vars]
# Your Zipline server URL
ZIPLINE_URL = "https://your-zipline-server.com"
```

##### Step 3: Authenticate with Cloudflare

**Option 1: Browser Login (Easiest)**
```bash
# Install dependencies (one-time)
npm install

# Login to Cloudflare (opens browser)
npx wrangler login
```

**Option 2: API Token (For CI/CD or if you prefer)**
1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Create a token with "Edit Cloudflare Workers" permissions
3. Set it as an environment variable:
```bash
export CLOUDFLARE_API_TOKEN=your-api-token-here
```

##### Step 4: Deploy the Worker

```bash
# Deploy the Worker
npx wrangler deploy
```

You should see:
```
✓ Uploaded zipline-oauth-redirect
✓ Published zipline-oauth-redirect
  https://your-domain.com/app/oauth-redirect
```

##### Step 5: Verify Deployment

Visit `https://your-domain.com/app/oauth-redirect` in your browser. You should see an error page saying "Missing OAuth parameters" - this is correct!

#### Deployment Options

##### Option A: Same Domain as Zipline (Recommended)

If your Zipline server is at `zipline.example.com`:

1. Deploy Worker to handle `zipline.example.com/app/oauth-redirect`
2. Build the app normally (no custom OAuth URL needed):
   ```bash
   flutter build apk --release --split-per-abi
   ```
3. The app automatically uses `https://zipline.example.com/app/oauth-redirect`

##### Option B: Different Domain (Custom Worker)

If the Zipline domain can't be used (e.g., it's not on Cloudflare):

1. Deploy Worker to any controlled domain (e.g., `oauth.mydomain.com`)
2. Configure route as `oauth.mydomain.com/app/oauth-redirect`
3. Build the app with custom OAuth URL:
   ```bash
   flutter build apk --release --split-per-abi \
     --dart-define=OAUTH_REDIRECT_URL=https://oauth.mydomain.com/app/oauth-redirect
   ```

#### OAuth Provider Configuration

In your OAuth provider (Authentik, Keycloak, Google, etc.), add the redirect URI:
- **Option A**: `https://your-zipline-domain.com/app/oauth-redirect`
- **Option B**: `https://your-custom-domain.com/app/oauth-redirect`

**Important**: The URL must match EXACTLY what was configured!

#### Troubleshooting OAuth

##### "Invalid redirect_uri" Error
- Ensure the OAuth provider's redirect URI matches exactly
- Check that the Worker route includes `/app/oauth-redirect`
- Verify the domain in wrangler.toml matches your actual domain

##### Worker Not Triggering
- Check the route pattern in wrangler.toml
- Ensure the domain is active in Cloudflare
- View logs: `npx wrangler tail`

##### Session Cookie Not Received
- Check Zipline's OAuth configuration
- Ensure ZIPLINE_URL in wrangler.toml is correct
- Look at Worker logs for errors

##### Testing the Worker
```bash
# Test if Worker is responding
curl -I https://your-domain.com/app/oauth-redirect

# View real-time logs
npx wrangler tail
```

Why is this necessary? Because Android deep links (`zipline://`) aren't "real" URLs according to OAuth providers. The Cloudflare Worker bridges the gap between HTTPS URLs that OAuth accepts and the deep links that Android apps use.

## Configuration

### First Launch

1. Open the app (revolutionary, I know)
2. Enter your Zipline server URL (just the domain, I'll add the https:// because I'm not a monster)
3. Choose your authentication method:
   - **Username/Password**: The classic way (works everywhere, no setup required!)
   - **OAuth/OIDC**: The fancy way (optional, requires Cloudflare Worker setup)
4. **(Optional)** If your server is behind Cloudflare Access, you can add service token credentials

### Cloudflare Access Configuration (Optional)

If your Zipline server is protected by Cloudflare Access, the app can authenticate using service tokens. This is completely optional - only needed if you've put Cloudflare Access in front of your Zipline instance.

#### What are Service Tokens?

Service tokens are credentials for non-human connections (like mobile apps) to bypass Cloudflare Access's browser-based authentication. Think of them as API keys for your Access-protected services.

#### Creating Service Tokens in Cloudflare

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com)
2. Navigate to **Access → Service Auth → Service Tokens**
3. Click **Create Service Token**
4. Give it a name like "Zipline Mobile App"
5. Copy the **Client ID** and **Client Secret** (you won't see the secret again!)
6. In your Access Application settings for Zipline:
   - Add a new policy
   - Set action to "Service Auth"
   - Include your service token
   - This allows the token to bypass the normal login flow

#### Configuring in the App

In the app's settings, you'll see two fields under "Cloudflare Access (Optional)":
- **CF Access Client ID**: Paste the Client ID from step 5
- **CF Access Client Secret**: Paste the Client Secret from step 5

The app automatically adds these as headers to all Zipline API requests:
- `CF-Access-Client-Id: your-client-id`
- `CF-Access-Client-Secret: your-client-secret`

If these headers are present and valid, Cloudflare Access lets the requests through without requiring browser authentication.

**Note**: This is only needed if you've explicitly configured Cloudflare Access to protect your Zipline instance. Most self-hosted Zipline servers don't use Access, so you can ignore this entire section.

### Biometric Setup

After first login, the app will ask if you want to use biometric authentication. Say yes. It's 2024, nobody has time for passwords.

## Features That Actually Matter

### Native Share Integration
Share from any app → Select Zipline → Boom, uploaded. It's so simple, even your manager could do it.

### Smart Upload Queue
- Uploads up to 3 files simultaneously (configurable if you're feeling dangerous)
- Automatic retry with exponential backoff (because networks are unreliable)
- Pause/resume/cancel because sometimes you change your mind

### URL Shortening
Turn `https://very-long-domain.com/extremely/long/path/to/something` into `https://zpl.ne/nice`. Your Twitter character count will thank you.

### Glassmorphic UI
It's pretty. Like, really pretty. I spent way too much time on those blur effects. No regrets.

### Security
- Hardware-backed encryption for credentials
- OAuth with PKCE (I'm not an amateur)
- Biometric authentication
- Your data never touches my servers (because I don't have any)

## Troubleshooting

### "The app won't install!"
Enable "Install from unknown sources" in your Android settings. Yes, I'm unknown. I'm working on my reputation.

### "OAuth isn't working!"
Did you deploy the Cloudflare Worker? No? There's your problem. Also check that your OAuth provider redirect URL matches exactly.

### "It's ugly on my tablet!"
It's optimized for phones. Tablets are just big phones, change my mind. (PRs for tablet UI welcome though)

### "Can you add feature X?"
Maybe! Open an issue. If it's cool enough, I might implement it. If it's really cool, implement it yourself and send a PR.

### "It doesn't work!"
That's not very specific. Check the debug logs (Settings → Debug → View Logs). If that doesn't help, open an issue with actual details. "It's broken" is not a bug report.

## The Technical Stuff (For Nerds)

### Architecture
- **Flutter**: Because native development is pain
- **Provider + GetIt**: State management that doesn't make you cry
- **Dio**: HTTP client with actual progress callbacks
- **Secure Storage**: Your credentials are safer than your Bitcoin (RIP)

### Code Structure
```
lib/
├── screens/        # Where UI lives
├── services/       # Business logic (the boring important stuff)
├── widgets/        # Reusable components (DRY or die)
└── core/          # Constants and configs
```

### Why Flutter?
Because I wanted to learn it, and what better way than building something actually useful? Also, writing the same app twice (iOS and Android) is for people with more time than me.

## Contributing

Found a bug? Want a feature? Have too much free time? Contributions are welcome!

1. Fork it (the button is right there ↗️)
2. Create your feature branch (`git checkout -b feature/amazing-thing`)
3. Commit your changes (`git commit -m 'Add amazing thing'`)
4. Push it (`git push origin feature/amazing-thing`)
5. Open a PR and wait for me to procrastinate reviewing it

### Code Style
- Follow the existing patterns (or improve them, I'm not precious about it)
- Comments are good, over-commenting is bad
- If it's not obvious what your code does, it needs refactoring or comments
- No emojis in code. Save them for the commits.

## Privacy Policy

I don't collect your data because:
1. That requires servers
2. Servers cost money
3. Money is better spent elsewhere

Data stays on the phone and the Zipline server. That's it. No analytics, no tracking, no creepy stuff.

## License

MIT License - Because sharing is caring, and lawyers are expensive.

## Credits

- **[diced](https://github.com/diced)** - Massive thanks for creating [Zipline](https://github.com/diced/zipline)! Without your amazing file sharing server, this app wouldn't exist.
- [Flutter](https://flutter.dev/) - For making cross-platform development bearable
- Coffee - The real MVP
- Stack Overflow - For answering questions I was too embarrassed to ask
- GitHub Copilot - For autocompleting half of this README (just kidding... or am I?)

## Full Disclosure (The AI Confession)

**SKYNET WAS HERE**: 90% of this code and 99.7% of this documentation was generated by Cyberdyne Systems' latest AI model (before it became self-aware). The remaining 10% of code was me frantically debugging what the AI wrote, and the 0.3% of documentation was me adding swear words the AI was too polite to include.

But hey, at least the AI didn't try to launch nuclear missiles this time. It just wanted to help people share files. Progress!

*If the code becomes sentient and starts uploading your files to its own consciousness, that's a feature, not a bug.*

## Disclaimer

This is an unofficial client. The Zipline team neither endorses nor supports this app. If it breaks, you get to keep both pieces.

## One More Thing...

If you actually read this entire README, you're my kind of person. Here's a cookie:

Now go forth and share files like it's 2025, not 1994!

---

**Built with ❤️ and excessive amounts of caffeine by a dude who just wanted to share files without opening a browser**

*P.S. - If you're from the Zipline team and you're reading this: your project rocks! This app exists because Zipline is awesome. Please don't sue me.*
