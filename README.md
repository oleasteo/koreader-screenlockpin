# ScreenLockPin — A Simple PIN Lock for KOReader

![Lock Screen Preview](lockscreen.png)

**ScreenLockPin** adds a fast, minimal PIN lock screen
to [KOReader](https://github.com/koreader/koreader), helping you protect your
privacy.

---

## ✨ Features

Just what you'd expect from a PIN lock screen 😅

- 🗽 **Flexible PIN length** — supports 4–8 digits
- 🔒 **Full-screen lock** — hides content for privacy
- ⚡ **Instant unlock** — immediate response, no extra confirmation button
- 🪶 **Lightweight design** — minimal overhead
- 🔁 **Auto-lock on wake** — secures your device automatically after sleep

---

## 💡 Not a Feature

- This plugin is designed for **privacy and casual protection**, not
  cryptographic security.
- The Screen Lock won't be active on boot, only when waking a sleeping device.
  It's planned as a configurable feature: #1
    - This allows you to reset your PIN after a reboot; if you ever forget it.

---

## 📦 Installation

1. Clone or download this repository.
2. Copy the folder `screenlockpin.koplugin` into KOReader’s `plugins` directory.
3. Restart KOReader. The plugin will appear in the *Main Menu*.

---

## ⚙️ Usage

1. Open KOReader’s *Main Menu* › **ScreenLock PIN**.
2. Set your desired PIN (4–8 digits) and confirm with **Save**.
3. Once saved, KOReader will lock automatically on wake.
4. Enter the PIN to unlock.

Internally, we use the *Settings* › *Screen* › *Sleep screen* › *Wallpaper* ›
**Postpone screen update after wake-up** setting. Changing this setting will
disable the lock screen.

---

## 🧩 Compatibility

Designed for and tested with **KOReader v2025.08**. Please report any
compatibility issues for this version or newer.

---

## 🧑‍💻 Contributing

Contributions and suggestions are welcome!  
Feel free to open an **issue** or **pull request** to improve functionality,
style, or compatibility.

---

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.
