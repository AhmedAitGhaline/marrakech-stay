# Marrakech Stay — Chat PRO Upgrade

## Nouveautés
- Chat redesign inspiré du design fourni : header premium doré, fond sombre, bulles modernes, animations.
- Messages en temps réel client ↔ support.
- Indicateur « est en train d’écrire… ».
- Indicateur en ligne / hors ligne :
  - le client voit si le support est en ligne ;
  - le support voit si le client sélectionné est en ligne.
- Pièces jointes : images, PDF, TXT/CSV, Word, Excel, PowerPoint et ZIP.
- Jusqu'à 5 fichiers par message.
- Taille maximale : 10 Mo par fichier.
- Prévisualisation des images et téléchargement/ouverture des documents.
- Sélecteur d'emojis complet via emoji-picker-element.
- Entrée/Enter envoie directement le message.
- Les pièces jointes sont stockées dans un bucket Supabase Storage privé.
- Les URL des pièces jointes sont temporaires (signed URLs).
- Les fichiers ne sont pas stockés dans la table messages.
- Le nettoyage d'un chat supprime également les pièces jointes associées quand les permissions le permettent.

## Supabase — à exécuter une fois
Dans le SQL Editor, exécuter :

`CHAT_PRO_UPGRADE_PATCH.sql`

Ce patch ajoute la colonne `messages.attachments`, crée le bucket privé `chat-attachments` et ses policies Storage.

### Important
Ne pas rendre le bucket public.
Ne jamais stocker de PAN/CVV dans le chat ou dans Supabase.

## Hébergement
Remplacer les fichiers du site par ceux de ce ZIP. Le projet reste compatible avec GitHub Pages / Vercel / hébergement statique.
