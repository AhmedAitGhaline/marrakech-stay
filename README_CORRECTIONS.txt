MARRAKECH STAY — VERSION CORRIGEE
=================================

Fichiers inclus
---------------
- index.html
- apartment.html
- marrakech-backoffice.html
- supabase-client.js
- schema.sql
- notification_patch.sql
- dark-mode.css

CE QUI A ETE CORRIGE
---------------------
1. supabase-client.js contient l'URL Supabase et la publishable key fournies.
2. Paiement: attente de 4,5 secondes avec état "Vérification du paiement..." avant le résultat.
3. Aucun numéro de carte complet ni CVV n'est enregistré. Seuls les 4 derniers chiffres + type + informations de facturation non sensibles sont conservés.
4. Admin: badges rouges de notifications pour Réservations, Avis, Paiements et Chat.
5. Admin: notifications toast en temps réel pour nouvelle réservation, message, avis et tentative de paiement.
6. Admin: les notifications sont marquées comme vues lorsque la section est ouverte.
7. Calendrier client: disponible = normal, sélection = vert, réservé = rouge + barré.
8. Calendrier admin: dates plus lisibles, état bloqué en rouge/barré et légende.
9. Réservations récentes: ordre et affichage corrigés.
10. Paiements admin: affichage sécurisé des informations de facturation et de carte masquée.

IMPORTANT — SUPABASE
--------------------
Tu as déjà exécuté schema.sql. NE LE RELANCE PAS si ta base actuelle fonctionne.

Exécute UNE SEULE FOIS notification_patch.sql dans:
Supabase Dashboard -> SQL Editor -> New -> coller notification_patch.sql -> Run

Ce patch ajoute:
- admin_seen pour réservations / avis / paiements
- champs d'adresse de facturation
- permissions admin nécessaires pour les messages et paiements
- Realtime pour payment_attempts
- index pour les compteurs non lus

PAIEMENT REEL
-------------
La version fournie reste un MODE TEST pour le paiement: après 4,5 secondes elle affiche un échec.
Pour accepter de vrais paiements, il faut intégrer un prestataire de paiement (par ex. Stripe ou CMI) avec tokenisation/Hosted Checkout. Ne stocke jamais le PAN complet ou le CVV dans Supabase.

ORDRE DE TEST
-------------
1. Ouvrir marrakech-backoffice.html et se connecter.
2. Ajouter un appartement.
3. Ouvrir l'appartement depuis index.html.
4. Vérifier le calendrier.
5. Faire une réservation test.
6. Remplir le formulaire de paiement test.
7. Vérifier l'attente de 4,5 secondes et le statut.
8. Vérifier le badge rouge Paiements/Réservations.
9. Tester un avis et vérifier le badge Avis.
10. Tester le chat et vérifier le badge Chat.
