MARRAKECH STAY — V3

Cette version conserve le DESIGN des 3 fichiers fournis par le client et relie les pages à la même base Supabase.

FICHIERS
- index.html
- apartment.html
- marrakech-backoffice.html
- supabase-client.js
- schema.sql
- chat_and_payment_patch.sql
- dark-mode.css

IMPORTANT — CHAT ADMIN
Le problème venait du fait que les fichiers fournis n'utilisaient pas la même source :
- index.html utilisait Supabase
- apartment.html utilisait localStorage pour les conversations
- marrakech-backoffice.html utilisait localStorage pour les conversations

V3 utilise la table Supabase public.messages pour les trois pages.

À FAIRE DANS SUPABASE
1. Ouvrir SQL Editor.
2. Si la base existe déjà, exécuter UNE FOIS : chat_and_payment_patch.sql
3. Le compte administrateur doit être créé dans Supabase Authentication > Users et avoir profiles.is_admin = true.
4. L'admin se connecte maintenant avec son EMAIL Supabase + mot de passe, pas avec l'ancien identifiant local locationanagency.
5. Vérifier que Realtime est activé pour messages.

Le patch donne SELECT/UPDATE sur messages à authenticated, mais RLS continue de limiter la lecture à un admin via is_admin().

PAIEMENT
Le paiement reste une SIMULATION. Aucun PAN complet ni CVV n'est enregistré. La base conserve uniquement des métadonnées non sensibles et les 4 derniers chiffres.

TEST CHAT
1. Ouvrir index.html ou apartment.html dans un navigateur A et envoyer un message.
2. Se connecter dans marrakech-backoffice.html avec le compte Supabase admin dans un navigateur B.
3. Ouvrir Chat support.
4. Le client doit apparaître dans la liste et son message doit apparaître automatiquement.
5. Répondre depuis admin : le message revient dans le chat client.

TEST DASHBOARD
Les réservations récentes sont maintenant lues depuis Supabase et triées par created_at.
