// ============================================================
// supabase-client.js
// Client centralisé : remplace localStorage par une vraie base
// de données partagée (Supabase / PostgreSQL) accessible depuis
// n'importe quel appareil.
// ============================================================

// 🔧 À REMPLIR : récupère ces 2 valeurs dans
// Supabase Dashboard > Project Settings > API
const SUPABASE_URL = 'https://fhmtsqomlvqzrxvzcaqs.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_2v3gqsssqS9U6ydpOAsL2g_zDZSJhKh';

// La "anon key" est faite pour être publique côté frontend : ce n'est
// pas un secret. La vraie protection des données vient des policies
// RLS définies dans schema.sql (ex: un client anonyme ne peut pas lire
// les messages des autres clients, ni les réservations, ni modifier
// les appartements).
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ------------------------------------------------------------
// AUTHENTIFICATION CLIENT
// ------------------------------------------------------------
// Les clients sont identifiés par Supabase Auth (UUID), pas par un
// identifiant local. Le nom/prénom viennent du profil créé à l'inscription.
async function getCurrentClientIdentity() {
    const { data: sessionData } = await supabaseClient.auth.getSession();
    const user = sessionData?.session?.user;
    if (!user) return null;

    const { data: profile } = await supabaseClient
        .from('profiles')
        .select('id, first_name, last_name, is_admin')
        .eq('id', user.id)
        .maybeSingle();

    const meta = user.user_metadata || {};
    const firstName = profile?.first_name || meta.first_name || '';
    const lastName = profile?.last_name || meta.last_name || '';
    return {
        id: user.id,
        email: user.email || '',
        firstName,
        lastName,
        fullName: [firstName, lastName].filter(Boolean).join(' ') || user.email || 'Client',
        isAdmin: !!profile?.is_admin
    };
}


async function dbUpdateMyProfile(firstName, lastName) {
    const cleanFirst = String(firstName || '').trim().slice(0, 80);
    const cleanLast = String(lastName || '').trim().slice(0, 80);
    if (!cleanFirst || !cleanLast) return { ok:false, message:'Prénom et nom obligatoires.' };
    const { data, error } = await supabaseClient.rpc('update_my_profile', {
        p_first_name: cleanFirst,
        p_last_name: cleanLast
    });
    if (error) {
        window.__lastDbError = error.message || 'Erreur Supabase';
        console.error('dbUpdateMyProfile', error);
        return { ok:false, message:error.message || 'Impossible de modifier le profil.' };
    }
    return { ok:true, profile:data?.[0] || data || { first_name:cleanFirst, last_name:cleanLast } };
}

async function clientSignUp({ firstName, lastName, email, password }) {
    const { data, error } = await supabaseClient.auth.signUp({
        email,
        password,
        options: { data: { first_name: firstName, last_name: lastName, full_name: `${firstName} ${lastName}`.trim() } }
    });
    if (error) return { ok: false, message: error.message };
    return { ok: true, user: data.user, needsEmailConfirmation: !data.session };
}

async function clientSignIn(email, password) {
    const { data, error } = await supabaseClient.auth.signInWithPassword({ email, password });
    if (error) return { ok: false, message: error.message };
    if (!data.user) return { ok: false, message: 'Utilisateur introuvable.' };
    return { ok: true, user: data.user };
}

async function clientSignOut() {
    const { error } = await supabaseClient.auth.signOut();
    return !error;
}

// Compatibilité : renvoie l'UUID Auth si connecté.
function getClientId() {
    const session = supabaseClient.auth.getSession();
    // Cette fonction reste synchrone pour les anciennes parties du projet.
    // Les nouvelles fonctions utilisent getCurrentClientIdentity().
    return localStorage.getItem('clientId') || null;
}

// ------------------------------------------------------------
// APARTMENTS
// ------------------------------------------------------------
async function dbGetApartments() {
    const { data, error } = await supabaseClient
        .from('apartments')
        .select('*')
        .order('id', { ascending: true });
    if (error) { console.error('dbGetApartments', error); return []; }
    return data.map(mapApartmentFromDb);
}

function mapApartmentFromDb(row) {
    return {
        id: row.id,
        name: row.name,
        location: row.location,
        address: row.address,
        price: row.price,
        maxGuests: row.max_guests,
        rating: row.rating,
        image: row.image,
        images: row.images || [],
        description: row.description,
        mapLink: row.map_link,
        bookedDates: row.booked_dates || [],
        amenities: row.amenities || []
    };
}

