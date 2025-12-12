# AMD GPU Registry Optimizer

**English** | [Русский](README.ru.md)

A PowerShell script for fine-tuning and optimizing AMD Radeon™ GPU settings in the Windows Registry.

## Description

This script provides a centralized interface for advanced users who want to get the most performance and stability out of their AMD graphics cards. It allows you to change hidden driver settings that are not available in the standard Adrenalin Software interface.

**DISCLAIMER:** Modifying the Windows Registry can lead to system instability, crashes, or even prevent your operating system from booting. Use this script at your own risk. The author is not responsible for any possible damage to your hardware or software.

## Features

- **Backup and Restore:** Automatically creates a backup of the modified registry keys before applying settings. You can easily undo all changes.
- **System Restore Point:** For added security, the script attempts to create a Windows Restore Point.
- **Flexible Profiles:** Choose between different optimization profiles depending on your GPU series (RDNA/RDNA2/RDNA3) and preferences (e.g., disabling the overlay for maximum FPS).
- **Disable Telemetry:** Disables AMD's data collection components.
- **Extensive Tweak Database:** Includes a large number of parameters for optimizing performance, stability, and image quality.

## How to Use

1.  **Download** the `main.ps1` script.
2.  **Run PowerShell as Administrator.**
    - Right-click the Start Menu.
    - Select "Windows PowerShell (Admin)".
3.  **Allow script execution (if required):**
    - In the PowerShell window, enter the command:
      ```powershell
      Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process
      ```
    - Press `Y` and `Enter` to confirm.
4.  **Navigate to the script's folder:**
    - Use the `cd` command, for example:
      ```powershell
      cd C:\Users\YourName\Downloads
      ```
5.  **Run the script:**
    - Enter the command:
      ```powershell
      .\main.ps1
      ```
6.  **Follow the on-screen instructions:**
    - The script will offer to create a backup and then show a menu for selecting optimization profiles.
    - After applying the settings, **be sure to restart your computer**.

## System Requirements

- **Operating System:** Windows 10, Windows 11
- **Graphics Card:** AMD Radeon™
- **Administrator rights** to run the script.

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details.