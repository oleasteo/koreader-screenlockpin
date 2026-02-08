local _ = require("gettext")

return {
    -- KOReader meta information
    name = "screenlockpin",
    fullname = _("ScreenLock PIN"),
    description = _([[Protect your device privacy with a PIN.]]),

    -- used to check for latest plugin updates
    update_url = "https://api.github.com/repos/oleasteo/koreader-screenlockpin/releases/latest",
    version = "2026.02",
    -- additional meta information; no effect in code
    website_url = "https://github.com/oleasteo/koreader-screenlockpin",
    repository_url = "https://github.com/oleasteo/koreader-screenlockpin.git",
}