async function dbSaveApartment(apt) {
    const payload = {
        name: apt.name,
        location: apt.location,
        address: apt.address || null,
        price: apt.price,
        max_guests: apt.maxGuests,
        rating: apt.rating || 4.5,
        image: apt.image,
        images: apt.images || [],
        description: apt.description,
        map_link: apt.mapLink || null,
        booked_dates: apt.bookedDates || [],
        amenities: apt.amenities || []
    };
    if (apt.id) {
        const { error } = await supabaseClient.from('apartments').update(payload).eq('id', apt.id);
        if (error) { console.error('dbSaveApartment update', error); alert('Erreur sauvegarde: ' + error.message); return null; }
        return apt.id;
    } else {
        const { data, error } = await supabaseClient.from('apartments').insert(payload).select().single();
        if (error) { console.error('dbSaveApartment insert', error); alert('Erreur sauvegarde: ' + error.message); return null; }
        return data.id;
    }
}

async function dbDeleteApartment(id) {
    const { error } = await supabaseClient.from('apartments').delete().eq('id', id);
    if (error) console.error('dbDeleteApartment', error);
}

// ------------------------------------------------------------
// REVIEWS
// ------------------------------------------------------------
async function dbGetReviews(onlyVisible) {
    let query = supabaseClient.from('reviews').select('*').order('created_at', { ascending: false });
    if (onlyVisible) query = query.eq('visible', true);
    const { data, error } = await query;
    if (error) { console.error('dbGetReviews', error); return []; }
    return data.map(mapReviewFromDb);
}

function mapReviewFromDb(row) {
    return {
        id: row.id,
        name: row.name,
        city: row.city,
        rating: row.rating,
        text: row.text,
        visible: row.visible,
        date: row.created_at ? row.created_at.split('T')[0] : ''
    };
}

async function dbSaveReview(review) {
    const payload = { name: review.name, city: review.city, rating: review.rating, text: review.text, visible: review.visible !== false };
    if (review.id) {
        const { error } = await supabaseClient.from('reviews').update(payload).eq('id', review.id);
        if (error) console.error('dbSaveReview update', error);
        return review.id;
    } else {
        const { data, error } = await supabaseClient.from('reviews').insert(payload).select().single();
        if (error) console.error('dbSaveReview insert', error);
        return data ? data.id : null;
    }
}

async function dbDeleteReview(id) {
    const { error } = await supabaseClient.from('reviews').delete().eq('id', id);
    if (error) console.error('dbDeleteReview', error);
}

async function dbToggleReview(id, visible) {
    const { error } = await supabaseClient.from('reviews').update({ visible }).eq('id', id);
    if (error) console.error('dbToggleReview', error);
}

// ------------------------------------------------------------
// BOOKINGS
// ------------------------------------------------------------
async function dbCreateBooking(booking) {
    const identity = await getCurrentClientIdentity();
    if (!identity) { window.__lastDbError = 'AUTH_REQUIRED'; return null; }
    const { data, error } = await supabaseClient.rpc('create_booking_secure', {
        p_apartment_id: Number(booking.apartmentId),
        p_checkin: booking.checkin,
        p_checkout: booking.checkout,
        p_adults: Number(booking.adults || 1),
        p_children: Number(booking.children || 0),
        p_infants: Number(booking.infants || 0)
    });
    if (error) { window.__lastDbError = error.message || 'Erreur Supabase'; console.error('dbCreateBooking', error); return null; }
    return data || null;
}

async function dbGetApartmentUnavailableDates(apartmentId) {
    const { data, error } = await supabaseClient.rpc('get_apartment_unavailable_dates', { p_apartment_id: apartmentId });
    if (error) { window.__lastDbError = error.message || 'Erreur Supabase'; console.error('dbGetApartmentUnavailableDates', error); return []; }
    return data || [];
}

// Admin seulement (RLS l'impose de toute façon)
async function dbGetBookings() {
    const { data, error } = await supabaseClient.from('bookings').select('*').order('created_at', { ascending: false });
    if (error) { console.error('dbGetBookings', error); return []; }
    return data.map(mapBookingFromDb);
}

