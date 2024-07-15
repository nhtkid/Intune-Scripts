# 🚀 Intune-Scripts Repository

Welcome to the Intune-Scripts repository! 🎉 This collection of PowerShell scripts is designed to enhance and streamline your Microsoft Intune management experience.

## 📚 Table of Contents

- [🎯 Purpose](#-purpose)
- [📂 Repository Structure](#-repository-structure)
- [🛠️ Scripts](#️-scripts)
- [🚀 Getting Started](#-getting-started)
- [📝 Usage](#-usage)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

## 🎯 Purpose

This repository aims to provide IT administrators and Intune enthusiasts with a set of powerful scripts to automate tasks, enhance security, and improve the overall management of devices through Microsoft Intune.

## 📂 Repository Structure

```
Intune-Scripts/
├── AutoPilot/
│   └── ... (AutoPilot related scripts)
├── Kiosk/
│   └── ... (Kiosk mode configuration scripts)
├── Remediation/
│   └── ... (Intune remediation scripts)
└── README.md
```

## 🛠️ Scripts

Here's a quick overview of the main scripts in this repository:

### 🖥️ AutoPilot Scripts
- `Get-WindowsAutoPilotInfo.ps1`: Retrieves AutoPilot information from devices.

### 🔒 Kiosk Scripts
- `Configure-KioskAutoLogon.ps1`: Sets up auto-logon for kiosk devices.

### 🩹 Remediation Scripts
- `Detect-KioskAutoLogon.ps1`: Detects if kiosk auto-logon is properly configured.
- `Remediate-KioskAutoLogon.ps1`: Remediates kiosk auto-logon configuration issues.

## 🚀 Getting Started

1. Clone this repository:
   ```
   git clone https://github.com/nhtkid/Intune-Scripts.git
   ```
2. Navigate to the script you want to use.
3. Review the script and adjust any parameters as needed.
4. Upload the script to your Intune environment or run locally as required.

## 📝 Usage

Each script in this repository is designed to be used with Microsoft Intune. Here are general steps for using these scripts:

1. Review the script and understand its purpose.
2. Test the script in a safe environment.
3. Upload the script to Intune:
   - Go to Intune > Devices > PowerShell scripts (or Windows scripts)
   - Add a new script and upload the .ps1 file
   - Configure the appropriate settings (run as 32/64-bit, run as user/system, etc.)
4. Assign the script to the desired group of devices.
5. Monitor the script's run results in Intune reporting.

⚠️ Always test scripts in a controlled environment before deploying to production devices.

## 🤝 Contributing

Contributions are welcome! 🎊 If you have a script that could benefit others, please feel free to submit a pull request. For major changes, please open an issue first to discuss what you would like to change.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

📬 For any questions or concerns, please open an issue in this repository.

Happy scripting! 💻✨
