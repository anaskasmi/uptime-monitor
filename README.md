# Uptime monitor

Every 5 minutes GitHub Actions requests each URL in `sites.txt`. A site that
fails twice in a row triggers a "DOWN" email, and a "RECOVERED" email follows
when it answers 200 again. Emails go through Brevo; the API key and the
addresses are repository secrets.

Add or remove a site by editing `sites.txt`.