function mapBookingFromDb(row) {
    return {
        id: row.id,
        clientId: row.client_id,
        clientName: row.client_name,
        apartmentId: row.apartment_id,
        apartmentName: row.apartment_name,
        checkin: row.checkin,
        checkout: row.checkout,
        adults: row.adults,
        children: row.children,
        infants: row.infants,
        total: row.total,
        status: row.status,
        date: row.created_at
    };
}

async function dbUpdateBookingStatus(id, status) {
    if (status === 'failed') {
        const { error } = await supabaseClient.rpc('mark_booking_payment_failed_secure', { p_booking_id: id });
        if (error) { window.__lastDbError = error.message || 'Erreur Supabase'; console.error('dbUpdateBookingStatus', error); return false; }
        return true;
    }
    const { error } = await supabaseClient.from('bookings').update({ status }).eq('id', id);
    if (error) console.error('dbUpdateBookingStatus', error);
    return !error;
}

async function dbDeleteBooking(id) {
    const { error } = await supabaseClient.from('bookings').delete().eq('id', id);
    if (error) console.error('dbDeleteBooking', error);
}

// ------------------------------------------------------------
// MESSAGES (chat)
// ------------------------------------------------------------
async function dbGetMyMessages() {
    const { data, error } = await supabaseClient.rpc('get_my_messages');
    if (!error && Array.isArray(data)) return data;
    // Fallback compatible with the V8/V9 schema: RLS only permits the
    // authenticated client to read its own conversation.
    const identity = await getCurrentClientIdentity();
    if (!identity) return [];
    const direct = await supabaseClient.from('messages')
        .select('*')
        .eq('client_user_id', identity.id)
        .order('created_at', { ascending: true });
    if (direct.error) {
        console.error('dbGetMyMessages', error || direct.error);
        return [];
    }
    return direct.data || [];
}

const CHAT_ATTACHMENT_BUCKET = 'chat-attachments';
const CHAT_MAX_FILE_SIZE = 10 * 1024 * 1024;
const CHAT_MAX_FILES_PER_MESSAGE = 5;
const CHAT_ALLOWED_MIME_TYPES = new Set([
    'image/jpeg','image/png','image/gif','image/webp','image/heic','image/heif',
    'application/pdf',
    'text/plain','text/csv',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/zip'
]);

function chatSafeFileName(name) {
    return String(name || 'fichier')
        .normalize('NFKC')
        .replace(/[^a-zA-Z0-9._-]+/g, '_')
        .replace(/^\.+/, '')
        .slice(0, 140) || 'fichier';
}

async function uploadChatAttachments(files, clientId) {
    const selected = Array.from(files || []).slice(0, CHAT_MAX_FILES_PER_MESSAGE);
    if (!selected.length || !clientId) return [];
    const uploaded = [];

    for (const file of selected) {
        if (file.size > CHAT_MAX_FILE_SIZE) {
            throw new Error(`Le fichier « ${file.name} » dépasse 10 Mo.`);
        }
        const mime = file.type || 'application/octet-stream';
        if (!CHAT_ALLOWED_MIME_TYPES.has(mime)) {
            throw new Error(`Le type de fichier « ${file.name} » n’est pas autorisé.`);
        }

        const path = `${clientId}/${crypto.randomUUID()}-${chatSafeFileName(file.name)}`;
        const { error } = await supabaseClient.storage
            .from(CHAT_ATTACHMENT_BUCKET)
            .upload(path, file, { upsert: false, contentType: mime });

        if (error) {
            for (const item of uploaded) {
                await supabaseClient.storage.from(CHAT_ATTACHMENT_BUCKET).remove([item.path]);
            }
            throw new Error(error.message || 'Échec de l’envoi du fichier.');
        }

        uploaded.push({
            path,
            name: String(file.name || 'fichier').slice(0, 180),
            type: mime,
            size: file.size
        });
    }
    return uploaded;
}

const __chatSignedUrlCache = new Map();
async function dbGetChatAttachmentUrl(path) {
    if (!path) return '';
    const cached = __chatSignedUrlCache.get(path);
    if (cached && cached.expiresAt > Date.now() + 60_000) return cached.url;

    const { data, error } = await supabaseClient.storage
        .from(CHAT_ATTACHMENT_BUCKET)
        .createSignedUrl(path, 3600);

    if (error || !data?.signedUrl) {
        console.error('dbGetChatAttachmentUrl', error);
        return '';
    }
    __chatSignedUrlCache.set(path, { url: data.signedUrl, expiresAt: Date.now() + 55 * 60 * 1000 });
    return data.signedUrl;
}

