MARRAKECH STAY V6
=================

Cette version ajoute :
- Mode nuit complet sur apartment.html.
- Comptes clients avec inscription : prénom + nom + email + mot de passe.
- Connexion/déconnexion Supabase Auth.
- Chaque conversation est liée à l'UUID du compte client.
- Le nom et prénom du client apparaissent dans le chat admin.
- Seul l'admin peut effacer tout l'historique d'un client.
- Réservations liées au compte client.
- Une réservation 8 -> 11 bloque les nuits 8, 9 et 10.
- 7 -> 8 reste possible et 11 -> 12 reste possible.
- Une sélection 7 -> 12 est refusée automatiquement.
- Une vérification est faite juste avant la création de la réservation.
- Une protection PostgreSQL empêche également les chevauchements même si quelqu'un contourne le navigateur.

IMPORTANT — SUPABASE
====================
1. Garde schema.sql dans le projet. Ne le supprime PAS.
2. Si schema.sql a déjà été exécuté, ne le relance pas.
3. Dans Supabase > SQL Editor > New query, colle puis Run :
   V5_SUPABASE_FIX.sql (si pas encore fait)
   puis V6_AUTH_BOOKING_CHAT.sql
4. Dans Supabase Authentication > Providers > Email, vérifie la configuration Email.
   Si la confirmation email est activée, le client devra confirmer son email avant de se connecter.
5. Ton compte admin doit toujours avoir profiles.is_admin = true.

TEST CLIENT
===========
1. Ouvre index.html.
2. Clique sur « Connexion » > « Créer un compte ».
3. Crée un compte avec prénom, nom, email et mot de passe.
4. Si Supabase demande une confirmation email, confirme puis connecte-toi.
5. Ouvre un appartement.
6. Clique sur le chat : le client connecté est utilisé automatiquement.
7. Envoie un message.

TEST ADMIN
==========
1. Ouvre marrakech-backoffice.html.
2. Connecte-toi avec le compte admin Supabase.
3. Onglet « Support client ».
4. Le client apparaît avec son prénom/nom.
5. Réponds au client.
6. Sélectionne le client puis « Effacer le chat » pour supprimer tout l'historique.

TEST RESERVATION
================
Si les dates 8 -> 11 sont réservées :
- 7 -> 8 : autorisé
- 11 -> 12 : autorisé
- 7 -> 12 : refusé
- 9 -> 10 : refusé

PAIEMENT
========
Le paiement reste une simulation de test. Le projet ne stocke jamais le numéro de carte complet, le CVV ou la date d'expiration.
