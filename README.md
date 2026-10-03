# Noria — espace SIRH

Interface RH en français, pensée pour ordinateur et mobile, avec connexion par identifiant et mot de passe. Les salariés n'ont pas besoin d'une adresse e-mail et aucun lien de connexion n'est envoyé par e-mail.

## Publication

Le site est publié sur une Supabase Edge Function :

`https://kpcprbhsaxdlwftofrym.supabase.co/functions/v1/noria`

Le dépôt de code est privé. La base `noria-sirh` est hébergée à Paris. Les tables et règles RLS sont gérées par `supabase/schema.sql`; la fonction publique qui sert le site et son API est dans `supabase/functions/noria/index.ts`.

## Accès et sécurité

- Le compte initial est créé dans `hr_accounts`, sans adresse e-mail.
- Les mots de passe sont hachés avec PBKDF2-SHA-256 côté serveur et la session est dans un cookie HTTP-only, `Secure` et `SameSite=Strict`.
- Les clés serveur Supabase ne sont pas intégrées au navigateur. Le site n'embarque que la clé publique Supabase ; les tables refusent l'accès direct aux rôles `anon` et `authenticated`.
- L'accès initial est communiqué à l'administrateur par le canal privé de livraison. Il peut ensuite changer son mot de passe dans Paramètres.

## Modules

Les vues disponibles couvrent collaborateurs, congés, temps de travail, recrutement, formations, documents, entretiens et paramètres. La première version permet l'authentification, la gestion des profils RH et les demandes/validations de congés. Les autres vues sont prêtes à être reliées aux processus internes et ne doivent pas encore être utilisées pour gérer des données réelles.

Avant d'importer des dossiers salariés, définir la politique de conservation, les sauvegardes, les droits par rôle et le processus RH de création/révocation des comptes.