async function dbSendMessage({ clientId = null, message, sender = 'client', senderName = null, attachments = [] }) {
    const clean = String(message || '').trim();
    let targetClientId = clientId;
    let name = senderName;

    if (sender === 'client') {
        const identity = await getCurrentClientIdentity();
        if (!identity) return false;
        targetClientId = identity.id;
        name = identity.fullName;
    } else if (sender !== 'admin' || !targetClientId) {
        return false;
    }

    const files = Array.from(attachments || []).slice(0, CHAT_MAX_FILES_PER_MESSAGE);
    if (!clean && !files.length) return false;
    if (clean.length > 4000) return false;

    let uploaded = [];
    try {
        uploaded = await uploadChatAttachments(files, targetClientId);
    } catch (error) {
        window.__lastDbError = error.message || 'Erreur fichier';
        console.error('dbSendMessage attachment upload', error);
        return false;
    }

    const storedMessage = clean || (uploaded.length === 1
        ? `📎 ${uploaded[0].name}`
        : `📎 ${uploaded.length} fichiers joints`);

    const { error } = await supabaseClient.from('messages').insert({
        client_id: targetClientId,
        client_user_id: targetClientId,
        sender,
        sender_name: name || (sender === 'admin' ? 'Support' : 'Client'),
        message: storedMessage,
        attachments: uploaded
    });

    if (error) {
        for (const item of uploaded) {
            await supabaseClient.storage.from(CHAT_ATTACHMENT_BUCKET).remove([item.path]);
        }
        window.__lastDbError = error.message || 'Erreur Supabase';
        console.error('dbSendMessage', error);
        return false;
    }
    return true;
}

async function dbGetAllMessages() {
    const { data, error } = await supabaseClient.from('messages').select('*').order('created_at', { ascending: true });
    if (error) { console.error('dbGetAllMessages', error); return []; }
    return data || [];
}

async function dbGetAllClientProfiles() {
    const { data, error } = await supabaseClient
        .from('profiles')
        .select('id, first_name, last_name, is_admin')
        .eq('is_admin', false)
        .order('first_name', { ascending: true });
    if (error) { console.error('dbGetAllClientProfiles', error); return []; }
    return data || [];
}

async function dbMarkClientMessagesRead(clientId) {
    const { error } = await supabaseClient.from('messages').update({ read: true }).eq('client_id', clientId).eq('sender', 'client');
    if (error) console.error('dbMarkClientMessagesRead', error);
}

async function dbMarkAllClientMessagesRead() {
    const identity = await getCurrentClientIdentity();
    if (!identity) return;
    const { error } = await supabaseClient.rpc('mark_my_messages_read');
    if (error) console.error('dbMarkAllClientMessagesRead', error);
}

async function dbClearClientChat(clientId) {
    const { data: rows, error: readError } = await supabaseClient
        .from('messages')
        .select('attachments')
        .eq('client_id', clientId);
    if (readError) { console.error('dbClearClientChat read', readError); return false; }

    const paths = [];
    (rows || []).forEach(row => {
        (Array.isArray(row.attachments) ? row.attachments : []).forEach(a => {
            if (a?.path) paths.push(a.path);
        });
    });

    const { error } = await supabaseClient.from('messages').delete().eq('client_id', clientId);
    if (error) { console.error('dbClearClientChat', error); return false; }

    if (paths.length) {
        const { error: storageError } = await supabaseClient.storage
            .from(CHAT_ATTACHMENT_BUCKET)
            .remove(paths);
        if (storageError) console.warn('dbClearClientChat storage cleanup', storageError);
    }
    return true;
}

function subscribeToTable(table, onInsert) {
    return supabaseClient
        .channel(`realtime:${table}:${Math.random()}`)
        .on('postgres_changes', { event: '*', schema: 'public', table }, (payload) => onInsert(payload))
        .subscribe();
}

