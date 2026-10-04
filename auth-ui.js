/* Marrakech Stay — Client authentication UI */
(function () {
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));

  function injectAuthModal() {
    if (document.getElementById('clientAuthModal')) return;
    const wrap = document.createElement('div');
    wrap.id = 'clientAuthModal';
    wrap.className = 'client-auth-overlay';
    wrap.innerHTML = `
      <div class="client-auth-card">
        <button class="client-auth-close" onclick="closeAuthModal()" aria-label="Fermer">&times;</button>
        <div class="client-auth-logo"><i class="fas fa-user-circle"></i></div>
        <h2 id="authTitle">Connexion</h2>
        <p id="authSubtitle">Connectez-vous à votre compte Marrakech Stay.</p>
        <div id="authLoginForm">
          <input id="authLoginEmail" type="email" placeholder="Adresse email" autocomplete="email">
          <input id="authLoginPassword" type="password" placeholder="Mot de passe" autocomplete="current-password">
          <button class="auth-primary" onclick="clientLogin()">Se connecter</button>
          <button class="auth-link" onclick="switchAuthMode('signup')">Créer un compte</button>
        </div>
        <div id="authSignupForm" style="display:none;">
          <div class="auth-two-cols">
            <input id="authFirstName" type="text" placeholder="Prénom" autocomplete="given-name">
            <input id="authLastName" type="text" placeholder="Nom" autocomplete="family-name">
          </div>
          <input id="authSignupEmail" type="email" placeholder="Adresse email" autocomplete="email">
          <input id="authSignupPassword" type="password" placeholder="Mot de passe (6 caractères min.)" autocomplete="new-password">
          <input id="authSignupConfirm" type="password" placeholder="Confirmer le mot de passe" autocomplete="new-password">
          <button class="auth-primary" onclick="clientSignup()">Créer mon compte</button>
          <button class="auth-link" onclick="switchAuthMode('login')">J'ai déjà un compte</button>
        </div>
        <div id="authStatus" class="auth-status" aria-live="polite"></div>
      </div>`;
    document.body.appendChild(wrap);
    wrap.addEventListener('click', e => { if (e.target === wrap) closeAuthModal(); });
  }

  function setStatus(message, error = false) {
    const el = document.getElementById('authStatus');
    if (!el) return;
    el.textContent = message || '';
    el.className = 'auth-status ' + (error ? 'error' : 'success');
  }

  function switchAuthMode(mode) {
    injectAuthModal();
    const login = mode !== 'signup';
    document.getElementById('authLoginForm').style.display = login ? 'block' : 'none';
    document.getElementById('authSignupForm').style.display = login ? 'none' : 'block';
    document.getElementById('authTitle').textContent = login ? 'Connexion' : 'Créer un compte';
    document.getElementById('authSubtitle').textContent = login ? 'Connectez-vous à votre compte Marrakech Stay.' : 'Créez votre compte pour réserver et discuter avec notre équipe.';
    setStatus('');
  }

  function openAuthModal(mode = 'login') {
    injectAuthModal();
    switchAuthMode(mode);
    document.getElementById('clientAuthModal').classList.add('show');
    setTimeout(() => document.querySelector(mode === 'signup' ? '#authFirstName' : '#authLoginEmail')?.focus(), 50);
  }

  function closeAuthModal() {
    document.getElementById('clientAuthModal')?.classList.remove('show');
  }

  async function clientLogin() {
    const email = document.getElementById('authLoginEmail').value.trim();
    const password = document.getElementById('authLoginPassword').value;
    if (!email || !password) return setStatus('Veuillez remplir tous les champs.', true);
    setStatus('Connexion en cours…');
    const result = await clientSignIn(email, password);
    if (!result.ok) return setStatus(result.message || 'Connexion impossible.', true);
    setStatus('Connexion réussie.');
    closeAuthModal();
    await updateAuthUI();
    if (typeof window.onClientAuthReady === 'function') await window.onClientAuthReady();
  }

  async function clientSignup() {
    const firstName = document.getElementById('authFirstName').value.trim();
    const lastName = document.getElementById('authLastName').value.trim();
    const email = document.getElementById('authSignupEmail').value.trim();
    const password = document.getElementById('authSignupPassword').value;
    const confirm = document.getElementById('authSignupConfirm').value;
    if (!firstName || !lastName || !email || !password || !confirm) return setStatus('Veuillez remplir tous les champs.', true);
    if (password.length < 6) return setStatus('Le mot de passe doit contenir au moins 6 caractères.', true);
    if (password !== confirm) return setStatus('Les deux mots de passe ne correspondent pas.', true);
    setStatus('Création du compte…');
    const result = await clientSignUp({ firstName, lastName, email, password });
    if (!result.ok) return setStatus(result.message || 'Création impossible.', true);
    if (result.needsEmailConfirmation) {
      setStatus('Compte créé. Vérifiez votre email puis connectez-vous.', false);
      switchAuthMode('login');
      document.getElementById('authLoginEmail').value = email;
      return;
    }
    setStatus('Compte créé avec succès.');
    closeAuthModal();
    await updateAuthUI();
    if (typeof window.onClientAuthReady === 'function') await window.onClientAuthReady();
  }


  function openClientProfile() {
    const modal = document.getElementById('clientProfileModal');
    if (!modal) return;
    getCurrentClientIdentity().then(identity => {
      if (!identity) { openAuthModal('login'); return; }
      document.getElementById('profileEmail').value = identity.email || '';
      document.getElementById('profileFirstName').value = identity.firstName || '';
      document.getElementById('profileLastName').value = identity.lastName || '';
      const status = document.getElementById('profileStatus');
      if (status) status.textContent = '';
      modal.classList.add('show');
      modal.setAttribute('aria-hidden','false');
    });
  }

  function closeClientProfile() {
    const modal = document.getElementById('clientProfileModal');
    if (modal) {
      modal.classList.remove('show');
      modal.setAttribute('aria-hidden','true');
    }
  }

  async function saveClientProfile() {
    const firstName = document.getElementById('profileFirstName')?.value.trim() || '';
    const lastName = document.getElementById('profileLastName')?.value.trim() || '';
    const status = document.getElementById('profileStatus');
    if (!firstName || !lastName) {
      if (status) { status.textContent = 'Veuillez remplir le prénom et le nom.'; status.style.color = '#c62828'; }
      return;
    }
    if (status) { status.textContent = 'Enregistrement…'; status.style.color = '#9b7724'; }
    const result = await dbUpdateMyProfile(firstName, lastName);
    if (!result?.ok) {
      if (status) { status.textContent = result?.message || 'Impossible de modifier le profil.'; status.style.color = '#c62828'; }
      return;
    }
    if (status) { status.textContent = 'Profil mis à jour.'; status.style.color = '#238636'; }
    await updateAuthUI();
    if (typeof window.onClientProfileUpdated === 'function') await window.onClientProfileUpdated(result.profile);
    setTimeout(closeClientProfile, 500);
  }

  async function logoutClient() {
    await clientSignOut();
    await updateAuthUI();
    if (typeof window.onClientAuthReady === 'function') await window.onClientAuthReady();
  }

  async function updateAuthUI() {
    injectAuthModal();
    const identity = await getCurrentClientIdentity();
    document.querySelectorAll('[data-client-account]').forEach(el => {
      if (identity) {
        el.innerHTML = `<i class="fas fa-user"></i>`;
        el.title = `${identity.fullName || 'Mon profil'} — Ouvrir le profil`;
        el.onclick = (e) => { e.preventDefault(); openClientProfile(); };
      } else {
        el.innerHTML = '<i class="fas fa-user"></i>';
        el.title = 'Se connecter / créer un compte';
        el.onclick = (e) => { e.preventDefault(); openAuthModal('login'); };
      }
    });
    document.querySelectorAll('[data-auth-required]').forEach(el => {
      el.style.display = identity ? '' : '';
    });
    return identity;
  }

  async function requireClientLogin(message = 'Connectez-vous ou créez un compte pour continuer.') {
    const identity = await getCurrentClientIdentity();
    if (identity) return identity;
    openAuthModal('login');
    setStatus(message, true);
    return null;
  }

  window.injectAuthModal = injectAuthModal;
  window.openAuthModal = openAuthModal;
  window.closeAuthModal = closeAuthModal;
  window.switchAuthMode = switchAuthMode;
  window.clientLogin = clientLogin;
  window.clientSignup = clientSignup;
  window.logoutClient = logoutClient;
  window.openClientProfile = openClientProfile;
  window.closeClientProfile = closeClientProfile;
  window.saveClientProfile = saveClientProfile;
  window.updateAuthUI = updateAuthUI;
  window.requireClientLogin = requireClientLogin;

  document.addEventListener('DOMContentLoaded', () => { injectAuthModal(); updateAuthUI(); });
})();
