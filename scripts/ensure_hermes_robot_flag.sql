-- Ensure Hermes IM user is marked as robot for client Bot badges.
-- Usage (from repo root, with compose MySQL up):
--   docker compose exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' < scripts/ensure_hermes_robot_flag.sql
-- Adjust schema name if your stack uses a different database.

-- Local docker-compose stack uses schema `im` (adjust if yours differs).
UPDATE `im`.user
SET robot = 1
WHERE username = 'hermes'
   OR phone = '13800000001'
   OR name = 'Hermes';

-- Confirm
SELECT uid, name, username, phone, robot, category
FROM `im`.user
WHERE username = 'hermes' OR phone = '13800000001' OR name = 'Hermes'
LIMIT 5;
