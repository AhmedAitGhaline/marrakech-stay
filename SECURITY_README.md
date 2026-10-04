# Marrakech Stay — V8 Security

Cette version renforce la sécurité sans changer le design ou les fonctionnalités principales du site.

## Ce qui est protégé

- **Supabase Auth** obligatoire pour réserver et utiliser le chat client.
- **RLS** sur les données sensibles.
- Les clients ne peuvent lire que **leurs propres messages**.
- L'admin est contrôlé par `profiles.is_admin = true`.
- Création des réservations par une **fonction PostgreSQL atomique** : le navigateur ne peut plus choisir librement le prix, le propriétaire, la capacité ou contourner les chevauchements.
- Anti-chevauchement côté serveur : une réservation `08→11` bloque les nuits 8, 9, 10 ; `07→08` et `11→12` restent possibles.
- Protection contre deux réservations simultanées du même appartement via verrou transactionnel PostgreSQL.
- Paiement de test : **aucun numéro de carte complet, CVV ou date d'expiration n'est enregistré ou envoyé à Supabase**. Seuls les 4 derniers chiffres, le type et les métadonnées nécessaires sont conservés.
- Vérification serveur du montant du paiement par rapport à la réservation.
- Limites anti-abus côté base pour chat, paiements et avis.
- Limites de longueur côté serveur.
- Le vieux fichier de référence contenant le paiement localStorage non sécurisé n'est pas inclus dans cette version.
- En-têtes de sécurité fournis pour les hébergeurs compatibles.
- Le thème public utilise maintenant une clé dédiée : **clair par défaut**, le choix sombre est séparé de l'ancien thème/admin.

## À faire dans Supabase

1. Exécuter `schema.sql` si c'est une nouvelle installation.
2. Si la base existe déjà, exécuter `SECURITY_V8_PATCH.sql` une seule fois après les anciennes migrations V5/V6/V7.
3. Dans **Authentication > Users**, créer le compte admin.
4. Mettre son UUID dans `public.profiles` avec `is_admin = true`.
5. Activer **MFA** pour le compte admin dans Supabase Auth.
6. Ne jamais mettre la clé `service_role` dans le projet frontend.

## Important

Aucun site internet ne peut être garanti « 100 % invulnérable ». Cette version supprime les principales failles applicatives présentes dans l'architecture statique actuelle. Pour une protection maximale en production, ajoute aussi un WAF/CDN (Cloudflare par exemple), HTTPS obligatoire, sauvegardes Supabase, surveillance des logs et MFA administrateur.
