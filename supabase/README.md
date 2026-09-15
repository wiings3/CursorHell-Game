# Cursor Hell Global Leaderboard

`leaderboard_schema.sql` creates the production Endless leaderboard table, safe public read view, and validated submission RPC.

The Godot client reads `res://leaderboard_config.json` with:

```json
{
  "url": "https://<project-ref>.supabase.co",
  "anon_key": "<publishable-or-anon-client-key>"
}
```

The key is intentionally a **public client key**, never a service-role/secret key. Direct writes to the leaderboard table are revoked. Run submissions go through `submit_endless_result`, which validates callsign/time/phase/score and requires the installation's private submission token.

For local testing without a committed config file, the client also accepts `CURSORHELL_SUPABASE_URL` and `CURSORHELL_SUPABASE_ANON_KEY` environment variables.
