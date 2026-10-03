# Noria - espace SIRH

Noria est un portail RH web en francais, responsive ordinateur/mobile, avec connexion par identifiant professionnel et mot de passe, sans adresse e-mail.

## Modules

- Vue d’ensemble, indicateurs d’effectif et absences, vues par role.
- Dossiers collaborateur, rattachement hierarchique, taux d’activite, dates d’arrivee/depart, historique et corrections de profil.
- Conges parametrables, jours feries, validations, annulation et registre des mouvements de soldes.
- Temps : arrivee/depart, pauses, demandes de correction avec valeurs d’origine, validation et cloture/reouverture mensuelle RH.
- Recrutement : offres et pipeline candidat, information de confidentialite et echeance de conservation configurable.
- Formations : catalogue, capacite, inscriptions et suivi d’achevement.
- Documents prives, formats PDF/PNG/JPEG, acces par liens signes courts et dates de conservation.
- Entretiens par motif configurable, formulaires propres au motif, champs automatiques repris du dossier, préparation et suivi de courriers.
- Modèles de courriers structurés et modifiables dans Documentation, balises de publipostage, association à plusieurs motifs, instant de génération configurable, aperçu imprimable et export PDF par le navigateur. Les courriers déjà générés gardent un instantané du modèle utilisé.
- Taches d’integration/depart avec modeles configurables, acces des nouveaux comptes a partir de leur date d’arrivee, notifications internes, administration des comptes et journal des actions/export.

## Architecture

La version Vercel sert l’interface et proxyfie `/api` vers la fonction Supabase `noria`. La fonction gere l’authentification personnalisee, les roles, les autorisations et Postgres. Les secrets serveur restent cote Supabase. Le navigateur ne lit pas directement les tables RH. La fonction Edge utilise un cookie de session HTTP-only, secure et same-site et des mots de passe PBKDF2-SHA-256.

Les tables RH ont RLS activee; les privileges Data API des roles clients sont revoques. Le stockage documentaire est prive. La limitation des essais de connexion est partagee entre les instances par une fonction Postgres.

## Publication et configuration

- Le code source vit dans `evansarr33/Intranet`; le proxy est `api/index.js`.
- Le bundle Edge `supabase/functions/noria/index.ts` est genere depuis `index.html`, `styles.css`, `app.js`, `work/edge-server.template.ts` et `work/edge-routes.template.ts` avec `work/build-edge.mjs`. Sa configuration Deno est `supabase/functions/noria/deno.json`.
- Les migrations versionnees sont dans `supabase/migrations/`; `supabase/schema.sql` reste le schema de reference pour une nouvelle base.
- Le secret de signature de session peut etre fourni dans Supabase sous `SESSION_SECRET` (au moins 32 caracteres). A defaut, la fonction conserve la compatibilite avec la cle serveur Supabase.

## Regles a valider avant les donnees reelles

L’application rend les regles configurables, mais l’employeur doit confirmer les droits de conges, temps partiel/prorata/report/arrondis, les horaires et pauses applicables, la delegation, les durees de conservation et la procedure de recuperation d’identifiant sans e-mail. Les echeances de conservation constituent un suivi; aucune suppression automatique n’est active. Confirmer aussi les parametres de sauvegarde/restauration et les engagements des hebergeurs.

La paie complete, les declarations sociales/DSN, la signature electronique, la biometrie, la geolocalisation et le portail candidat public ne font pas partie de ce perimetre initial. L’implementation ne remplace ni la recette d’acceptation par roles ni la validation juridique/RH.

Les trames de courrier initiales sont des projets modifiables; elles doivent être relues et validées par l’équipe RH avant notification officielle.
