# Intune App Protection Policy (MAM): How to exempt iOS app using URL Protocol

This guide explains how to extract **URL protocols (schemes)** from an iOS app IPA file and configure them as exemptions in **Microsoft Intune App Protection Policies (MAM)**. This is required when an app does not support Intune MAM directly but still needs to integrate with **Edge (managed browser)** for SSO.

---

## Why is this needed?

Some apps:

 Do **not support Intune MAM SDK** (cannot be wrapped/protected by Intune).
* Are deployed as **MDM-managed apps** instead.
* Use an **external browser (e.g., Edge)** for completing authentication (SSO).

Without exemption, the **authentication token** returned from the protected browser cannot be passed back into the unmanaged app, leading to SSO errors (e.g., HTTP 403 Forbidden). By exempting the app’s URL scheme, Intune allows the token handoff back into the app.

https://learn.microsoft.com/en-us/intune/intune-service/apps/app-protection-policies-exception
---

## Prerequisites

* macOS device with terminal access.
* [Homebrew](https://brew.sh/) installed.
* [ipatool](https://github.com/majd/ipatool) installed.
* An Apple ID with access to the App Store.

---

## Step 1: Install ipatool

```bash
brew tap majd/repo
brew install ipatool
```

For reference: [ipatool GitHub](https://github.com/majd/ipatool)

---

## Step 2: Authenticate with App Store

```bash
ipatool auth login
```

Follow the prompts to log in with your Apple ID.

---

## Step 3: Download the IPA

```bash
ipatool download --bundle-identifier <com.example.app> --output MyApp.ipa
```

* Replace `<com.example.app>` with the app’s bundle identifier.
* The `.ipa` file will be saved in your current working directory.

---

## Step 4: Extract `Info.plist`

Unzip the `.ipa`:

```bash
unzip MyApp.ipa -d MyApp
```

Locate the `Info.plist`:

```bash
cd MyApp/Payload/<AppName>.app
ls | grep Info.plist
```

---

## Step 5: Read the URL Schemes

Use `plutil` to convert the plist to JSON:

```bash
plutil -convert json Info.plist -o Info.json
cat Info.json | grep CFBundleURLSchemes -A 5
```

Example output:

```json
"CFBundleURLTypes": [
  {
    "CFBundleURLSchemes": [
      "org.benevity.app"
    ]
  },
  {
    "CFBundleURLSchemes": [
      "pendo-9ad6ce34"
    ]
  }
]
```

In this case, the URL schemes are:

* `org.benevity.app`
* `pendo-9ad6ce34`

---

## Step 6: Configure Intune App Protection Policy

1. Go to **Microsoft Intune admin center** → **Apps** → **App protection policies**.
2. Edit the relevant **iOS MAM policy**.
3. Under **Exempt apps (data transfer exemptions)** → **Custom apps**, add the extracted URL schemes.

   * Example: `org.benevity.app`, `pendo-9ad6ce34`
4. Save and deploy the policy.

---

## Step 7: Test the Flow

1. Install the target app on a managed device.
2. Open the app → trigger SSO login.
3. Confirm Edge is used for authentication.
4. Validate that the app receives the auth token and no longer fails with 403 errors.

---

## Troubleshooting

* If the exemption fails, double-check for **multiple URL schemes** in the plist.
* Some apps use **analytics frameworks (e.g., Pendo)** that also need exemption.
* Test all possible flows (login, deep links) after updating Intune.

---

✅ You now have a repeatable process to extract iOS app URL schemes and configure Intune MAM exemptions to ensure seamless SSO handoff between Edge and unmanaged apps.


## Security considerations

Exempting apps from Intune MAM introduces trade-offs:

What’s allowed: Only the token handoff from Edge (or another protected app) to the exempted app, via its unique URL scheme.

What’s not enforced: Once data enters the exempted app, Intune protections no longer apply. For example, copy/paste restrictions or data encryption at rest.

Risks:

The exempted app could expose data outside managed boundaries.

If a malicious app could somehow hijack the scheme (unlikely on iOS due to bundle signing), it might intercept tokens.

Best practice:

Only exempt trusted, business-critical apps.

Keep the exemption list as small as possible.

Involve your security/compliance team for approval.

📖 Microsoft also cautions that this method should be used only when necessary: App protection policies exceptions

## Summary

By extracting the IPA and inspecting Info.plist, you can identify an app’s URL schemes and configure them as exemptions in Intune App Protection Policies. This allows authentication flows (via Edge) to return tokens properly to apps that don’t support Intune MAM. However, exemptions reduce enforcement, so they should be applied carefully and only for trusted apps.