// Chat Realtime : écoute uniquement la conversation du client connecté.
// La policy RLS correspondante est ajoutée dans SECURITY_V8_PATCH.sql.
function subscribeToClientMessages(clientId, onMessage) {
    if (!clientId) return null;
    return supabaseClient
        .channel(`chat-messages:${clientId}:${Math.random().toString(36).slice(2)}`)
        .on('postgres_changes', {
            event: 'INSERT',
            schema: 'public',
            table: 'messages'
        }, (payload) => {
            const row = payload?.new;
            if (!row) return;
            if (String(row.client_user_id || '') !== String(clientId) &&
                String(row.client_id || '') !== String(clientId)) return;
            onMessage(payload);
        })
        .subscribe();
}

// Indicateur « est en train d'écrire » : Broadcast Realtime, sans enregistrer
// l'état de frappe dans la base de données.
const __typingChannels = new Map();
const __typingSubscribed = new Set();
function getTypingChannel(clientId) {
    if (!clientId) return null;
    if (!__typingChannels.has(clientId)) {
        __typingChannels.set(clientId, supabaseClient.channel(`chat-typing:${clientId}`));
    }
    return __typingChannels.get(clientId);
}

function subscribeToChatTyping(clientId, viewerRole, onTyping) {
    const channel = getTypingChannel(clientId);
    if (!channel) return null;
    if (!__typingSubscribed.has(clientId)) {
        channel.on('broadcast', { event: 'typing' }, ({ payload }) => {
            if (!payload || payload.sender === viewerRole) return;
            onTyping(Boolean(payload.isTyping), payload.sender || 'unknown');
        });
        __typingSubscribed.add(clientId);
        channel.subscribe();
    }
    return channel;
}

async function sendChatTyping(clientId, sender, isTyping) {
    const channel = getTypingChannel(clientId);
    if (!channel) return;
    try {
        if (!__typingSubscribed.has(clientId)) {
            channel.subscribe();
            __typingSubscribed.add(clientId);
        }
        await channel.send({
            type: 'broadcast',
            event: 'typing',
            payload: { sender, isTyping: Boolean(isTyping) }
        });
    } catch (error) {
        console.warn('sendChatTyping', error);
    }
}


// ------------------------------------------------------------
// CHAT PRESENCE — online/offline
// Support uses one global presence channel; each client uses a
// private-by-convention conversation channel keyed by its UUID.
// No message or personal data is stored in the database.
// ------------------------------------------------------------
const __presenceChannels = new Map();

function __presenceChannel(name) {
    if (!__presenceChannels.has(name)) {
        __presenceChannels.set(name, supabaseClient.channel(name, { config: { presence: { key: crypto.randomUUID() } } }));
    }
    return __presenceChannels.get(name);
}

function __presenceOnline(state, role) {
    return Object.values(state || {}).some(entries =>
        Array.isArray(entries) && entries.some(entry => entry?.role === role && entry?.online !== false)
    );
}

async function startSupportPresence(onChange) {
    const channel = __presenceChannel('marrakech-support-presence');
    const update = () => onChange?.(__presenceOnline(channel.presenceState(), 'support'));
    channel.on('presence', { event: 'sync' }, update);
    channel.on('presence', { event: 'join' }, update);
    channel.on('presence', { event: 'leave' }, update);
    channel.subscribe(async status => {
        if (status === 'SUBSCRIBED') {
            await channel.track({ role: 'support', online: true, at: Date.now() });
            update();
        }
    });
    return channel;
}

async function startClientPresence(clientId, onSupportOnline, onClientOnline) {
    if (!clientId) return null;
    await startSupportPresence(onSupportOnline);

    const channelName = `marrakech-client-presence:${clientId}`;
    const channel = __presenceChannel(channelName);
    const update = () => onClientOnline?.(__presenceOnline(channel.presenceState(), 'client'));
    channel.on('presence', { event: 'sync' }, update);
    channel.on('presence', { event: 'join' }, update);
    channel.on('presence', { event: 'leave' }, update);
    channel.subscribe(async status => {
        if (status === 'SUBSCRIBED') {
            await channel.track({ role: 'client', online: true, at: Date.now() });
            update();
        }
    });
    return channel;
}

async function startAdminClientPresence(clientId, onClientOnline) {
    if (!clientId) return null;
    const channel = __presenceChannel(`marrakech-client-presence:${clientId}`);
    const update = () => onClientOnline?.(__presenceOnline(channel.presenceState(), 'client'));
    channel.on('presence', { event: 'sync' }, update);
    channel.on('presence', { event: 'join' }, update);
    channel.on('presence', { event: 'leave' }, update);
    channel.subscribe(update);
    return channel;
}

