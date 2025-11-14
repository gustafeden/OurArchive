# Enable Email/Password Authentication in Firebase

## Quick Fix

You're seeing "Email sign-up is not enabled" because Email/Password authentication isn't enabled in your Firebase project yet.

## Steps to Enable

### 1. Go to Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your **OurArchive** project

### 2. Navigate to Authentication
1. In the left sidebar, click **Authentication**
2. Click the **Sign-in method** tab at the top

### 3. Enable Email/Password
1. Find **Email/Password** in the list of providers
2. Click on it
3. Toggle the **Enable** switch to ON
4. Click **Save**

**That's it!** The feature will work immediately - no need to redeploy your app.

## Visual Guide

```
Firebase Console
└── Your Project (OurArchive)
    └── Authentication
        └── Sign-in method tab
            └── Email/Password
                └── [Toggle to Enable]
                └── Click Save
```

## What Gets Enabled

Once enabled, users can:
- ✅ Sign up with email and password
- ✅ Sign in with email and password
- ✅ Upgrade anonymous accounts to email accounts (preserving all data)

## Other Sign-In Methods (Optional)

While you're there, you can also enable:
- **Google Sign-In** (recommended for easier sign-in)
- **Apple Sign-In** (required for App Store if you have other social logins)
- **Anonymous** (should already be enabled)

## Testing

After enabling:

### Test 1: Create New Account
1. Launch app
2. Tap "Sign in with Email"
3. Tap "Create New Account"
4. Enter email and password
5. Should create account successfully

### Test 2: Upgrade Anonymous Account
1. Launch app
2. Sign in anonymously (if not already)
3. Create a household
4. Tap "Sign in with Email" (from settings/welcome)
5. Tap "Create New Account"
6. Enter email and password
7. Should upgrade account and preserve household

### Test 3: Sign In
1. Sign out
2. Tap "Sign in with Email"
3. Enter your credentials
4. Should sign in successfully

## Troubleshooting

### Still getting error?
- Make sure you clicked **Save** after enabling
- Try refreshing the Firebase Console page
- Wait 30 seconds and try again (sometimes takes a moment to propagate)

### Other errors?
- **"Email already in use"** - Try signing in instead of signing up
- **"Weak password"** - Password must be at least 6 characters
- **"Invalid email"** - Check email format (needs @ and .)

## Security Notes

Email/Password authentication is:
- ✅ Secure (passwords are hashed)
- ✅ Free (no cost for authentication)
- ✅ Private (no third-party involved)
- ✅ Reliable (Firebase handles everything)

## Next Steps

After enabling, consider:
1. Test account creation and sign-in
2. Test anonymous account upgrade
3. Add Google Sign-In (makes sign-in easier for users)
4. Set up password reset emails (in Firebase Console → Authentication → Templates)

---

**This is a one-time setup.** Once enabled, it works for all users automatically!
