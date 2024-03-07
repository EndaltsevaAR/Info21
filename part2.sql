DROP PROCEDURE IF EXISTS insert_p2p_check;
DROP PROCEDURE IF EXISTS insert_verter_check;
DROP FUNCTION IF EXISTS fnc_trg_p2p_insert CASCADE;
DROP FUNCTION IF EXISTS fnc_trg_xp_insert CASCADE;

-- 1 procedure

CREATE OR REPLACE PROCEDURE insert_p2p_check
    (peer_checked text, peer_checking text,
    task_title text, state statuses_type, check_time time)
AS $$
BEGIN
    IF (state = 'Start') THEN
        IF (SELECT COALESCE((SELECT count(*) FROM P2P JOIN Checks ON P2P."Check" = Checks.ID
        WHERE Peer = peer_checked AND CheckingPeer = peer_checking AND Task = task_title
            GROUP BY P2P."Check" ORDER BY P2P."Check" DESC LIMIT 1), 0) % 2 = 0) THEN
            INSERT INTO Checks (Peer, Task, Date) VALUES (peer_checked, task_title, now());
            INSERT INTO P2P ("Check", CheckingPeer, State, Time)
                VALUES ((SELECT ID FROM Checks WHERE Peer = peer_checked AND Task = task_title
                GROUP BY ID ORDER BY ID DESC LIMIT 1), peer_checking, state, check_time);
        ELSE RAISE EXCEPTION 'Previous check is not completed';
        END IF;
    ELSE
        IF ((SELECT count(*) FROM P2P JOIN Checks ON P2P."Check" = Checks.ID
        WHERE Peer = peer_checked AND CheckingPeer = peer_checking AND Task = task_title
            GROUP BY P2P."Check" ORDER BY P2P."Check" DESC LIMIT 1) = 1) THEN
            INSERT INTO P2P ("Check", CheckingPeer, State, Time)
                VALUES ((SELECT ID FROM Checks WHERE Peer = peer_checked AND Task = task_title
                GROUP BY ID ORDER BY ID DESC LIMIT 1), peer_checking, state, check_time);
        ELSE RAISE EXCEPTION 'Сheck does not exist';
        END IF;
    END IF;
END;
$$ LANGUAGE PLPGSQL;

-- DROP PROCEDURE IF EXISTS insert_p2p_check;

CALL insert_p2p_check('almetate', 'nohoteth', 'CP_SimpleBashUtils', 'Start', '12:37:00');
CALL insert_p2p_check('almetate', 'nohoteth', 'CP_SimpleBashUtils', 'Success', '12:37:00');
CALL insert_p2p_check('almetate', 'nohoteth', 'CP_SimpleBashUtils', 'Start', '12:39:00');
CALL insert_p2p_check('almetate', 'nohoteth', 'CP_SimpleBashUtils', 'Success', '12:39:00');
-- for check wrong data
--CALL insert_p2p_check('almetate', 'nohoteth', 'abc', 'Start', '12:37:00');

-- 2 procedure

CREATE OR REPLACE PROCEDURE insert_verter_check
    (peer_checked text, task_title text, status statuses_type, check_time time)
