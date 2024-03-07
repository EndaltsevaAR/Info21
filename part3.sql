-- 1) Написать функцию, возвращающую таблицу TransferredPoints в более человекочитаемом виде

CREATE OR REPLACE FUNCTION fnc_transferredpoints_new()
    RETURNS TABLE
            (
                "Peer1"        text,
                "Peer2"        text,
                "PointsAmount" integer
            )
AS
$$
BEGIN
    RETURN query
        (SELECT tp1.CheckingPeer, tp1.CheckedPeer, (tp1.PointsAmount - COALESCE(tp2.PointsAmount, 0))
         FROM TransferredPoints tp1
                  LEFT JOIN TransferredPoints tp2
                            ON tp1.CheckingPeer = tp2.CheckedPeer AND tp1.CheckedPeer = tp2.CheckingPeer
                                AND tp1.ID < tp2.ID)
        EXCEPT
        (SELECT tp3.CheckingPeer, tp3.CheckedPeer, tp3.PointsAmount
         FROM TransferredPoints tp3
                  JOIN TransferredPoints tp4
                       ON tp3.CheckingPeer = tp4.CheckedPeer AND tp3.CheckedPeer = tp4.CheckingPeer
                           AND tp3.ID > tp4.ID)
        ORDER BY 1, 2;
END;
$$ LANGUAGE PLPGSQL;

SELECT *
FROM fnc_transferredpoints_new()
WHERE "PointsAmount" >= 1;
SELECT *
FROM fnc_transferredpoints_new()
WHERE "PointsAmount" = 0;
SELECT *
FROM fnc_transferredpoints_new();

-- 2) Написать функцию, которая возвращает таблицу вида:
-- ник пользователя, название проверенного задания, кол-во полученного XP

CREATE OR REPLACE FUNCTION completed_successfully()
    RETURNS table
            (
                "Peer" text,
                "Task" text,
                "XP"   integer
            )
AS
$$
BEGIN
    RETURN query
        SELECT Checks.Peer, Checks.Task, x.XPAmount xpa
        FROM Checks
                 JOIN XP x on Checks.ID = x."Check"
        ORDER BY Peer;
END;
$$ LANGUAGE PLPGSQL;

SELECT *
FROM completed_successfully()
WHERE "Peer" = 'joserans';
SELECT *
FROM completed_successfully()
WHERE "XP" >= 200;
SELECT *
FROM completed_successfully();

-- 3) Написать функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня

CREATE OR REPLACE FUNCTION not_left_campus_all_day(day DATE)
    RETURNS table
            (
                "Peer" text
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT TimeTracking.Peer
        FROM TimeTracking
        WHERE TimeTracking.Date = day
          AND State = 1
        GROUP BY TimeTracking.Peer
        HAVING COUNT(State) = 1;
END;
$$ LANGUAGE PLPGSQL;

SELECT *
FROM not_left_campus_all_day('2023-10-10');
SELECT *
FROM not_left_campus_all_day('2023-01-09');
SELECT *
FROM not_left_campus_all_day('2023-10-05');

-- 4) Посчитать изменение в количестве пир поинтов каждого пира по таблице TransferredPoints

CREATE OR REPLACE FUNCTION fnc_peer_points_change()
    RETURNS TABLE
            (
                "Peer"         text,
                "PointsChange" integer
            )
AS
$$
BEGIN
    RETURN query
        SELECT Nickname,
               ((SELECT COALESCE(SUM(PointsAmount), 0)
                 FROM TransferredPoints tp
                 WHERE tp.CheckingPeer = Peers.Nickname) -
                (SELECT COALESCE(SUM(PointsAmount), 0)
                 FROM TransferredPoints tp
                 WHERE tp.CheckedPeer = Peers.Nickname))::integer pc
        FROM Peers
        ORDER BY pc DESC;
END;
$$ LANGUAGE PLPGSQL;

