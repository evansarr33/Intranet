# Noria — espace SIRH

Interface RH en français, adaptée au mobile, avec connexion par identifiant et mot de passe. Aucune adresse e-mail n'est demandée aux salariés et aucun lien de connexion n'est envoyé par e-mail.

## Architecture

- Site statique et fonctions Node.js hébergés sur Vercel.
- Données dans Supabase, région UE à choisir lors du provisionnement.
- Connexion interne par identifiant RH. Le serveur hache les mots de passe avec `scrypt` ; la session est conservée dans un cookie HTTP uniquement, sécurisé et signé.
- La clé Supabase secrète reste côté serveur. Les rôles navigateur `anon` et `authenticated` n'ont aucun accès aux tables. Le serveur vérifie chaque session et les droits RH.
- Le compte initial est créé une seule fois via l'action `setup`, protégée par `SETUP_SECRET`.

## Mise en service

1. Créer ou sélectionner un projet Supabase et exécuter [`supabase/schema.sql`](supabase/schema.sql) dans le SQL Editor.
2. Dans les variables d'environnement du projet Vercel, configurer `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SESSION_SECRET` (au moins 32 caractères aléatoires) et `SETUP_SECRET` (au moins 24 caractères aléatoires).
3. Déployer le contenu du dépôt sur Vercel, puis appeler `POST /api?action=setup` une seule fois avec l'en-tête `Authorization: Bearer <SETUP_SECRET>` et un JSON contenant `identifier`, `password`, `first_name` et `last_name`. Choisir un mot de passe initial d'au moins 12 caractères et le communiquer au titulaire par un canal interne.
4. Retirer `SETUP_SECRET` des variables Vercel après la création du compte initial.

L'action d'initialisation refuse toute création si un compte existe déjà. Elle n'envoie pas de courrier électronique. Une personne RH peut ajouter les comptes suivants depuis la gestion des collaborateurs ; l'identifiant et le mot de passe sont à remettre au salarié par un canal interne.

## Modules préparés

Collaborateurs, demandes et validations de congés, temps de travail, recrutement, formations, documents RH et entretiens. La gestion des comptes et des congés dispose d'API serveur ; les autres modules nécessitent encore leurs écrans de gestion avant une utilisation en production.

## Protection des données

N'utiliser que des données professionnelles nécessaires. Les tables sont protégées par RLS et les rôles clients n'ont pas de droits SQL ; seules les fonctions serveur utilisent la clé secrète. Prévoir une procédure RH de remise et de réinitialisation des mots de passe, une politique de conservation, une sauvegarde et une validation de conformité avant d'importer des dossiers salariés réels.

