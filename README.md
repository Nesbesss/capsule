# Capsule

<img src="icon.png" width="128" height="128">

Minimalist speech-to-text for macOS.

### Installation
1. Download `Capsule.dmg`.
2. Move to Applications.
3. Open the app (Right-click -> Open if macOS blocks it).

### Permissions
1. **Microphone**: Allow when prompted.
2. **Accessibility**: Grant in `System Settings > Privacy & Security > Accessibility`. (This is required for the "Paste" feature to work).

### Usage
- **Hold Right Option**: Record.
- **Release Right Option**: Paste.

### Troubleshooting
**If it doesn't paste:**
Run this command in Terminal to reset accessibility permissions:
```bash
tccutil reset Accessibility com.nesbes.capsule
```
Then restart the app and grant permissions again.