SELECT *
FROM fnc_peer_points_change()
WHERE "PointsChange" >= 0;
SELECT *
FROM fnc_peer_points_change()
WHERE "Peer" = 'spicepim';
SELECT *
FROM fnc_peer_points_change();

-- 5) Посчитать изменение в количестве пир поинтов каждого пира по таблице,
-- возвращаемой первой функцией из Part 3

CREATE OR REPLACE FUNCTION fnc_peer_points_change_new()
    RETURNS TABLE
            (
                "Peer"         text,
                "PointsChange" integer
            )
AS
$$
BEGIN
    RETURN query
        SELECT Nickname,
               ((SELECT COALESCE(SUM("PointsAmount"), 0)
                 FROM fnc_transferredpoints_new() tp1
                 WHERE tp1."Peer1" = Peers.Nickname) -
                (SELECT COALESCE(SUM("PointsAmount"), 0)
                 FROM fnc_transferredpoints_new() tp2
                 WHERE tp2."Peer2" = Peers.Nickname))::integer pc
        FROM Peers
        ORDER BY pc DESC;
END;
$$ LANGUAGE PLPGSQL;

SELECT *
FROM fnc_peer_points_change_new()
WHERE "PointsChange" >= 0;
SELECT *
FROM fnc_peer_points_change_new()
WHERE "Peer" = 'spicepim';
SELECT *
FROM fnc_peer_points_change_new();

-- 6) Определить самое часто проверяемое задание за каждый день

CREATE OR REPLACE FUNCTION frequently_checked()
    RETURNS TABLE
            (
                "Day"  date,
                "Task" text
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH checked_data AS (SELECT Checks.Date AS Date,
                                     Checks.Task AS Task,
                                     count(*)    AS task_count
                              FROM Checks
                              GROUP BY Checks.Task, Checks.Date),
             tmp_data AS (SELECT checked_data.Date, checked_data.Task, max(task_count) AS max_checks
                          FROM checked_data
                          GROUP BY checked_data.Date, checked_data.Task)

        SELECT date, task
        FROM tmp_data
        ORDER BY date;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM frequently_checked()
WHERE "Task" = 'CP_SimpleBashUtils';
SELECT *
FROM frequently_checked()
WHERE "Day" = '2023-09-05';
SELECT *
FROM frequently_checked();

--12) Using recursive common table expression, output the number of preceding tasks for each task
-- using at this part

CREATE OR REPLACE FUNCTION recurs_tasks_history_count()
    RETURNS TABLE
            (
                "Task"      text,
                "PrevCount" integer
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH RECURSIVE TaskHierarchy AS (SELECT t1.Title, t1.ParentTask, 0 AS Counts
                                         FROM Tasks AS t1
                                         WHERE ParentTask IS NULL

                                         UNION ALL

                                         SELECT t2.Title, t2.ParentTask, TH.Counts + 1
                                         FROM Tasks AS t2
                                                  JOIN TaskHierarchy AS TH ON t2.ParentTask = TH.Title)
        SELECT Title, Counts
        FROM TaskHierarchy;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM recurs_tasks_history_count();

-- 7) Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания

CREATE OR REPLACE FUNCTION peer_completed_block(block_name text)
    RETURNS TABLE
            (
                Peer text,
                Day  date
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH blocks_max AS (SELECT substring("Task" FROM 1 FOR POSITION('_' IN "Task") - 1) AS task_prefix,
                                   MAX("PrevCount")                                         AS max_prevcount
                            FROM recurs_tasks_history_count()
                            GROUP BY task_prefix),

             peer_tasks AS (SELECT "Peer" AS Peer, "Task" AS Task
                            FROM completed_successfully() AS cs
                            WHERE ((SELECT "PrevCount" FROM recurs_tasks_history_count() WHERE "Task" = cs."Task"))
                                      = (SELECT max_prevcount FROM blocks_max WHERE task_prefix = block_name))

        SELECT peer_tasks.Peer, MAX(Checks.Date)
        FROM peer_tasks
                 JOIN Checks ON Checks.peer = peer_tasks.Peer
        WHERE peer_tasks.Task = Checks.task
        GROUP BY peer_tasks.Peer
        ORDER BY peer_tasks.Peer;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM peer_completed_block('CPPP');
SELECT *
FROM peer_completed_block('CPP');
SELECT *
FROM peer_completed_block('CP');

-- 8) Определить, к какому пиру стоит идти на проверку каждому обучающемуся

