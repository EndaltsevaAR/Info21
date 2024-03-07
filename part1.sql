--ЭКСПОРТ И ИМПОРТ РАБОТАЮТ, НО ПИРУ НУЖНО СКОРРЕКТИРОВАТЬ ПУТЬ ФАЙЛА НА СВОЮ ПАПКУ ДЛЯ КОРРЕКТНОЙ РАБОТЫ
--CREATE DATABASE info_db; --команда в консоли в psql

--написала дропы для внутренней работы, чтобы дропать после появления ограничений
DROP TYPE IF EXISTS statuses_type CASCADE;
DROP TABLE IF EXISTS Peers CASCADE;
DROP TABLE IF EXISTS Tasks CASCADE;
DROP TABLE IF EXISTS Checks CASCADE;
DROP TABLE IF EXISTS P2P CASCADE;
DROP TABLE IF EXISTS Verter CASCADE;
DROP TABLE IF EXISTS XP CASCADE;
DROP TABLE IF EXISTS TransferredPoints CASCADE;
DROP TABLE IF EXISTS Friends CASCADE;
DROP TABLE IF EXISTS Recommendations CASCADE;
DROP TABLE IF EXISTS TimeTracking CASCADE;

-- создание таблиц и типа для бд
CREATE TABLE IF NOT EXISTS Peers
(
    Nickname text PRIMARY KEY,
    Birthday DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS Tasks
(
    Title      text PRIMARY KEY,
    ParentTask text REFERENCES Tasks (Title),
    MaxXP      integer NOT NULL CHECK ( MaxXP > 0 )
);

CREATE TYPE statuses_type AS ENUM ('Start', 'Success', 'Failure');

CREATE TABLE IF NOT EXISTS Checks
(
    ID   serial PRIMARY KEY,
    Peer text REFERENCES Peers (Nickname),
    Task text REFERENCES Tasks (Title),
    Date DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS P2P
(
    ID           serial PRIMARY KEY,
    "Check"      integer REFERENCES Checks (ID),
    CheckingPeer text REFERENCES Peers (Nickname),
    State        statuses_type NOT NULL,
    Time         time          NOT NULL
);

CREATE TABLE IF NOT EXISTS Verter
(
    ID      serial PRIMARY KEY,
    "Check" integer REFERENCES Checks (ID),
    State   statuses_type NOT NULL,
    Time    time          NOT NULL
);

CREATE TABLE IF NOT EXISTS XP
(
    ID       serial PRIMARY KEY,
    "Check"  integer REFERENCES Checks (ID),
    XPAmount integer NOT NULL
);

CREATE TABLE IF NOT EXISTS TransferredPoints
(
    ID           serial PRIMARY KEY,
    CheckingPeer text REFERENCES Peers (Nickname),
    CheckedPeer  text REFERENCES Peers (Nickname),
    PointsAmount integer NOT NULL CHECK (PointsAmount > 0)
);

CREATE TABLE IF NOT EXISTS Friends
(
    ID    serial PRIMARY KEY,
    Peer1 text REFERENCES Peers (Nickname),
    Peer2 text REFERENCES Peers (Nickname)
);

CREATE TABLE IF NOT EXISTS Recommendations
(
    ID              serial PRIMARY KEY,
    Peer            text REFERENCES Peers (Nickname),
    RecommendedPeer text REFERENCES Peers (Nickname)
);

CREATE TABLE IF NOT EXISTS TimeTracking
(
    ID    serial PRIMARY KEY,
    Peer  text REFERENCES Peers (Nickname),
    Date  DATE                             NOT NULL,
    Time  time                             NOT NULL,
    State integer CHECK (State IN (1, 2) ) NOT NULL
);

-- обнуление содержимого таблиц
TRUNCATE Peers CASCADE;
TRUNCATE Tasks CASCADE;
TRUNCATE Checks CASCADE;
TRUNCATE P2P CASCADE;
TRUNCATE Verter CASCADE;
TRUNCATE XP CASCADE;
TRUNCATE TransferredPoints CASCADE;
TRUNCATE Friends CASCADE;
TRUNCATE Recommendations CASCADE;
TRUNCATE TimeTracking CASCADE;

-- процедура импорта из файла .csv
--sudo chmod 777 /home/joserans_home
--sudo chown -R postgres:postgres /home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files
CREATE OR REPLACE PROCEDURE import_from_csv(table_name text, file_name text, delimetr char)
AS
$$
BEGIN
    EXECUTE 'COPY ' || table_name || ' FROM ' || quote_literal(file_name) || ' DELIMITER ' || quote_literal(delimetr) ||
            ' CSV HEADER';
END
$$
    LANGUAGE plpgsql;
/*
--проверка работоспособности импорта из файла
--sudo chown -R postgres:postgres /home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files
CALL import_from_csv('Peers', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/peers.csv', '|');
CALL import_from_csv('Tasks', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/tasks.csv', '|');
CALL import_from_csv('Checks', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/checks.csv', '|');
CALL import_from_csv('P2P', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/p2p.csv', '|');
CALL import_from_csv('Verter', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/verter.csv', '|');
CALL import_from_csv('XP', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/xp.csv', '|');
CALL import_from_csv('TransferredPoints', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/transferredpoints.csv', '|');
CALL import_from_csv('Friends', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/friends.csv', '|');
CALL import_from_csv('Recommendations', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/recommendations.csv', '|');
CALL import_from_csv('TimeTracking', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/timetracking.csv', '|');
*/

--заполнение данных вручную, если не из файлов

INSERT INTO Peers (Nickname, Birthday)
VALUES ('joserans', '1991-09-08'),
       ('lpuddy', '1990-10-02'),
       ('spicepim', '1995-01-01'),
       ('almetate', '2001-05-05'),
       ('nohoteth', '1970-09-01');

INSERT INTO Tasks (Title, ParentTask, MaxXP)
VALUES ('CP_SimpleBashUtils', null, 250),
       ('CPP_s21_string+', 'CP_SimpleBashUtils', 500),
       ('CPP_s21_math', 'CP_SimpleBashUtils', 300),
       ('CPP_s21_decimal', 'CP_SimpleBashUtils', 350),
       ('CPP_s21_matrix', 'CPP_s21_decimal', 200),
       ('CPPP_SmartCalc_v1.0', 'CPP_s21_decimal', 500),
       ('CPPP_3DViewer_v1.0', 'CPPP_SmartCalc_v1.0', 750);

INSERT INTO Checks (Peer, Task, Date)
VALUES ('joserans', 'CP_SimpleBashUtils', '2023-09-01'),
       ('lpuddy', 'CP_SimpleBashUtils', '2023-09-01'),
       ('spicepim', 'CP_SimpleBashUtils', '2023-10-01'),
       ('joserans', 'CPP_s21_string+', '2023-10-02'),
       ('lpuddy', 'CP_SimpleBashUtils', '2023-09-11'),
       ('lpuddy', 'CPP_s21_decimal', '2023-10-04'),
       ('joserans', 'CPP_s21_decimal', '2023-09-08'),
       ('joserans', 'CPP_s21_math', '2023-09-05'),
       ('almetate', 'CP_SimpleBashUtils', '2023-09-12');

INSERT INTO P2P ("Check", CheckingPeer, State, Time)
VALUES (1, 'almetate', 'Start', TIME '12:00:00'),
       (1, 'almetate', 'Success', TIME '12:30:00'),
       (2, 'nohoteth', 'Start', TIME '18:35:02'),
       (2, 'nohoteth', 'Success', TIME '19:40:07'),
       (3, 'joserans', 'Start', TIME '15:00:00'),
       (3, 'joserans', 'Success', TIME '15:38:00'),
       (4, 'lpuddy', 'Start', TIME '07:00:09'),
       (4, 'lpuddy', 'Failure', TIME '07:06:09'),
       (5, 'spicepim', 'Start', TIME '16:15:49'),
       (5, 'spicepim', 'Success', TIME '17:05:49'),
       (6, 'nohoteth', 'Start', TIME '23:15:49'),
       (7, 'spicepim', 'Start', TIME '09:00:00'),
       (7, 'spicepim', 'Success', TIME '09:30:00'),
       (8, 'nohoteth', 'Start', TIME '05:35:02'),
       (8, 'nohoteth', 'Success', TIME '05:40:07'),
       (9, 'lpuddy', 'Start', TIME '12:35:08'),
       (9, 'lpuddy', 'Success', TIME '12:40:03');

INSERT INTO Verter ("Check", State, Time)
VALUES (1, 'Start', TIME '12:31:00'),
       (1, 'Success', TIME '12:32:00'),
       (2, 'Start', TIME '19:45:02'),
       (2, 'Failure', TIME '19:46:02'),
       (3, 'Start', TIME '15:39:00'),
       (8, 'Start', TIME '05:41:07'),
       (8, 'Success', TIME '05:45:07');

INSERT INTO XP ("Check", XPAmount)
VALUES (1, 250),
       (5, 200),
       (7, 350),
       (8, 200),
       (9, 230);


INSERT INTO TransferredPoints (CheckingPeer, CheckedPeer, PointsAmount)
VALUES ('almetate', 'joserans', 1),
       ('nohoteth', 'lpuddy', 2),
       ('joserans', 'spicepim', 1),
       ('lpuddy', 'joserans', 1),
       ('spicepim', 'lpuddy', 1),
       ('spicepim', 'joserans', 1),
       ('nohoteth', 'joserans', 1),
       ('lpuddy', 'almetate', 1);

INSERT INTO Friends (Peer1, Peer2)
VALUES ('almetate', 'joserans'),
       ('joserans', 'spicepim'),
       ('joserans', 'lpuddy'),
       ('joserans', 'nohoteth'),
       ('spicepim', 'lpuddy');

INSERT INTO Recommendations (Peer, RecommendedPeer)
VALUES ('almetate', 'joserans'),
       ('joserans', 'spicepim'),
       ('joserans', 'lpuddy'),
       ('joserans', 'nohoteth'),
       ('spicepim', 'lpuddy');

INSERT INTO TimeTracking (Peer, Date, Time, State)
VALUES ('almetate', '2023-09-09', TIME '10:00:00', 1),
       ('almetate', '2023-09-09', TIME '16:00:00', 2),
       ('nohoteth', '2023-09-01', TIME '17:10:00', 1),
       ('nohoteth', '2023-09-01', TIME '21:01:05', 2),
       ('joserans', '2023-10-01', TIME '14:10:00', 1),
       ('joserans', '2023-10-01', TIME '20:45:25', 2),
       ('spicepim', '2023-09-11', TIME '09:10:03', 1),
       ('spicepim', '2023-09-11', TIME '23:54:25', 2),
       ('lpuddy', '2023-10-02', TIME '05:10:00', 1),
       ('lpuddy', '2023-10-02', TIME '10:45:25', 2),
       ('lpuddy', '2023-10-05', TIME '00:00:00', 1),
       ('lpuddy', '2023-10-06', TIME '00:00:00', 2);


-- процедура экспорта в  файл .csv
CREATE OR REPLACE PROCEDURE export_from_csv(table_name text, file_name text, delimetr char)
AS
$$
BEGIN
    EXECUTE 'COPY (SELECT * FROM  ' || table_name || ') TO ' || quote_literal(file_name) || ' DELIMITER ' || quote_literal(delimetr) ||
            ' CSV HEADER';
END
$$
    LANGUAGE plpgsql;
/*
--проверка работоспособности импорта из файла
--sudo chown -R postgres:postgres /home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files
CALL export_from_csv('peers', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/peers.csv', '|');
CALL export_from_csv('tasks', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/tasks.csv', '|');
CALL export_from_csv('checks', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/checks.csv', '|');
CALL export_from_csv('p2p', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/p2p.csv', '|');
CALL export_from_csv('verter', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/verter.csv', '|');
CALL export_from_csv('xp', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/xp.csv', '|');
CALL export_from_csv('transferredpoints', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/transferredpoints.csv', '|');
CALL export_from_csv('friends', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/friends.csv', '|');
CALL export_from_csv('recommendations', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/recommendations.csv', '|');
CALL export_from_csv('timetracking', '/home/joserans_home/school21/sql/info/SQL2_Info21_v1.0-1/src/files/timetracking.csv', '|');
*/