AS $$
DECLARE check_id Checks.ID%TYPE;
BEGIN
    IF (status = 'Start') THEN
        check_id := (SELECT COALESCE((SELECT P2P."Check" FROM P2P
        JOIN Checks ON P2P."Check" = Checks.ID
        WHERE Peer = peer_checked AND Task = task_title AND State = 'Success'
            GROUP BY P2P."Check" ORDER BY P2P."Check" DESC LIMIT 1), 0));
        IF (check_id = 0) THEN
            RAISE EXCEPTION 'There is no p2p check with the status "Success"
            for peer "%" and task "%"', peer_checked, task_title;
        ELSE
            INSERT INTO Verter ("Check", State, Time)
                VALUES (check_id, status, check_time);
        END IF;
    ELSE
        check_id := (SELECT COALESCE((SELECT Verter."Check" FROM Verter
        JOIN Checks ON Verter."Check" = Checks.ID
        WHERE Peer = peer_checked AND Task = task_title AND State = 'Start'
        GROUP BY Verter."Check" ORDER BY Verter."Check" DESC LIMIT 1), 0));
        IF (check_id = 0) THEN
            RAISE EXCEPTION 'There is no verter check with the status "Start"
            for peer "%" and task "%"', peer_checked, task_title;
        ELSIF EXISTS (SELECT "Check" FROM Verter
            WHERE "Check" = check_id AND State IN ('Success', 'Failure')) THEN
            RAISE EXCEPTION 'Сheck with id = "%" for peer "%" and task "%"
            already completed', check_id, peer_checked, task_title;
        ELSE
            INSERT INTO Verter ("Check", State, Time)
                VALUES (check_id, status, check_time);
        END IF;
    END IF;
END;
$$
LANGUAGE PLPGSQL;

-- DROP PROCEDURE IF EXISTS insert_verter_check;

CALL insert_verter_check('almetate', 'CP_SimpleBashUtils', 'Start', '12:37:05');
CALL insert_verter_check('almetate', 'CP_SimpleBashUtils', 'Success', '12:40:05');
-- for check wrong data
--CALL insert_verter_check('almetate', 'CP_SimpleBashUtils', 'Failure', '12:40:05');
--CALL insert_verter_check('almetate', 'ABc', 'Failure', '12:40:05');

-- 3 function

CREATE OR REPLACE FUNCTION fnc_trg_p2p_insert()
    RETURNS trigger AS $trg_p2p_insert$
DECLARE
    check_id TransferredPoints.ID%TYPE;
    checked_peer TransferredPoints.CheckedPeer%TYPE;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        checked_peer := (SELECT Peer FROM Checks 
        WHERE Checks.ID = NEW."Check");
        check_id := (SELECT ID FROM TransferredPoints AS tp
        WHERE tp.CheckingPeer = NEW.CheckingPeer AND tp.CheckedPeer = checked_peer);
        IF (check_id IS NOT NULL) THEN
            UPDATE TransferredPoints
            SET PointsAmount = PointsAmount + 1
            WHERE ID = check_id;
        ELSE
            INSERT INTO TransferredPoints (CheckingPeer, CheckedPeer, PointsAmount)
            VALUES (NEW.CheckingPeer, checked_peer, 1);
        END IF;
    END IF;
    RETURN NULL;
END;
$trg_p2p_insert$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER trg_p2p_insert
AFTER INSERT ON P2P
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_p2p_insert();

-- DROP FUNCTION IF EXISTS fnc_trg_p2p_insert CASCADE;

CREATE OR REPLACE FUNCTION fnc_trg_xp_insert()
    RETURNS trigger AS $trg_xp_insert$
BEGIN
    IF (NEW.XPAmount > (SELECT MaxXP FROM Tasks WHERE Title =
    (SELECT Task FROM Checks WHERE ID = NEW."Check"))) THEN
        RAISE EXCEPTION 'Check with ID = "%" can''t give % XP', NEW."Check", NEW.XPAmount;
    ELSIF NOT EXISTS (SELECT ID FROM P2P WHERE ("Check" = NEW."Check" AND State = 'Success'))
    OR EXISTS (SELECT ID FROM Verter WHERE ("Check" = NEW."Check" AND State = 'Failure')) THEN
        RAISE EXCEPTION 'Check with ID = "%" was not successfull', NEW."Check";
    END IF;
    RETURN NEW;
END;
$trg_xp_insert$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER trg_xp_insert
BEFORE INSERT ON XP
FOR EACH ROW
EXECUTE FUNCTION fnc_trg_xp_insert();

-- DROP FUNCTION IF EXISTS fnc_trg_xp_insert CASCADE;
/*
-- for check wrong data
INSERT INTO XP ("Check", XPAmount)
    VALUES (4, 100);

 */
