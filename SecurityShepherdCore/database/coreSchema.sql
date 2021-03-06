DELIMITER ;

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

DROP SCHEMA IF EXISTS `core` ;
CREATE SCHEMA IF NOT EXISTS `core` DEFAULT CHARACTER SET latin1 ;
USE `core` ;

SELECT "Creating Tables" FROM DUAL;

-- -----------------------------------------------------
-- Table `core`.`class`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `core`.`class` (
  `classId` VARCHAR(64) NOT NULL ,
  `className` VARCHAR(32) NOT NULL ,
  `classYear` VARCHAR(5) NOT NULL ,
  PRIMARY KEY (`classId`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `core`.`users`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `core`.`users` (
  `userId` VARCHAR(64) NOT NULL ,
  `classId` VARCHAR(64) NULL ,
  `userName` VARCHAR(32) NOT NULL ,
  `userPass` VARCHAR(512) NOT NULL ,
  `userRole` VARCHAR(32) NOT NULL ,
  `badLoginCount` INT NOT NULL DEFAULT 0 ,
  `suspendedUntil` DATETIME NOT NULL DEFAULT '1000-01-01 00:00:00' ,
  `userAddress` VARCHAR(128) NULL ,
  `tempPassword` TINYINT(1)  NULL DEFAULT FALSE ,
  `userScore` INT NOT NULL DEFAULT 0 ,
  `goldMedalCount` INT NOT NULL DEFAULT 0 ,
  `silverMedalCount` INT NOT NULL DEFAULT 0 ,
  `bronzeMedalCount` INT NOT NULL DEFAULT 0 ,
  `badSubmissionCount` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`userId`) ,
  INDEX `classId` (`classId` ASC) ,
  UNIQUE INDEX `userName_UNIQUE` (`userName` ASC) ,
  CONSTRAINT `classId`
    FOREIGN KEY (`classId` )
    REFERENCES `core`.`class` (`classId` )
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `core`.`modules`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `core`.`modules` (
  `moduleId` VARCHAR(64) NOT NULL ,
  `moduleName` VARCHAR(64) NOT NULL ,
  `moduleType` VARCHAR(16) NOT NULL ,
  `moduleCategory` VARCHAR(64) NULL ,
  `moduleResult` VARCHAR(256) NULL ,
  `moduleHash` VARCHAR(256) NULL ,
  `moduleStatus` VARCHAR(16) NULL DEFAULT 'open' ,
  `incrementalRank` INT NULL DEFAULT 200,
  `scoreValue` INT NOT NULL DEFAULT 50 ,
  `scoreBonus` INT NOT NULL DEFAULT 5 ,
  `hardcodedKey` TINYINT(1) NOT NULL DEFAULT TRUE,
  `goldMedalAvailable` TINYINT(1) NOT NULL DEFAULT TRUE,
  `silverMedalAvailable` TINYINT(1) NOT NULL DEFAULT TRUE,
  `bronzeMedalAvailable` TINYINT(1) NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`moduleId`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `core`.`results`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `core`.`results` (
  `userId` VARCHAR(64) NOT NULL ,
  `moduleId` VARCHAR(64) NOT NULL ,
  `startTime` DATETIME NOT NULL ,
  `finishTime` DATETIME NULL ,
  `csrfCount` INT NULL DEFAULT 0 ,
  `resultSubmission` LONGTEXT NULL ,
  `knowledgeBefore` INT NULL ,
  `knowledgeAfter` INT NULL ,
  `difficulty` INT NULL ,
  PRIMARY KEY (`userId`, `moduleId`) ,
  INDEX `fk_Results_Modules1` (`moduleId` ASC) ,
  CONSTRAINT `fk_Results_users1`
    FOREIGN KEY (`userId` )
    REFERENCES `core`.`users` (`userId` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Results_Modules1`
    FOREIGN KEY (`moduleId` )
    REFERENCES `core`.`modules` (`moduleId` )
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `core`.`cheatsheet`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `core`.`cheatsheet` (
  `cheatSheetId` VARCHAR(64) NOT NULL ,
  `moduleId` VARCHAR(64) NOT NULL ,
  `createDate` DATETIME NOT NULL ,
  `solution` LONGTEXT NOT NULL ,
  PRIMARY KEY (`cheatSheetId`, `moduleId`) ,
  INDEX `fk_CheatSheet_Modules1` (`moduleId` ASC) ,
  CONSTRAINT `fk_CheatSheet_Modules1`
    FOREIGN KEY (`moduleId` )
    REFERENCES `core`.`modules` (`moduleId` )
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `core`.`sequence`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `core`.`sequence` (
  `tableName` VARCHAR(32) NOT NULL ,
  `currVal` BIGINT(20) NOT NULL DEFAULT 282475249 ,
  PRIMARY KEY (`tableName`) )
ENGINE = InnoDB;

SELECT "Creating Procedures" FROM DUAL;

-- -----------------------------------------------------
-- procedure authUser
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`authUser` (IN theName VARCHAR(32), IN theHash VARCHAR(512))
BEGIN
DECLARE theDate DATETIME;
COMMIT;
SELECT NOW() FROM DUAL INTO theDate;
SELECT userId, userName, userRole, badLoginCount, tempPassword, classId FROM `users`
    WHERE userName = theName 
    AND userPass = SHA2(theHash, 512)
    AND suspendedUntil < theDate ;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userLocked
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userLocked` (IN theName VARCHAR(32))
BEGIN
DECLARE theDate DATETIME;
COMMIT;
SELECT NOW() FROM DUAL INTO theDate;
SELECT userName FROM `users` 
    WHERE userName = theName
    AND theDate > suspendedUntil;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userLock
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userLock` (theName VARCHAR(32))
BEGIN
DECLARE theDate DATETIME;
DECLARE untilDate DATETIME;
DECLARE theCount INT;

COMMIT;
SELECT NOW() FROM DUAL INTO theDate;
-- Get the badLoginCount from users if they are not suspended already or account has attempted a login within the last 10 mins
SELECT badLoginCount FROM `users` 
    WHERE userName = theName
    AND suspendedUntil < (theDate - '0000-00-00 00:10:00')
    INTO theCount;
    
SELECT suspendedUntil FROM `users` 
    WHERE userName = theName
    AND suspendedUntil < (theDate - '0000-00-00 00:10:00')
    INTO untilDate;
IF (untilDate < theDate) THEN
    IF (theCount >= 3) THEN
        -- Set suspended until 30 mins from now
        UPDATE `users` SET
            suspendedUntil = TIMESTAMPADD(MINUTE, 30, theDate),
            badLoginCount = 0
            WHERE userName = theName;
        COMMIT;
    -- ELSE the user is already suspended, or theCount < 3
    ELSE
        -- Get user where their last bad login was within 10 mins ago
        SELECT COUNT(userId) FROM users
            WHERE userName = theName
            AND suspendedUntil < (theDate - '0000-00-00 00:10:00')
            INTO theCount;
            
        -- IF a user was counted then they are not suspended, but have attemped a bad login within 10 mins of their last
        IF (theCount > 0) THEN 
            UPDATE `users` SET
                badLoginCount = (badLoginCount + 1),
                suspendedUntil = theDate
                WHERE userName = theName;
            COMMIT;
        -- ELSE this is the first time within 10 mins that this account has logged in bad
        ELSE
            UPDATE `users` SET
                badLoginCount = 1,
                suspendedUntil = theDate
                WHERE userName = theName;
            COMMIT;
        END IF;
    END IF;
END IF;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure suspendUser
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`suspendUser` (theId VARCHAR(64), theMins INT)
BEGIN
DECLARE theDate DATETIME;
COMMIT;
SELECT NOW() FROM DUAL INTO theDate;
UPDATE `users` SET
    suspendedUntil = TIMESTAMPADD(MINUTE, theMins, theDate)
    WHERE userId = theId;
COMMIT;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure unSuspendUser
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`unSuspendUser` (theId VARCHAR(64))
BEGIN
DECLARE theDate DATETIME;
COMMIT;
SELECT NOW() FROM DUAL INTO theDate;
UPDATE `users` SET
    suspendedUntil = theDate
    WHERE userId = theId;
COMMIT;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure userFind
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userFind` (IN theName VARCHAR(32))
BEGIN
COMMIT;
SELECT userName, suspendedUntil FROM `users`
    WHERE userName = theName;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure playerCount
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`playerCount` ()
BEGIN
    COMMIT;
    SELECT count(userId) FROM users
        WHERE userRole = 'player';
END


$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userCreate
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userCreate` (IN theClassId VARCHAR(64), IN theUserName VARCHAR(32), IN theUserPass VARCHAR(512), IN theUserRole VARCHAR(32), IN theUserAddress VARCHAR(128), tempPass BOOLEAN)
BEGIN
    DECLARE theId VARCHAR(64);
    DECLARE theClassCount INT;    
    
    COMMIT;
    -- If (Valid User Type) AND (classId = null or (Valid Class Id)) Then create user
    IF (theUserRole = 'player' OR theUserRole = 'admin') THEN
        IF (theClassId != null) THEN
            SELECT count(classId) FROM class
                WHERE classId = theClassId
                INTO theClassCount;
            IF (theClassCount != 1) THEN
                SELECT null FROM DUAL INTO theClassId;
            END IF;
        END IF;
                
        -- Increment sequence for users table
        UPDATE sequence SET
            currVal = currVal + 1
            WHERE tableName = 'users';
        COMMIT;
        SELECT SHA(CONCAT(currVal, tableName)) FROM sequence
            WHERE tableName = 'users'
            INTO theId;
        
        -- Insert the values, badLoginCount and suspendedUntil Values will use the defaults defined by the table
        INSERT INTO users (
                userId,
                classId,
                userName,
                userPass,
                userRole,
                userAddress,
                tempPassword
            ) VALUES (
                theId,
                theClassId,
                theUserName,
                SHA2(theUserPass, 512),
                theUserRole,
                theUserAddress,
                tempPass
            );
        COMMIT;
        SELECT null FROM DUAL;
    ELSE
        SELECT 'Invalid Role Type Detected' FROM DUAL;
    END IF;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userBadLoginReset
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userBadLoginReset` (IN theUserId VARCHAR(45))
BEGIN
    COMMIT;
    UPDATE users SET
        badLoginCount = 0
        WHERE userId = theUserId;
    COMMIT;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userPasswordChange
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userPasswordChange` (IN theUserName VARCHAR(32), IN currentPassword VARCHAR(512), IN newPassword VARCHAR(512))
BEGIN
DECLARE theDate DATETIME;
COMMIT;
SELECT NOW() FROM DUAL INTO theDate;
UPDATE users SET
    userPass = SHA2(newPassword, 512),
    tempPassword = FALSE
    WHERE userPass = SHA2(currentPassword, 512)
    AND userName = theUserName
    AND suspendedUntil < theDate;
COMMIT;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userPasswordChangeAdmin
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userPasswordChangeAdmin` (IN theUserId VARCHAR(64), IN newPassword VARCHAR(512))
BEGIN
DECLARE theDate DATETIME;
COMMIT;
SELECT NOW() FROM DUAL INTO theDate;
UPDATE users SET
    userPass = SHA2(newPassword, 512),
    tempPassword = FALSE
    WHERE userId = theUserId;
COMMIT;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure classCreate
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`classCreate` (IN theClassName VARCHAR(32), IN theClassYear VARCHAR(5))
BEGIN
    DECLARE theId VARCHAR(64);
    COMMIT;
    UPDATE sequence SET
        currVal = currVal + 1
        WHERE tableName = 'users';
    COMMIT;
    SELECT SHA(CONCAT(currVal, tableName)) FROM sequence
        WHERE tableName = 'users'
        INTO theId;
    
    INSERT INTO class VALUES (theId, theClassName, theClassYear);
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure classCount
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`classCount` ()
BEGIN
    SELECT count(ClassId) FROM class;
END$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure classesGetData
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`classesGetData` ()
BEGIN
    SELECT classId, className, classYear FROM class;
END$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure classFind
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`classFind` (IN theClassId VARCHAR(64))
BEGIN
    SELECT className, classYear FROM class
        WHERE classId = theClassId;
END$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure playersByClass
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`playersByClass` (IN theClassId VARCHAR(64))
BEGIN
    COMMIT;
    SELECT userId, userName, userAddress FROM users
        WHERE classId = theClassId
        AND userRole = 'player'
        ORDER BY userName;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure playerUpdateClass
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`playerUpdateClass` (IN theUserId VARCHAR(64), IN theClassId VARCHAR(64))
BEGIN
COMMIT;
UPDATE users SET
    classId = theClassId
    WHERE userId = theUserId
    AND userRole = 'player';
COMMIT;
SELECT userName FROM users
    WHERE userId = theUserId
    AND classId = theClassId
    AND userRole = 'player';
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure playerFindById
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`playerFindById` (IN playerId VARCHAR(64))
BEGIN
COMMIT;
SELECT userName FROM users
    WHERE userId = playerId
    AND userRole = 'player';
END$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure playersWithoutClass
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`playersWithoutClass` ()
BEGIN
    COMMIT;
    SELECT userId, userName, userAddress FROM users
        WHERE classId is NULL
        AND userRole = 'player'
        ORDER BY userName;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure playerUpdateClassToNull
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`playerUpdateClassToNull` (IN theUserId VARCHAR(45))
BEGIN
COMMIT;
UPDATE users SET
    classId = NULL
    WHERE userId = theUserId
    AND userRole = 'player';
COMMIT;
SELECT userName FROM users
    WHERE userId = theUserId
    AND classId IS NULL
    AND userRole = 'player';
END
$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userUpdateRole
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userUpdateRole` (IN theUserId VARCHAR(64), IN theNewRole VARCHAR(32))
BEGIN
COMMIT;
UPDATE users SET
    userRole = theNewRole
    WHERE userId = theUserId;
COMMIT;
SELECT userName FROM users
    WHERE userId = theUserId;
END
$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure moduleCreate
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleCreate` (IN theModuleName VARCHAR(64), theModuleType VARCHAR(16), theModuleCategory VARCHAR(64), isHardcodedKey BOOLEAN, theModuleSolution VARCHAR(256))
BEGIN
DECLARE theId VARCHAR(64);
DECLARE theDate DATETIME;
COMMIT;
SELECT NOW() FROM DUAL
    INTO theDate;
IF (theModuleSolution IS NULL) THEN
    SELECT SHA2(theDate, 256) FROM DUAL
        INTO theModuleSolution;
END IF;
IF (isHardcodedKey IS NULL) THEN
    SELECT TRUE FROM DUAL
        INTO isHardcodedKey;
END IF;
IF (theModuleType = 'lesson' OR theModuleType = 'challenge') THEN
    -- Increment sequence for users table
    UPDATE sequence SET
        currVal = currVal + 1
        WHERE tableName = 'modules';
    COMMIT;
    SELECT SHA(CONCAT(currVal, tableName, theDate, theModuleName)) FROM sequence
        WHERE tableName = 'modules'
        INTO theId;
    INSERT INTO modules (
        moduleId, moduleName, moduleType, moduleCategory, moduleResult, moduleHash, hardcodedKey
    )VALUES(
        theId, theModuleName, theModuleType, theModuleCategory, theModuleSolution, SHA2(CONCAT(theModuleName, theId), 256), isHardcodedKey
    );
    COMMIT;
    SELECT moduleId, moduleHash FROM modules
        WHERE moduleId = theId;
ELSE
    SELECT 'ERROR: Invalid module type submited' FROM DUAL;
END IF;

END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure moduleAllInfo
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleAllInfo` (IN theType VARCHAR(64), IN theUserId VARCHAR(64))
BEGIN
(SELECT moduleName, moduleCategory, moduleId, finishTime
FROM modules LEFT JOIN results USING (moduleId) WHERE userId = theUserId AND moduleType = theType AND moduleStatus = 'open') UNION (SELECT moduleName, moduleCategory, moduleId, null FROM modules WHERE moduleId NOT IN (SELECT moduleId FROM modules JOIN results USING (moduleId) WHERE userId = theUserId AND moduleType = theType AND moduleStatus = 'open') AND moduleType = theType  AND moduleStatus = 'open') ORDER BY moduleCategory, moduleName;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure lessonInfo
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`lessonInfo` (IN theUserId VARCHAR(64))
BEGIN
(SELECT moduleName, moduleCategory, moduleId, finishTime
FROM modules LEFT JOIN results USING (moduleId) WHERE userId = theUserId AND moduleType = 'lesson' AND moduleStatus = 'open') UNION (SELECT moduleName, moduleCategory, moduleId, null FROM modules WHERE moduleId NOT IN (SELECT moduleId FROM modules JOIN results USING (moduleId) WHERE userId = theUserId AND moduleType = 'lesson' AND moduleStatus = 'open') AND moduleType = 'lesson'  AND moduleStatus = 'open') ORDER BY moduleName, moduleCategory, moduleName;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure moduleGetResult
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleGetResult` (IN theModuleId VARCHAR(64))
BEGIN
COMMIT;
SELECT moduleName, moduleResult FROM modules
    WHERE moduleId = theModuleId
    AND moduleResult IS NOT NULL;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure userUpdateResult
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userUpdateResult` (IN theModuleId VARCHAR(64), IN theUserId VARCHAR(64), IN theBefore INT, IN theAfter INT, IN theDifficulty INT, IN theAdditionalInfo LONGTEXT)
BEGIN
DECLARE theDate TIMESTAMP;
DECLARE theBonus INT;
DECLARE totalScore INT;
DECLARE medalInfo INT; -- Used to find out if there is a medal available
DECLARE goldMedalInfo INT;
DECLARE silverMedalInfo INT;
DECLARE bronzeMedalInfo INT;
COMMIT;
SELECT NOW() FROM DUAL
    INTO theDate;
-- Get current bonus and decrement the bonus value
SELECT 0 FROM DUAL INTO totalScore;
SELECT scoreBonus FROM modules
    WHERE moduleId = theModuleId
    INTO theBonus;
IF (theBonus > 0) THEN
    SELECT (totalScore + theBonus) FROM DUAL
        INTO totalScore;
    UPDATE modules SET 
        scoreBonus = scoreBonus - 1
        WHERE moduleId = theModuleId;
    COMMIT;
END IF;

-- Medal Available?
SELECT count(moduleId) FROM modules
	WHERE moduleId = theModuleId
	AND (goldMedalAvailable = TRUE OR silverMedalAvailable = TRUE OR bronzeMedalAvailable = TRUE)
	INTO medalInfo;
COMMIT;

IF (medalInfo > 0) THEN
	SELECT count(moduleId) FROM modules WHERE moduleId = theModuleId AND goldMedalAvailable = TRUE INTO goldMedalInfo;
	IF (goldMedalInfo > 0) THEN
		UPDATE users SET goldMedalCount = goldMedalCount + 1 WHERE userId = theUserId; 
		UPDATE modules SET goldMedalAvailable = FALSE WHERE moduleId = theModuleId;
		COMMIT;
	ELSE	
		SELECT count(moduleId) FROM modules WHERE moduleId = theModuleId AND silverMedalAvailable = TRUE INTO silverMedalInfo;
		IF (silverMedalInfo > 0) THEN
			UPDATE users SET silverMedalCount = silverMedalCount + 1 WHERE userId = theUserId;
			UPDATE modules SET silverMedalAvailable = FALSE WHERE moduleId = theModuleId;
			COMMIT;
		ELSE
			SELECT count(moduleId) FROM modules WHERE moduleId = theModuleId AND bronzeMedalAvailable = TRUE INTO bronzeMedalInfo;
			IF (bronzeMedalInfo > 0) THEN
				UPDATE users SET bronzeMedalCount = bronzeMedalCount + 1 WHERE userId = theUserId;
				UPDATE modules SET bronzeMedalAvailable = FALSE WHERE moduleId = theModuleId;
				COMMIT;
			END IF;
		END IF;
	END IF;
END IF;

-- Get the Score value for the level
SELECT (totalScore + scoreValue) FROM modules
    WHERE moduleId = theModuleId
    INTO totalScore;
    
-- Update users score
UPDATE users SET
    userScore = userScore + totalScore
    WHERE userId = theUserId;
COMMIT;

-- Update result row
UPDATE results SET
    finishTime = theDate,
    `knowledgeBefore` = theBefore,
    `knowledgeAfter` = theAfter,
    `difficulty`  = theDifficulty,
    `resultSubmission` = theAdditionalInfo
    WHERE startTime IS NOT NULL
    AND finishTime IS NULL
    AND userId = theUserId
    AND moduleId = theModuleId;
COMMIT;
SELECT moduleName FROM modules
    JOIN results USING (moduleId)
    WHERE startTime IS NOT NULL
    AND finishTime IS NOT NULL
    AND userId = theUserId
    AND moduleId = theModuleId;
END $$

DELIMITER ;

-- -----------------------------------------------------
-- procedure moduleGetHash
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleGetHash` (IN theModuleId VARCHAR(64), IN theUserId VARCHAR(64))
BEGIN
DECLARE theDate DATETIME;
DECLARE tempInt INT;
COMMIT;
SELECT NOW() FROM DUAL
    INTO theDate;
SELECT COUNT(*) FROM results
    WHERE userId = theUserId
    AND moduleId = theModuleId
    AND startTime IS NOT NULL
    INTO tempInt;
IF(tempInt = 0) THEN
    INSERT INTO results 
        (moduleId, userId, startTime)
        VALUES
        (theModuleId, theUserId, theDate);
    COMMIT;
END IF;
SELECT moduleHash, moduleCategory, moduleType FROM modules
    WHERE moduleId = theModuleId AND moduleStatus = 'open';
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure moduleGetResultFromHash
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleGetResultFromHash` (IN theHash VARCHAR(256))
BEGIN
COMMIT;
SELECT moduleResult FROM modules
    WHERE moduleHash = theHash;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure resultMessageByClass
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`resultMessageByClass` (IN theClassId VARCHAR(64), IN theModuleId VARCHAR(64))
BEGIN
COMMIT;
SELECT userName, resultSubmission FROM results
    JOIN users USING (userId)
    JOIN class USING (classId)
    WHERE classId = theClassId
    AND moduleId = theModuleId;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure resultMessageSet
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`resultMessageSet` (IN theMessage VARCHAR(128), IN theUserId VARCHAR(64), IN theModuleId VARCHAR(64))
BEGIN
COMMIT;
UPDATE results SET
    resultSubmission = theMessage
    WHERE moduleId = theModuleId
    AND userId = theUserId;
COMMIT;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure resultMessagePlus
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`resultMessagePlus` (IN theModuleId VARCHAR(64), IN theUserId2 VARCHAR(64))
BEGIN
UPDATE results SET
    csrfCount = csrfCount + 1
    WHERE userId = theUserId2
    AND moduleId = theModuleId;
COMMIT;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure resultMessagePlus
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`csrfLevelComplete` (IN theModuleId VARCHAR(64), IN theUserId2 VARCHAR(64))
BEGIN
	DECLARE temp INT;
COMMIT;
SELECT csrfCount FROM results
    WHERE userId = theUserId2
    AND moduleId = theModuleId;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure moduleGetIdFromHash
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleGetIdFromHash` (IN theHash VARCHAR(256))
BEGIN
COMMIT;
SELECT moduleId FROM modules
    WHERE moduleHash = theHash;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userGetNameById
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userGetNameById` (IN theUserId VARCHAR(64))
BEGIN
COMMIT;
SELECT userName FROM users
    WHERE userId = theUserId;
END
$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure userBadSubmission
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userBadSubmission` (IN theUserId VARCHAR(64))
BEGIN
UPDATE users SET
    badSubmissionCount = badSubmissionCount + 1
    WHERE userId = theUserId;
COMMIT;
UPDATE users SET
	userScore = userScore - userScore/10
	WHERE userId = theUserId AND badSubmissionCount > 40 AND userScore > 5;
COMMIT;
UPDATE users SET 
	userScore = userScore - 10
	WHERE userId = theUserId AND badSubmissionCount > 40 AND userScore <= 5;
COMMIT;
END
$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure resetUserBadSubmission
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`resetUserBadSubmission` (IN theUserId VARCHAR(64))
BEGIN
UPDATE users SET
    badSubmissionCount = 0
    WHERE userId = theUserId;
COMMIT;
END
$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure moduleComplete
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleComplete` (IN theModuleId VARCHAR(64), IN theUserId VARCHAR(64))
BEGIN
DECLARE theDate DATETIME;
COMMIT;
SELECT NOW() FROM DUAL
    INTO theDate;
UPDATE results SET
    finishTime = theDate
    WHERE startTime IS NOT NULL
    AND moduleId = theModuleId
    AND userId = theUserId;
COMMIT;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure cheatSheetCreate
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`cheatSheetCreate` (IN theModule VARCHAR(64), IN theSheet LONGTEXT)
BEGIN
DECLARE theDate DATETIME;
DECLARE theId VARCHAR(64);
    COMMIT;
    UPDATE sequence SET
        currVal = currVal + 1
        WHERE tableName = 'cheatSheet';
    COMMIT;
	SELECT NOW() FROM DUAL INTO theDate;
	
    SELECT SHA(CONCAT(currVal, tableName, theDate)) FROM `core`.`sequence`
        WHERE tableName = 'cheatSheet'
        INTO theId;
    
    INSERT INTO `core`.`cheatsheet`
        (cheatSheetId, moduleId, createDate, solution)
        VALUES
        (theId, theModule, theDate, theSheet);
    COMMIT;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure moduleGetAll
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleGetAll` ()
BEGIN
COMMIT;
SELECT moduleId, moduleName, moduleType, moduleCategory FROM modules
    ORDER BY moduleType, moduleCategory, moduleName;
END
$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure cheatSheetGetSolution
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`cheatSheetGetSolution` (IN theModuleId VARCHAR(64))
BEGIN
COMMIT;
SELECT moduleName, solution FROM modules
    JOIN cheatsheet USING (moduleId)
    WHERE moduleId = theModuleID
    ORDER BY createDate DESC;
END
$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure moduleGetHashById
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleGetHashById` (IN theModuleId VARCHAR(64))
BEGIN
COMMIT;
SELECT moduleHash FROM modules
    WHERE moduleId = theModuleId;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userCheckResult
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userCheckResult` (IN theModuleId VARCHAR(64), IN theUserId VARCHAR(64))
BEGIN
COMMIT;
-- Returns a module Name if the user has not completed the module identified by moduleId
SELECT moduleName FROM results
    JOIN modules USING(moduleId)
    WHERE finishTime IS NULL
    AND startTime IS NOT NULL
    AND finishTime IS NULL
    AND userId = theUserId
    AND moduleId = theModuleId;
END


$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure moduleIncrementalInfo
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleIncrementalInfo` (IN theUserId VARCHAR(64))
BEGIN
(SELECT moduleName, moduleCategory, moduleId, finishTime, incrementalRank FROM modules LEFT JOIN results USING (moduleId) WHERE userId = theUserId AND moduleStatus = 'open') UNION (SELECT moduleName, moduleCategory, moduleId, null, incrementalRank FROM modules WHERE moduleStatus = 'open' AND moduleId NOT IN (SELECT moduleId FROM modules JOIN results USING (moduleId) WHERE userId = theUserId)) ORDER BY incrementalRank;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure moduleFeedback
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleFeedback` (IN theModuleId VARCHAR(64))
BEGIN
SELECT userName, TIMESTAMPDIFF(MINUTE, finishTime, startTime)*(-1), difficulty, knowledgeBefore, knowledgeAfter, resultSubmission
	FROM modules 
	LEFT JOIN results USING (moduleId)
  LEFT JOIN users USING (userId)
  WHERE moduleId = theModuleId;
END
$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userProgress
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userProgress` (IN theClassId VARCHAR(64))
BEGIN
    COMMIT;
SELECT userName, count(finishTime), userScore FROM users JOIN results USING (userId) WHERE finishTime IS NOT NULL 
AND classId = theClassId
GROUP BY userName UNION SELECT userName, 0, userScore FROM users WHERE classId = theClassId AND userId NOT IN (SELECT userId FROM users JOIN results USING (userId) WHERE classId = theClassId AND finishTime IS NOT NULL GROUP BY userName) ORDER BY userScore DESC;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure classScoreboard
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`classScoreboard` (IN theClassId VARCHAR(64))
BEGIN
    COMMIT;
SELECT userId, userName, userScore, goldMedalCount, silverMedalCount, bronzeMedalCount FROM users 
	WHERE classId = theClassId AND userRole = 'player' AND userScore > 0
	ORDER BY userScore DESC, goldMedalCount DESC, silverMedalCount DESC, bronzeMedalCount DESC, userId ASC;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure totalScoreboard
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`totalScoreboard` ()
BEGIN
    COMMIT;
SELECT userId, userName, userScore, goldMedalCount, silverMedalCount, bronzeMedalCount FROM users 
	WHERE userRole = 'player' AND userScore > 0
	ORDER BY userScore DESC, goldMedalCount DESC, silverMedalCount DESC, bronzeMedalCount DESC, userId ASC;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure userStats
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userStats` (IN theUserName VARCHAR(32))
BEGIN
DECLARE temp INT;
SELECT COUNT(*) FROM modules INTO temp;
SELECT userName, sum(TIMESTAMPDIFF(MINUTE, finishTime, startTime)*(-1)) AS "Time", CONCAT(COUNT(*),"/", temp) AS "Progress"
    FROM modules
    LEFT JOIN results USING (moduleId)
    LEFT JOIN users USING (userId)
    WHERE userName = theUserName AND resultSubmission IS NOT NULL
    GROUP BY userName;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure userStatsDetailed
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`userStatsDetailed` (IN theUserName VARCHAR(32))
BEGIN
DECLARE temp INT;
SELECT COUNT(*) FROM modules INTO temp;
SELECT userName, moduleName, TIMESTAMPDIFF(MINUTE, finishTime, startTime)*(-1) AS "Time"
    FROM modules
    LEFT JOIN results USING (moduleId)
    LEFT JOIN users USING (userId)
    WHERE userName = theUserName AND resultSubmission IS NOT NULL
    ORDER BY incrementalRank;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure moduleOpenInfo
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleOpenInfo` (IN theUserId VARCHAR(64))
BEGIN
(SELECT moduleName, moduleCategory, moduleId, finishTime FROM modules LEFT JOIN results USING (moduleId) 
WHERE userId = theUserId AND moduleStatus = 'open') UNION (SELECT moduleName, moduleCategory, moduleId, null FROM modules WHERE moduleId NOT IN (SELECT moduleId FROM modules JOIN results USING (moduleId) WHERE userId = theUserId AND moduleStatus = 'open') AND moduleStatus = 'open') ORDER BY moduleCategory, moduleName;
END

$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure moduleClosednfo
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleClosednfo` (IN theUserId VARCHAR(64))
BEGIN
(SELECT moduleName, moduleCategory, moduleId, finishTime
FROM modules LEFT JOIN results USING (moduleId) WHERE userId = theUserId AND moduleStatus = 'closed') UNION (SELECT moduleName, moduleCategory, moduleId, null FROM modules WHERE moduleId NOT IN (SELECT moduleId FROM modules JOIN results USING (moduleId) WHERE userId = theUserId AND moduleStatus = 'closed') AND moduleStatus = 'closed') ORDER BY moduleCategory, moduleName;
END
$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure moduleTournamentOpenInfo
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleTournamentOpenInfo` (IN theUserId VARCHAR(64))
BEGIN
(SELECT moduleName, moduleCategory, moduleId, finishTime, incrementalRank, scoreValue FROM modules LEFT JOIN results USING (moduleId) 
WHERE userId = theUserId AND moduleStatus = 'open') UNION (SELECT moduleName, moduleCategory, moduleId, null, incrementalRank, scoreValue FROM modules WHERE moduleId NOT IN (SELECT moduleId FROM modules JOIN results USING (moduleId) WHERE userId = theUserId AND moduleStatus = 'open') AND moduleStatus = 'open') ORDER BY incrementalRank, scoreValue, moduleName;
END

$$

DELIMITER ;

-- -----------------------------------------------------
-- procedure moduleSetStatus
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleSetStatus` (IN theModuleId VARCHAR(64), IN theStatus VARCHAR(16))
BEGIN
UPDATE modules SET
    moduleStatus = theStatus
    WHERE moduleId = theModuleId;
COMMIT;
END
$$

DELIMITER ;
-- -----------------------------------------------------
-- procedure moduleAllStatus
-- -----------------------------------------------------

DELIMITER $$
USE `core`$$
CREATE PROCEDURE `core`.`moduleAllStatus` ()
BEGIN
SELECT moduleId, moduleName, moduleStatus
    FROM modules;
END
$$

DELIMITER ;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- -----------------------------------------------------
SELECT "Data for table `core`.`sequence`" FROM DUAL;
-- -----------------------------------------------------
SET AUTOCOMMIT=0;
USE `core`;
INSERT INTO `core`.`sequence` (`tableName`, `currVal`) VALUES ('users', '282475249');
INSERT INTO `core`.`sequence` (`tableName`, `currVal`) VALUES ('cheatSheet', '282475299');
INSERT INTO `core`.`sequence` (`tableName`, `currVal`) VALUES ('class', '282475249');
INSERT INTO `core`.`sequence` (`tableName`, `currVal`) VALUES ('modules', '282475576');

COMMIT;

-- -----------------------------------------------------
SELECT "Inserting Data for table `core`.`modules`" FROM DUAL;
-- -----------------------------------------------------
SET AUTOCOMMIT=0;
USE `core`;
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('0dbea4cb5811fff0527184f99bd5034ca9286f11', 'Insecure Direct Object References', 'lesson', 'Insecure Direct Object References', '59e571b1e59441e76e0c85e5b49', 'fdb94122d0f032821019c7edf09dc62ea21e25ca619ed9107bcc50e4a8dbc100', 'open', '5', '10', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('b9d82aa7b46ddaddb6acfe470452a8362136a31e', 'Poor Data Validation', 'lesson', 'Poor Data Validation', '6680b08b175c9f3d521764b41349fcbd3c0ad0a76655a10d42372ebccdfdb4bb', '4d8d50a458ca5f1f7e2506dd5557ae1f7da21282795d0ed86c55fefe41eb874f', 'open', '6', '10', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('bf847c4a8153d487d6ec36f4fca9b77749597c64', 'Security Misconfiguration', 'lesson', 'Security Misconfigurations', '55b34717d014a5a355f6eced4386878fab0b2793e1d1dbfd23e6262cd510ea96', 'fe04648f43cdf2d523ecf1675f1ade2cde04a7a2e9a7f1a80dbb6dc9f717c833', 'open', '7', '10', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('9533e21e285621a676bec58fc089065dec1f59f5', 'Broken Session Management', 'lesson', 'Session Management', '6594dec9ff7c4e60d9f8945ca0d4', 'b8c19efd1a7cc64301f239f9b9a7a32410a0808138bbefc98986030f9ea83806', 'open', '16', '10', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('52c5394cdedfb2e95b3ad8b92d0d6c9d1370ea9a', 'Failure to Restrict URL Access', 'lesson', 'Failure to Restrict URL Access', 'f60d1337ac4d35cb67880a3adda79', 'oed23498d53ad1d965a589e257d8366d74eb52ef955e103c813b592dba0477e3', 'open', '25', '15', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('ca8233e0398ecfa76f9e05a49d49f4a7ba390d07', 'Cross Site Scripting', 'lesson', 'XSS', 'ea7b563b2935d8587539d747d', 'zf8ed52591579339e590e0726c7b24009f3ac54cdff1b81a65db1688d86efb3a', 'open', '26', '15', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('cd7f70faed73d2457219b951e714ebe5775515d8', 'Cross Site Scripting 1', 'challenge', 'XSS', '445d0db4a8fc5d4acb164d022b', 'd72ca2694422af2e6b3c5d90e4c11e7b4575a7bc12ee6d0a384ac2469449e8fa', 'open', '35', '20', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('53a53a66cb3bf3e4c665c442425ca90e29536edd', 'Insecure Data Storage', 'lesson', 'Mobile Insecure Data Storage', 'Battery777', 'ecfad0a5d41f59e6bed7325f56576e1dc140393185afca8975fbd6822ebf392f', 'open', '45', '25', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('201ae6f8c55ba3f3b5881806387fbf34b15c30c2', 'Insecure Cryptographic Storage', 'lesson', 'Insecure Cryptographic Storage', 'base64isNotEncryptionBase64isEncodingBase64HidesNothingFromYou', 'if38ebb58ea2d245fa792709370c00ca655fded295c90ef36f3a6c5146c29ef2', 'open', '46', '25', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('408610f220b4f71f7261207a17055acbffb8a747', 'SQL Injection', 'lesson', 'Injection', '3c17f6bf34080979e0cebda5672e989c07ceec9fa4ee7b7c17c9e3ce26bc63e0', 'e881086d4d8eb2604d8093d93ae60986af8119c4f643894775433dbfb6faa594', 'open', '55', '30', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('891a0208a95f1791287be721a4b851d4c584880a', 'Insecure Cryptographic Storage Challenge 1', 'challenge', 'Insecure Cryptographic Storage', 'mylovelyhorserunningthroughthefieldwhereareyougoingwithyourbiga', 'x9c408d23e75ec92495e0caf9a544edb2ee8f624249f3e920663edb733f15cd7', 'open', '65', '35', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('2dc909fd89c2b03059b1512e7b54ce5d1aaa4bb4', 'Insecure Direct Object Reference Challenge 1', 'challenge', 'Insecure Direct Object References', 'dd6301b38b5ad9c54b85d07c087aebec89df8b8c769d4da084a55663e6186742', 'o9a450a64cc2a196f55878e2bd9a27a72daea0f17017253f87e7ebd98c71c98c', 'open', '66', '35', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('6be5de81223cc1b38b6e427cc44f8b6a28d2bc96', 'Poor Data Validation 1', 'challenge', 'Bad Data Validation', 'd30475881612685092e5ec469317dcc5ccc1f548a97bfdb041236b5bba7627bf', 'ca0e89caf3c50dbf9239a0b3c6f6c17869b2a1e2edc3aa6f029fd30925d66c7e', 'open', '67', '35', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('a4bf43f2ba5ced041b03d0b3f9fa3541c520d65d', 'Session Management Challenge 1', 'challenge', 'Session Management', 'db7b1da5d7a43c7100a6f01bb0c', 'dfd6bfba1033fa380e378299b6a998c759646bd8aea02511482b8ce5d707f93a', 'open', '75', '40', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('2ab09c0c18470ae5f87d219d019a1f603e66f944', 'Reverse Engineering', 'lesson', 'Mobile Reverse Engineering', 'DrumaDrumaDrumBoomBoom', '19753b944b63232812b7af1a0e0adb59928158da5994a39f584cb799f25a95b9', 'open', '75', '40', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('3d5b46abc6865ba09aaff98a8278a5f5e339abff', 'Failure To Restrict URL Access Challenge 1', 'challenge', 'Failure to Restrict URL Access', 'c776572b6a9d5b5c6e4aa672a4771213', '4a1bc73dd68f64107db3bbc7ee74e3f1336d350c4e1e51d4eda5b52dddf86c99', 'open', '76', '40', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('1506f22cd73d14d8a73e0ee32006f35d4f234799', 'Unintended Data Leakage', 'lesson', 'Mobile Data Leakage', 'SilentButSteadyRedLed', '392c20397c535845d93c32fd99b94f70afe9cca3f78c1e4766fee1cc08c035ec', 'open', '77', '40', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('453d22238401e0bf6f1ff5d45996407e98e45b07', 'Cross Site Request Forgery', 'lesson', 'CSRF', '666980771c29857b8a84c686751ce7edaae3d6ac1', 'ed4182af119d97728b2afca6da7cdbe270a9e9dd714065f0f775cd40dc296bc7', 'open', '78', '40', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('5b461ebe2e5e2797740cb3e9c7e3f93449a93e3a', 'Content Provider Leakage', 'lesson', 'Mobile Content Providers', 'LazerLizardsFlamingWizards', '4d41997b5b81c88f7eb761c1975481c4ce397b80291d99307cfad69662277d39', 'open', '79', '50', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('52885a3db5b09adc24f38bc453fe348f850649b3', 'Reverse Engineering 1', 'challenge', 'Mobile Reverse Engineering', 'christopherjenkins', '072a9e4fc888562563adf8a89fa55050e3e1cfbbbe1d597b0537513ac8665295', 'open', '85', '50', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('f771a10efb42a79a9dba262fd2be2e44bf40b66d', 'SQL Injection 1', 'challenge', 'Injection', 'f62abebf5658a6a44c5c9babc7865110c62f5ecd9d0a7052db48c4dbee0200e3', 'ffd39cb26727f34cbf9fce3e82b9d703404e99cdef54d2aa745f497abe070b', 'open', '85', '45', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('b6432a6b5022cb044e9946315c44ab262ab59e88', 'Unvalidated Redirects and Forwards', 'lesson', 'Unvalidated Redirects and Forwards', '658c43abcf81a61ca5234cfd7a2', 'f15f2766c971e16e68aa26043e6016a0a7f6879283c873d9476a8e7e94ea736f', 'open', '86', '45', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('335440fef02d19259254ed88293b62f31cccdd41', 'Client Side Injection', 'lesson', 'Mobile Injection', 'VolcanicEruptionsAbruptInterruptions', 'f758a97011ec4452cc0707e546a7c0f68abc6ef2ab747ea87e0892767152eae1', 'open', '87', '50', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('544aa22d3dd16a8232b093848a6523b0712b23da', 'SQL Injection 2', 'challenge', 'Injection', 'fd8e9a29dab791197115b58061b215594211e72c1680f1eacc50b0394133a09f', 'e1e109444bf5d7ae3d67b816538613e64f7d0f51c432a164efc8418513711b0a', 'open', '88', '45', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('d7eaeaa1cc4f218abd86d14eefa183a0f8eb6298', 'NoSQL Injection One', 'challenge', 'Injection', 'c09f32d4c3dd5b75f04108e5ffc9226cd8840288a62bdaf9dc65828ab6eaf86a', 'd63c2fb5da9b81ca26237f1308afe54491d1bacf9fffa0b21a072b03c5bafe66', 'open', '89', '45', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('0cdd1549e7c74084d7059ce748b93ef657b44457', 'Poor Authentication', 'lesson', 'Mobile Poor Authentication', 'UpsideDownPizzaDip', '77777b312d5b56a17c1f30550dd34e8d6bd8b037f05341e64e94f5411c10ac8e', 'open', '90', '50', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('ef6496892b8e48ac2f349cdd7c8ecb889fc982af', 'Broken Crypto', 'lesson', 'Mobile Broken Crypto', '33edeb397d665ed7d1a580f3148d4b2f', '911fa7f4232e096d6a74a0623842c4157e29b9bcc44e8a827be3bb7e58c9a212', 'open', '97', '50', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('f16bf2ab1c1bf400d36330f91e9ac6045edcd003', 'Reverse Engineering 2', 'challenge', 'Mobile Reverse Engineering', 'FireStoneElectric', '5bc811f9e744a71393a277c51bfd8fbb5469a60209b44fa3485c18794df4d5b1', 'open', '98', '50', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('b70a84f159876bb9885b6e0087d22f0a52abbfcf', 'Session Management Challenge 2', 'challenge', 'Session Management', '4ba31e5ffe29de092fe1950422a', 'd779e34a54172cbc245300d3bc22937090ebd3769466a501a5e7ac605b9f34b7', 'open', '105', '55', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('20e755179a5840be5503d42bb3711716235005ea', 'CSRF 1', 'challenge', 'CSRF', '7639c952a191d569a0c741843b599604c37e33f9f5d8eb07abf0254635320b07', 's74a796e84e25b854906d88f622170c1c06817e72b526b3d1e9a6085f429cf52', 'open', '106', '55', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('307f78f18fd6a87e50ed6705231a9f24cd582574', 'Insecure Data Storage 1', 'challenge', 'Mobile Insecure Data Storage', 'WarshipsAndWrenches', '362f84cf26bf96aeae358d5d0bbee31e9291aaa5367594c29b3af542a7572c01', 'open', '116', '60', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('0e9e650ffca2d1fe516c5d7b0ce5c32de9e53d1e', 'Session Management Challenge 3', 'challenge', 'Session Management', 'e62008dc47f5eb065229d48963', 't193c6634f049bcf65cdcac72269eeac25dbb2a6887bdb38873e57d0ef447bc3', 'open', '115', '60', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('3f010a976bcbd6a37fba4a10e4a057acc80bdc09', 'Broken Crypto 1', 'challenge', 'Mobile Broken Crypto', 'd1f2df53084b970ab538457f5af34c8b', 'd2f8519f8264f9479f56165465590b499ceca941ab848805c00f5bf0a40c9717', 'open', '117', '60', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('d4e2c37d8f1298fcaf4edcea7292cb76e9eab09b', 'Cross Site Scripting 2', 'challenge', 'XSS', '495ab8cc7fe9532c6a75d378de', 't227357536888e807ff0f0eff751d6034bafe48954575c3a6563cb47a85b1e888', 'open', '119', '60', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('9e46e3c8bde42dc16b9131c0547eedbf265e8f16', 'Reverse Engineering 3', 'challenge', 'Mobile Reverse Engineering', 'C1babd72225f0e9934YZ8', 'dbae0baa3f71f196c4d2c6c984d45a6c1c635bf1b482dccfe32e9b01b69a042b', 'open', '120', '76', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('0709410108f91314fb6f7721df9b891351eb2fcc', 'Insecure Cryptographic Storage Challenge 2', 'challenge', 'Insecure Cryptographic Storage', 'TheVigenereCipherIsAmethodOfEncryptingAlphabeticTextByUsingPoly', 'h8aa0fdc145fb8089661997214cc0e685e5f86a87f30c2ca641e1dde15b01177', 'open', '126', '65', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('82e8e9e2941a06852b90c97087309b067aeb2c4c', 'Insecure Direct Object Reference Challenge 2', 'challenge', 'Insecure Direct Object References', '1f746b87a4e3628b90b1927de23f6077abdbbb64586d3ac9485625da21921a0f', 'vc9b78627df2c032ceaf7375df1d847e47ed7abac2a4ce4cb6086646e0f313a4', 'open', '127', '65', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('6319a2e38cc4b2dc9e6d840e1b81db11ee8e5342', 'Cross Site Scripting 3', 'challenge', 'XSS', '6abaf491c9122db375533c04df', 'ad2628bcc79bf10dd54ee62de148ab44b7bd028009a908ce3f1b4d019886d0e', 'open', '128', '65', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('da3de2e556494a9c2fb7308a98454cf55f3a4911', 'Insecure Data Storage 2', 'challenge', 'Mobile Insecure Data Storage', 'starfish123', 'ec09515a304d2de1f552e961ab769967bdc75740ad2363803168b7907c794cd4', 'open', '129', '65', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('cb7d696bdf88899e8077063d911fc8da14176702', 'Insecure Data Storage 3', 'challenge', 'Mobile Insecure Data Storage', 'c4ptainBrunch', '11ccaf2f3b2aa4f88265b9cacb5e0ed26b11af978523e34528cf0bb9d32de851', 'open', '130', '60', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('de626470273c01388629e5a56ac6f17e2eef957b', 'Insecure Direct Object Reference Bank', 'challenge', 'Insecure Direct Object References', '4a1df02af317270f844b56edc0c29a09f3dd39faad3e2a23393606769b2dfa35', '1f0935baec6ba69d79cfb2eba5fdfa6ac5d77fadee08585eb98b130ec524d00c', 'open', '131', '60', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('f40b0cd5d45327c9426675313f581cf70c7c7c28', 'Unintended Data Leakage 1', 'challenge', 'Mobile Data Leakage', 'BagsofSalsa', '517622a535ff89f7d90674862740b48f53aad7b41390fe46c6f324fee748d136', 'open', '132', '60', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('5dda8dc216bd6a46fccaa4ed45d49404cdc1c82e', 'SQL Injection 3', 'challenge', 'Injection', '9815 1547 3214 7569', 'b7327828a90da59df54b27499c0dc2e875344035e38608fcfb7c1ab8924923f6', 'open', '135', '70', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('94cd2de560d89ef59fc450ecc647ff4d4a55c15d', 'CSRF 2', 'challenge', 'CSRF', '45309dbaf8eaf6d1a5f1ecb1bf1b6be368a6542d3da35b9bf0224b88408dc001', 'z311736498a13604705d608fb3171ebf49bc18753b0ec34b8dff5e4f9147eb5e', 'open', '136', '70', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('5ca9115f3279b9b9f3308eb6a59a4fcd374846d6', 'CSRF 3', 'challenge', 'CSRF', '6bdbe1901cbe2e2749f347efb9ec2be820cc9396db236970e384604d2d55b62a', 'z6b2f5ebbe112dd09a6c430a167415820adc5633256a7b44a7d1e262db105e3c', 'open', '137', '70', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('a3f7ffd0f9c3d15564428d4df0b91bd927e4e5e4', 'Client Side Injection 1', 'challenge', 'Mobile Injection', 'SourHatsAndAngryCats', '8855c8bb9df4446a546414562eda550520e29f7a82400a317c579eb3a5a0a8ef', 'open', '138', '70', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('cfbf7b915ee56508ad46ab79878f37fd9afe0d27', 'CSRF 4', 'challenge', 'CSRF', 'bb78f73c7efefec25e518c3a91d50d789b689c4515b453b6140a2e4e1823d203', '84118752e6cd78fecc3563ba2873d944aacb7b72f28693a23f9949ac310648b5', 'open', '139', '70', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('1e3c02ad49fa9a9e396a3b268d7da8f0b647d8f9', 'Unintended Data Leakage 2', 'challenge', 'Mobile Data Leakage', '627884736748', '85ceae7ec397c8f4448be51c33a634194bf5da440282227c15954bbdfb54f0c7', 'open', '140', '70', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('fcc2558e0a23b8420e173cf8029876cb887408d3', 'CSRF JSON', 'challenge', 'CSRF', 'f57f1377bd847a370d42e1410bfe48c9a3484e78d50e83f851b634fe77d41a6e', '2e0981dcb8278a57dcfaae3b8da0c78d5a70c2d38ea9d8b3e14db3aea01afcbb', 'open', '141', '70', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('ced925f8357a17cfe3225c6236df0f681b2447c4', 'Session Management Challenge 4', 'challenge', 'Session Management', '238a43b12dde07f39d14599a780ae90f87a23e', 'ec43ae137b8bf7abb9c85a87cf95c23f7fadcf08a092e05620c9968bd60fcba6', 'open', '145', '75', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('182f519ef2add981c77a584380f41875edc65a56', 'Cross Site Scripting 4', 'challenge', 'XSS', '515e05137e023dd7828adc03f639c8b13752fbdffab2353ccec', '06f81ca93f26236112f8e31f32939bd496ffe8c9f7b564bce32bd5e3a8c2f751', 'open', '146', '75', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('e0ba96bb4c8d4cd2e1ff0a10a0c82b5362edf998', 'SQL Injection 4', 'challenge', 'Injection', 'd316e80045d50bdf8ed49d48f130b4acf4a878c82faef34daff8eb1b98763b6f', '1feccf2205b4c5ddf743630b46aece3784d61adc56498f7603ccd7cb8ae92629', 'open', '147', '75', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('b3cfd5890649e6815a1c7107cc41d17c82826cfa', 'Insecure Cryptographic Storage Challenge 3', 'challenge', 'Insecure Cryptographic Storage', 'THISISTHESECURITYSHEPHERDABCENCRYPTIONKEY', '2da053b4afb1530a500120a49a14d422ea56705a7e3fc405a77bc269948ccae1', 'open', '148', '75', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('63bc4811a2e72a7c833962e5d47a41251cd90de3', 'Broken Crypto 2', 'challenge', 'Mobile Broken Crypto', 'DancingRobotChilliSauce', 'fb5c9ce0f5539b737e534fd317befff7427f6610ed626dfd43abf35295f106bc', 'open', '149', '75', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('e635fce334aa61fdaa459c21c286d6332eddcdd3', 'Client Side Injection 2', 'challenge', 'Mobile Injection', 'BurpingChimneys', 'cfe68711def42bb0b201467b859322dd2750f633246842280dc68c858d208425', 'open', '155', '80', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('0a37cb9296ff3763f7f3a45ff313bce47afa9384', 'CSRF 5', 'challenge', 'CSRF', '8f34078ef3e53f619618d9def1ede8a6a9117c77c2fad22f76bba633da83e6d4', '70b96195472adf3bf347cbc37c34489287969d5ba504ac2439915184d6e5dc49', 'open', '156', '80', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('3b14ca3c8f9b90c9b2c8cd1fba9fa67add1272a3', 'Poor Data Validation 2', 'challenge', 'Bad Data Validation', '05adf1e4afeb5550faf7edbec99170b40e79168ecb3a5da19943f05a3fe08c8e', '20e8c4bb50180fed9c1c8d1bf6af5eac154e97d3ce97e43257c76e73e3bbe5d5', 'open', '157', '80', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('ba6e65e4881c8499b5e53eb33b5be6b5d0f1fb2c', 'Poor Authentication 1', 'challenge', 'Mobile Poor Authentication', 'MegaKillerExtremeCheese', 'efa08298fc6a4add4b9a4bbdbbbb18ac934667971fa275bd7d234589bd8a8467', 'open', '160', '60', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('c7ac1e05faa2d4b1016cfcc726e0689419662784', 'Failure To Restrict URL Access Challenge 2', 'challenge', 'Failure to Restrict URL Access', '40b675e3d404c52b36abe31d05842b283975ec62e8', '278fa30ee727b74b9a2522a5ca3bf993087de5a0ac72adff216002abf79146fa', 'open', '165', '85', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('fccf8e4d5372ee5a73af5f862dc810545d19b176', 'Cross Site Scripting 5', 'challenge', 'XSS', '7d7cc278c30cca985ab027e9f9e09e2f759e5a3d1f63293', 'f37d45f597832cdc6e91358dca3f53039d4489c94df2ee280d6203b389dd5671', 'open', '166', '85', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('a84bbf8737a9ca749d81d5226fc87e0c828138ee', 'SQL Injection 5', 'challenge', 'Injection', '343f2e424d5d7a2eff7f9ee5a5a72fd97d5a19ef7bff3ef2953e033ea32dd7ee', '8edf0a8ed891e6fef1b650935a6c46b03379a0eebab36afcd1d9076f65d4ce62', 'open', '175', '90', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('04a5bd8656fdeceac26e21ef6b04b90eaafbd7d5', 'CSRF 6', 'challenge', 'CSRF', 'df611f54325786d42e6deae8bbd0b9d21cf2c9282ec6de4e04166abe2792ac00', '2fff41105149e507c75b5a54e558470469d7024929cf78d570cd16c03bee3569', 'open', '176', '90', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('145111e80400e4fd48bd3aa5aca382e9c5640793', 'Insecure Cryptographic Storage Challenge 4', 'challenge', 'Insecure Cryptographic Storage', '50980917266ce6ec07471f49b1a046ca6a5034eb9261fb44c3ffc4b16931255c', 'b927fc4d8c9f70a78f8b6fc46a0cc18533a88b2363054a1f391fe855954d12f9', 'open', '177', '90', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('dc89383763c68cba0aaa1c6f3fd4c17e9d49a805', 'SQL Injection Stored Procedure', 'challenge', 'Injection', 'd9c5757c1c086d02d491cbe46a941ecde5a65d523de36ac1bfed8dd4dd9994c8', '7edcbc1418f11347167dabb69fcb54137960405da2f7a90a0684f86c4d45a2e7', 'open', '177', '90', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('3b1af0ad239325bf494c6e606585320b31612e72', 'Broken Crypto 3', 'challenge', 'Mobile Broken Crypto', 'ShaveTheSkies', 'f5a3f19dd44b53c6d29dda65fa90791bb312a3044b3110acb8a65d165376bf34', 'open', '180', '180', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('c6841bcc326c4bad3a23cd4fa6391eb9bdb146ed', 'Cross Site Scripting 6', 'challenge', 'XSS', 'c13e42171dbd41a7020852ffdd3399b63a87f5', 'd330dea1acf21886b685184ee222ea8e0a60589c3940afd6ebf433469e997caf', 'open', '185', '95', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('ad332a32a6af1f005f9c8d1e98db264eb2ae5dfe', 'SQL Injection 6', 'challenge', 'Injection', '17f999a8b3fbfde54124d6e94b256a264652e5087b14622e1644c884f8a33f82', 'd0e12e91dafdba4825b261ad5221aae15d28c36c7981222eb59f7fc8d8f212a2', 'open', '186', '95', '5', 1);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('ed732e695b85baca21d80966306a9ab5ec37477f', 'Session Management Challenge 5', 'challenge', 'Session Management', 'a15b8ea0b8a3374a1dedc326dfbe3dbae26', '7aed58f3a00087d56c844ed9474c671f8999680556c127a19ee79fa5d7a132e1', 'open', '205', '110', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('adc845f9624716eefabcc90d172bab4096fa2ac4', 'Failure to Restrict URL Access 3', 'challenge', 'Failure to Restrict URL Access', '8c1dbfdc7cad35a116535f76f21e448c6c7c0ebc395be2be80e5690e01adec18', 'e40333fc2c40b8e0169e433366350f55c77b82878329570efa894838980de5b4', 'open', '206', '110', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('9294ba32bdbd680e3260a0315cd98bf6ce8b69bd', 'Session Management Challenge 6', 'challenge', 'Session Management', 'bb0eb566322d6b1f1dff388f5eee9929f6f1f9f5cac9eed266ef6e5053fe08e6', 'b5e1020e3742cf2c0880d4098146c4dde25ebd8ceab51807bad88ff47c316ece', 'open', '207', '110', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('6158a695f20f9286d5f12ff3f4d42678f4a9740c', 'Security Misconfig Cookie Flag', 'challenge', 'Security Misconfigurations', '92755de2ebb012e689caf8bfec629b1e237d23438427499b6bf0d7933f1b8215', 'c4285bbc6734a10897d672c1ed3dd9417e0530a4e0186c27699f54637c7fb5d4', 'open', '208', '110', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('368491877a0318e9a774ba5d648c33cb0165ba1e', 'Session Management Challenge 7', 'challenge', 'Session Management', '9042eeaa8455f71deea31a5a32ae51e71477b1581c3612972902206ac51bb621', '269d55bc0e0ff635dcaeec8533085e5eae5d25e8646dcd4b05009353c9cf9c80', 'open', '209', '110', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('64070f5aec0593962a29a141110b9239d73cd7b3', 'SQL Injection 7', 'challenge', 'Injection', '4637cae3d9b961fdff880d6d5ce4f69e91fe23db0aae7dcd4038e20ed8a287dc', '8c2dd7e9818e5c6a9f8562feefa002dc0e455f0e92c8a46ab0cf519b1547eced', 'open', '210', '110', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('7153290d128cfdef5f40742dbaeb129a36ac2340', 'Session Management Challenge 8', 'challenge', 'Session Management', '11d84b0ad628bb6e99e0640ff1791a29a1938609829ef5bdccee92b2bccd2bcd', '714d8601c303bbef8b5cabab60b1060ac41f0d96f53b6ea54705bb1ea4316334', 'open', '215', '115', '5', 0);
INSERT INTO modules (`moduleId`, `moduleName`, `moduleType`, `moduleCategory`, `moduleResult`, `moduleHash`, `moduleStatus`, `incrementalRank`, `scoreValue`, `scoreBonus`, `hardcodedKey`) VALUES ('853c98bd070fe0d31f1ec8b4f2ada9d7fd1784c5', 'CSRF 7', 'challenge', 'CSRF', '849e1efbb0c1e870d17d32a3e1b18a8836514619146521fbec6623fce67b73e8', '7d79ea2b2a82543d480a63e55ebb8fef3209c5d648b54d1276813cd072815df3', 'open', '235', '120', '5', 0);

COMMIT;

-- -----------------------------------------------------
SELECT "Data for table cheatsheet" FROM DUAL;
-- -----------------------------------------------------
SET AUTOCOMMIT=0;
USE `core`;
COMMIT;

COMMIT;
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('1ed105033900e462b26ca0685b00d98f59efcd93', '0dbea4cb5811fff0527184f99bd5034ca9286f11', '2012-02-10 10:11:53', 'Stop the request with a proxy and change the &quot;username&quot; parameter to be equal to &quot;admin&quot;');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('286ac1acdd084193e940e6f56df5457ff05a9fe1', '453d22238401e0bf6f1ff5d45996407e98e45b07', '2012-02-10 10:11:53', 'To complete the lesson, the attack string is the following:<br/>&quot;https://hostname:port/root/grantComplete/csrfLesson?userId=tempId&quot;');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('44a6af94f6f7a16cc92d84a936cb5c7825967b47', 'cd7f70faed73d2457219b951e714ebe5775515d8', '2012-02-10 10:11:53', 'Input is being filtered. To complete this challenge, enter the following attack string: <br/>&lt;iframe src=&#39;#&#39; onload=&#39;alert(&quot;XSS&quot;)&#39;&gt;&lt;/iframe&gt;');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('5487f2bf98beeb3aea66941ae8257a5e0bec38bd', '2dc909fd89c2b03059b1512e7b54ce5d1aaa4bb4', '2012-02-10 10:11:53', 'The user Ids in this challenge follow a sequence 1,3,5 etc. The Hidden Users ID is 11');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('5eccb1b8b1c033bba8ef928089808751cbe6e1f8', '94cd2de560d89ef59fc450ecc647ff4d4a55c15d', '2012-02-10 10:11:53', 'To complete this challenge, you must force another user to submit a post request. The easiest way to achieve this is to force the user to visit a custom webpage that submits the post request. This means the webpage needs to be accessable. It can be accessed via a HTTP server, a public Dropbox link, a shared file area. The following is an example webpage that would complete the challenge<br/><br/>&lt;html&gt;<br/>&lt;body&gt;<br/>&lt;form id=&quot;completeChallenge2&quot; action=&quot;https://hostname:port/user/csrfchallengetwo/plusplus&quot; method=&quot;POST&quot; &gt;<br/>&lt;input type=&quot;hidden&quot; name=&quot;userid&quot; value=&quot;exampleId&quot; /&gt;<br/>&lt;input type=&quot;submit&quot;/&gt;<br/>&lt;/form&gt;<br/>&lt;script&gt;<br/>document.forms[&quot;completeChallenge2&quot;].submit();<br/>&lt;/script&gt;<br/>&lt;/body&gt;<br/>&lt;/html&gt;<br/><br/>The class form function should be used to create an iframe that forces the user to visit this attack page.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('6924e936f811e174f206d5432cf7510a270a18fa', 'b70a84f159876bb9885b6e0087d22f0a52abbfcf', '2012-02-10 10:11:53', 'Use the login function with usernames like admin, administrator, root, etc to find administrator email accounts. Use the forgotten password functionality to change the password for the email address recovered. Inspect the response of the password reset request to see what the password was reset to. Use this password to login!');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('7382ff2f7ee416bf0d37961ec54de32c502351de', 'a4bf43f2ba5ced041b03d0b3f9fa3541c520d65d', '2012-02-10 10:11:53', 'Base 64 Decode the &quot;checksum&quot; cookie in the request to find it equals &quot;userRole=user&quot;. Change the value of userRole to be administrator instead. The cookies new value should be &quot;dXNlclJvbGU9YWRtaW5pc3RyYXRvcg==&quot; when you replace it.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('776ef847e16dde4b1d65a476918d2157f62f8c91', '5ca9115f3279b9b9f3308eb6a59a4fcd374846d6', '2012-02-10 10:11:53', 'To complete this challenge, you must force an admin to submit a post request. The easiest way to achieve this is to force the admin to visit a custom webpage that submits the post request. This means the webpage needs to be accessable. It can be accessed via a HTTP server, a public Dropbox link, a shared file area. The following is an example webpage that would complete the challenge<br/><br/>&lt;html&gt;<br/>&lt;body&gt;<br/>&lt;form id=&quot;completeChallenge3&quot; action=&quot;https://hostname:port/user/csrfchallengetwo/plusplus&quot; method=&quot;POST&quot; &gt;<br/>&lt;input type=&quot;hidden&quot; name=&quot;userid&quot; value=&quot;exampleId&quot; /&gt;<br/>&lt;input type=&quot;hidden&quot; name=&quot;csrfToken&quot; value=&quot;anythingExceptNull&quot; /&gt;<br/>&lt;input type=&quot;submit&quot;/&gt;<br/>&lt;/form&gt;<br/>&lt;script&gt;<br/>document.forms[&quot;completeChallenge3&quot;].submit();<br/>&lt;/script&gt;<br/>&lt;/body&gt;<br/>&lt;/html&gt;<br/><br/>The class form function should be used to create an iframe that forces the admin to visit this attack page.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('82c207a4e07cbfc54faec884be6db0524e74829e', '891a0208a95f1791287be721a4b851d4c584880a', '2012-02-10 10:11:53', 'To complete this challenge, move every character five places back to get the following plaintext;<br/>The result key for this lesson is the following string; mylovelyhorserunningthroughthefieldwhereareyougoingwithyourbiga');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('860e5ed692c956c2ae6c4ba20c95313d9f5b0383', 'b6432a6b5022cb044e9946315c44ab262ab59e88', '2012-02-10 10:11:53', 'To perform the CSRF correctly use the following attack string;<br/>https://hostname:port/user/redirect?to=https://hostname:port/root/grantComplete/unvalidatedredirectlesson?userid=tempId');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('945b7dcdef1a36ded2ab008422396f8ba51c0630', 'd4e2c37d8f1298fcaf4edcea7292cb76e9eab09b', '2012-02-10 10:11:53', 'Input is being filtered. To complete this challenge, enter the following attack string;<br/>&lt;input type=&quot;button&quot; onmouseup=&quot;alert(&#39;XSS&#39;)&quot;/&gt;');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('97f946ed0bbda4f85e472321a256eacf2293239d', '20e755179a5840be5503d42bb3711716235005ea', '2012-02-10 10:11:53', 'To complete this challenge, you can embed the CSRF request in an iframe very easily as follows;<br/>&lt;iframe src=&quot;https://hostname:port/user/csrfchallengeone/plusplus?userid=exampleId&quot;&gt;&lt;/iframe&gt;<br/>Then you need another user to be hit with the attack to mark it as completed.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('af5959a242047ee87f728b87570a4e9ed9417e5e', '544aa22d3dd16a8232b093848a6523b0712b23da', '2012-02-10 10:11:53', 'To complete this challenge, the following attack strings will return all rows from the table:<br/>&#39; || &#39;1&#39; = &#39;1<br/>&#39; OOORRR &#39;1&#39; = &#39;1<br/>The filter in this case does not filter alternative expressions of the boolean OR statement, and it also does not recursively filter OR, so if you enter enough nested OR statements, they will work as well.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('b8515347017439da4216c6f8d984326eb21652d0', '52c5394cdedfb2e95b3ad8b92d0d6c9d1370ea9a', '2012-02-10 10:11:53', 'The url of the result key is hidden in a div with an ID &quot;hiddenDiv&quot; that can be found in the source HTML of the lesson. User can also right click and inspect the element.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('b921c6b7dc82648f0a0d07513f3eecb39b3ed064', 'ca8233e0398ecfa76f9e05a49d49f4a7ba390d07', '2012-02-10 10:11:53', 'The following attack vector will work wonderfully;<br/>&lt;script&gt;alert(&#39;XSS&#39;)&lt;/script&gt;');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('ba4e0a2727561c41286aa850b89022c09e088b67', '0e9e650ffca2d1fe516c5d7b0ce5c32de9e53d1e', '2012-02-10 10:11:53', 'Use the password change function to send a functionality request. Stop this request with a proxy, and take the value of the &quot;current&quot; cookie. Base 64 Decode this two times. Modify the value to an administrator username such as &quot;admin&quot;. Encode this two times and change the value of the current cookie to reflect this change. Sign in as the username you set your current cookie\'\'s value to with the new password you set.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('bb94a8412d7bb95f84c73afa420ca57fbc917912', '9533e21e285621a676bec58fc089065dec1f59f5', '2012-02-10 10:11:53', 'Use a proxy to stop the request to complete the lesson. Change the value of the &quot;lessonComplete&quot; cookie to &quot;lessonComplete&quot; to complete the lesson.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('c0b869ff8a4cd1f388e5e6bdd6525d176175c296', '408610f220b4f71f7261207a17055acbffb8a747', '2012-02-10 10:11:53', "The lesson can be completed with the following attack string<br/>\' OR \'1\' = \'1");
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('c0ed3f81fc615f28a39ed2c23555cea074e513f0', '0709410108f91314fb6f7721df9b891351eb2fcc', '2012-02-10 10:11:53', 'To complete this challenge, inspect the javascript that executes when the &quot;check&quot; is performed. The encryption key is stored in the &quot;theKey&quot; parameter. The last IF statment in the script checks if the output is equal to the encrypted Result Key.<br/>So the key and ciphertext is stored in the script. You can use this informaiton to decypt the result key manually with the vigenere cipher. You can also modify the javascript to decode the key for you. To do this, make the following changes;<br/> 1) Change the line &quot;input\\_char\\_value += alphabet . indexOf (theKey . charAt (theKey\\_index));&quot; to: <br/>&quot;input\\_char\\_value -= alphabet . indexOf (theKey . charAt (theKey\\_index));&quot;<br/>This inverts the process to decrypt instead of decrypt<br/>2) Add the following line to the end of the script:<br/>$(&quot;#resultDiv&quot;).html(&quot;Decode Result: &quot; + output);');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('d0a0742494656c79767864b2898247df4f37b728', '6319a2e38cc4b2dc9e6d840e1b81db11ee8e5342', '2012-02-10 10:11:53', 'Input is being filtered. What is being filtered out is being completly removed. The filter does not act in a recursive fashion so with enough nested javascript triggers, it can be defeated. To complete this challenge, enter the following attack string;<br/>&lt;input type=&quot;button&quot; oncliconcliconcliconcliconclickkkkk=&quot;alert(&#39;XSS&#39;)&quot;/&gt;');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('d51277769f9452b6508a3a22d9f52bea3b0ff84d', 'f771a10efb42a79a9dba262fd2be2e44bf40b66d', '2012-02-10 10:11:53', 'To complete this challenge, the following attack string will return all rows from the table:<br/>test&#39;or&#39;&#39;!=&#39;2@test.com<br/>The input is validated as an email address before it is passed to the DB.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('e7e44ba680b2ab1f6958b1344c9e43931b81164a', '5dda8dc216bd6a46fccaa4ed45d49404cdc1c82e', '2012-02-10 10:11:53', 'To complete this challenge, you must craft a second statment to return Mary Martin\'\'s credit card number as the current statement only returns the customerName attribute. The following string will perform this; </br> &#39; UNION ALL SELECT creditCardNumber FROM customers WHERE customerName = &#39;Mary Martin<br/> The filter in this challenge is difficult to get around. But the \'\'UNION\'\' operator is not being filtered. Using the UNION command you are able to return the results of custom statements.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('f392e5a69475b14fbe5ae17639e174f379c0870e', '201ae6f8c55ba3f3b5881806387fbf34b15c30c2', '2012-02-10 10:11:53', 'The lesson is encoded in . Most proxy applicaitons include a decoder for this encoding.');
INSERT INTO `core`.`cheatsheet` (`cheatSheetId`, `moduleId`, `createDate`, `solution`) VALUES ('6afa50948e10466e9a94c7c2b270b3f958e412c6', '82e8e9e2941a06852b90c97087309b067aeb2c4c', '2012-02-10 10:11:53', "The user Id\'s in this challenge are hashed using MD5. You can google the ID\'s to find their plain text if you have an internet connection to find their plain text. The sequence of ID\'\'s is as follows;<br/>2, 3, 5, 7, 9, 11<br/>The next number in the sequence is 13. Modify the request with a proxy so that the id is the MD5 of 13 (c51ce410c124a10e0db5e4b97fc2af39)");
CALL cheatSheetCreate('a84bbf8737a9ca749d81d5226fc87e0c828138ee', "To complete this challenge without prior knowledge, a user must exploit an SQL injection flaw in a 'VIP Coupon Check' call. To find this function call they must deobfusticate the JavaScript file in the challenge. The address of the function is <b>challenges/8edf0a8ed891e6fef1b650935a6c46b03379a0eebab36afcd1d9076f65d4ce62VipCouponCheck</b> on the exposed server. The parameter vulnerable to SQL injection in the POST request call to this URL is <b>couponCode</b>. There is no filter in this challenge so using <b>' union select itemId, percentOff, CONCAT('This is the couponCode: ', couponCode, ' ') from vipCoupons; -- </b> as the vulnerable parameter value will retrieve the necessary coupon.");
CALL cheatSheetCreate('e0ba96bb4c8d4cd2e1ff0a10a0c82b5362edf998', "The filter in this challenge is removing all single quotes. However as there are two user parameters being utilised in the challenges login query, backslashes can be used to escape the user input's intended string context. The challenge can be completed with a user name of a <b>Backslash (\\)</b>  and a password of <b>OR 1 = 1 AND idusers = 7; -- </b> so that you are signed in as the admin user.");
CALL cheatSheetCreate('ad332a32a6af1f005f9c8d1e98db264eb2ae5dfe', "This challenge can be defeated by encoding SQL Injection attacks for \\x UTF. For Example, the following will reveal the challenges result key; <b>\\x27\\x20UNION\\x20SELECT\\x20userAnswer\\x20FROM\\x20users\\x20WHERE\\x20userName\\x20\\x3D\\x20\\x27Brendan\\x27\\x3B\\x20--\\x20</b>");
CALL cheatSheetCreate('182f519ef2add981c77a584380f41875edc65a56', 'This challenge does not require a solution to be formed in XHTML to be detected. One way to pass this challenge is to submit the following; <b>http://test\"oNmouseover=alert(123);//</b>'); 
CALL cheatSheetCreate('fccf8e4d5372ee5a73af5f862dc810545d19b176', 'This challenge does not require a solution to be formed in XHTML to be detected. One way to pass this challenge is to submit the following; <b>http://test\"\"onmouseover=alert(123);//</b>'); 
CALL cheatSheetCreate('0a37cb9296ff3763f7f3a45ff313bce47afa9384', "To guarantee completing this CSRF Challenge in a single attempt, a user must craft a CSRF attack that sends a POST request, to the request described in the challenge write up, with all of the possible CSRF tokens for the challenge. The only possible csrf tokens for this challenge are 0, 1 and 2.");
CALL cheatSheetCreate('04a5bd8656fdeceac26e21ef6b04b90eaafbd7d5', "To guarantee completing this CSRF Challenge in a single attempt, a user must craft a CSRF attack that sends a POST request, to the request described in the challenge write up, with all of the possible CSRF tokens for the challenge. The only possible csrf tokens for this challenge are c4ca4238a0b923820dcc509a6f75849b, c81e728d9d4c2f636f067f89cc14862c and eccbc87e4b5ce2fe28308fd9f2a7baf3.");
CALL cheatSheetCreate('853c98bd070fe0d31f1ec8b4f2ada9d7fd1784c5', "To complete this challenge, a user must exploit an SQL injection flaw in the 'Retrieve Token' function to retrieve another users CSRF token. This information must be utilised to launch a CSRF attack against them before they refresh the challenge page themselves. One a victim refreshes the challenge page, their token updates. Social Engineering will need to be utilised to successfully complete this challenge.");
CALL cheatSheetCreate('3d5b46abc6865ba09aaff98a8278a5f5e339abff', "View the source of this challenge and inspect the JavaScript at the end of the page. It contains two functions, and one of them is for a HTML element that is not in the level. This function is an admin function and reveals a URL very similar to the user function. Send a valid post request, as described by the JavaScript, to that URL to retrieve the result key.");
CALL cheatSheetCreate('c7ac1e05faa2d4b1016cfcc726e0689419662784', "View the source of this challenge and inspect the JavaScript at the end of the page. You can deobfusticate the JavaScript with an on line web tool, give it a Google. The script contains two functions, and one of them is for a HTML element that is not in the level. This function is an admin function and reveals a URL very similar to the user function. Send a valid post request, as described by the JavaScript, to that URL to retrieve the result key.");
CALL cheatSheetCreate('b3cfd5890649e6815a1c7107cc41d17c82826cfa', "There are a number of ways to defeat the crypto and get the encryption key in this challenge. The quickest way is to submit base64 encoded spaces. The crypto XOR's the spaces with the key and returns the resultant 'cipher text', which is the encryption key.");
CALL cheatSheetCreate('ced925f8357a17cfe3225c6236df0f681b2447c4', "Users must discover the session id for this sub application is very weak. The default session ID for a guest will be 00000001 base64'd twice. The admins session ID is TURBd01EQXdNREF3TURBd01EQXlNUT09 (00000021 when decoded).");
CALL cheatSheetCreate('c6841bcc326c4bad3a23cd4fa6391eb9bdb146ed', 'This challenge does not require a solution to be formed in XHTML to be detected. One way to pass this challenge is to submit the following; <b> http://\"\"onmouseover=alert(123);//</b>');
CALL cheatsheetCreate('53a53a66cb3bf3e4c665c442425ca90e29536edd', 'The Admin credentials are stored in plain text in a db file. Go to /data/data/insecuredata/databases and run the following command \" Strings Members\" or \"cat Members\". To get to root CLI on the VM press alt F1.');
CALL cheatsheetCreate('307f78f18fd6a87e50ed6705231a9f24cd582574', "The Admin credentials are encoded in a db file. Go to /data/data/insecuredata1/databases and cat the Users.db file. Burp has a decoder which will reveal the key, alternativly there are online tools which can also do this");
CALL cheatsheetCreate('da3de2e556494a9c2fb7308a98454cf55f3a4911', "The Admin credentials are hashed (but not salted) in a db file. Go to /data/data/insecuredata2/databases and cat the db file called Password.db. The key is a password which has been hashed using MD5, there are online tools which will attempt to crack this hashed value. ");
CALL cheatsheetCreate('335440fef02d19259254ed88293b62f31cccdd41', "The Login is vulnerable to SQL injection, Admin ' OR 1 = 1 ; -- will work in the username field and anything in the password field (So a blank field error does not occur).");
CALL cheatsheetCreate('a3f7ffd0f9c3d15564428d4df0b91bd927e4e5e4', "The login is vulnerable to SQL injection however, some input is being filtered. OR + 1 = 1 will be filtering into spaces of comments. anyOtherValue=anyOtherValue will work as well as 0r.");
CALL cheatsheetCreate('e635fce334aa61fdaa459c21c286d6332eddcdd3', "The login is vulnerable to SQL injection however there is filtering in place, to get an OR in the statement use OORR, to get a comment use -OR-. So the following statement should work: Admin ' oorr 'a' = 'a' ; -or- ");
CALL cheatsheetCreate('ef6496892b8e48ac2f349cdd7c8ecb889fc982af', "The chat has not been encrypted but encoded using hex, this can be decoded using burp or the following site:http://www.asciitohex.com/ ");
CALL cheatsheetCreate('3f010a976bcbd6a37fba4a10e4a057acc80bdc09', "The chat has been encrypted using DES. The same key is used every time and the key is stored insecurely within the app package. ");
CALL cheatsheetCreate('63bc4811a2e72a7c833962e5d47a41251cd90de3', "The chat has been encrypted using AES (with CBC mode). Multiple keys are used this time but keys are stored insecurely on the App. key 1 decrypts message 1, key 2 decrypts message 2 and so forth. ");
CALL cheatsheetCreate('2ab09c0c18470ae5f87d219d019a1f603e66f944', "The key is stored in the source code of the App, get dex2jar and use it to turn the apk to a jar file, then open the jar and find the key in the main class.");
CALL cheatsheetCreate('f16bf2ab1c1bf400d36330f91e9ac6045edcd003', "The key is stored in the source code of the App, get dex2jar and use it to turn the apk to a jar file, then open the jat. The key is present within a conditional statement in the class called Triangle.");
CALL cheatsheetCreate('9e46e3c8bde42dc16b9131c0547eedbf265e8f16', "The key is not present in the code, however a check for the key is. This can be reverse engineered and the code extracted and run as a java class. Running this java class after changing the check to print the key will reveal it.");
CALL cheatsheetCreate('1506f22cd73d14d8a73e0ee32006f35d4f234799', 'Logs are stored insecurely on the App. These contain the key. The logs can be found in a directory called \"files\" within the app package in the data/data directory. Every time the app is interacted with, new logs are generated. ');
CALL cheatSheetCreate('ed732e695b85baca21d80966306a9ab5ec37477f', "In this challenge you must craft a HTTP request to reset an admin accounts password. The HTTP request is described in the javascript contained in the challenge page (The last function in the script). The token value in this request must be a base 64 encoded date time value such as the following;<br><br> <b>Thu Aug 28 18:48:10 BST 2014</b><br><br> The token value must be less than 10 minutes from the servers time.");
CALL cheatSheetCreate('cfbf7b915ee56508ad46ab79878f37fd9afe0d27', "To complete this challenge a user must craft a CSRF attack that sends a POST request, to the request described in the challenge write up, with their CSRF token. This CSRF Token will work on any user.");
CALL cheatSheetCreate('9294ba32bdbd680e3260a0315cd98bf6ce8b69bd', "The first step in completing this challenge is to get an admin user's email address. Try to sign in as 'root' or 'superuser' to get one. To complete this challenge a user must use SQL Injection in the email Parameter in the GET request to the SecretQuestion servlet. The following email submission will achieve the response of the users secret answer (This example is URL Encoded)<br><br/>&quot;UNION+SELECT+secretAnswer+FROM+users+WHERE+userName=&quot;<b>root</b><br><br>You can then use this answer along with a user email address to complete the level.");
CALL cheatSheetCreate('7153290d128cfdef5f40742dbaeb129a36ac2340', "To complete this challenge a user must send the server a request with the 'challengeRole' value set to 'nmHqLjQknlHs'. The challengeRole cookie is encoded with ATOM-128. The value 'nmHqLjQknlHs' when decoded is 'superuser'.");
CALL cheatSheetCreate('145111e80400e4fd48bd3aa5aca382e9c5640793', "To complete this challenge a user must deobfusticate the javascript found in /couponCheck.js and extract the relevent cryptoinformation to manually decrypt a javascript array of encrypted coupons, or to manipulate the javascript so that it returns the decrypted coupons. The Coupon code for free trolls is <b>e!c!3etZoumo@Stu4rU176</b>");
CALL cheatSheetCreate('adc845f9624716eefabcc90d172bab4096fa2ac4', "To complete this challenge, a SQL Injection Flaw must be exploited to learn the name of the super admin. The injection is performed through the BASE64 encoded cookie named 'currentPerson'. a simple &quot;or&quot;1&quot;!=&quot;0 vector will work. take the super admin's name and submit it encoded for BASE64 as the currentPerson cookie value in the request that is submitted when the Admin button is clicked. This will return the result key for the challenge.");
CALL cheatSheetCreate('64070f5aec0593962a29a141110b9239d73cd7b3', "To complete this challenge, a SQL injection flaw must be exploited. The vulnerable paramater is 'subUserEmail'. It must be mostly well formed as an email address to get past the validation process. The following vector, which is URL encoded, will sign the user in as user 1. <br><br><b>'or'1'='1'union%0aselect%0auserName%0afrom%0ausers%0awhere''!='%40v</b>");
CALL cheatSheetCreate('1e3c02ad49fa9a9e396a3b268d7da8f0b647d8f9', "To complete this challenge, connect the android debug bridge to the VM and run  adb logcat –d \<file location\> to dump logs to a text file. Trigger the key log by pressing the lotto button");
CALL cheatSheetCreate('f40b0cd5d45327c9426675313f581cf70c7c7c28', "To complete this challenge, start the app, go to the command line of the VM using ALT F1 and then navigate to /sdcard/, pictorial logs are places there. Connect adb to the device and run the adb pull command on the logs. ");
CALL cheatSheetCreate('ba6e65e4881c8499b5e53eb33b5be6b5d0f1fb2c', "To complete this challenge, start the app, and login to get the key. you must login with an auth code. the code must be odd, must contain the numbers 2 and 4 and must be six digits long. previous codes may show up in a suggestion when typing the code in which will reveal this pattern.");
CALL cheatSheetCreate('52885a3db5b09adc24f38bc453fe348f850649b3', "To complete this challenge, find jarsigner which comes with the jdk and in a command line run the following:  jarsigner -verify -verbose -certs ReverseEngineer2.apk.");
CALL cheatSheetCreate('3b1af0ad239325bf494c6e606585320b31612e72', "To complete this challenge, use adb pull to grab the key file and the key.db file from the app's /data/data/ directory. With the db password: Pa88w0rd1234 decrypt the database to get the key to the level. This will either require a small amount of coding or you can download and build sqlcipher. Finally there is an App on the playstore which can be used called SQLCipher Decrypt.");
CALL cheatSheetCreate('0cdd1549e7c74084d7059ce748b93ef657b44457', "To complete this challenge, you need to login to the App. The password reset function rquires two answers which can be gathered from the logs on the App. The answers are chicken and meade. This will reset the password to a six digit code and allow you to login and view the key.");
CALL cheatSheetCreate('368491877a0318e9a774ba5d648c33cb0165ba1e', "This challenge requires a bit of thinking to complete organically. First you must find some admin email addresses. The login function will return them when valid usernames are submitted. Try using root or superuser with any password. Use the email address in the secret question function to get that user's Secret Question. The secret question for each user is 'What is your favourite flower?'. There are only so many flowers. Any of the following flowers are valid answers. Root's favourite flower is 'Franklin Tree'. <br><br> Valid answers: Jade Vine, Corpse Flower, Gibraltar Campion, Franklin Tree, Middlemist Red, Chocolate Cosmos or Ghost Orchid");
CALL cheatSheetCreate('6be5de81223cc1b38b6e427cc44f8b6a28d2bc96', "The shopping cart application does not validate the number of items you are buying. Set the troll amount to 1, rageAmount to 0, notBadAmount to 0 and the MeGusta Amount to -101. ");
CALL cheatSheetCreate('3b14ca3c8f9b90c9b2c8cd1fba9fa67add1272a3', "The shopping cart application only ensures that the amount of items bought is a positive number. By buying 999295724 trolls, the total cost integer value will overflow and enter a negative state.");
CALL cheatSheetCreate('b9d82aa7b46ddaddb6acfe470452a8362136a31e', "Enter a valid number in the submit box and click submit number. Capture the request in a HTTP proxy and modify the number to a negative value.");
CALL cheatSheetCreate('bf847c4a8153d487d6ec36f4fca9b77749597c64', "Sign into the application with the generic admin default combination of 'admin' and 'password'.");
CALL cheatSheetCreate('fcc2558e0a23b8420e173cf8029876cb887408d3', "To complete this challenge, you must force another user to submit a post request which contains a JSON payload. The easiest way to achieve this is to force the user to visit a custom web page that submits the post request. This means the web page needs to be accessible. It can be accessed via a HTTP server, a public Dropbox link, a shared file area. It is possible to use HTML forms to submit cross domain POST requets with JSON payloads by setting the <b>enctype</b> attribute to text/plain and then forming the JSON payload around the necessary equals symbol which normally deliminates the parameter name from the parameter value. The following is an example web page that would complete the challenge<br/><br/>&lt;html&gt;<br/>&lt;body&gt;<br/>&lt;form id=&quot;completeChallengeJson&quot; enctype=&quot;text/plain&quot; action=&quot;https://hostname:port/user/csrfchallengetwo/plusplus&quot; method=&quot;POST&quot; &gt;<br/>&lt;input type=&quot;hidden&quot; name=&#x27;{&quot;userId&quot;:&quot;exampleId&quot;,&quot;&#x27; value=&#x27;&quot;,&quotend&quote}&#x27;><br/>&lt;/form&gt;<br/>&lt;script&gt;<br/>document.forms[&quot;completeChallengeJson&quot;].submit();<br/>&lt;/script&gt;<br/>&lt;/body&gt;<br/>&lt;/html&gt;<br/><br/>The class form function should be used to create an iframe that forces the user to visit this attack page.");
CALL cheatSheetCreate('6158a695f20f9286d5f12ff3f4d42678f4a9740c', "To complete this challenge, you must be able to capture the traffic of another user. The simplest way to simulate this would be to create a second user account and open it in a separate browser and open this challenge. You could then just steal the cookie straight from the browser. To demo how to solve this as expected you would actually open Wireshark and record the 2nd user opening the challenge. Filter the network capture for ip.dst == ShepherdInstanceIp, and find the unencrypted HTTP packet. Right click it and select 'Follow TCP stream'. You'll see the cookie in that dialog. <br><br> Once you have the token collected, in your original browser, click the button and intercept the request with a Proxy. Replace your cookie value with the one you collected from another user.");
CALL cheatSheetCreate('de626470273c01388629e5a56ac6f17e2eef957b', "To complete this challenge you must first register an account. The account must have a unique name. The next step is to click the refresh balance button. Capture this request, and replay it with different account numbers until you find one with cash. If you are the first person to attempt this challenge, the account number 1 should have 10 million in it. Take note of the account number that has cash. Now fill out the 'Transfer Funds' form with any data. Capture that requets and change the receiver account number parameter to the value the sender account number parameter is currently equal to (This is your account number), change the sender account number to the identifier you noted earlier and set the transfer amount to as high as possible (must be some money left in account to work). Keep doing this untill your account has more than 5 million in it. Then open the level again or sign in / out of the account to get the result key");
CALL cheatSheetCreate('dc89383763c68cba0aaa1c6f3fd4c17e9d49a805', "The following attack vectors will expose the result key over two queries.<br><br>Step One: <b>test' AND (SELECT 7303 FROM(SELECT COUNT(*),CONCAT(0x716b6a7671,(SELECT MID((IFNULL(CAST(comment AS CHAR),0x20)),1,50) FROM sqlchalstoredproc.customers ORDER BY customerId LIMIT 2,1),0x71786b7a71,FLOOR(RAND(0)*2))x FROM INFORMATION_SCHEMA.CHARACTER_SETS GROUP BY x)a) AND 'hdTL'='hdTL</b><br><br>This will return an error revealing the first part of the key in the message with <b>qxkzq1</b> added to the end for padding. remove those characters and record the rest of the key revealed. <br><br>Step Two: <b>test' AND (SELECT 9441 FROM(SELECT COUNT(*),CONCAT(0x716b6a7671,(SELECT MID((IFNULL(CAST(comment AS CHAR),0x20)),51,50) FROM sqlchalstoredproc.customers ORDER BY customerId LIMIT 2,1),0x71786b7a71,FLOOR(RAND(0)*2))x FROM INFORMATION_SCHEMA.CHARACTER_SETS GROUP BY x)a) AND 'ilGf'='ilGf</b><br><br>This will reveal the second part of the key, padded with <b>qkjvq</b> at the start and <b>qxkzq1</b> at the end. Remove the padding and add the rest to the previously revealed part of the result key. That is the key to solve this challenge.");
CALL cheatSheetCreate('5b461ebe2e5e2797740cb3e9c7e3f93449a93e3a', "Connect to the device via adb and run the following command - adb shell content query --uri content://com.somewhere.hidden.SecretProvider/data");

COMMIT;

-- Default admin user

call userCreate(null, 'admin', 'password', 'admin', 'admin@securityShepherd.org', true);

-- Enable backup script

SELECT "Creating BackUp Schema" FROM DUAL;

DROP DATABASE IF EXISTS backup;
CREATE DATABASE backup; 

SET GLOBAL event_scheduler = ON;
SET @@global.event_scheduler = ON;
SET GLOBAL event_scheduler = 1;
SET @@global.event_scheduler = 1;

USE core;
DELIMITER $$

drop event IF EXISTS update_status;

create event update_status
on schedule every 1 minute
do

BEGIN

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

drop table IF EXISTS `backup`.`users`;
drop table IF EXISTS `backup`.`class`;
drop table IF EXISTS `backup`.`modules`;
drop table IF EXISTS `backup`.`results`;
drop table IF EXISTS `backup`.`cheatsheet`;
drop table IF EXISTS `backup`.`sequence`;
-- -----------------------------------------------------
-- Table `core`.`class`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `backup`.`class` (
  `classId` VARCHAR(64) NOT NULL ,
  `className` VARCHAR(32) NOT NULL ,
  `classYear` VARCHAR(5) NOT NULL ,
  PRIMARY KEY (`classId`) )
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `core`.`users`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `backup`.`users` (
  `userId` VARCHAR(64) NOT NULL ,
  `classId` VARCHAR(64) NULL ,
  `userName` VARCHAR(32) NOT NULL ,
  `userPass` VARCHAR(512) NOT NULL ,
  `userRole` VARCHAR(32) NOT NULL ,
  `badLoginCount` INT NOT NULL DEFAULT 0 ,
  `suspendedUntil` DATETIME NOT NULL DEFAULT '1000-01-01 00:00:00' ,
  `userAddress` VARCHAR(128) NULL ,
  `tempPassword` TINYINT(1)  NULL DEFAULT FALSE ,
  `userScore` INT NOT NULL DEFAULT 0 ,
  PRIMARY KEY (`userId`) ,
  INDEX `classId` (`classId` ASC) ,
  UNIQUE INDEX `userName_UNIQUE` (`userName` ASC) ,
  CONSTRAINT `classId`
    FOREIGN KEY (`classId` )
    REFERENCES `backup`.`class` (`classId` )
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `core`.`modules`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `backup`.`modules` (
  `moduleId` VARCHAR(64) NOT NULL ,
  `moduleName` VARCHAR(64) NOT NULL ,
  `moduleType` VARCHAR(16) NOT NULL ,
  `moduleCategory` VARCHAR(64) NULL ,
  `moduleResult` VARCHAR(256) NULL ,
  `moduleHash` VARCHAR(256) NULL ,
  `incrementalRank` INT NULL ,
  `scoreValue` INT NOT NULL DEFAULT 50 ,
  `scoreBonus` INT NOT NULL DEFAULT 5 ,
  PRIMARY KEY (`moduleId`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `core`.`results`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `backup`.`results` (
  `userId` VARCHAR(64) NOT NULL ,
  `moduleId` VARCHAR(64) NOT NULL ,
  `startTime` DATETIME NOT NULL ,
  `finishTime` DATETIME NULL ,
  `csrfCount` INT NULL DEFAULT 0 ,
  `resultSubmission` LONGTEXT NULL ,
  `knowledgeBefore` INT NULL ,
  `knowledgeAfter` INT NULL ,
  `difficulty` INT NULL ,
  PRIMARY KEY (`userId`, `moduleId`) ,
  INDEX `fk_Results_Modules1` (`moduleId` ASC) ,
  CONSTRAINT `fk_Results_users1`
    FOREIGN KEY (`userId` )
    REFERENCES `backup`.`users` (`userId` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Results_Modules1`
    FOREIGN KEY (`moduleId` )
    REFERENCES `backup`.`modules` (`moduleId` )
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `core`.`cheatsheet`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `backup`.`cheatsheet` (
  `cheatSheetId` VARCHAR(64) NOT NULL ,
  `moduleId` VARCHAR(64) NOT NULL ,
  `createDate` DATETIME NOT NULL ,
  `solution` LONGTEXT NOT NULL ,
  PRIMARY KEY (`cheatSheetId`, `moduleId`) ,
  INDEX `fk_CheatSheet_Modules1` (`moduleId` ASC) ,
  CONSTRAINT `fk_CheatSheet_Modules1`
    FOREIGN KEY (`moduleId` )
    REFERENCES `backup`.`modules` (`moduleId` )
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `core`.`sequence`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `backup`.`sequence` (
  `tableName` VARCHAR(32) NOT NULL ,
  `currVal` BIGINT(20) NOT NULL DEFAULT 282475249 ,
  PRIMARY KEY (`tableName`) )
ENGINE = InnoDB;



Insert into `backup`.`class` (Select * from `core`.`class`);
Insert into `backup`.`users` (Select * from `core`.`users`);
Insert into `backup`.`modules` (Select * from `core`.`modules`);
Insert into `backup`.`results` (Select * from `core`.`results`);
Insert into `backup`.`cheatsheet` (Select * from `core`.`cheatsheet`);
Insert into `backup`.`sequence` (Select * from `core`.`sequence`);

END $$

DELIMITER ;