CREATE OR REPLACE FUNCTION peer_recommendations()
    RETURNS TABLE
            (
                "Peer"            text,
                "RecommendedPeer" text
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT r.peer AS peer, r.recommendedPeer AS recommendedPeer
        FROM (SELECT Recommendations.peer,
                     Recommendations.recommendedPeer,
                     ROW_NUMBER() OVER (PARTITION BY Recommendations.peer
                         ORDER BY COUNT(Recommendations.recommendedPeer) DESC) AS row_num
              FROM recommendations
              GROUP BY Recommendations.peer, Recommendations.recommendedPeer) AS r
        WHERE r.row_num > 0;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM peer_recommendations()
WHERE "Peer" = 'almetate';
SELECT *
FROM peer_recommendations()
WHERE "RecommendedPeer" = 'joserans';
SELECT *
FROM peer_recommendations();


-- 9) Определить процент пиров, которые:
--
--  Приступили только к блоку 1
--  Приступили только к блоку 2
--  Приступили к обоим
--  Не приступили ни к одному

CREATE OR REPLACE FUNCTION blocks_percentage(pblock1 text, pblock2 text)
    RETURNS TABLE
            (
                "StartedBlock1"       BIGINT,
                "StartedBlock2"       BIGINT,
                "StartedBothBlocks"   BIGINT,
                "DidntStatrAnyBlocks" BIGINT
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH started_first AS (SELECT DISTINCT Peer
                               From Checks
                               WHERE Task LIKE '%' || pblock1 || '_%'),
             started_second AS (SELECT DISTINCT Peer
                                From Checks
                                WHERE Task LIKE '%' || pblock2 || '_%'),
             started_both AS (SELECT *
                              FROM started_first
                              INTERSECT
                              SELECT *
                              FROM started_second)
        SELECT 100 * (SELECT COUNT(*) FROM started_first) / (SELECT COUNT(*) FROM Peers),
               100 * (SELECT COUNT(*) FROM started_second) / (SELECT COUNT(*) FROM Peers),
               100 * (SELECT COUNT(*) FROM started_both) / (SELECT COUNT(*) FROM Peers),
               100 * ((SELECT COUNT(*) FROM Peers) - (SELECT COUNT(*) FROM started_first) -
                      (SELECT COUNT(*) FROM started_second) + (SELECT COUNT(*) FROM started_both)) /
               (SELECT COUNT(*) FROM Peers)
        FROM started_first,
             started_second,
             started_both
        LIMIT 1;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM blocks_percentage('CPP', 'CP');
SELECT *
FROM blocks_percentage('CP', 'CPP');

-- 10) Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения

