MARRAKECH STAY V7 — FINAL CORRECTIONS

1) Thème principal du site : clair par défaut.
   Le mode sombre reste disponible et mémorisé uniquement après choix de l'utilisateur.

2) Apartment.html :
   - équipements lisibles en sombre (fond sombre + texte blanc, icônes dorées conservées)
   - calendrier identique en clair/sombre : arrivée + départ #C9A03D, intervalle doré translucide
   - conflit de dates affiché dans une vraie fenêtre interne au site, pas un alert navigateur
   - description conserve les retours à la ligne et reconstitue les séparations 📍 / ✨ / puces si une ancienne donnée est sur une seule ligne
   - paiement simulé avec attente aléatoire de 5 à 10 secondes

3) Admin :
   - système visuel de paiement repris de admin(2).html : cartes, logos, détails et bouton Supprimer
   - données bancaires affichées uniquement sous forme sûre : marque + 4 derniers chiffres
   - jamais de PAN complet, CVV ou date d'expiration stockés
   - suppression des paiements réservée à l'admin
   - clear chat réservé à l'admin

4) Supabase :
   Après schema.sql + V5_SUPABASE_FIX.sql + V6_AUTH_BOOKING_CHAT.sql,
   exécuter V7_FINAL_PATCH.sql dans SQL Editor.

5) Important :
   - Ne pas supprimer schema.sql du projet.
   - Ne jamais mettre la service_role key dans le frontend.
   - Le paiement est une simulation, pas un vrai processeur de paiement.

V7.1 — Navigation publique : le bouton Admin a été retiré de index.html et apartment.html.
Le panneau admin reste accessible directement via marrakech-backoffice.html et continue d'être protégé par Supabase Auth + profil administrateur.
Le thème clair est le thème principal par défaut.
