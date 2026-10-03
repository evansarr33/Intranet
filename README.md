# Noria — espace SIRH

Interface RH en français, pensée pour ordinateur et mobile, avec connexion par identifiant et mot de passe. Les salariés n'ont pas besoin d'une adresse e-mail et aucun lien de connexion n'est envoyé par e-mail.

## Publication

Le site est hébergé sur Vercel. Son API /api relaie les demandes vers la fonction Edge Supabase :

https://kpcprbhsaxdlwftofrym.supabase.co/functions/v1/noria

Le dépôt de code est public à la demande de son propriétaire. La base noria-sirh est hébergée à Paris. Les tables et règles RLS sont gérées par supabase/schema.sql. Vercel n'a besoin d'aucune clé secrète : la clé serveur et la signature des sessions restent dans les secrets de la fonction Edge Supabase.

## Accès et sécurité

- Connexion avec identifiant RH et mot de passe, sans adresse e-mail.
- Les mots de passe sont hachés avec PBKDF2-SHA-256 côté serveur.
- La session passe par un cookie HTTP-only, Secure et SameSite=Strict.
- La clé serveur Supabase n'est jamais intégrée au navigateur ni à Vercel.
- L'accès initial est communiqué à l'administrateur par le canal privé de livraison. Il peut ensuite changer son mot de passe dans Paramètres.

## Modules

Les vues disponibles couvrent collaborateurs, congés, temps de travail, recrutement, formations, documents, entretiens et paramètres. La première version permet l'authentification, la gestion des profils RH et les demandes/validations de congés. Les autres vues sont prêtes à être reliées aux processus internes et ne doivent pas encore être utilisées pour gérer des données réelles.

Avant d'importer des dossiers salariés, définir la politique de conservation, les sauvegardes, les droits par rôle et le processus RH de création/révocation des comptes.