CREATE OR REPLACE FUNCTION birthday_submitions()
    RETURNS TABLE
            (
                "SuccessfulChecks"   BIGINT,
                "UnsuccessfulChecks" BIGINT
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH passed AS (SELECT COUNT(*) AS amount
                        FROM Peers AS pr
                                 INNER JOIN Checks AS ch
                                            ON (ch.Peer = pr.Nickname)
                                 LEFT JOIN Verter ON Verter."Check" = ch.ID
                                 LEFT JOIN P2P ON P2P."Check" = ch.ID
                        WHERE ((Verter.State = 'Success' OR Verter.State IS NULL) AND P2P.State = 'Success' AND
                               (EXTRACT(DAY FROM pr.Birthday) = EXTRACT(DAY FROM ch.Date)) AND
                               (EXTRACT(MONTH FROM pr.Birthday) = EXTRACT(MONTH FROM ch.Date)))
                        GROUP BY pr.Nickname),
             missed AS (SELECT COUNT(*) AS amount
                        FROM Peers AS pr
                                 INNER JOIN Checks AS ch
                                            ON (ch.Peer = pr.Nickname)
                                 LEFT JOIN Verter ON Verter."Check" = ch.ID
                                 LEFT JOIN P2P ON P2P."Check" = ch.ID
                        WHERE ((Verter.State = 'Failure' OR Verter.State IS NULL) AND P2P.State = 'Failure' AND
                               (EXTRACT(DAY FROM pr.Birthday) = EXTRACT(DAY FROM ch.Date)) AND
                               (EXTRACT(MONTH FROM pr.Birthday) = EXTRACT(MONTH FROM ch.Date)))
                        GROUP BY pr.Nickname),
             total_peers AS (SELECT count(*) AS amount
                             FROM peers)

        SELECT (COALESCE((ps.amount::FLOAT), 0) / (SELECT amount FROM total_peers) * 100)::BIGINT AS SuccessfulChecks,
               (COALESCE((SELECT amount FROM missed)::FLOAT, 0) / (SELECT amount FROM total_peers) *
                100)::BIGINT                                                                      AS UnsuccessfulChecks
        FROM passed AS ps;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM birthday_submitions();

-- 11) Determine all peers who did the given tasks 1 and 2, but did not do task 3

CREATE OR REPLACE FUNCTION peers_parts_tasks(task_1 text, task_2 text, task_3 text)
    RETURNS TABLE
            (
                "Peer" text
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH first_task AS (SELECT DISTINCT cs."Peer" AS Peer
                            FROM completed_successfully() cs
                            WHERE cs."Task" = task_1),
             second_task AS (SELECT DISTINCT cs."Peer" AS Peer
                             FROM completed_successfully() cs
                             WHERE cs."Task" = task_2),
             do_third_task AS (SELECT DISTINCT cs."Peer" AS Peer FROM completed_successfully() cs WHERE cs."Task" = task_3)

        SELECT Peer
        FROM first_task
        INTERSECT

        SELECT Peer
        FROM second_task

        INTERSECT

        (SELECT Nickname
         FROM Peers

         EXCEPT

         SELECT Peer
         FROM do_third_task);

END;
$$ LANGUAGE plpgsql;

SELECT *
FROM peers_parts_tasks('CPP_s21_math', 'CPP_s21_decimal', 'CP_SimpleBashUtils');
SELECT *
FROM peers_parts_tasks('CP_SimpleBashUtils', 'CPP_s21_math', 'CPPP_3DViewer_v1.0');
SELECT *
FROM peers_parts_tasks('CP_SimpleBashUtils', 'CPP_s21_decimal', 'CPPP_3DViewer_v1.0');
SELECT *
FROM peers_parts_tasks('CP_SimpleBashUtils', 'CP_SimpleBashUtils', 'CPPP_3DViewer_v1.0');


--12) Using recursive common table expression, output the number of preceding tasks for each task

CREATE OR REPLACE FUNCTION recurs_tasks_history_count()
    RETURNS TABLE
            (
                "Task"      text,
                "PrevCount" integer
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH RECURSIVE TaskHierarchy AS (SELECT t1.Title, t1.ParentTask, 0 AS Counts
                                         FROM Tasks AS t1
                                         WHERE ParentTask IS NULL

                                         UNION ALL

                                         SELECT t2.Title, t2.ParentTask, TH.Counts + 1
                                         FROM Tasks AS t2
                                                  JOIN TaskHierarchy AS TH ON t2.ParentTask = TH.Title)
        SELECT Title, Counts
        FROM TaskHierarchy;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM recurs_tasks_history_count();

--13) Find "lucky" days for checks. A day is considered "lucky" if it has at least N consecutive successful checks

CREATE OR REPLACE FUNCTION lucky_days(N integer)
    RETURNS TABLE
            (
                "Lucky_day" DATE
            )
