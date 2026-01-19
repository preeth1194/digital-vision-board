# Keystore Alias Mismatch - Troubleshooting

## The Problem

The error shows:
```
No key with alias '***' found in keystore
```

This means the **key alias** in your GitHub secret doesn't match the alias you used when creating the keystore.

## Solution

### Step 1: Check What Alias You Used

When you created the keystore, you specified an alias. Common aliases are:
- `upload`
- `key`
- `release`
- `androidkey`

**If you don't remember**, you can check by listing the keys in your keystore:

```bash
# On your local machine where you have the keystore:
keytool -list -v -keystore android/upload-keystore.jks
```

You'll be prompted for the keystore password, then you'll see output like:
```
Keystore type: JKS
Keystore provider: SUN

Your keystore contains 1 entry

Alias name: upload  <-- THIS IS YOUR ALIAS
Creation date: Jan 19, 2025
Entry type: PrivateKeyEntry
Certificate chain length: 1
...
```

### Step 2: Update GitHub Secret

1. Go to GitHub → Your repo → **Settings** → **Secrets and variables** → **Actions**
2. Go to **Production** environment (or Repository secrets if you used those)
3. Find `ANDROID_KEY_ALIAS`
4. Update it to match the alias from Step 1
5. Save

### Step 3: Re-run the Workflow

Push a new commit or manually trigger the workflow. It should now work.

---

## Common Issues

### Issue 1: Wrong Alias Name

**Symptom:** "No key with alias 'xxx' found"

**Fix:** 
- Check the actual alias in your keystore using `keytool -list`
- Update the `ANDROID_KEY_ALIAS` secret to match exactly (case-sensitive!)

### Issue 2: Keystore Created with Different Alias

**Symptom:** You created the keystore with alias `mykey` but secret says `upload`

**Fix:**
- Option A: Update the secret to match your keystore alias
- Option B: Re-create the keystore with the alias you want to use

### Issue 3: Multiple Keys in Keystore

**Symptom:** Keystore has multiple aliases, not sure which one to use

**Fix:**
- Use `keytool -list` to see all aliases
- Use the one you created most recently, or the one you intended for release signing
- Update `ANDROID_KEY_ALIAS` to that alias

---

## Quick Verification Commands

### List all aliases in keystore:
```bash
keytool -list -keystore android/upload-keystore.jks
```

### Get detailed info about a specific alias:
```bash
keytool -list -v -keystore android/upload-keystore.jks -alias upload
```

### Verify keystore file is valid:
```bash
keytool -list -v -keystore android/upload-keystore.jks
# If it prompts for password and shows keys, it's valid
```

---

## Standard Setup

If you're creating a new keystore, use this standard setup:

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Then set:
- `ANDROID_KEY_ALIAS` = `upload`
- `ANDROID_KEYSTORE_PASSWORD` = your keystore password
- `ANDROID_KEY_PASSWORD` = your key password (can be same)

---

## For GitHub Actions

Make sure your Production environment (or Repository) secrets have:

| Secret Name | Value | Example |
|------------|-------|---------|
| `ANDROID_KEYSTORE_BASE64` | Base64 encoded keystore | (very long string) |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | `MyPassword123!` |
| `ANDROID_KEY_PASSWORD` | Key password | `MyPassword123!` |
| `ANDROID_KEY_ALIAS` | **Must match keystore alias** | `upload` |

**The alias must match exactly** (case-sensitive, no spaces).
