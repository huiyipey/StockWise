'use strict';
(() => {
  const config = window.STOCKWISE_AUTH_CONFIG;
  const query = new URLSearchParams(location.search);
  const mode = query.get('mode');
  // Password recovery and email-recovery actions retain Firebase's existing handler.
  if (['resetPassword', 'recoverEmail', 'revertSecondFactorAddition'].includes(mode)) {
    const target = new URL(`https://${config.authDomain}/__/auth/action`);
    for (const key of ['mode', 'oobCode', 'lang']) if (query.has(key)) target.searchParams.set(key, query.get(key));
    target.searchParams.set('apiKey', config.apiKey);
    location.replace(target.href);
    return;
  }
  const card = document.querySelector('.card');
  const symbol = document.getElementById('symbol');
  const title = document.getElementById('title');
  const message = document.getElementById('message');
  const hint = document.getElementById('hint');
  const retry = document.getElementById('retry');
  const code = query.get('oobCode');
  // Remove the one-time link from browser history before making any network request.
  history.replaceState(null, '', location.pathname);
  function show(success, offline = false) {
    card.setAttribute('aria-busy', 'false');
    symbol.className = success ? 'symbol' : 'symbol error';
    symbol.textContent = success ? '\u2713' : '!';
    title.textContent = success ? 'Email verified' : (offline ? 'Could not connect' : 'This link is unavailable');
    message.textContent = success
      ? 'Your email address has been confirmed. Return to StockWise to finish setting up your account.'
      : (offline ? 'Check your internet connection and try again, or return to StockWise to check your verification status.'
        : 'It may have expired or already been used. Return to StockWise to check your status or request a new email.');
    hint.hidden = false;
    hint.textContent = success ? 'You can now close this tab.' : 'Already verified? Open StockWise and tap "I\'ve verified my email".';
    retry.hidden = !offline;
  }
  async function verify() {
    retry.hidden = true;
    if (mode === 'returnToApp') {
      card.setAttribute('aria-busy', 'false');
      symbol.className = 'symbol'; symbol.textContent = '\u2192';
      title.textContent = 'Return to StockWise';
      message.textContent = 'Open the StockWise app to finish setting up your account. The app will check whether your email is verified.';
      hint.hidden = false; hint.textContent = 'Tap "I\'ve verified my email" if your status has not refreshed automatically.';
      return;
    }
    if (!['verifyEmail', 'verifyAndChangeEmail'].includes(mode) || !code || !config?.apiKey) return show(false);
    try {
      const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:update?key=${encodeURIComponent(config.apiKey)}`, {
        method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({oobCode: code}),
        referrerPolicy: 'no-referrer', signal: AbortSignal.timeout(20000),
      });
      show(response.ok, response.status >= 500 || response.status === 429);
    } catch (_) { show(false, true); }
  }
  retry.addEventListener('click', verify);
  verify();
})();