AS
$$
BEGIN
RETURN QUERY
WITH lucky_days AS (SELECT Checks.Date AS Date,
                           P2P.time    AS Time,
                           P2P.state   AS Result,
                           XP.xpamount AS RealXP,
                           Tasks.maxxp AS MaxXP
                    FROM P2P
                             JOIN Checks ON P2P."Check" = Checks.id
                             JOIN XP ON XP."Check" = Checks.id
                             JOIN Tasks ON Tasks.title = Checks.task
                    WHERE (state = 'Success')
                      AND XP.xpamount >= Tasks.maxxp * 0.8
                    ORDER BY 1, 2)

SELECT Date
FROM lucky_days
GROUP BY Date
HAVING COUNT(*) >= n;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM lucky_days(1);
SELECT *
FROM lucky_days(2);

--14) Find the peer with the highest amount of XP

CREATE OR REPLACE FUNCTION max_xp()
    RETURNS TABLE
            (
                "Peer" text,
                "XP"   bigint
            )
AS
$$
BEGIN
RETURN QUERY
SELECT Checks.peer, SUM(xpamount) AS XP
FROM XP
         JOIN Checks ON XP."Check" = Checks.id
GROUP BY Checks.peer
ORDER BY XP DESC
LIMIT 1;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM max_xp();


--15) Determine the peers that came before the given time at least N times during the whole time

CREATE OR REPLACE FUNCTION before_time(enter_time time, N integer)
    RETURNS TABLE
            (
                "Peer" text
            )
AS
$$
BEGIN
RETURN QUERY
SELECT tt.peer
FROM TimeTracking AS tt
WHERE tt.time < enter_time
GROUP BY tt.peer
HAVING count(*) >= N;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM before_time(TIME '13:00:00', 1);
SELECT *
FROM before_time(TIME '13:00:00', 2);

--16) Determine the peers who left the campus more than M times during the last N days

CREATE OR REPLACE FUNCTION lefted_peers(M integer, N integer)
    RETURNS TABLE
            (
                "Peer" text
            )
AS
$$
BEGIN
RETURN QUERY
SELECT tt.peer
FROM TimeTracking AS tt
WHERE tt.date BETWEEN CURRENT_DATE - N AND CURRENT_DATE
  AND tt.state = 2
GROUP BY tt.peer
HAVING count(*) >= M;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM lefted_peers(1, 1);
SELECT *
FROM lefted_peers(1, 30);
SELECT *
FROM lefted_peers(2, 30);

--17) Determine for each month the percentage of early entries

CREATE OR REPLACE FUNCTION birthday_entries()
    RETURNS TABLE ("Month" text, "EarlyEntries" real) AS $$
BEGIN
    RETURN QUERY
    WITH
        months(m) AS
            (SELECT * FROM generate_series('2000-01-01'::date, '2000-12-01'::date, '1 month')),
        entries AS
            (SELECT Time, Birthday FROM TimeTracking tt JOIN Peers ON tt.Peer = Peers.Nickname AND tt.State = 1),
        total_entries AS
            (SELECT m, COUNT(Time) FROM months LEFT JOIN entries
                ON EXTRACT(MONTH FROM months.m) = EXTRACT(MONTH FROM entries.Birthday)
            GROUP BY m
            ORDER BY m),
        early_entries AS
            (SELECT m, COUNT(Time) FROM months LEFT JOIN entries
                ON EXTRACT(MONTH FROM months.m) = EXTRACT(MONTH FROM entries.Birthday)
                    AND EXTRACT(HOUR FROM entries.Time) < 12
            GROUP BY m
            ORDER BY m)
        SELECT to_char(te.m, 'Month'), (ee.count::numeric /
            (CASE WHEN te.count = 0 THEN 1 ELSE te.count END) * 100)::real
        FROM total_entries te JOIN early_entries ee ON te.m = ee.m;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM birthday_entries();