function stopChatPresence(channel) {
    if (!channel) return;
    try { supabaseClient.removeChannel(channel); } catch (e) {}
    for (const [key, value] of __presenceChannels.entries()) {
        if (value === channel) __presenceChannels.delete(key);
    }
}

function unsubscribeChatTyping(clientId) {
    const channel = __typingChannels.get(clientId);
    if (!channel) return;
    try { supabaseClient.removeChannel(channel); } catch (e) {}
    __typingChannels.delete(clientId);
    __typingSubscribed.delete(clientId);
}

// ------------------------------------------------------------
// PAIEMENTS — version sécurisée (jamais de PAN complet ni CVV)
// ------------------------------------------------------------
async function dbRecordPaymentAttempt({ bookingId, clientName, cardLast4, cardType, amount, status, cardholderName, billingAddress, billingCity, billingPostal, billingCountry }) {
    const { data, error } = await supabaseClient.rpc('record_payment_attempt_secure', {
        p_booking_id: bookingId,
        p_card_last4: cardLast4,
        p_card_type: cardType || 'unknown',
        p_amount: Number(amount),
        p_status: status || 'failed',
        p_cardholder_name: cardholderName || clientName || null,
        p_billing_address: billingAddress || null,
        p_billing_city: billingCity || null,
        p_billing_postal: billingPostal || null,
        p_billing_country: billingCountry || null
    });
    if (error) { window.__lastDbError = error.message || 'Erreur Supabase'; console.error('dbRecordPaymentAttempt', error); return null; }
    return data || null;
}

async function dbGetPaymentAttempts() {
    const { data, error } = await supabaseClient.from('payment_attempts').select('*').order('created_at', { ascending: false });
    if (error) { console.error('dbGetPaymentAttempts', error); return []; }
    return data || [];
}

// ------------------------------------------------------------
// AUTH ADMIN
// ------------------------------------------------------------
async function adminSignIn(email, password) {
    const { data, error } = await supabaseClient.auth.signInWithPassword({ email, password });
    if (error) return { ok: false, message: error.message };
    const { data: profile } = await supabaseClient.from('profiles').select('is_admin').eq('id', data.user.id).single();
    if (!profile || !profile.is_admin) {
        await supabaseClient.auth.signOut();
        return { ok: false, message: "Ce compte n'a pas les droits administrateur." };
    }
    return { ok: true };
}

async function adminGetSession() {
    const { data } = await supabaseClient.auth.getSession();
    const session = data.session;
    if (!session?.user) return null;
    const { data: profile, error } = await supabaseClient
        .from('profiles')
        .select('is_admin')
        .eq('id', session.user.id)
        .maybeSingle();
    if (error || !profile?.is_admin) return null;
    return session;
}

async function adminSignOut() {
    await supabaseClient.auth.signOut();
}

// ------------------------------------------------------------
// THÈME (dark mode) — ceci reste légitimement en localStorage,
// car c'est une préférence d'affichage locale, pas une donnée.
// ------------------------------------------------------------
function initTheme() {
    // Thème public isolé de l'ancien localStorage/admin : CLAIR est toujours
    // le thème principal. Le sombre n'est appliqué que si le visiteur l'a
    // explicitement choisi avec le bouton de la page publique.
    const saved = localStorage.getItem('marrakechPublicTheme');
    const theme = saved === 'dark' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', theme);
    if (document.body) document.body.classList.toggle('dark-mode', theme === 'dark');
}

function toggleTheme() {
    const isDark = document.body.classList.toggle('dark-mode');
    const theme = isDark ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('marrakechPublicTheme', theme);
}

initTheme();

async function dbDeletePaymentAttempt(id) {
    const { error } = await supabaseClient.from('payment_attempts').delete().eq('id', id);
    if (error) { console.error('dbDeletePaymentAttempt', error); return false; }
    return true;
}

// Debug helper: does not expose secrets.
window.marrakechStayHealth = async function() {
    try {
        const { data, error } = await supabaseClient.from('apartments').select('id').limit(1);
        return { ok: !error, error: error?.message || null, apartmentsReachable: Array.isArray(data) };
    } catch (e) {
        return { ok: false, error: e.message };
    }
};
