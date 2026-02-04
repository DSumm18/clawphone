# ClawPhone - Clean Specification

*Last updated: 2026-02-04*

## What It Is
iOS app that connects to a user's EXISTING Clawdbot via voice/text.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  ClawPhone App  │────▶│  ClawPhone API   │────▶│  User's Bot     │
│  (iOS)          │     │  (our server)    │     │  (their server) │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌──────────────────┐
                        │    Supabase      │
                        │  (connections)   │
                        └──────────────────┘
```

## Connection Flow

1. User downloads ClawPhone app
2. User has existing Clawdbot on Telegram
3. User goes to @ClawWatchSetup_bot
4. User provides: bot URL + gateway token
5. Setup bot sends code TO USER'S BOT (security: proves ownership)
6. User sees code in their bot chat
7. User enters code in ClawPhone app
8. Connected!

## Security

- Codes expire in 10 minutes
- Codes are single-use
- Code sent to user's bot (not setup chat) = ownership verification
- Longer numeric codes (8 digits) for better security
- Rate limiting on validation attempts

## Database (Supabase)

**Project:** Clawwatch
**URL:** https://dybdxegrgofmmlvkthqb.supabase.co

**Tables:**
- `clawwatch_users` - user accounts
- `pending_messages` - message queue
- `device_connections` - links device to user's bot
- `connection_codes` - 6-digit pairing codes

## Components

### ClawPhone API (our server)
- **Location:** /root/.openclaw/workspace/clawphone-api/
- **Port:** 8080
- **Service:** clawphone.service
- **Purpose:** Bridge between app and user's bot

### Setup Bot
- **Telegram:** @ClawWatchSetup_bot
- **Location:** /root/.openclaw/workspace/clawphone-bot/
- **Purpose:** Help users connect their bot

### iOS App
- **Location:** /root/.openclaw/workspace/apps/clawphone/
- **Bundle ID:** com.dsumm.clawphone

## Watch Integration

ClawWatch syncs through iPhone (Option A):
- Watch is extension of phone app
- Phone handles all API connections
- Watch syncs via WatchConnectivity
- User sets up once on phone, watch works automatically

## TODO

- [ ] Fix app icon (Clawbot theme, not rocket)
- [ ] Fix voice (Fish Audio not playing)
- [ ] Add avatar in chat bubbles
- [ ] Send code to user's bot (not setup chat)
- [ ] Longer codes (8 digits)
- [ ] Rate limiting on code validation
- [ ] Clean UI polish

## What NOT To Do

- Don't use local JSON for connections (use Supabase)
- Don't hardcode bot URLs
- Don't overcomplicate the architecture
- Don't modify user's bot code (we're just a bridge)
