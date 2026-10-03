# Noria — espace SIRH

Noria est un espace RH en français, utilisable sur ordinateur et mobile. La connexion se fait avec un identifiant et un mot de passe, sans adresse e-mail ni lien magique.

## Modules opérationnels

- **Vue d’ensemble** : effectif, absences du jour, demandes à traiter et postes ouverts.
- **Collaborateurs** : annuaire, dossiers, service, poste, contrat, arrivée, lieu, statut et solde de congés. La création et la modification des dossiers sont réservées à l’administration RH.
- **Congés et absences** : demandes, historique, validation ou refus, contrôle des chevauchements et suivi du solde.
- **Temps de travail** : pointage d’arrivée et de départ et historique personnel; les managers consultent les pointages de leur équipe.
- **Recrutement** : offres, candidatures et étapes du processus. Les données candidates sont limitées aux rôles RH/manager.
- **Talents et formations** : catalogue, places disponibles et inscriptions.
- **Documents RH** : dépôts de fichiers privés, liens de consultation temporaires, accès limité au salarié concerné et aux rôles RH autorisés.
- **Entretiens** : planification et suivi selon le rôle.
- **Sécurité du compte** : changement de mot de passe, sessions HTTP-only et mots de passe protégés par PBKDF2-SHA-256.

## Architecture et publication

L’interface est servie par la fonction Supabase `noria` et publiée aussi sur Vercel. Le dépôt GitHub `evansarr33/Intranet` contient l’interface, le proxy Vercel et le schéma. Le proxy Vercel transmet l’API à Supabase; la clé serveur reste dans Supabase.

La fonction s’appuie sur les tables `employees`, `hr_accounts`, `leave_requests`, `attendance_records`, `job_postings`, `candidates`, `training_courses`, `training_enrollments`, `employee_documents` et `performance_reviews`. Les accès aux tables passent par le serveur, avec RLS et révocation des privilèges directs des rôles clients.

## Données RH

Avant d’importer des données réelles, l’organisation doit définir ses durées de conservation, ses sauvegardes, ses règles de congés et de temps, ses procédures de départ et les rôles de validation. Les documents ne doivent contenir que les informations nécessaires aux finalités RH. La paie, les déclarations sociales, la signature électronique et les workflows juridiques ne sont pas inclus dans cette version.
